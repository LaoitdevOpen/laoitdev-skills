---
name: react-standard
description: "Core frontend coding standards for React + TypeScript projects using MUI, TanStack libraries, i18next, and Zod. Use this whenever writing any new component, hook, service, type, or utility — or when reviewing existing code for consistency. Covers naming conventions, file structure, TypeScript patterns, i18n, error handling, and import aliases."
---

# Frontend Coding Standards

## Core Invariants (always enforced — never violate)

- Always use `useTranslation()` for user-visible strings — never hardcode them.
- Use named exports, not default exports, for everything except route components.
- **Route files live only in `src/routes/`** — never create route files inside `features/`.
- **Use `bun` for all package installation** — never `npm`, `yarn`, or `pnpm`.
- **Use MUI Grid `size` prop for column sizing** — never `xs`/`sm`/`md`/`lg`/`xl` props directly on Grid.

## Package Manager

This project uses **bun** exclusively. Always use `bun` for all package operations:

```bash
bun add <package>          # install a dependency
bun add -d <package>       # install a dev dependency
bun install                # install all dependencies from lockfile
bun run <script>           # run a package.json script
bunx <cli>                 # run a package binary without installing globally
```

Never use `npm`, `yarn`, or `pnpm`.

## Tech Stack

| Concern | Library |
|---|---|
| UI | MUI v9 (Material UI) |
| Tables | `material-react-table` v3 (via shared `DataTable` wrapper) |
| Styling engine | `@emotion/react` + `@emotion/styled` (required MUI peer deps) |
| Routing | TanStack Router (file-based) |
| Data fetching | TanStack Query v5 |
| Forms | TanStack Form v1 |
| Validation | Zod v4 |
| i18n | i18next + react-i18next |
| HTTP | Axios (shared instance from `@/core/api/axios.config`) |
| Date | Day.js (via MUI `LocalizationProvider` with `AdapterDayjs`) |

> **MUI v9 requires both `@emotion/react` and `@emotion/styled` as peer dependencies.** Always install them together:
> ```bash
> bun add @mui/material @emotion/react @emotion/styled
> ```

## TypeScript

- All files are `.ts` or `.tsx`. No `.js`.
- Prefer `type` over `interface` for data shapes; use `interface` only when extension is needed.
- Avoid `any`. Use `unknown` at system boundaries; narrow before use.
- Export types from the feature's `types/index.ts` or alongside the component.
- Never `as any` unless wrapping a known incompatibility (e.g., TanStack Form generics).

## Naming Conventions

- **Components**: PascalCase (`ElectricityList`, `SectionCard`)
- **Hooks**: camelCase prefixed with `use` (`useElectricities`, `useCreateElectricity`)
- **Services**: camelCase object exported as const (`electricityService`)
- **Types**: PascalCase (`Electricity`, `ElectricityFilterParams`)
- **Constants**: SCREAMING_SNAKE_CASE for values, PascalCase for option arrays (`ELECTRICITY_ENDPOINTS`, `USER_USING_TYPES`)
- **Files**: kebab-case (`electricity.service.ts`, `useElectricities.ts`)
- **Route files**: live in `src/routes/_layout/section/feature/` only — kebab-case directories, `index.tsx` for list, `create.tsx` for create, `$paramId/index.tsx` for detail, `$paramId/edit.tsx` for edit

## Imports

Use path alias `@/` for absolute imports from `src/`:
```ts
import { DataTable } from '@/shared/components/DataTable'
import { useSnackbar } from '@/core/context/SnackbarContext'
import { electricityService } from '../services'
```

Prefer relative imports for intra-feature files; use `@/` for cross-feature or shared.

## i18n

Always use `useTranslation()` — never hardcode user-visible strings.

```tsx
const { t } = useTranslation()
// Usage
t('electricities.code')
t('common.save')
```

Translations live in the i18n config. Key structure: `featureName.keyName` or `common.keyName`.

## Error Handling

- API errors surface via `useSnackbar()` (`showSuccess`, `showError`).
- Translate API errors with `useAPIErrorTranslator()` → `translateError(error)`.
- Form submit errors show inline via `onError` of `useMutation`.

```tsx
const { showSuccess, showError } = useSnackbar()
const { translateError } = useAPIErrorTranslator()

mutation.mutate(data, {
  onSuccess: () => showSuccess(t('feature.updateSuccess')),
  onError: (error) => showError(translateError(error)),
})
```

## Comments

Write no comments unless the WHY is non-obvious. Self-documenting names are preferred.

## Component Shape

Functional components only. Named exports (not default exports) for everything except route components which can be inline functions.

```tsx
// Named export - preferred
export function ElectricityList({ data, isLoading }: ElectricityListProps) { ... }

// Props interface above component
interface ElectricityListProps {
  data?: Electricity[]
  isLoading?: boolean
}
```

## MUI Usage

- Use `sx` prop for one-off styles; avoid inline `style`.
- Prefer MUI responsive breakpoints: `{ xs: ..., sm: ..., md: ... }`.
- Use `elevation={0}` with `border` on Cards for flat design.
- Use `Container maxWidth="xl"` for page-level containers.

### MUI Grid

**MUI v9: `Grid2` is deprecated and removed.** It has been merged into `Grid`. Always import `Grid` from `@mui/material`.

**MUI Grid must use the `size` prop.** Never put breakpoint props directly on `<Grid>` (`xs`, `sm`, `md`, `lg`, `xl`). Never use the legacy `item` prop. Never import or use `Grid2`.

Import from `@mui/material` — MUI v9 unified Grid, no separate `Grid2` import:

```tsx
import { Grid } from '@mui/material'
```

| Wrong | Correct |
|---|---|
| `<Grid xs={12} md={6}>` | `<Grid size={{ xs: 12, md: 6 }}>` |
| `<Grid item xs={12} md={6}>` | `<Grid size={{ xs: 12, md: 6 }}>` |
| `import Grid2 from '@mui/material/Grid2'` | `import { Grid } from '@mui/material'` |
| `<Grid md={10}>` | `<Grid size={{ md: 10 }}>` or `<Grid size={10}>` |

Container rows stay unchanged:

```tsx
<Grid container spacing={3}>
  <Grid size={{ xs: 12, md: 6 }}>...</Grid>
  <Grid size={12}>...</Grid>
</Grid>
```

## Shared Components

Prefer shared components over re-implementing:
- `DataTable` — MRT wrapper for all data tables
- `SectionCard` — Card with icon + title for detail pages
- `InfoRow` — label/value pair inside SectionCard
- `OrganizationFilter` — org hierarchy filter UI
- `ConfirmDialog` / `useConfirmDialog` — confirmation modals
- Form components via `useAppForm` (see frontend-tanstack-form skill)
