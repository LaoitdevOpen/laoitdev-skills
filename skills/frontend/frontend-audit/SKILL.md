---
name: frontend-audit
description: "Audit frontend code against project skills and design standards. Use this whenever the user asks to audit, review, or check code — a single component, a feature folder, or the whole project. Also use when the user shares code and asks 'is this correct?', 'does this follow our standards?', 'review this', or 'check my implementation'. Checks UX/UI design match (theme colors, typography, layout), architecture compliance, form patterns (TanStack Form), table patterns (MRT DataTable), query patterns (TanStack Query), routing patterns, coding standards, detail page layout, and translation/i18n compliance (hardcoded strings, Zod schema factory pattern, API error translation). Suggests specific fixes referencing the relevant skill."
---

# Frontend Audit

Perform a structured audit of frontend code against the project's established skills and design standards. The goal is actionable findings — not just a list of violations, but specific suggestions that reference the skill the developer should follow.

## When This Skill Applies

- User asks to "audit", "review", "check", or "validate" any component, feature, or file
- User asks "is this correct?" or "does this follow our standards?" about code they share
- User wants to know what's wrong before submitting a PR
- User asks for a design review or UX check

## Audit Workflow

### Step 1: Gather Context

Before reading any files, ask the user for:

1. **Scope**: What do you want audited? (file path, feature name, or "whole project")
2. **Design reference**: Is there a Figma link, screenshots, or mockup to compare against? (optional)
3. **Focus**: Is there a particular concern? (e.g., "mostly the form", "just check the architecture")

If the user already shared code or a file path in their message, skip asking for scope.

### Step 2: Read the Relevant Skills

Load the skills that apply to what you're auditing. Don't load all of them — load only what's relevant to the code in front of you:

| If you see... | Read skill |
|---|---|
| Form components, `useForm`, field inputs | `frontend-tanstack-form` |
| Table, list view, columns | `frontend-table-mrt` |
| `useQuery`, `useMutation`, API calls | `frontend-tanstack-query` |
| Route files, `createFileRoute`, navigation | `frontend-tanstack-router` |
| `src/core/` files, providers, interceptors | `frontend-core` |
| Colors, `sx` props, `SectionCard`, `InfoRow` | `frontend-theme` |
| Detail/view page (single item display) | `frontend-detail-page` |
| Feature folder structure, file placement | `frontend-feature-architecture` |
| `t()`, `useTranslation`, translation keys, Zod messages, API errors | `frontend-i18n` |
| Any component at all | `react-standard` |

### Step 3: Read the Code

Read the files the user wants audited. For a feature folder, read:
- `components/` files
- `hooks/` files
- `services/` files
- `types/` and `schemas/` if present

For a single component, read it fully.

### Step 4: Design Audit (if design reference provided)

If the user provided a Figma link, screenshot, or mockup:

1. **Layout match** — Does the component structure match the design? Check section order, card grouping, spacing.
2. **Color compliance** — Are all colors from `theme.palette` tokens? Flag any hardcoded hex values or non-theme colors.
3. **Typography** — Are text styles using MUI variant tokens (`h5`, `body1`, `caption`, etc.)?
4. **Component fidelity** — Does the rendered output closely match the design? Note any missing UI elements.

Reference the `frontend-theme` skill for the exact palette tokens when reporting violations.

### Step 5: Implementation Audit

Check each relevant category. For each finding, note:
- **File and approximate line** if possible
- **What's wrong**
- **What it should be** — and which skill to follow

#### Architecture
Read `frontend-feature-architecture`. Check:
- **No route files inside `features/`** — route files (`createFileRoute`) belong only in `src/routes/`
- Files are in the correct subfolder (`components/`, `hooks/`, `services/`, `types/`, `schemas/`, `constants/`, `utils/`)
- Component names match their role (e.g., `FeatureList.tsx`, `FeatureForm.tsx`, `FeatureDetail.tsx`)
- `index.ts` exports are in place
- No cross-feature imports (features importing from other features)
- Nothing in `core/` imports from `features/`

#### Coding Standards
Read `react-standard`. Check:
- Named exports (not default exports, except route components)
- All user-visible strings use `useTranslation()` — no hardcoded strings (full detail covered in Translation & i18n section)
- TypeScript: no `any`, proper interface/type definitions
- Import aliases used (`@/shared`, `@/features`, etc.)

#### Theme & UI
Read `frontend-theme`. Check:
- Colors use `theme.palette` tokens, not hardcoded hex
- `SectionCard` and `InfoRow` used for detail/info layouts
- Dark mode not broken (no hardcoded colors that don't invert)
- MUI Grid uses `size` prop — flag as **Error** for any of these (Grid2 is deprecated and removed in MUI v9):
  - `Grid2` import (`import Grid2 from '@mui/material/Grid2'` or `import { Grid2 }`) — replace with `import { Grid } from '@mui/material'`
  - `xs`/`sm`/`md`/`lg`/`xl` props directly on `<Grid>` — replace with `size={{ xs: ..., md: ... }}`
  - `item` prop on `<Grid>` — remove it, use `size` prop instead
  - Fix: `<Grid size={{ xs: 12, md: 6 }}>`. See: `react-standard` skill.

#### Forms
Read `frontend-tanstack-form`. Check:
- Uses `useAppForm`, not raw `useForm`
- Field components are `App*` variants (`AppTextField`, `AppSelect`, etc.)
- Submit uses `<form.SubmitButton>`, not a raw MUI `<Button type="submit">`
- Form DOM scope is `<form.AppForm>` wrapping a `<form>` element
- Zod schema is defined and passed as `validators`

#### Tables
Read `frontend-table-mrt`. Check:
- Uses `DataTable` wrapper from `@/shared/components/DataTable`, not raw `MaterialReactTable`
- Column definitions use `MRT_ColumnDef` type
- Server-side pagination wired through `manualPagination`
- Row actions use the expected menu pattern

#### Data Fetching
Read `frontend-tanstack-query`. Check:
- Query keys defined as factory objects in the feature's constants file — not inline arrays
- `useQuery` / `useMutation` called from a custom hook, not directly in a component
- Mutations invalidate the right query keys after success
- `staleTime` is not overridden arbitrarily

#### Routing
Read `frontend-tanstack-router`. Check:
- Route files use `createFileRoute` — all live in `src/routes/`, never inside feature folders
- Search schemas imported from `features/[feature]/schemas/[feature].schema.ts` — never defined inline in route files
- Search params validated via `validateSearch: zodValidator(featureSearchSchema)` — schema uses `fallback(z.number(), 1).default(1)` pattern from `@tanstack/zod-adapter`
- Inside route component functions: `Route.useSearch()`, `Route.useNavigate()`, `Route.useParams()` — never bare `useSearch({ from })`, `useNavigate()`, or `useParams({ from })`
- Every `beforeLoad` on a layout route returns `{ breadcrumb: '...' }` — create, edit, detail, and list pages all need a breadcrumb key
- Auth/permission guards use `guardRoute(context.user, ['permission-key'])` or `guardAdmin(context.user)` inside `beforeLoad`
- `loader` uses `context.queryClient.ensureQueryData` to prefetch on detail/edit pages
- `routeTree.gen.ts` is not manually edited
- Navigation uses `Route.useNavigate()` or `<Link>`, never `window.location`
- Router config includes `scrollRestoration: true` and `user: undefined` in context

#### Translation & i18n
Read `frontend-i18n`. Check:
- Every user-visible string (labels, placeholders, buttons, headings, snackbar messages) passes through `t()` — no hardcoded English or Lao strings anywhere in components
- `useTranslation()` is called at the top of any component that renders text; the `t` function is not imported as a raw utility and called outside a component
- Zod validation schemas use the factory function pattern: `export const getFeatureSchema = (t: TFunction) => z.object({...})` — static schemas with hardcoded string messages are a violation
- Factory schemas are instantiated inside the component with `const schema = getFeatureSchema(t)` — not at module scope
- Every `useMutation` `onError` callback uses `translateError(error)` from `useAPIErrorTranslator` — not a raw string or `error.message`
- Option/select lists store translation keys as values and call `t(opt.label)` at render time — not hardcoded labels inline
- Translation key naming: camelCase, feature-level keys nest under feature name (`ministries.createSuccess`), shared labels under `common.*` or `fields.*`, errors under `errors.{category}.{key}`
- New business error codes are registered in `useAPIErrorTranslator.ts` AND added to both `en/translation.json` and `lo/translation.json`
- If a new `validation.*` key is needed that doesn't match an existing shared key, it's added to **both** translation files — not just one

#### Detail Pages
Read `frontend-detail-page`. Check:
- Hero section uses `primary.main` background with item name, code/ID, and status chips
- Content grid uses `SectionCard` cards with `InfoRow` fields
- Loading state uses skeleton
- Error and not-found states handled
- Back navigation present
- Action buttons (edit, delete) in expected positions

### Step 6: Produce the Audit Report

Output a structured report. Use this format:

---

## Audit Report: `[Feature or File Name]`

### Summary
One or two sentences on the overall state. Is this mostly compliant? Are there systemic issues?

### Design Review *(skip if no design was provided)*
- **Layout**: pass / issues found
- **Colors**: pass / issues found  
- **Typography**: pass / issues found
- Notes on any gaps

### Findings

Use severity levels:
- **Critical** — Violates a Core Invariant; must fix before merging
- **Warning** — Non-compliant with skill pattern; should fix
- **Info** — Minor inconsistency or suggestion

Group findings by category. For each:

> **[Category] · [Severity]**  
> `path/to/file.tsx` — Description of the issue.  
> Fix: What to do instead. See: `skill-name` skill.

Example:

> **[Theme & UI] · Warning**  
> `FeatureDetail.tsx` — Uses `<Grid xs={12} md={6}>` instead of the `size` prop.  
> Fix: Replace with `<Grid size={{ xs: 12, md: 6 }}>`. See: `react-standard` skill.

### Suggestions
Any improvements that aren't violations — patterns the developer could adopt to make this code more consistent or maintainable. Reference the relevant skill.

### Compliance Score *(optional)*
A rough pass/fail count per category if helpful.

---

## Tone and Approach

- Be specific: "line 42 in UserForm.tsx uses a raw `<Button type="submit">` — replace with `<form.SubmitButton>`" is more useful than "the form submit is wrong."
- Be constructive: pair every critical finding with a concrete fix.
- If something is done correctly, say so briefly — developers need to know what to keep, not just what to change.
- If you can't determine compliance without reading a bundled resource (e.g., the full form composition reference), say so and read it.
- If the scope is large (whole project), focus on one feature at a time and offer to continue.
