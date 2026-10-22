# State

## Location

```
${SOFTWARE_FACTORY_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/software-factory}/<owner>-<repo>/<id>/
```

`<owner>-<repo>` comes from the `origin` remote. The directory is outside
every repository, so nothing in it can be committed, and it survives
reboots. Close out deletes it.

| File | Written in | Purpose |
|---|---|---|
| `state.json` | every stage | Pipeline position and things git/GitHub can't show |
| `spec.md` | Define | What "done" means |
| `plan.md` | Plan | How to get there |
| `review.md` | Review | Self-review findings, each marked fixed, accepted, or open |
| `pr-body.md` | Review | PR description, used by Publish or the human |
| `worktree/` | Build | The item's git worktree |

## `state.json`

```json
{
  "version": 1,
  "id": "issue-123",
  "title": "Prevent token refresh race",
  "source": { "type": "github-issue", "ref": "acme/api#123", "url": "https://github.com/acme/api/issues/123" },
  "stage": "build",
  "awaiting": "build-approval",
  "mode": "gated",
  "publish": true,
  "base": "main",
  "branch": "fix/123-token-refresh-race",
  "worktree": "/Users/me/.local/state/software-factory/acme-api/issue-123/worktree",
  "pr": null,
  "approvals": { "plan": "2026-10-22T14:03:00Z", "build": null, "review": null },
  "attempts": { "verify": 1, "ci": 0, "review_rounds": 0 },
  "escalation": null,
  "updated_at": "2026-10-22T14:40:12Z"
}
```

| Field | Values |
|---|---|
| `source` | `{"type": "github-issue", "ref", "url"}` or `{"type": "user-input"}` |
| `stage` | `define` `plan` `build` `review` `publish` `shepherd` `handoff` |
| `awaiting` | `null`, `plan-approval`, `build-approval`, `review-approval`, `human-push`, `human-merge` |
| `mode` | `gated` or `auto` |
| `publish` | `false` when `--local-only` |
| `pr` | `null` or `{"number", "url"}` |
| `approvals.*` | ISO timestamp, `"auto"`, or `null` |
| `escalation` | `null` or `{"stage", "reason", "at"}` |

Reset `attempts.ci` to 0 whenever CI goes green.

## Stage detection

`scripts/factory.sh status <id>` combines observed facts with
`state.json` and prints `derived_stage`. Precedence, first match wins:

1. **PR merged / closed** → `done-merged` / `done-closed`
2. **PR open**
   - item is `--local-only` → `pr-opened-externally`
   - labelled `dont-merge` → `held`
   - approved, checks pass, no unresolved threads, no conflicts → `ready-to-merge`
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
  rebuild `state.json` from the PR — branch, base, and title from
  `gh pr view`; a minimal spec from the PR body and linked issue — and
  continue at `shepherd`. The original plan is not recoverable, and
  isn't needed once the PR exists.
- **State dir missing, no PR:** the item can't be recovered; start again
  from Define. If the branch still exists locally, offer to reuse it.
