---
name: org-defaults
description: >
  Organization-wide default values and governance policy for thanoslabs
  repositories. Load whenever another skill or instruction refers to "org
  defaults", or when you need org-specific values such as the organization
  name, reviewer roles, protected-branch rules, or review requirements.
---

# thanoslabs Org Defaults

Other skills in this library are org-neutral and refer to the values and
policies defined here. This skill is the only place org-specific values
live — to adopt these skills in another organization, replace this skill
and nothing else.

## Resolution Order

When a value or policy below conflicts with other instructions:

1. The host repository's `AGENTS.md` (or explicit user instruction) wins.
2. Then this skill.
3. Then any inline fallback written in the referring skill.

## Values

| Key | Value |
|---|---|
| Organization | `thanoslabs` |
| Default branch | `main` |
| Reviewer team | `@thanoslabs/reviewers` |
| Ticket reference format | GitHub issues (`Closes #123` / `Refs #123`) |

## Governance Policy

1. All changes go through a Pull Request. Never push directly to the
   default branch, force-push protected branches, rewrite shared branch
   history, or bypass branch protection or review requirements.
2. Human review by the reviewer team is required before merging a PR,
   releasing to production, modifying infrastructure, changing
   security-sensitive code, or performing destructive migrations.
3. For substantial refactors or architecture changes: open an
   issue/discussion first, break the work into smaller reviewable PRs,
   and preserve backward compatibility where possible.
4. Keep the trail auditable: issue/task, branch, commits, and PR
   description should tell one traceable story.
