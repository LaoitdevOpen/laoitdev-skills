---
name: tanstack-query
description: "How to use TanStack Query v5 for data fetching, mutations, and cache management. Use this whenever creating hooks for API calls — list queries, single-item queries, create/update/delete mutations, or cache invalidation. Covers useQuery, useMutation, query key factories, staleTime defaults, and the service layer pattern."
---

# Data Fetching with TanStack Query

## Core Invariants (always enforced — never violate)

- Always define query keys as a factory object in the feature's constants file — never inline ad-hoc array keys.

## Query Client Config

The global `QueryClient` is configured in `@/core/config/query-client.config`:
- `staleTime: 5 minutes` — data stays fresh for 5 min before refetch
- `gcTime: 10 minutes` — unused cache cleared after 10 min
- `retry: 1` — one retry on failure
- `refetchOnWindowFocus: false`

## Query Keys

Always define query keys as a factory object in the feature's constants file. This makes invalidation precise.

```ts
// constants/your-feature.constants.ts
import type { YourFeatureFilterParams } from '../types'

export const YOUR_FEATURE_QUERY_KEYS = {
  all: ['your-features'] as const,
  lists: () => [...YOUR_FEATURE_QUERY_KEYS.all, 'list'] as const,
  list: (params: YourFeatureFilterParams) => [...YOUR_FEATURE_QUERY_KEYS.lists(), params] as const,
  details: () => [...YOUR_FEATURE_QUERY_KEYS.all, 'detail'] as const,
  detail: (id: number) => [...YOUR_FEATURE_QUERY_KEYS.details(), id] as const,
}
```

## List Query

```ts
// hooks/useYourFeatures.ts
import { useQuery } from '@tanstack/react-query'
import { YOUR_FEATURE_QUERY_KEYS } from '../constants'
import { yourFeatureService } from '../services'
import type { YourFeatureFilterParams } from '../types'

export function useYourFeatures(params?: YourFeatureFilterParams) {
  return useQuery({
    queryKey: YOUR_FEATURE_QUERY_KEYS.list(params || {}),
    queryFn: ({ signal }) => yourFeatureService.getAll(params, signal),
    staleTime: 5 * 60 * 1000,
  })
}
```

## Single Item Query

```ts
// hooks/useYourFeature.ts
import { useQuery } from '@tanstack/react-query'
import { YOUR_FEATURE_QUERY_KEYS } from '../constants'
import { yourFeatureService } from '../services'

export function useYourFeature(id: number) {
  return useQuery({
    queryKey: YOUR_FEATURE_QUERY_KEYS.detail(id),
    queryFn: ({ signal }) => yourFeatureService.getById(id, signal),
    staleTime: 5 * 60 * 1000,
    enabled: !!id,
  })
}
```

## Create Mutation

```ts
// hooks/useCreateYourFeature.ts
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { YOUR_FEATURE_QUERY_KEYS } from '../constants'
import { yourFeatureService } from '../services'
import type { YourFeatureCreateRequest } from '../types'

export function useCreateYourFeature() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (data: YourFeatureCreateRequest) => yourFeatureService.create(data),
    onSuccess: () => {
      // Invalidate the list so it refetches
      queryClient.invalidateQueries({ queryKey: YOUR_FEATURE_QUERY_KEYS.lists() })
    },
  })
}
```

## Update Mutation

```ts
// hooks/useUpdateYourFeature.ts
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { YOUR_FEATURE_QUERY_KEYS } from '../constants'
import { yourFeatureService } from '../services'
import type { YourFeatureUpdateRequest } from '../types'

export function useUpdateYourFeature(id: number) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (data: YourFeatureUpdateRequest) => yourFeatureService.update(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: YOUR_FEATURE_QUERY_KEYS.lists() })
      queryClient.invalidateQueries({ queryKey: YOUR_FEATURE_QUERY_KEYS.detail(id) })
    },
  })
}
```

## Delete Mutation

```ts
// hooks/useDeleteYourFeature.ts
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { YOUR_FEATURE_QUERY_KEYS } from '../constants'
import { yourFeatureService } from '../services'

export function useDeleteYourFeature() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (id: number) => yourFeatureService.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: YOUR_FEATURE_QUERY_KEYS.lists() })
    },
  })
}
```

## Service Layer Pattern

Each feature has a service object in `services/your-feature.service.ts`. The service handles Axios calls; hooks handle caching.

```ts
import axiosInstance from '@/core/api/axios.config'
import { YOUR_FEATURE_ENDPOINTS } from '../constants'
import type { YourFeaturesResponse, YourFeatureDetailResponse, YourFeatureCreateRequest } from '../types'

export const yourFeatureService = {
  async getAll(params?: YourFeatureFilterParams, signal?: AbortSignal): Promise<YourFeaturesResponse> {
    const { data } = await axiosInstance.get<YourFeaturesResponse>(
      YOUR_FEATURE_ENDPOINTS.BASE, { params, signal }
    )
    return data
  },

  async getById(id: number, signal?: AbortSignal): Promise<YourFeatureDetailResponse> {
    const { data } = await axiosInstance.get<YourFeatureDetailResponse>(
      YOUR_FEATURE_ENDPOINTS.DETAIL(id), { signal }
    )
    return data
  },

  async create(payload: YourFeatureCreateRequest, signal?: AbortSignal) {
    const { data } = await axiosInstance.post(YOUR_FEATURE_ENDPOINTS.BASE, payload, { signal })
    return data
  },

  async update(id: number, payload: YourFeatureUpdateRequest, signal?: AbortSignal) {
    const { data } = await axiosInstance.put(YOUR_FEATURE_ENDPOINTS.UPDATE(id), payload, { signal })
    return data
  },

  async delete(id: number, signal?: AbortSignal) {
    const { data } = await axiosInstance.delete(YOUR_FEATURE_ENDPOINTS.DETAIL(id), { signal })
    return data
  },
}
```

## Using Mutations in Components

```tsx
const createMutation = useCreateYourFeature()

// In form onSubmit or button handler:
createMutation.mutate(formData, {
  onSuccess: () => {
    showSuccess(t('feature.createSuccess'))
    navigate({ to: '/feature' })
  },
  onError: (error) => {
    showError(translateError(error))
  },
})

// Check pending state for loading UI:
<Button disabled={createMutation.isPending}>
  {createMutation.isPending ? t('common.saving') : t('common.save')}
</Button>
```

## Route Loader Prefetch

For detail pages, prefetch in the route loader so data is ready before the component renders:

```ts
// routes/_layout/section/feature/$featureId/index.tsx
loader: async ({ params, context }) => {
  await context.queryClient.ensureQueryData({
    queryKey: YOUR_FEATURE_QUERY_KEYS.detail(Number(params.featureId)),
    queryFn: ({ signal }) => yourFeatureService.getById(Number(params.featureId), signal),
  })
},
```

The component's `useYourFeature(id)` call then hits the cache immediately.

## Cache Invalidation Strategy

- After **create**: invalidate `lists()`
- After **update**: invalidate both `lists()` and `detail(id)`
- After **delete**: invalidate `lists()`
- For granular invalidation, pass `exact: true` or specific query keys

```ts
// Invalidate all lists (any params)
queryClient.invalidateQueries({ queryKey: YOUR_FEATURE_QUERY_KEYS.lists() })

// Invalidate exact detail
queryClient.invalidateQueries({ queryKey: YOUR_FEATURE_QUERY_KEYS.detail(id) })

// Invalidate everything for this feature
queryClient.invalidateQueries({ queryKey: YOUR_FEATURE_QUERY_KEYS.all })
```
