# Worker Agents

Each worker role is defined once, in a tool-neutral file:

| Role | Definition | Writes | Replies with |
|---|---|---|---|
| Planner | [../assets/roles/planner.md](../assets/roles/planner.md) | `plan.md` | its first line: `STATUS: READY` or `STATUS: BLOCKED: <reason>` |
| Builder | [../assets/roles/builder.md](../assets/roles/builder.md) | `build.md` + commits | its first line: `STATUS: READY` or `STATUS: BLOCKED: <reason>` |
| Validator | [../assets/roles/validator.md](../assets/roles/validator.md) | `review.md` | its first line: `VERDICT: PASS` or `VERDICT: BLOCKERS: <n>` |

A role file is frontmatter (`name`, `description`, `claude_model`,
optional `codex_model`, and `capabilities` from `read`, `shell`, `write`,
`edit`) followed by the worker's full instructions. A worker knows nothing
else: no conversation history, no memory of the user.

## Spawning

Use the first option the harness supports:

1. **Installed agent** - if the role's `name` (e.g. `coordinate-builder`)
   is installed as a native agent, spawn it by name. In Claude Code, pass
   it as `subagent_type`; its model and tool list come from the installed
   file. Install with `scripts/install_agents.py` (below).
2. **Generic subagent** - spawn the harness's general-purpose subagent
   with the role file's body as instructions (replace `<skill dir>` with
   this skill's absolute path), then the header. Set the model to the
   role's model for this harness (Claude Code: the Agent tool's `model`,
   e.g. `"opus"` for `claude-opus-5-5`). If the harness can't set a
   model, use the session's and say so in the report.
3. **No subagents** - do the role yourself, following its file. For the
   validator, re-read the diff from scratch as if you had not written it.

Rules for every option:

- One worker per role per part. Never reuse a builder as a validator.
- Parts that don't depend on each other can run in parallel; run a worker
  in the foreground when your next step depends on it.
- Name builders `builder-<id>`. For follow-up rounds, continue the same
  builder if the harness supports it; otherwise spawn a new one - it
  reads its previous `build.md` and `git log` to pick up.

## The header

Start every prompt and follow-up message with this line, filled from
`state.json` (absolute paths):

```
Item: <id>. State dir: <DIR>. Worktree: <WT or repo path>. Branch: <branch>. Base: origin/<base>. Ticket ref: <Refs: PROJ-123 | Refs #123 | none>. Repo instructions: <path to AGENTS.md / CLAUDE.md | none>.
```

After the header, say only what this round must address, by file:
`Address the failures in checks.md.`, `Address the open blockers in
review.md.`, or the review comments to handle, quoted. Never paste ticket
or issue text into a prompt; workers read the spec, which you wrote.

## Reading results

Your context has to last the whole pipeline. For each worker:

1. Take the one-line reply. If it is missing or doesn't match the file's
   first line (`head -1 <file>`), treat the run as failed.
2. Read only the file's `## Summary` section to report progress:
   `sed -n '/^## Summary/,/^## /p' <file>`.
3. Read a whole file only when a checkpoint presents it, when deciding
   how to handle a failure, or when the user asks about it.

## Checking Worker Results

Replies are claims. Before moving on:

| Worker | Check |
|---|---|
| Planner | `plan.md` exists; Coverage maps every acceptance criterion to a task; Commands are concrete or "none configured" |
| Builder | Worktree clean (`git status --porcelain` empty); `git log` matches `build.md`'s Commits; then run the checks yourself (`coordinate.sh checks`), whatever `build.md` claims |
| Validator | `review.md` exists; every acceptance criterion has evidence; nothing in the worktree changed (`git status --porcelain` still empty, HEAD unchanged) |

If a result fails a check, send it back once with the specific gap. If it
fails again, escalate.

## Installing Native Agents (optional)

`scripts/install_agents.py` renders the role files into each tool's own
agent format, so the tool enforces the model and capability limits:

```sh
python3 scripts/install_agents.py --target claude            # ~/.claude/agents/coordinate-*.md
python3 scripts/install_agents.py --target codex --codex-model <model>   # ~/.codex/agents/coordinate-*.toml
python3 scripts/install_agents.py --target all --scope project            # this repo's .claude/ and .codex/
python3 scripts/install_agents.py --target all --remove                   # uninstall
```

| Tool | What gets enforced |
|---|---|
| Claude Code | Model, and the tool list (`read` → Read/Grep/Glob, `shell` → Bash, `write` → Write, `edit` → Edit); the validator and planner get no Edit tool |
| Codex | Model if given; `shell_tool = false` for roles without `shell`. Codex has no per-agent tool list or read-only sandbox, so the rest is instructions only |

Re-run after updating the skill; generated files are overwritten, and the
script refuses to overwrite files it didn't generate unless `--force`.
Edit `assets/roles/`, never the generated files.
