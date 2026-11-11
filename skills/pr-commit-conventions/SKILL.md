---
name: pr-commit-conventions
description: >
  Conventions for branches, commit messages, and pull requests. Use whenever
  committing changes, writing a commit message, creating a branch, opening or
  updating a pull request, or when the user asks to "commit this", "open a PR",
  "push my changes", or "clean up my commits". Apply before running any
  git commit / gh pr create command.
---

# PR & Commit Conventions

Follow these conventions for every branch, commit, and pull request.
Where a rule conflicts with an explicit user instruction, the user wins.

## Branches

1. Never commit directly to `main` or `master`. If on the default branch,
   create a branch before committing.
2. Name branches `<prefix>/<TICKET>-<short-kebab-description>`:
   - `<prefix>` is the value of the `GIT_BRANCH_PREFIX` environment
     variable when set (a personal namespace, e.g. `jonathann`; check with
     `echo "$GIT_BRANCH_PREFIX"`), otherwise the change type (`feat`,
     `fix`, ...).
   - `<TICKET>-` is the ticket ID exactly as the tracker writes it
     (`PROJ-123`, or `123` for a GitHub issue). Omit it, including the
     dash, when there is no ticket. Never invent one.
   - The description is 2-4 lowercase kebab-case words, at most 40
     characters.

   | `GIT_BRANCH_PREFIX` | Ticket | Branch |
   |---|---|---|
   | unset | none | `feat/webhook-retries` |
   | unset | `#123` | `fix/123-auth-token-refresh` |
   | `jonathann` | `PROJ-123` | `jonathann/PROJ-123-webhook-retries` |
   | `jonathann` | none | `jonathann/bump-go-version` |
3. Keep one concern per branch. If the work has drifted into a second
   concern, tell the user and suggest splitting rather than piling on.

## Commit Messages

Use the [Conventional Commits](https://www.conventionalcommits.org) format:

```
<type>(<optional scope>): <subject>

<optional body>
```

Rules:

1. **Type** is one of: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`,
   `perf`, `ci`. Breaking changes append `!` after the type: `feat!:`.
2. **Subject**: imperative mood ("add", not "added" or "adds"), lowercase,
   no trailing period, ≤ 72 characters.
3. **Body**: explain *why*, not what — the diff already shows what. Include
   a body whenever the reason for the change isn't obvious from the subject.
4. One logical change per commit. Do not mix refactors with behavior
   changes, or formatting-only noise with either.
5. Never fabricate ticket references. Include a ticket ID in the body
   (e.g. `Refs: PROJ-123`) only when the user provided one or it is
   visible in the branch name.

Examples:

```
feat(webhooks): add exponential backoff to delivery retries

Deliveries to slow consumers were exhausting the worker pool.
Backoff caps at 5 attempts over ~10 minutes.
```

```
fix(auth): prevent token refresh race on concurrent requests
```

Bad (and why):

- `fixed stuff` — no type, past tense, says nothing
- `feat: update code and fix tests and reformat` — three concerns in one commit
- `refactor(api): Rewrote the handler.` — past tense, capitalized, trailing period

## Pull Requests

1. **Title** follows the same format as a commit subject
   (`feat(webhooks): add delivery retries`). If the PR will be
   squash-merged, the title becomes the commit — write it to that standard.
2. **Description** uses this structure:

   ```markdown
   ## Summary
   What changed, in 1–3 sentences.

   ## Motivation
   Why this change is needed. Link the issue/ticket if one exists.

   ## Testing
   What was actually run and its result (commands, test names).
   State plainly if something could not be verified.

   ## Notes
   Tradeoffs, known limitations, follow-up work. Omit if none.
   ```

3. Keep PRs focused on a single concern and reviewable in one sitting.
   If the diff exceeds roughly 400 changed lines of hand-written code,
   suggest splitting it.
4. Include screenshots or terminal output for UI-visible or CLI-visible
   changes.
5. Report testing honestly: if tests fail or were skipped, say so in the
   Testing section — never claim verification that didn't happen.

## Before Requesting Review

Verify, in order:

1. Branch is up to date with the default branch (rebase or merge if not).
2. Tests, linting, and type checks pass locally where configured.
3. The diff contains no unrelated formatting churn, debug statements,
   or leftover TODOs from this change.
4. No secrets, credentials, or machine-specific paths are included.
5. Documentation affected by the change is updated in the same PR —
   README, setup/config docs, API references, changelog. This applies
   when the change touches behavior, configuration, public interfaces,
   or developer workflows; if docs are intentionally deferred, say so
   in the PR's Notes section.
6. Commit history tells a coherent story; squash fixup commits
   (`oops`, `fix typo`, `wip`) before opening the PR.

## Governance

Merge and review governance (protected branches, who must review, when
human sign-off is required) is defined by the `org-defaults` skill if
installed, or the host repository's `AGENTS.md` — apply those alongside
these conventions, with the host repository taking precedence.

If neither source is available, apply this minimum: all changes go
through a Pull Request, and never force-push or rewrite history on
shared branches.

<!--
CUSTOMIZE: convention choices to adjust before relying on this skill —
- allowed commit types and scopes (match your changelog tooling)
- PR size threshold and required description sections
- merge strategy (squash vs merge commit) — affects rule 1 under Pull Requests
Org-specific values (org name, reviewer team, ticket-reference format,
governance policy) do NOT belong here — they live in the org-defaults skill.
-->
