---
name: vue-patterns
description: Design patterns for Shelfsight's Vue 3 + TypeScript frontend (frontend/). Use before writing or changing any .vue/.ts file under frontend/ — views, components, Pinia stores, composables, API modules, router — to pick the right pattern and location, and when reviewing frontend code for structure.
---

# Vue patterns for Shelfsight

The frontend is a Vue 3 SPA (Vite, TypeScript, Pinia, Vue Router, Tailwind v4, vue-chartjs) talking to the Rails API. Data always flows one way:

```
View ──(store action)──▶ Pinia store ──▶ src/api/<resource>.ts ──▶ request() ──▶ Rails
  │                          │
  └──props──▶ components ◀───┘ (state read via the store in the View, passed down as props)
```

## Decision table

| I'm writing… | Pattern | Put it in | Exists |
|---|---|---|---|
| A page / route target | **View (container)** | `src/views/<Name>View.vue` | ✅ `HomeView.vue` |
| Reusable UI | **Presentational component** | `src/components/<area>/<Name>.vue` | — |
| A chart | **Chart wrapper component** (presentational) | `src/components/charts/<Name>Chart.vue` | — |
| Server data used by more than one view, or that survives navigation | **Pinia setup store** | `src/stores/<domain>.ts` → `use<Domain>Store` | — |
| Reusable stateful logic (async state, polling, debounce) | **Composable** | `src/composables/use<Thing>.ts` | ✅ `useAsync.ts` |
| An HTTP call | **API module** over `request()` | `src/api/<resource>.ts` | ✅ `client.ts`, `health.ts` |
| Request/response shapes | **Types** mirroring the Rails serializers | `src/types/api.ts` | ✅ |
| Auth gating | **Router guard** + `meta.requiresAuth` | `src/router/index.ts` | ✅ (router only) |

✅ = exists today. The rest gets created the first time a milestone needs it, following this skill.

## Views (containers)
- Own the page: read stores, call store actions, read route params, decide loading/empty/error states.
- Pass data down to components as props; react to their events.
- Contain layout, not reusable widgets. If markup repeats or exceeds ~40 lines for one concern, extract a component.

## Presentational components
```vue
<script setup lang="ts">
import type { Recommendation } from '@/types/api'

const props = defineProps<{ recommendation: Recommendation; busy?: boolean }>()
const emit = defineEmits<{ save: [id: number]; dismiss: [id: number] }>()
</script>
```
- **No stores, no API calls, no router.** Inputs are props; outputs are events (or `defineModel` for two-way form fields).
- Never mutate props. Emit and let the parent change state.
- Typed with `defineProps<T>()` / `defineEmits<T>()`, using types imported from `src/types/api.ts`.
- Chart wrappers take plain arrays via props and build the `vue-chartjs` data and options with `computed`. Each one also renders a text/table alternative (SPEC §7, accessibility).

## Pinia stores (setup syntax)
```ts
export const useImportsStore = defineStore('imports', () => {
  const current = ref<Import | null>(null)
  const { loading, error, run } = useAsync(importsApi.create)

  async function upload(file: File) {
    current.value = (await run(file)) ?? null
  }

  const inProgress = computed(() => ['pending', 'processing'].includes(current.value?.status ?? ''))
  return { current, loading, error, inProgress, upload }
})
```
- A store owns **server state** for one domain (auth, imports, insights, library, recommendations), plus its `loading` and `error`.
- Actions call `src/api/*` modules. **Never** call `fetch` or `request()` directly from a store or component.
- Expose derived state as `computed` getters. Keep UI-only state (an open modal, a hovered row) in the component, not the store.
- `useAuthStore` owns the token: it calls `setAuthToken()` and persists to `localStorage` (SPEC §7).

## Composables
- `use<Thing>()` returns refs and functions. It has no template and no global state (that's a store).
- `useAsync(fn)` ✅ gives `{ data, error, loading, run }`, ignores stale responses, and stores errors instead of throwing. Use it for one-off async calls in views and inside store actions.
- `usePolling(fn, { intervalMs: 2000, until, timeoutMs: 300_000 })` is planned for import and batch status polling. It should use `onScopeDispose` for cleanup and stop on a terminal status or timeout.
- If a composable needs the router or a store, call them inside the composable, not at module scope.

## API modules
```ts
// src/api/imports.ts
import { request } from './client'
import type { Import } from '@/types/api'

export const create = (file: File) => {
  const body = new FormData()
  body.append('file', file)
  return request<{ import: Import }>('/imports', { method: 'POST', body }).then((r) => r.import)
}
export const get = (id: number) => request<{ import: Import }>(`/imports/${id}`).then((r) => r.import)
```
- One file per backend resource. Plain functions; no state.
- Unwrap the envelope here (`r.import`), so stores get domain objects.
- `request()` already adds the bearer token and throws `ApiError(status, code, message, details)`.

## Errors in the UI
- Branch on `error instanceof ApiError` and its **`code`** (e.g. `invalid_goodreads_export`, `not_enough_data`, `rate_limited`), never on message text.
- On a `401`, clear auth and redirect to `/login`. Handle this centrally (store + router guard), not in each view.
- Every view has explicit **loading**, **empty**, and **error** states.

## Router
- Lazy-load views except Home: `component: () => import('@/views/LibraryView.vue')`.
- Use `meta: { requiresAuth: true }` with one `router.beforeEach` guard that reads `useAuthStore`.
- Keep filters in the query string (SPEC §7 Library) using `route.query` and `router.replace`.

## General rules
- `<script setup lang="ts">` and the Composition API only. No Options API, no `any`.
- Derived state uses `computed`. Use `watch` only for side effects (syncing to the URL or `localStorage`).
- Tailwind utility classes. Use `<style scoped>` only for what Tailwind can't express.
- Component names are PascalCase and multi-word; composables are `useX`; stores are `useXStore`.

## Anti-patterns
| Don't | Why |
|---|---|
| `fetch`/`request()` in components or stores | Bypasses the token, error mapping and response envelope |
| Stores imported into presentational components | Hidden coupling; components stop being reusable or testable |
| Mutating props | Breaks one-way data flow; Vue warns |
| `watch` to compute a value | Use `computed`; watchers drift out of sync |
| Matching on `error.message` | Messages change; `code` is the contract |
| Duplicating API types inline | Drifts from the serializers; keep everything in `src/types/api.ts` |

## Testing
| Unit | How |
|---|---|
| API module | Stub `fetch` (`vi.stubGlobal`) like `__tests__/client.spec.ts` ✅ |
| Composable | Call it directly; assert refs, like `__tests__/useAsync.spec.ts` ✅ |
| Store | `setActivePinia(createPinia())`; `vi.mock('@/api/<resource>')` |
| Presentational component | `mount(C, { props })`; assert render and `wrapper.emitted()` |
| View | Mock the API module; `flushPromises()`; assert states, like `__tests__/HomeView.spec.ts` ✅ |

oxlint requires typed mocks: `vi.fn<typeof fetch>()`, not `vi.fn()`.

A full worked example (the import upload flow) is in `references/examples.md`.
