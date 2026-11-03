import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import * as profileApi from '@/api/goodreadsProfile'
import { useAsync } from '@/composables/useAsync'
import { useImportsStore } from '@/stores/imports'
import type { GoodreadsProfile } from '@/types/api'

/** Extracts the numeric Goodreads user id from bare digits or a profile URL. */
export function extractGoodreadsUserId(input: string): string | null {
  const text = input.trim()
  if (/^\d+$/.test(text)) return text
  return text.match(/\/user\/show\/(\d+)/)?.[1] ?? null
}

export const useGoodreadsProfileStore = defineStore('goodreadsProfile', () => {
  const profile = ref<GoodreadsProfile | null>(null)
  const loadCall = useAsync(profileApi.get)
  const saveCall = useAsync(profileApi.update)
  const syncCall = useAsync(profileApi.sync)

  const loading = loadCall.loading
  const saving = saveCall.loading
  const syncing = syncCall.loading
  const loadError = loadCall.error
  const saveError = saveCall.error
  const syncError = syncCall.error
  const invalidInput = ref(false)
  const hasProfile = computed(() => profile.value !== null)

  async function load() {
    const result = await loadCall.run()
    if (result !== undefined) profile.value = result
  }

  /** Returns true on success. `invalidInput` is set when no id could be extracted. */
  async function save(input: string, rssEnabled: boolean) {
    const id = extractGoodreadsUserId(input)
    invalidInput.value = id === null
    if (id === null) return false
    const saved = await saveCall.run(id, rssEnabled)
    if (saved) profile.value = saved
    return !!saved
  }

  async function sync() {
    const created = await syncCall.run()
    if (created) useImportsStore().track(created)
    return !!created
  }

  return {
    profile,
    hasProfile,
    loading,
    saving,
    syncing,
    loadError,
    saveError,
    syncError,
    invalidInput,
    load,
    save,
    sync,
  }
})
