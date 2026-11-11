# AGENTS.md

## Purpose

This is a general-purpose **skills repository**: a library of reusable agent skills (self-contained `SKILL.md` packages) that can be installed into agent environments such as Claude Code. The skills themselves are the product of this repo — there is no application code.

This repository may be worked on by humans and AI coding agents.  
This document defines the operational expectations, conventions, and guardrails for contributors and autonomous agents.

Agents should prioritize:
1. Correctness
2. Maintainability
3. Minimal, focused changes
4. Clear reasoning and documentation
5. Safety and reversibility

---

# Repository Principles

## Core Rules

- Do not rewrite large sections unnecessarily.
- Prefer incremental changes over broad refactors.
- Preserve existing architecture unless explicitly instructed otherwise.
- Avoid introducing new dependencies unless justified.
- Keep implementations simple and readable.
- Match existing code style and conventions.
- Favor explicitness over cleverness.

---

# Agent Workflow

## Before Making Changes

Agents should:

1. Read relevant files fully before editing.
2. Understand local patterns and conventions.
3. Search for existing utilities before creating new ones.
4. Check for related tests.
5. Identify configuration, environment, or deployment implications.

## While Making Changes

Agents should:

- Keep diffs focused and minimal.
- Avoid unrelated formatting changes.
- Update documentation when behavior changes.
- Add or update tests when appropriate.
- Preserve backward compatibility unless instructed otherwise.

## After Making Changes

Agents should:

1. Run relevant tests if available.
2. Run linting/formatting if configured.
3. Verify imports/builds/type checks pass when applicable.
4. Summarize:
   - what changed
   - why it changed
   - any tradeoffs or follow-up work

---

# Code Style Expectations

## General

- Write self-documenting code.
- Prefer small, composable functions.
- Avoid deep nesting.
- Use descriptive variable and function names.
- Minimize hidden side effects.

## Comments

Add comments only when necessary to explain:
- intent
- constraints
- non-obvious decisions

Do not add redundant comments describing obvious code behavior.

## Logging

- Keep logs concise and actionable.
- Never log secrets or sensitive data.

---

# Testing Guidelines

## Preferred Approach

- Test behavior, not implementation details.
- Keep tests deterministic.
- Reuse existing test helpers and fixtures.
- Cover happy paths and important edge cases.

## Avoid

- Brittle timing-based tests
- Excessive mocking
- Copy-pasted test setups

---

# Dependency Policy

Before adding a dependency, agents should consider:

- Is this already solved in the repository?
- Can the standard library handle this?
- Is the dependency actively maintained?
- Does it significantly increase complexity or bundle size?

Document the rationale for any new dependency.

---

# Security Guidelines

Agents must:

- Never commit secrets, credentials, or tokens.
- Avoid introducing vulnerabilities through:
  - unsanitized input
  - unsafe eval/execution
  - insecure deserialization
  - command injection
- Use least-privilege principles.
- Validate external input.

If a change may affect security, explicitly mention it.

---

# Configuration Rules

- Prefer environment variables for configuration.
- Document new environment variables.
- Provide sensible defaults when possible.
- Avoid hardcoded machine-specific paths.

---

# Documentation Expectations

Update documentation when changing:

- setup steps
- developer workflows
- public APIs
- configuration
- architectural behavior

Relevant docs may include:
- `README.md`
- `/docs`
- inline code docs
- examples
- changelogs

---

# Repository Structure

```text
/
├── skills/                     # The product of this repo: one directory per skill
│   └── <skill-name>/           # kebab-case; must match the skill's frontmatter name
│       ├── SKILL.md            # Required: YAML frontmatter + instructions
│       ├── references/         # Optional: detailed docs loaded on demand
│       ├── scripts/            # Optional: executable helpers the skill invokes
│       ├── assets/             # Optional: templates/files used in skill output
│       └── agents/openai.yaml  # OpenAI Codex display name + description
├── templates/
│   └── skill-template/         # Copy this to start a new skill
├── docs/                       # Repo-level docs (authoring guide, review checklist)
├── .agents/                    # Config for agents working ON this repo
│   ├── instructions/           # Repo-local agent instructions
│   └── skills/                 # Repo-local skills (e.g. a "new-skill" scaffolder)
├── .github/                    # CI, CODEOWNERS, Renovate
├── AGENTS.md                   # This file
└── README.md                   # Catalog of available skills + install instructions
```

Note the distinction: `skills/` holds the distributable skills this repo exists to share; `.agents/` holds tooling for agents contributing to this repo itself.

---

# Skill Authoring Conventions

## Layout

- One skill per directory under `skills/`, named in kebab-case.
- Every skill must have a `SKILL.md` with YAML frontmatter containing at minimum:
  - `name` — must exactly match the directory name
  - `description` — states **what the skill does** and **when to use it**; this is
    what an agent reads to decide whether to load the skill, so include concrete
    trigger phrases and use cases
- Keep `SKILL.md` focused (roughly under 500 lines). Move deep detail into
  `references/` files and link to them, so they are only loaded when needed.
- `scripts/` contents must be self-contained and runnable without repo-external
  setup; document any required tools at the top of the script.
- Keep `SKILL.md` agent-neutral. Agent-specific settings go where that
  agent reads them: Claude Code settings in `SKILL.md` frontmatter (e.g.
  `model`), OpenAI Codex settings in `agents/openai.yaml`. Give every
  skill an `agents/openai.yaml` with at least `display_name` and
  `short_description`; see the template for the other fields.

## Quality Bar

- A skill should be usable by an agent with no context beyond the skill itself.
- Prefer imperative, unambiguous instructions over background prose.
- Include examples of correct output where the format matters.
- Test a skill by actually invoking it in an agent session before submitting.
- Update the skill catalog in `README.md` when adding, renaming, or removing a skill.

## Scope

- One skill per PR when adding or substantially reworking a skill.
- Don't create overlapping skills; extend an existing one instead.
- Skills must not embed secrets, tokens, or organization-internal URLs that
  would break for other users.
- Keep skills org-neutral: org-specific values (org name, reviewer teams,
  ticket formats, governance policy) live only in the
  [org-defaults](skills/org-defaults/SKILL.md) skill. Other skills refer
  to it by name and may include a generic inline fallback, so each skill
  stays reusable outside this organization as-is.

---

# Git & Commit Guidance

## Branch, Commit, and PR Conventions

This repo follows its own skills:
[pr-commit-conventions](skills/pr-commit-conventions/SKILL.md) for branch
naming, commit message format (Conventional Commits), PR structure, and
the pre-review checklist; [org-defaults](skills/org-defaults/SKILL.md)
for org values and governance policy (protected branches, review
requirements, large-change process). Read and apply both before
committing or opening a PR. If working on either skill itself, the
version on the default branch is the one in effect.

This repo has no governance overrides. If any are ever needed, they go
here and take precedence over the skills' defaults.

---

# Architecture Guidance

Unless instructed otherwise:

- Preserve public interfaces.
- Avoid unnecessary abstractions.
- Prefer composition over inheritance.
- Keep modules cohesive.
- Minimize coupling between layers.

---

# Performance Expectations

Agents should:

- Avoid premature optimization.
- Consider performance for hot paths.
- Avoid unnecessary allocations/network calls.
- Preserve scalability characteristics of existing systems.

Call out meaningful performance tradeoffs.

---

# AI-Agent Specific Instructions

## Allowed Actions

Agents may:
- read files
- modify files
- create files
- run local analysis/testing commands
- propose refactors

## Disallowed Actions

Agents must NOT:
- delete large sections without justification
- overwrite user work unexpectedly
- introduce breaking changes silently
- fabricate test results
- assume undocumented behavior as fact

## Decision Making

When requirements are ambiguous:
- prefer conservative implementations
- document assumptions
- avoid hidden magic

When multiple valid approaches exist:
- choose the simplest maintainable solution

---

# Preferred Change Characteristics

Good changes are:

- small
- reviewable
- tested
- documented
- reversible

---

# Escalation Conditions

Agents should request human review when:

- security implications are unclear
- migrations may cause data loss
- architecture changes are substantial
- requirements conflict
- production impact is uncertain

---

# Repository Overrides

Project-specific instructions may override this file.

Potential override locations:

- `/docs/`
- `.github/`
- language-specific config files
- nested `AGENTS.md` files

The most specific applicable instruction takes precedence.

---

# Final Checklist

Before completing work, agents should verify:

- [ ] Changes are scoped appropriately
- [ ] Code follows repository conventions
- [ ] Tests pass or limitations are documented
- [ ] Documentation is updated if needed
- [ ] No secrets or sensitive data were introduced
- [ ] Changes are explainable and reviewable
