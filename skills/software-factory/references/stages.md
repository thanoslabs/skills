# Stages

Each stage lists what to do, the commands involved, and the exit check
that must hold before moving on. `$DIR` is the item's state directory
(`scripts/factory.sh dir <id>`); `$WT` is `$DIR/worktree`.

Write `state.json` after every stage transition, checkpoint, and
escalation — never only at the end of a turn.

## 1. Define

Turn the source into `$DIR/spec.md` using
[../assets/spec.md](../assets/spec.md).

**From an issue** (`#123`, `owner/repo#123`, or an issue URL):

```sh
gh issue view 123 --json number,title,body,labels,assignees,state,comments,url
```

- If the issue is closed, or assigned to someone other than the current
  user (`gh api user --jq .login`), stop and ask before continuing.
- Set `id` to `issue-<n>` and `source` to the issue.
- Copy acceptance criteria verbatim when present; otherwise derive them
  from the issue and mark them *derived* in the spec.

**From a description:** set `id` to a 2–4 word kebab-case slug and
`source.type` to `user-input`. Write the spec from what the user said.
Ask questions only for gaps that would change the implementation.

**Readiness check** — escalate (see SKILL.md) instead of continuing if:

- No acceptance criterion can be stated as something a test or reviewer
  could check.
- The work is too large for one PR. Propose a split as a list of
  independently mergeable items, each a candidate spec.

Create `$DIR` and an initial `state.json`. Exit check: `spec.md` exists
with at least one testable acceptance criterion.

## 2. Plan

1. `git fetch origin` and determine the base branch
   (`org-defaults` → host `AGENTS.md` → `gh repo view --json defaultBranchRef`).
2. Explore the repo read-only: conventions, related code, tests, CI
   config. Find how to run tests, lint, and type checks — record the
   exact commands in the plan.
3. Write `$DIR/plan.md` using [../assets/plan.md](../assets/plan.md):
   ordered small tasks, each with its own verification step, plus risks.
4. Choose the branch name per `pr-commit-conventions`
   (`<type>/<short-kebab-description>`; include the issue number when
   there is one, e.g. `fix/123-token-refresh-race`). Record it as
   `branch` — do not create it yet.

**Checkpoint: plan.** Present the spec and plan together.

After approval, if publishing and the source is an issue: assign the
current user (`gh issue edit <n> --add-assignee @me`), add the
`in-progress` label unless `scripts/factory.sh missing-labels` lists it,
and comment the plan on the issue.

## 3. Build

```sh
git worktree add -b "$BRANCH" "$WT" "origin/$BASE"
```

1. Work task by task through `plan.md`, in `$WT` only.
2. Where the repo has tests, write or update the test for a behavior
   before implementing it.
3. Commit each logical change per `pr-commit-conventions`. Reference the
   issue in the body (`Refs #123`) only when the source is an issue.
4. **Verify:** run the plan's test, lint, and type-check commands.
   On failure, fix and re-run; increment `attempts.verify` per failed
   run. At 3, escalate.
5. If the plan turns out wrong mid-build, update `plan.md` and note the
   deviation — in gated mode, stop and present the revised plan before
   continuing.

Exit check: all plan tasks done, worktree clean, verification passing
(or failures explicitly accepted by the user).

**Checkpoint: build.** Present `git diff --stat origin/$BASE...HEAD`,
the commit list, verification results, and any plan deviations.

## 4. Review

1. Review the full diff against `spec.md` with **fresh context**: spawn
   a subagent with no conversation history if the agent supports it,
   giving it only the spec, the plan, the diff, and the repo. Otherwise
   re-read the diff from scratch as a skeptical reviewer.
2. The reviewer reports in three groups:
   - **Blockers** — bugs, unmet acceptance criteria, security issues,
     missing tests for new behavior.
   - **Important** — meaningful but non-blocking problems.
   - **Nits** — style and cleanup.
3. Write the findings to `$DIR/review.md`, marking each as fixed,
   accepted, or open. Fix all blockers, re-verify, and re-review once.
   Fix important issues where cheap; leave the rest open for the human.
4. Write `$DIR/pr-body.md` in the `pr-commit-conventions` PR format.
   Include `Closes #<n>` when the source is an issue. The Testing section
   lists exactly what was run and its result.
5. Get the release label: `scripts/factory.sh release-label "<title>"`.
   If the title isn't Conventional Commits, fix the title. Check it
   against `scripts/factory.sh missing-labels`; if the repo lacks it, add
   a warning to the PR body's Notes section.
6. Run the `pr-commit-conventions` "Before Requesting Review" checklist.

**Checkpoint: review.** Present `review.md` (fixed and remaining), the
PR title, the release label, and `pr-body.md`. This is the last checkpoint before anything
is pushed.

## 5. Publish

Skip with `--local-only`; go straight to Handoff.

```sh
git -C "$WT" fetch origin
git -C "$WT" rebase "origin/$BASE"          # unpublished branch: rebase is fine
# re-run verification if the rebase brought in changes
git -C "$WT" push -u origin "$BRANCH"
gh pr create --head "$BRANCH" --base "$BASE" --title "<title>" \
  --body-file "$DIR/pr-body.md" --label "<release label>"
```

Omit `--label` if the repo lacks the release label — `gh pr create`
fails on unknown labels.

Record `pr.number` and `pr.url`. Reviewers are requested by CODEOWNERS;
request others only if `org-defaults` or the host repo says to.

## 6. Shepherd

One pass per invocation — see [shepherding.md](shepherding.md). After
the pass, re-run `factory.sh status`; if still `shepherd`, report what
is pending (CI running, awaiting review) and stop. The user can re-run
later or schedule repeats with their agent's loop or scheduling feature.

No checkpoints here: fixes go to the PR, where reviewers see them.

## 7. Handoff

**Local-only:** set `awaiting: human-push` and print:

```sh
git -C <worktree> push -u origin <branch>
gh pr create --head <branch> --base <base> --title "<title>" \
  --body-file <state-dir>/pr-body.md --label <release label>
```

Omit `--label` if the repo lacks the release label, and tell the user
to set the release label by hand.

If the user later opens the PR and resumes with `--publish`, shepherding
picks up from there.

**Published:** when `derived_stage` is `ready-to-merge`, add the
`ready-to-merge` label to the PR, set
`awaiting: human-merge`, and report the PR URL. Do not merge.

## 8. Close out

When the PR is merged or closed (or on `abandon`):

```sh
git worktree remove "$WT"                  # refuses if dirty — report, don't force
git branch -d "$BRANCH"                    # merged only; -d refuses unmerged work
rm -rf "$DIR"
```

On `abandon` of a published item, do not close the PR or delete the
remote branch — tell the user they exist. Keep the local branch on
abandon unless the user says otherwise.
