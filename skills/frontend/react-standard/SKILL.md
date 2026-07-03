---
name: react-standard
description: "Core frontend coding standards for React + TypeScript projects using MUI, TanStack libraries, i18next, and Zod. Use this whenever writing any new component, hook, service, type, or utility — or when reviewing existing code for consistency. Covers naming conventions, file structure, TypeScript patterns, i18n, error handling, and import aliases."
---

# Frontend Coding Standards

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
> ```
> @mui/material @emotion/react @emotion/styled
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
- **Route files**: kebab-case directories, `index.tsx` for list pages, `$paramId/index.tsx` for detail, `$paramId/edit.tsx` for edit

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
- Use MUI `Grid` with `size={{ xs: 12, md: 6 }}` (v9 unified Grid — no separate Grid2 import needed).
- Use `elevation={0}` with `border` on Cards for flat design.
- Use `Container maxWidth="xl"` for page-level containers.

## Shared Components

Prefer shared components over re-implementing:
- `DataTable` — MRT wrapper for all data tables
- `SectionCard` — Card with icon + title for detail pages
- `InfoRow` — label/value pair inside SectionCard
- `OrganizationFilter` — org hierarchy filter UI
- `ConfirmDialog` / `useConfirmDialog` — confirmation modals
- Form components via `useAppForm` (see frontend-tanstack-form skill)
