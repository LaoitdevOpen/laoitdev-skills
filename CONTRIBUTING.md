# Contributing

Thanks for improving this skill collection. This repo favors small, well-scoped skills over sprawling ones — if you're not sure whether your idea should be one skill or several, open an issue first and we'll figure it out together.

## Adding a new skill

1. **Pick (or propose) a category.** Skills live under `skills/<category>/<skill-name>/`. Current categories: `backend`, `frontend`, `mobile`. Propose a new category via issue if none fit.
2. **Folder layout:**
   ```text
   skills/<category>/<skill-name>/
   ├── SKILL.md            # required
   ├── references/         # optional — extra docs loaded on demand
   └── templates/           # optional — files the skill copies/adapts
   ```
3. **`SKILL.md` frontmatter requirements:**
   - `name`: must exactly match the `<skill-name>` folder name (kebab-case).
   - `description`: the single most important field. It's matched against the user's task to decide whether the skill triggers, so it must state *when* to use the skill, not just *what* it does. Include concrete trigger phrases a user might actually say, even ones that don't name the underlying tech by name.
4. **Body content**: write it as instructions to an agent, not documentation for a human reader — imperative, concrete, with copy-paste-able code patterns where relevant. Prefer showing a real example over describing an abstraction.
5. **Validate locally** before opening a PR:
   ```bash
   ./scripts/validate-skills.sh
   ```
6. Update the relevant `skills/<category>/README.md` to list the new skill.

## PR checklist

- [ ] `SKILL.md` frontmatter has `name` (matches folder) and a trigger-oriented `description`
- [ ] `./scripts/validate-skills.sh` passes
- [ ] Category `README.md` updated to list the new/changed skill
- [ ] No secrets, internal URLs, or company-specific credentials committed

## Reporting issues / requesting skills

Use the issue templates — a bug report for something incorrect in an existing skill, or a skill request for a new one.
