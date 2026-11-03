import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import * as recsApi from '@/api/recommendations'
import { useAsync } from '@/composables/useAsync'
import { usePolling } from '@/composables/usePolling'
import type { RecommendationBatch, RecommendationQuota } from '@/types/api'

export const BATCH_TIMEOUT_MS = 120_000

const isActive = (b: RecommendationBatch | null) =>
  b?.status === 'pending' || b?.status === 'processing'

export const useRecommendationsStore = defineStore('recommendations', () => {
  const batch = ref<RecommendationBatch | null>(null)
  const quota = ref<RecommendationQuota | null>(null)
  const loaded = ref(false)

  const loadCall = useAsync(recsApi.latest)
  const generateCall = useAsync(recsApi.generate)

  const poller = usePolling(
    async () => {
      const latest = await recsApi.getBatch(batch.value!.id)
      batch.value = latest
      if (!isActive(latest)) {
        // Quota changed once the batch settled; refresh best-effort.
        try {
          quota.value = (await recsApi.latest()).quota
        } catch {
          // Ignore.
        }
      }
      return latest
    },
    { intervalMs: 2000, timeoutMs: BATCH_TIMEOUT_MS, until: (b) => !isActive(b) },
  )

  const loading = loadCall.loading
  const generating = generateCall.loading
  const error = computed(() => loadCall.error.value ?? generateCall.error.value)
  const recommendations = computed(() => batch.value?.recommendations ?? [])
  const inProgress = computed(() => isActive(batch.value))
  const timedOut = computed(
    () => inProgress.value && !poller.active.value && !generating.value && loaded.value,
  )
  const canGenerate = computed(
    () => (quota.value?.remaining ?? 0) > 0 && !inProgress.value && !generating.value,
  )

  async function load() {
    const result = await loadCall.run()
    if (!result) return
    batch.value = result.batch
    quota.value = result.quota
    loaded.value = true
    if (isActive(result.batch)) poller.start()
  }

  async function generate() {
    const result = await generateCall.run()
    if (!result) return
    batch.value = result.batch
    quota.value = result.quota
    loaded.value = true
    if (isActive(result.batch)) poller.start()
  }

  return {
    batch,
    quota,
    loaded,
    loading,
    generating,
    error,
    recommendations,
    inProgress,
    timedOut,
    canGenerate,
    load,
    generate,
  }
})
