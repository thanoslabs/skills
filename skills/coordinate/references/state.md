# State

## Location

```
${COORDINATE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/coordinate}/<owner>-<repo>/<id>/
```

`<owner>-<repo>` comes from the `origin` remote. The directory is outside
every repository, so nothing in it can be committed, and it survives
reboots. Close out deletes it.

| File | Written in | Purpose |
|---|---|---|
| `state.json` | every stage | Pipeline position and things git/GitHub can't show |
| `spec.md` | Clarify | What "done" means, decisions, assumptions |
| `plan.md` | Plan | How to get there |
| `review.md` | Validate | Validator findings, each marked fixed, accepted, or open |
| `pr-body.md` | Validate | Brief PR description, used by Publish or the human |
| `worktree/` | Build | The item's git worktree |

## `state.json`

```json
{
  "version": 2,
  "id": "proj-123-backoff-config",
  "title": "Add retry backoff configuration",
  "group": "proj-123",
  "part": 1,
  "summary": "add backoff config",
  "ticket": { "key": "PROJ-123", "url": "https://example.atlassian.net/browse/PROJ-123", "title": "Retry webhook deliveries with backoff" },
  "source": { "type": "jira", "ref": "PROJ-123" },
  "stage": "build",
  "awaiting": "build-approval",
  "mode": "gated",
  "publish": true,
  "base": "main",
  "branch": "jonathann/PROJ-123-backoff-config",
  "worktree": "/Users/me/.local/state/coordinate/acme-api/proj-123-backoff-config/worktree",
  "pr": null,
  "approvals": { "clarify": "2026-10-22T13:51:00Z", "plan": "2026-10-22T14:03:00Z", "build": null, "validate": null },
  "attempts": { "verify": 1, "ci": 0, "review_rounds": 0 },
  "escalation": null,
  "updated_at": "2026-10-22T14:40:12Z"
}
```

| Field | Values |
|---|---|
| `group` | Shared by every item from one request; lowercased ticket key, `issue-<n>`, or a slug |
| `part` | 1-based order within the group; orders the PR announcement |
| `summary` | A few words for the PR announcement, e.g. `add backoff config` |
| `ticket` | `null` or `{"key", "url", "title"}`; `url` may be `null` |
| `source` | `{"type": "jira", "ref"}`, `{"type": "github-issue", "ref", "url"}`, or `{"type": "user-input"}` |
| `stage` | `clarify` `plan` `build` `validate` `publish` `shepherd` `handoff` |
| `awaiting` | `null`, `clarify-approval`, `plan-approval`, `build-approval`, `validate-approval`, `human-push`, `human-merge` |
| `mode` | `gated` or `auto` |
| `publish` | `false` when `--local-only` |
| `pr` | `null` or `{"number", "url", "draft"}` |
| `approvals.*` | ISO timestamp, `"auto"`, or `null` |
| `escalation` | `null` or `{"stage", "reason", "at"}` |

Reset `attempts.ci` to 0 whenever CI goes green.

## Stage detection

`scripts/coordinate.sh status <id>` combines observed facts with
`state.json` and prints `derived_stage`. Precedence, first match wins:

1. **PR merged / closed** → `done-merged` / `done-closed`
2. **PR open**
   - item is `--local-only` → `pr-opened-externally`
   - labelled `dont-merge` → `held`
   - not a draft, approved, checks pass, no unresolved threads, no conflicts → `ready-to-merge`
   - otherwise → `shepherd`
3. **No PR, `state.json` exists** → the recorded `stage`, unless it needs
   a branch that no longer exists → `inconsistent`
4. **Nothing** → `new`

Rules 1–2 come from GitHub, so they hold even when `state.json` is stale
or the human acted by hand. Rule 3 is the only place `state.json` decides,
because before a PR exists the local stages leave no remote trace.

## What is not stored

PR review comments, CI results, and approvals are **read live from
GitHub** on every shepherding pass and never copied here. A local copy
would go stale the moment a reviewer edits, resolves, or adds a comment.
Only counters derived from them (`attempts.ci`, `attempts.review_rounds`)
are kept.

## Lost or stale state

- **State dir missing but a PR exists** (another machine, deleted state):
  rebuild `state.json` from the PR - branch, base, and title from
  `gh pr view`; the ticket key from the branch name; a minimal spec from
  the PR body and linked ticket or issue - and
  continue at `shepherd`. The original plan is not recoverable, and
  isn't needed once the PR exists.
- **State dir missing, no PR:** the item can't be recovered; start again
  from Clarify. If the branch still exists locally, offer to reuse it.
