---
name: react-core
description: "How to implement the src/core folder — app-level infrastructure shared by every feature. Covers folder structure, Axios config with auth interceptors, QueryClient, router config, i18n setup, theme, AuthContext, SnackbarContext, ThemeContext, type-safe storage utility, Zustand layout store, and main.tsx provider composition. Use whenever setting up a new project, adding a new core concern, or modifying any of these foundational files."
---

# Core Folder

`src/core/` contains app-level infrastructure that every feature depends on but no single feature owns. Nothing in `core/` should import from `features/`.

## Core Invariants (always enforced — never violate)

- Nothing in `core/` may import from `features/`.

## References

Read the relevant file when you need it:
- `references/contexts.md` — full implementation of `ThemeContext`, `AuthContext`, `SnackbarContext`
- `references/storage-store.md` — `storage` utility, `STORAGE_KEYS`, `useLayoutStore` (Zustand)

---

## Folder Structure

```
src/core/
├── api/
│   └── axios.config.ts        # Axios instance — auth header + 401 handling
├── config/
│   ├── i18n.config.ts         # i18next init — import side-effect in main.tsx
│   ├── query-client.config.ts # QueryClient singleton with default options
│   └── theme.config.ts        # createAppTheme(mode) factory
├── router/
│   ├── index.tsx              # createRouter + Register declaration
│   └── routeTree.gen.ts       # auto-generated — never edit manually
├── context/
│   ├── AuthContext.tsx         # user state, login(), logout()
│   ├── SnackbarContext.tsx     # showSuccess/Error/Warning/Info
│   └── ThemeContext.tsx        # ThemeProvider + MUI + dayjs
├── store/
│   └── layout.store.ts        # Zustand — sidebar open/close (persisted)
└── utils/
    └── storage.ts             # Type-safe localStorage + STORAGE_KEYS
```

---

## `core/api/axios.config.ts`

Single Axios instance. Attaches the Bearer token on every request; handles global 401 by clearing the token and redirecting to `/login`.

```ts
import axios from 'axios'
import { storage, STORAGE_KEYS } from '@/core/utils/storage'

const axiosInstance = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 30000,
  headers: { 'Content-Type': 'application/json' },
})

axiosInstance.interceptors.request.use((config) => {
  const token = storage.get<string>(STORAGE_KEYS.ACCESS_TOKEN)
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

axiosInstance.interceptors.response.use(
  (response) => response,
  (error) => {
    const isLoginRequest = error.config?.url?.includes('/auth/login')
    const isOnLoginPage = window.location.pathname.includes('/login')
    if (error.response?.status === 401 && !isLoginRequest && !isOnLoginPage) {
      storage.remove(STORAGE_KEYS.ACCESS_TOKEN)
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export default axiosInstance
```

All feature services: `import axiosInstance from '@/core/api/axios.config'`

---

## `core/config/query-client.config.ts`

```ts
import { QueryClient } from '@tanstack/react-query'

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,   // 5 min
      gcTime: 1000 * 60 * 10,     // 10 min
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
})
```

---

## `core/router/index.tsx`

Route tree generation config → see `tanstack-router` skill.

```ts
import { createRouter as createTanStackRouter } from '@tanstack/react-router'
import { routeTree } from './routeTree.gen'
import { queryClient } from '@/core/config/query-client.config'
import type { RouterContext } from '@/routes/__root'

export function createRouter() {
  return createTanStackRouter({
    routeTree,
    defaultPreload: 'intent',
    scrollRestoration: true,
    context: {
      queryClient,
      user: undefined,
    } as RouterContext,
  })
}

declare module '@tanstack/react-router' {
  interface Register { router: ReturnType<typeof createRouter> }
}
```

---

## `core/config/i18n.config.ts`

Import as a side-effect in `main.tsx` — never import the default export unless you need the `i18n` instance.

```ts
import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import LanguageDetector from 'i18next-browser-languagedetector'
import enTranslation from '@/locales/en.json'

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources: { en: { translation: enTranslation } },
    lng: 'en',
    fallbackLng: 'en',
    defaultNS: 'translation',
    interpolation: { escapeValue: false },
    detection: { order: ['localStorage', 'navigator'], caches: ['localStorage'] },
    debug: import.meta.env.DEV,
  })

export default i18n
```

Add languages by adding keys under `resources` and JSON files under `src/locales/`.

---

## `main.tsx` — Provider Composition

Order matters — outer providers must not depend on inner ones.

```tsx
import { StrictMode, Suspense } from 'react'
import { createRoot } from 'react-dom/client'
import { QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from '@tanstack/react-router'
import { ThemeProvider } from '@/core/context/ThemeContext'
import { AuthProvider } from '@/core/context/AuthContext'
import { SnackbarProvider } from '@/core/context/SnackbarContext'
import { queryClient } from '@/core/config/query-client.config'
import { createRouter } from '@/core/router'
import '@/core/config/i18n.config'   // side-effect — init i18next before first render
import './index.css'

const router = createRouter()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>   {/* outermost — loaders + AuthProvider need it */}
      <ThemeProvider>                            {/* MUI theme always available */}
        <AuthProvider>                           {/* inside Theme, outside Snackbar */}
          <SnackbarProvider>                     {/* route components can call useSnackbar() */}
            <Suspense fallback={null}>
              <RouterProvider router={router} />
            </Suspense>
          </SnackbarProvider>
        </AuthProvider>
      </ThemeProvider>
    </QueryClientProvider>
  </StrictMode>,
)
```
