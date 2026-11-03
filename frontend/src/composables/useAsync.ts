import { ref, shallowRef } from 'vue'

/**
 * Tracks one async operation's data, error and loading state.
 *
 *   const { data, error, loading, run } = useAsync(getHealth)
 *   onMounted(() => run())
 *
 * `error` is an `ApiError` (from `@/api/client`) for backend errors; check
 * `error.value instanceof ApiError` and branch on `.code`. Network failures
 * surface as a plain `Error`.
 *
 * If `run` is called again before an earlier call settles, only the latest
 * call updates state (stale responses are ignored).
 */
export function useAsync<T, A extends unknown[] = []>(fn: (...args: A) => Promise<T>) {
  const data = shallowRef<T | null>(null)
  const error = shallowRef<Error | null>(null)
  const loading = ref(false)
  let latest = 0

  async function run(...args: A): Promise<T | undefined> {
    const id = ++latest
    loading.value = true
    error.value = null
    try {
      const result = await fn(...args)
      if (id === latest) data.value = result
      return result
    } catch (e) {
      if (id === latest) error.value = e instanceof Error ? e : new Error(String(e))
      return undefined
    } finally {
      if (id === latest) loading.value = false
    }
  }

  return { data, error, loading, run }
}
