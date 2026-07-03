---
name: tanstack-router
description: "How to use TanStack Router for file-based routing. Use this whenever creating new route files, adding search params validation, implementing route guards, using loaders, or navigating programmatically. Covers createFileRoute, validateSearch with Zod, beforeLoad guards, loader prefetch, useSearch, useParams, useNavigate, and Link."
---

# Routing with TanStack Router

## Core Invariants (always enforced — never violate)

- Never manually edit `src/routeTree.gen.ts` — it is auto-generated; commit it, don't hand-edit it.

## References

Read the relevant file when you need it:
- `references/authenticated-routes.md` — full auth guard setup, RouterContext, `beforeLoad` redirect, per-route permission guard
- `references/navigation-blocking.md` — `useBlocker`, custom dialog with `withResolver`, `Block` component, options table

---

## Route Tree Generation

`src/routeTree.gen.ts` is auto-generated — never edit it manually. Commit it to git so TypeScript can type-check in CI without running the dev server.

### Vite plugin (recommended)

```ts
// vite.config.ts
import { tanstackRouter } from '@tanstack/router-plugin/vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [
    tanstackRouter({ target: 'react', autoCodeSplitting: true }),
    react(),
  ],
})
```

> `TanStackRouterVite` is a deprecated alias — prefer `tanstackRouter`.

### CLI (CI / without dev server)

```bash
bun add -D @tanstack/router-cli
bunx tsr generate   # one-shot before build/type-check
bunx tsr watch      # continuous watch
```

### Plugin config options

```ts
tanstackRouter({
  target: 'react',
  routesDirectory: './src/routes',
  generatedRouteTree: './src/routeTree.gen.ts',
  autoCodeSplitting: true,
  routeFileIgnorePrefix: '-',
  quoteStyle: 'single',
  semicolons: false,
})
```

---

## Route File Naming

```
src/routes/
├── __root.tsx
├── _layout.tsx
└── _layout/
    └── your-section/
        └── your-feature/
            ├── index.tsx          # /your-section/your-feature/
            ├── create.tsx         # /your-section/your-feature/create
            └── $featureId/
                ├── index.tsx      # /your-section/your-feature/$featureId
                └── edit.tsx       # /your-section/your-feature/$featureId/edit
```

`_` prefix = pathless layout (no URL segment). `$param` = dynamic segment.

---

## Creating Route Files

### List Page (with search params)

```tsx
// src/routes/_layout/your-section/your-feature/index.tsx
import { createFileRoute, Link } from '@tanstack/react-router'
import { zodValidator } from '@tanstack/zod-adapter'
import { getFeatureSearchSchema } from '@/features/your-feature/schemas/your-feature.schema'
import { guardRoute } from '@/shared/utils/route-guard.util'

export const Route = createFileRoute('/_layout/your-section/your-feature/')({
  validateSearch: zodValidator(getFeatureSearchSchema()),
  beforeLoad: ({ context }) => {
    guardRoute(context.user, ['feature-index'])
    return { breadcrumb: 'breadcrumbs.features' }
  },
  component: FeaturePage,
})

function FeaturePage() {
  const searchParams = Route.useSearch()
  const { data, isLoading } = useYourFeatures(searchParams)

  return (
    <Container maxWidth="xl">
      <Button component={Link} to="/your-section/your-feature/create" variant="contained">
        {t('feature.create')}
      </Button>
      <FeatureList searchParams={searchParams} data={data?.items} total={data?.total} isLoading={isLoading} />
    </Container>
  )
}
```

### Detail Page (with loader prefetch)

```tsx
export const Route = createFileRoute('/_layout/your-section/your-feature/$featureId/')({
  beforeLoad: ({ context }) => {
    guardRoute(context.user, ['feature-index'])
    return { breadcrumb: 'breadcrumbs.featureDetail' }
  },
  loader: async ({ params, context }) => {
    await context.queryClient.ensureQueryData({
      queryKey: YOUR_FEATURE_QUERY_KEYS.detail(Number(params.featureId)),
      queryFn: ({ signal }) => yourFeatureService.getById(Number(params.featureId), signal),
    })
  },
  component: FeatureDetailPage,
})

function FeatureDetailPage() {
  const { featureId } = Route.useParams()
  const { data, isLoading, error } = useYourFeature(Number(featureId))
  return <FeatureDetail feature={data?.item} isLoading={isLoading} error={error} />
}
```

### Edit Page

```tsx
export const Route = createFileRoute('/_layout/your-section/your-feature/$featureId/edit')({
  beforeLoad: ({ context }) => {
    guardRoute(context.user, ['feature-edit'])
    return { breadcrumb: 'breadcrumbs.editFeature' }
  },
  component: () => <FeatureUpdateForm />,
})
```

---

## Search Params Validation

```ts
// features/your-feature/schemas/your-feature.schema.ts
export const getFeatureSearchSchema = () => z.object({
  page: z.number().min(1).catch(1),
  page_size: z.number().min(1).max(100).catch(20),
  search: z.string().optional(),
  status: z.enum(['active', 'inactive']).optional(),
  sort_by: z.string().optional(),
  sort_order: z.enum(['asc', 'desc']).optional(),
})

export type FeatureSearch = z.infer<ReturnType<typeof getFeatureSearchSchema>>
```

Wire up in route:
```ts
import { zodValidator } from '@tanstack/zod-adapter'
validateSearch: zodValidator(getFeatureSearchSchema())
```

---

## Navigation Hooks

### useNavigate

```tsx
const navigate = useNavigate({ from: '/_layout/section/feature/' })

navigate({ search: (prev) => ({ ...prev, page: newPage }) })   // update search
navigate({ to: '/section/feature/$featureId', params: { featureId: String(id) } })
navigate({ to: '/section/feature' })
```

### Route.useNavigate (preferred in list routes — fully typed)

```tsx
const navigate = Route.useNavigate()
navigate({ search: (prev) => ({ ...prev, status: 'active' }) })
```

### useSearch — three modes

```tsx
// 1. Inside route file — no args
const searchParams = Route.useSearch()

// 2. In a feature component — pass from (strict mode, recommended)
const searchParams = useSearch({ from: '/_layout/section/feature/' })
//   from must match the route id in routeTree.gen.ts exactly (include trailing slash for index routes)

// 3. Non-strict — renders under multiple routes (broad type, avoid for single-route components)
const searchParams = useSearch({ strict: false })

// select — re-renders only when selection changes
const page = useSearch({ from: '/_layout/section/feature/', select: (s) => s.page })
```

### useParams

```tsx
const { featureId } = Route.useParams()                                           // in route file
const { featureId } = useParams({ from: '/_layout/section/feature/$featureId/' }) // outside route file
const { featureId } = useParams({ strict: false })                                // non-strict
```

### Link

```tsx
<Button component={Link} to="/section/feature/create">Create</Button>
<Link to="/section/feature/$featureId" params={{ featureId: '123' }}>View</Link>
```

---

## Router Config

```ts
// core/config/router.config.ts
export const router = createRouter({
  routeTree,
  defaultPreload: 'intent',
  scrollRestoration: true,
  context: { queryClient, user: undefined },
})

declare module '@tanstack/react-router' {
  interface Register { router: typeof router }
}
```

## Root Layout

`_layout.tsx` wraps all authenticated routes — Navbar, Sidebar, `<Outlet />`. Its `beforeLoad` handles auth redirects (see `references/authenticated-routes.md`).
