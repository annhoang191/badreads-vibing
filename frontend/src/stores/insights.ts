import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import * as insightsApi from '@/api/insights'
import { useAsync } from '@/composables/useAsync'
import { usePolling } from '@/composables/usePolling'
import type { InsightsSnapshot } from '@/types/api'

export const REFRESH_TIMEOUT_MS = 120_000

export const useInsightsStore = defineStore('insights', () => {
  const snapshot = ref<InsightsSnapshot | null>(null)
  const loaded = ref(false)

  const loadCall = useAsync(insightsApi.get)
  const refreshCall = useAsync(insightsApi.refresh)
  let baseline: string | null = null

  const poller = usePolling(
    async () => {
      const latest = await insightsApi.get()
      if (latest) snapshot.value = latest
      return latest
    },
    {
      intervalMs: 2000,
      timeoutMs: REFRESH_TIMEOUT_MS,
      until: (latest) => !!latest && latest.computed_at !== baseline,
    },
  )

  const loading = loadCall.loading
  const error = computed(() => loadCall.error.value ?? refreshCall.error.value)
  const refreshing = computed(() => refreshCall.loading.value || poller.active.value)

  async function load() {
    const result = await loadCall.run()
    if (result !== undefined) {
      snapshot.value = result
      loaded.value = true
    }
  }

  /** Requests a recompute, then polls until `computed_at` changes (or 2 minutes pass). */
  async function refresh() {
    baseline = snapshot.value?.computed_at ?? null
    await refreshCall.run()
    if (refreshCall.error.value) return
    poller.start()
  }

  return { snapshot, loaded, loading, error, refreshing, load, refresh }
})
