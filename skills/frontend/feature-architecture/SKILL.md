---
name: feature-architecture
description: "Feature folder structure and architecture for React + TypeScript admin apps. Use this when creating a new feature, adding a major section, or when asked how to organize a feature's files. Covers the canonical folder layout (components, hooks, services, types, schemas, constants, utils), what goes where, and index export conventions."
---

# Feature Architecture

## Core Invariants (always enforced — never violate)

- **Route files NEVER go inside `features/`** — they live exclusively in `src/routes/`. A feature folder contains zero route files.
- Feature folders contain only: `components/`, `hooks/`, `services/`, `schemas/`, `types/`, `constants/`, `utils/`, `index.ts`.
- Nothing in `features/` may import from `src/routes/`.

## Project Top-Level Structure

```
src/
├── assets/          # Static assets, locale JSON files
├── core/            # App-level infrastructure (axios, queryClient, router, i18n, contexts)
├── features/        # Business logic, UI components, hooks, services — one folder per domain
├── routes/          # ALL route files — file-based routing only, never inside features/
└── shared/          # Cross-feature shared components, hooks, types, utils
```

## Canonical Feature Folder Layout

```
features/
└── your-feature/
    ├── components/
    │   ├── YourFeatureList.tsx        # Data table component
    │   ├── YourFeatureDetail.tsx      # Detail view
    │   ├── YourFeatureForm.tsx        # Create/Update form
    │   ├── YourFeatureFilters.tsx     # Filter accordion
    │   ├── YourFeatureFormSections/   # Form sub-sections (optional)
    │   │   ├── BasicInfoSection.tsx
    │   │   └── index.ts
    │   └── index.ts                   # Re-exports all public components
    ├── constants/
    │   └── your-feature.constants.ts  # Endpoints, query keys, option lists
    ├── hooks/
    │   ├── useYourFeatures.ts         # List query
    │   ├── useYourFeature.ts          # Single item query
    │   ├── useCreateYourFeature.ts    # Create mutation
    │   ├── useUpdateYourFeature.ts    # Update mutation
    │   ├── useDeleteYourFeature.ts    # Delete mutation
    │   └── index.ts                   # Re-exports all hooks
    ├── schemas/
    │   └── your-feature.schema.ts     # Zod schemas (search + form) — imported by route files
    ├── services/
    │   ├── your-feature.service.ts    # Axios service object
    │   └── index.ts
    ├── types/
    │   └── index.ts                   # All TypeScript types/interfaces
    ├── utils/                         # Pure utility functions (optional)
    │   └── index.ts
    └── index.ts                       # Public API of the feature
```

## What Goes Where

### `types/index.ts`
All TypeScript types for the feature — API response shapes, filter params, form data types.

```ts
export interface YourFeature {
  id: number
  name: string | null
  // ...
}

export interface YourFeaturesResponse {
  items: YourFeature[]
  total: number
}

export interface YourFeatureFilterParams {
  page?: number
  page_size?: number
  search?: string
  // ...
}
```

### `constants/your-feature.constants.ts`
Three things: API endpoint strings, TanStack Query key factory, and option arrays.

```ts
export const YOUR_FEATURE_ENDPOINTS = {
  BASE: '/v1/admin/your-features',
  DETAIL: (id: number) => `/v1/admin/your-features/${id}`,
  UPDATE: (id: number) => `/v1/admin/your-features/${id}`,
} as const

export const YOUR_FEATURE_QUERY_KEYS = {
  all: ['your-features'] as const,
  lists: () => [...YOUR_FEATURE_QUERY_KEYS.all, 'list'] as const,
  list: (params: YourFeatureFilterParams) => [...YOUR_FEATURE_QUERY_KEYS.lists(), params] as const,
  details: () => [...YOUR_FEATURE_QUERY_KEYS.all, 'detail'] as const,
  detail: (id: number) => [...YOUR_FEATURE_QUERY_KEYS.details(), id] as const,
}

export const STATUS_OPTIONS = [
  { value: 'active', label: 'yourFeature.statusOptions.active' },
  { value: 'inactive', label: 'yourFeature.statusOptions.inactive' },
] as const
```

### `services/your-feature.service.ts`
Object with async methods, each taking an optional `signal?: AbortSignal` for cancellation.

```ts
import axiosInstance from '@/core/api/axios.config'

export const yourFeatureService = {
  async getAll(params?: YourFeatureFilterParams, signal?: AbortSignal) {
    const { data } = await axiosInstance.get<YourFeaturesResponse>(
      YOUR_FEATURE_ENDPOINTS.BASE, { params, signal }
    )
    return data
  },
  async getById(id: number, signal?: AbortSignal) {
    const { data } = await axiosInstance.get(YOUR_FEATURE_ENDPOINTS.DETAIL(id), { signal })
    return data
  },
  async update(id: number, payload: YourFeatureUpdateRequest, signal?: AbortSignal) {
    const { data } = await axiosInstance.put(YOUR_FEATURE_ENDPOINTS.UPDATE(id), payload, { signal })
    return data
  },
}
```

### `hooks/` — one file per operation
Thin wrappers around TanStack Query. See `tanstack-query` skill for full patterns.

### `schemas/your-feature.schema.ts`
Zod schemas for both search params and form validation. Search schemas are imported by route files. Form schemas use factory functions that accept `t: TFunction`. See `tanstack-form` and `tanstack-router` skills.

```ts
import { fallback } from '@tanstack/zod-adapter'

// Search schema — imported by route file for validateSearch
export const yourFeatureSearchSchema = z.object({
  page: fallback(z.number(), 1).default(1),
  page_size: fallback(z.number(), 20).default(20),
  search: z.string().optional(),
})
export type YourFeatureSearch = z.infer<typeof yourFeatureSearchSchema>

// Form schema — factory because it needs translated error messages
export const getYourFeatureSchema = (t: TFunction) => z.object({
  name: z.string().min(1, t('validation.required')),
})
export type YourFeatureFormData = z.infer<ReturnType<typeof getYourFeatureSchema>>
```

### `components/index.ts`
Named re-exports only — keeps route file imports clean.

```ts
export { YourFeatureList } from './YourFeatureList'
export { YourFeatureDetail } from './YourFeatureDetail'
export { YourFeatureFilters } from './YourFeatureFilters'
```

### `index.ts` (feature root)
Barrel export of the feature's public API. Route files import from here or from specific sub-paths.

```ts
export * from './components'
export * from './hooks'
export * from './types'
```

## Route Files — Where They Live

Route files are **not part of the feature folder**. They live in `src/routes/` following the URL structure:

```
src/routes/
└── _layout/
    └── your-section/
        └── your-feature/
            ├── index.tsx          # list page
            ├── create.tsx         # create page
            └── $featureId/
                ├── index.tsx      # detail page
                └── edit.tsx       # edit page
```

Route files are thin — they only wire URL params/search to feature components. See `tanstack-router` skill for the full route file pattern.

## Form Sections Pattern

For complex forms, split fields into section components under `YourFeatureFormSections/`. Each section receives `form` as a typed prop:

```tsx
interface BasicInfoSectionProps {
  form: YourFeatureFormApi
}

export function BasicInfoSection({ form }: BasicInfoSectionProps) {
  return (
    <FormSectionCard title="Basic Info">
      <form.AppField name="name">
        {(field) => <field.TextField label={t('feature.name')} />}
      </form.AppField>
    </FormSectionCard>
  )
}
```

The `YourFeatureFormApi` type is defined in the schema file:
```ts
export interface YourFeatureFormApi extends AppFormApi<YourFeatureFormData> {}
```
