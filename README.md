# laoitdev-skills

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A curated collection of [Agent Skills](https://www.anthropic.com/news/skills) for Claude Code — reusable, self-contained playbooks that teach an agent project-specific conventions, workflows, and patterns.

## What's a skill?

Each skill is a folder containing a `SKILL.md` with YAML frontmatter (`name`, `description`) plus the body instructions. The `description` field is what triggers the skill: an agent matches it against the current task and decides whether to invoke it. Skills can also ship `references/` (extra docs loaded on demand) and `templates/` (files to copy/adapt).

## Repository structure

```text
skills/
├── backend/    # Backend/API conventions and patterns (contributions welcome)
├── frontend/   # Frontend/web conventions and patterns (contributions welcome)
└── mobile/     # Mobile app conventions and patterns
    ├── flutter-clean-arch-getx/   # Flutter Clean Architecture + GetX feature scaffolding
    └── flutter-flavors/           # Flutter build flavors (dev/stage/prod) across platforms
```

See each category's `README.md` for the current skill list in that domain.

## Using these skills

### Option A: install as a plugin (recommended)

This repo is also a [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) bundling every skill into one `laoitdev-skills` plugin. From inside Claude Code:

```
/plugin marketplace add LaoitdevOpen/laoitdev-skills
/plugin install laoitdev-skills@laoitdev-skills
```

Skills install automatically and trigger themselves based on their `description` — no per-skill setup needed. Update later with `/plugin marketplace update laoitdev-skills`.

### Option B: copy individual skills

Copy a skill folder (e.g. `skills/mobile/flutter-flavors/`) into your project's `.claude/skills/` directory, or into `~/.claude/skills/` to make it available globally. Claude Code discovers `SKILL.md` files automatically and invokes them when their `description` matches the task at hand.

## Contributing

New skills, fixes, and category expansions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the folder conventions, frontmatter requirements, and PR checklist. Please also read the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE)
