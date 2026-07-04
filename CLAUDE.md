# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A curated collection of [Agent Skills](https://www.anthropic.com/news/skills) for Claude Code: self-contained playbooks that teach an agent project-specific conventions and workflows for other codebases (React/TypeScript frontends, Flutter mobile apps, etc.). This repo does not contain application code — it contains the skills themselves, distributed two ways:

1. **Plugin/marketplace**: the whole repo is a Claude Code plugin marketplace (`.claude-plugin/marketplace.json`) bundling every skill into one plugin (`.claude-plugin/plugin.json`, name `laoitdev-skills`). Users run `/plugin marketplace add LaoitdevOpen/laoitdev-skills` then `/plugin install laoitdev-skills@laoitdev-skills`.
2. **Copy-paste**: users copy an individual skill folder into their own project's `.claude/skills/` or `~/.claude/skills/`.

Both distribution paths must keep working, so don't restructure `skills/` without checking both `plugin.json`'s `skills` field and each category `README.md`.

## Commands

```bash
./scripts/validate-skills.sh   # validate every skills/**/SKILL.md frontmatter (name, description present)
claude plugin validate .       # validate .claude-plugin/marketplace.json and plugin.json schema
```

CI (`.github/workflows/validate-skills.yml`) runs `validate-skills.sh` on every push to `main` and every PR — it's the only automated check, so a passing local run means CI will pass.

To test the plugin end-to-end locally without publishing:

```bash
claude plugin marketplace add ./
claude plugin install laoitdev-skills@laoitdev-skills
# ... verify, then:
claude plugin uninstall laoitdev-skills@laoitdev-skills
claude plugin marketplace remove laoitdev-skills
```

## Repository structure

```text
skills/
├── backend/    # empty — contributions welcome
├── frontend/   # 9 skills — React + TypeScript conventions
└── mobile/     # 2 skills — Flutter conventions
```

Each skill is `skills/<category>/<skill-name>/SKILL.md`, optionally with `references/` (extra docs loaded on demand) and `templates/` (files the skill copies/adapts). `.claude-plugin/plugin.json`'s `skills` field lists all three category directories explicitly (`./skills/frontend`, `./skills/backend`, `./skills/mobile`) — this is required because Claude Code's default plugin scan only looks one level under `skills/` for `<name>/SKILL.md`, and this repo nests an extra category level.

## Adding or editing a skill

Full rules are in `CONTRIBUTING.md`; the load-bearing ones:

- Folder: `skills/<category>/<skill-name>/`. Categories today: `backend`, `frontend`, `mobile`.
- Frontmatter `name` must exactly match the `<skill-name>` folder name (kebab-case) — `validate-skills.sh` enforces this.
- Frontmatter `description` is the trigger mechanism: an agent matches it against the task to decide whether to invoke the skill. State *when* to use it (concrete trigger phrases a user might say), not just what it does — see any existing `SKILL.md` for the density expected (e.g. `skills/frontend/frontend-audit/SKILL.md`).
- Write the body as instructions to an agent, not documentation for a human — imperative, concrete, copy-paste-able patterns over abstract descriptions.
- After adding/editing a skill, update that category's `skills/<category>/README.md` table.
- Frontend skills follow a shared convention of a `## Core Invariants (always enforced — never violate)` section near the top, listing the small set of rules that make the skill's target codebase pattern non-negotiable (e.g. `tanstack-router`'s "route files live only in `src/routes/`"). Follow this pattern for new skills that have hard invariants rather than burying them in prose.
