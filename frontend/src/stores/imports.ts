import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import * as importsApi from '@/api/imports'
import { useAsync } from '@/composables/useAsync'
import { usePolling } from '@/composables/usePolling'
import { useAuthStore } from '@/stores/auth'
import type { Import } from '@/types/api'

const isTerminal = (i: Import) => i.status === 'completed' || i.status === 'failed'

export const useImportsStore = defineStore('imports', () => {
  const current = ref<Import | null>(null)
  const history = ref<Import[]>([])

  const createCall = useAsync(importsApi.create)
  const historyCall = useAsync(importsApi.list)
  const uploading = createCall.loading
  const error = computed(() => createCall.error.value ?? historyCall.error.value)

  const poller = usePolling(
    async () => {
      const latest = await importsApi.get(current.value!.id)
      current.value = latest
      if (latest.status === 'completed') {
        try {
          await useAuthStore().fetchMe()
        } catch {
          // Stats refresh is best-effort.
        }
      }
      // Keep the history list in sync once an import settles (e.g. after an RSS sync in Settings).
      if (isTerminal(latest)) {
        const i = history.value.findIndex((imp) => imp.id === latest.id)
        if (i >= 0) history.value.splice(i, 1, latest)
        else history.value.unshift(latest)
      }
      return latest
    },
    { until: isTerminal },
  )

  const inProgress = computed(
    () => current.value?.status === 'pending' || current.value?.status === 'processing',
  )

  async function upload(file: File) {
    const created = await createCall.run(file)
    if (!created) return
    current.value = created
    poller.start()
  }

  /** Starts polling an import created elsewhere (e.g. an RSS sync). */
  function track(created: Import) {
    current.value = created
    poller.start()
  }

  async function loadHistory() {
    history.value = (await historyCall.run()) ?? history.value
  }

  async function resume() {
    await loadHistory()
    const latest = history.value[0]
    if (latest && !isTerminal(latest)) {
      current.value = latest
      poller.start()
    }
  }

  return { current, history, uploading, error, inProgress, upload, track, loadHistory, resume }
})
