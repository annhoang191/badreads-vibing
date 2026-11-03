# Worked example: import upload flow (SPEC §3.2, §7 Onboarding)

How the patterns compose for one feature. It's a sketch to copy the shape from: check types against `src/types/api.ts` and the Rails serializers before you use it.

```
OnboardingView (container)
  ├─ CsvDropzone (presentational)        emits `select(file)`
  ├─ ImportStatusCard (presentational)   props: import
  └─ useImportsStore
        ├─ upload(file)  → api/imports.create   (useAsync)
        └─ watch(id)     → usePolling(api/imports.get) until terminal status
```

## Types (`src/types/api.ts`)
```ts
export type ImportStatus = 'pending' | 'processing' | 'completed' | 'failed'

export interface Import {
  id: number
  source: 'csv' | 'rss'
  status: ImportStatus
  filename: string | null
  stats: { rows_total?: number; books_created?: number; rows_skipped?: number } | null
  error_message: string | null
  started_at: string | null
  finished_at: string | null
}
```

## API module (`src/api/imports.ts`)
```ts
import { request } from './client'
import type { Import } from '@/types/api'

export function create(file: File) {
  const body = new FormData()
  body.append('file', file)
  return request<{ import: Import }>('/imports', { method: 'POST', body }).then((r) => r.import)
}

export const get = (id: number) =>
  request<{ import: Import }>(`/imports/${id}`).then((r) => r.import)
```

## Composable (`src/composables/usePolling.ts`)
```ts
import { onScopeDispose, ref } from 'vue'

export function usePolling<T>(
  fn: () => Promise<T>,
  opts: { intervalMs?: number; until: (value: T) => boolean; timeoutMs?: number },
) {
  const active = ref(false)
  let timer: ReturnType<typeof setTimeout> | undefined
  let deadline = 0

  async function tick() {
    const value = await fn()
    if (!active.value) return
    if (opts.until(value) || Date.now() > deadline) return stop()
    timer = setTimeout(tick, opts.intervalMs ?? 2000)
  }

  function start() {
    stop()
    active.value = true
    deadline = Date.now() + (opts.timeoutMs ?? 300_000)
    void tick()
  }

  function stop() {
    active.value = false
    clearTimeout(timer)
  }

  onScopeDispose(stop)
  return { active, start, stop }
}
```

## Store (`src/stores/imports.ts`)
```ts
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import * as importsApi from '@/api/imports'
import { useAsync } from '@/composables/useAsync'
import { usePolling } from '@/composables/usePolling'
import type { Import } from '@/types/api'

const TERMINAL = ['completed', 'failed'] as const

export const useImportsStore = defineStore('imports', () => {
  const current = ref<Import | null>(null)
  const { loading: uploading, error, run: create } = useAsync(importsApi.create)

  const poller = usePolling(
    async () => (current.value = await importsApi.get(current.value!.id)),
    { until: (i) => TERMINAL.includes(i.status as (typeof TERMINAL)[number]) },
  )

  async function upload(file: File) {
    const created = await create(file)
    if (!created) return
    current.value = created
    poller.start()
  }

  const inProgress = computed(() => current.value?.status === 'pending' || current.value?.status === 'processing')

  return { current, uploading, error, inProgress, upload }
})
```

## Presentational component (`src/components/imports/ImportStatusCard.vue`)
```vue
<script setup lang="ts">
import { computed } from 'vue'
import type { Import } from '@/types/api'

const props = defineProps<{ import: Import }>()
const label = computed(() => ({ pending: 'Queued', processing: 'Importing…', completed: 'Done', failed: 'Failed' })[props.import.status])
</script>

<template>
  <section class="rounded border p-4" aria-live="polite">
    <p class="font-medium">{{ label }}</p>
    <p v-if="props.import.stats" class="text-sm text-gray-600">
      {{ props.import.stats.books_created ?? 0 }} books added ·
      {{ props.import.stats.rows_skipped ?? 0 }} rows skipped
    </p>
    <p v-if="props.import.error_message" class="text-sm text-red-600">{{ props.import.error_message }}</p>
  </section>
</template>
```

## View (`src/views/OnboardingView.vue`)
```vue
<script setup lang="ts">
import { computed } from 'vue'
import { ApiError } from '@/api/client'
import CsvDropzone from '@/components/imports/CsvDropzone.vue'
import ImportStatusCard from '@/components/imports/ImportStatusCard.vue'
import { useImportsStore } from '@/stores/imports'

const imports = useImportsStore()

const errorText = computed(() => {
  const e = imports.error
  if (!(e instanceof ApiError)) return e ? 'Something went wrong. Try again.' : null
  return e.code === 'invalid_goodreads_export'
    ? "That file doesn't look like a Goodreads export."
    : e.code === 'import_in_progress'
      ? 'An import is already running.'
      : e.message
})
</script>

<template>
  <main class="mx-auto max-w-xl p-8">
    <CsvDropzone :disabled="imports.uploading || imports.inProgress" @select="imports.upload" />
    <p v-if="errorText" role="alert" class="mt-4 text-red-600">{{ errorText }}</p>
    <ImportStatusCard v-if="imports.current" class="mt-6" :import="imports.current" />
  </main>
</template>
```

## Tests
```ts
// __tests__/stores/imports.spec.ts
vi.mock('@/api/imports')            // then vi.mocked(importsApi.create).mockResolvedValue(...)
beforeEach(() => setActivePinia(createPinia()))
// upload() sets current and starts polling; stops on 'completed' (use vi.useFakeTimers())

// __tests__/components/ImportStatusCard.spec.ts
// mount(ImportStatusCard, { props: { import: { ...base, status: 'failed', error_message: 'x' } } })
// expect(wrapper.text()).toContain('Failed')
```
