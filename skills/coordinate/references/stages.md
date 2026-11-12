# Stages

Each stage lists who does it, what to do, and the exit check that must
hold before moving on. `$DIR` is the item's state directory
(`scripts/coordinate.sh dir <id>`); `$WT` is `$DIR/worktree`. Worker
roles, the prompt header, and how to check results are in
[workers.md](workers.md).

Write `state.json` after every stage transition, checkpoint, and
escalation - never only at the end of a turn.

## 1. Clarify (coordinator)

Goal: understand the work well enough that a worker with no conversation
history could plan it from `spec.md` alone. You do this yourself; do not
delegate the conversation with the user.

### 1a. Resolve the source

**Jira ticket** (`PROJ-123`, or a URL containing `/browse/PROJ-123`):

- Read the ticket with whatever Jira access exists, in this order: a
  Jira/Atlassian MCP tool (e.g. `jira_get_issue`), `acli jira workitem view
  PROJ-123 --json`, `jira issue view PROJ-123 --plain`. Read the summary,
  description, acceptance criteria, comments, status, assignee, parent or
  epic, and linked issues.
- Record `ticket` as `{key, url, title}` (`url` may be null if no tool
  returned it).
- If the ticket is Done/Closed, or assigned to someone else, ask before
  continuing.
- No Jira access: ask the user to paste the summary, description, and
  acceptance criteria. Keep the key so branches and PRs still carry it.

**GitHub issue** (`#123`, `owner/repo#123`, URL):

```sh
gh issue view 123 --json number,title,body,labels,assignees,state,comments,url
```

If the issue is closed or assigned to someone else, ask before
continuing. If the issue body names a Jira key, treat it as the ticket too.

**Description:** look for a Jira key in what the user said. If there is
none, ask once whether the work has a ticket, with these options:

1. They give a key - resolve it as above.
2. Create one - only with `--publish` and only on an explicit yes. Ask for
   the project key and issue type if not obvious, create it with a summary
   and description drawn from the spec, and show the resulting key.
3. No ticket - continue without one.

### 1b. Understand the work

1. Explore the target repo(s) read-only, enough to know where the change
   lands and what it touches: structure, related code, tests, conventions.
   For a wide sweep, delegate a read-only search to a subagent and keep
   only its conclusions.
2. List every unknown. For each, decide:
   - **Would the answer change what gets built or how it's accepted?**
     Ask the user.
   - **Can the code, ticket, or docs answer it?** Look it up; don't ask.
   - **Neither?** Make the conventional choice and record it under
     Assumptions in the spec.
3. Ask in rounds of at most 4 questions. Each question must stand on its
   own, offer concrete options, and lead with your recommended option.
   Use a structured question tool if the agent has one.
4. Repeat until no open question would change the implementation.

### 1c. Split into parts

One part per independently reviewable concern. Split when the work has
multiple independent concerns or would exceed roughly 400 changed lines
of hand-written code. For each part, decide:

- a 2-4 word kebab slug (also used in the branch name)
- a few-word summary for the PR announcement (e.g. "add backoff config")
- its repo, if the group spans repos
- dependencies: prefer independent parts. If part B needs part A, B's
  base is A's branch (a stacked PR); say so in both specs.

### 1d. Write the spec(s)

For each part, create `$DIR`, an initial `state.json` (with `group`,
`part`, `summary`, `ticket`), and `$DIR/spec.md` from
[../assets/spec.md](../assets/spec.md). Copy acceptance criteria verbatim
from the ticket or issue when present; otherwise derive them and mark
them *(derived)*.

Exit check: every part's `spec.md` has at least one testable acceptance
criterion and no open questions that would change the implementation.

**Checkpoint: clarify.** Present the parts (slug, summary, repo,
dependencies), each spec's goal and acceptance criteria, the assumptions
made, and the planned branch names. This is where the user corrects the
scope before any worker runs.

## 2. Plan (planner)

1. `git fetch origin` and determine the base branch (`org-defaults` →
   host `AGENTS.md` → `gh repo view --json defaultBranchRef`), or the
   parent part's branch for a stacked part. Record `base`.
2. Work out the branch name per "Branch names" in `SKILL.md` and record
   it as `branch` (don't create it yet).
3. Spawn a **planner** (`coordinate-planner`). It writes `$DIR/plan.md`
   from [../assets/plan.md](../assets/plan.md) and replies with its
   first line.
4. Check the plan (see [workers.md](workers.md#checking-worker-results)):
   every acceptance criterion is covered by a task with a verification
   step, and the test/lint/type-check commands are concrete.
5. Record the plan's commands in `state.json` as `checks`, skipping any
   marked "none configured":
   `[{"name": "tests", "command": "<cmd>"}, ...]`. These are what
   `coordinate.sh checks` runs; they live outside the repo, so the
   branch can't change them.

**Checkpoint: plan.** Present the spec and plan together, including the
exact check commands - they will be run as shell commands.

After approval, if publishing and the source is a GitHub issue: assign
the current user (`gh issue edit <n> --add-assignee @me`), add the
`in-progress` label if the repo has it, and comment the
plan on the issue.

## 3. Build (builder)

You create the branch and worktree, so names are always right:

```sh
git worktree add -b "$BRANCH" "$WT" "origin/$BASE"   # stacked part: use the parent branch
```

Spawn a **builder** (`coordinate-builder`, named `builder-<id>`). It
works task by task through `plan.md` in `$WT` only, commits per
`pr-commit-conventions` with the header's ticket reference, runs the
checks, writes `$DIR/build.md`, and replies with its first line.

Then check it yourself, and run the checks - the builder's own claims
don't count:

```sh
git -C "$WT" status --porcelain                 # must be empty
git -C "$WT" log --oneline "origin/$BASE"..HEAD # commits match build.md
scripts/coordinate.sh checks <id>               # writes checks.md; exit 1 on failure
```

- `STATUS: BLOCKED`: read `build.md`'s Blocked section and escalate, or
  answer it if the spec already settles it.
- `CHECKS: FAIL`: send the builder `Address the failures in checks.md.`
  Increment `attempts.verify` per failed run; at 3, escalate.
- Plan deviations: the builder records them in `plan.md`. In gated mode,
  present a revised plan before letting the builder continue.

Exit check: all plan tasks done, worktree clean, checks passing (or
failures explicitly accepted by the user).

**Checkpoint: build.** Present the diff stat, the commit list, the check
results, and any plan deviations.

## 4. Validate (validator)

Validate starts only once `checks.md` says `CHECKS: PASS` for the
current HEAD; the validator judges the code, not whether it compiles.

1. Spawn a **validator** (`coordinate-validator`) - a fresh agent that
   never saw the build. It reads `checks.md`, verifies each acceptance
   criterion with evidence, reviews the diff, writes `$DIR/review.md`
   with findings grouped as **Blockers**, **Important**, and **Nits**,
   and replies with its first line.
2. On `VERDICT: BLOCKERS`, send the builder `Address the open blockers
   in review.md.`, re-run `coordinate.sh checks`, then spawn a new
   validator once more. Still blocked after that: escalate.
3. Fix important findings where cheap (via the builder); leave the rest
   marked open for the human. Mark each finding fixed, accepted, or open.
4. Write the PR title (Conventional Commits, same type as the branch
   when the branch uses a type prefix) and `$DIR/pr-body.md` from
   [../assets/pr-body.md](../assets/pr-body.md).
5. Pick the release label from the title (see Labels in `SKILL.md`) and
   check that the repo has it.
6. Run the `pr-commit-conventions` "Before Requesting Review" checklist,
   except its PR description structure (overridden below).

**Checkpoint: validate.** Present `review.md` (fixed and remaining), the
check results, the PR title, the release label (or that it is missing),
and `pr-body.md`. This is the last checkpoint before anything is pushed.

### PR description (override)

PRs opened by this skill use a **brief** description instead of the
`pr-commit-conventions` four-section structure: at most two sentences
saying what changed and why, then a ticket line. Test results, review
findings, and notes go in the checkpoint and handoff reports, not the PR.

## 5. Publish (coordinator)

Skip with `--local-only`; go to Handoff.

```sh
git -C "$WT" fetch origin
git -C "$WT" rebase "origin/$BASE"          # unpublished branch: rebase is fine
scripts/coordinate.sh checks <id>           # again if the rebase brought in changes
git -C "$WT" push -u origin "$BRANCH"
gh pr create --draft --head "$BRANCH" --base "$BASE" --title "<title>" \
  --body-file "$DIR/pr-body.md" --label "<release label>"
```

Omit `--label` if the repo lacks the release label - `gh pr create` fails
on unknown labels. Record `pr` as `{number, url, draft: true}`.

Do not request reviewers: draft PRs are not ready for review. When the
PR is marked ready, CODEOWNERS requests reviewers.

## 6. Report (coordinator)

After publishing, get the group's PRs and hand them to the
`change-comms` skill as a **review request**:

```sh
scripts/coordinate.sh prs <group>
# {"group", "ticket": {key, title, url} | null,
#  "prs": [{url, summary, title, draft}],     ordered by part
#  "pending": [{id, summary}]}                parts with no PR yet
```

Pass `prs` in the given order, with each `summary`, the ticket as the
header, and `pending` as not yet published. Present the result in a
fenced block. `/coordinate comms` reprints it at any time.

## 7. Shepherd (coordinator + builder)

For each open PR in play, run one pass of the `pr-shepherd` skill with:

- the PR number, and the item's worktree `$WT` as the checkout
- the check commands from `plan.md`
- a builder subagent as the implementer (see
  [workers.md](workers.md)): you triage, the builder makes
  code changes, you check its result

Then, from the pass report:

- `ci` fixed this pass → increment `attempts.ci`; CI green → reset it to
  0. At 3 consecutive, escalate.
- Changes pushed in response to a review → increment
  `attempts.review_rounds`. At 5, escalate.
- "Stopped for human" → escalate with the pass's reason.
- If the PR has `ready-to-merge` but the pass found new failures,
  comments, or conflicts, remove the label.

Re-run `coordinate.sh status`; if still `shepherd`, report what is
pending and stop. The user can re-run later or schedule repeats.

No checkpoints here: fixes go to the PR, where reviewers see them.

### `/coordinate ready <id>`

Only on the user's request: confirm checks are green or explain why not,
then `gh pr ready <n>` and set `pr.draft` to false. CODEOWNERS reviewers
are requested by GitHub at this point.

## 8. Handoff (coordinator)

**Local-only:** set `awaiting: human-push` and print, per item:

```sh
git -C <worktree> push -u origin <branch>
gh pr create --draft --head <branch> --base <base> --title "<title>" \
  --body-file <state-dir>/pr-body.md --label <release label>
```

Omit `--label` if the repo lacks the release label, and tell the user to
set it by hand. Tell them to resume with `--publish` once the PRs exist;
the PRs are then recorded and `/coordinate comms` prints the announcement.

**Draft PR open:** report the PR URL, check status, and that marking it
ready is theirs (or `/coordinate ready <id>`).

**Published and ready:** when `derived_stage` is `ready-to-merge`, add the
`ready-to-merge` label, set `awaiting: human-merge`, and report the PR URL.
Do not merge.

## 9. Close out (coordinator)

When the PR is merged or closed (or on `abandon`):

```sh
git worktree remove "$WT"                  # refuses if dirty - report, don't force
git branch -d "$BRANCH"                    # merged only; -d refuses unmerged work
rm -rf "$DIR"
```

On `abandon` of a published item, do not close the PR or delete the
remote branch - tell the user they exist. Keep the local branch on
abandon unless the user says otherwise. Never change the Jira ticket's
status.
