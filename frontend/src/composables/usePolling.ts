import { onScopeDispose, ref } from 'vue'

/**
 * Calls `fn` every `intervalMs` (default 2s) until `until(value)` is true,
 * the timeout (default 5 minutes) elapses, `stop()` is called, or the
 * owning scope is disposed. Errors from `fn` stop polling.
 */
export function usePolling<T>(
  fn: () => Promise<T>,
  opts: { intervalMs?: number; until: (value: T) => boolean; timeoutMs?: number },
) {
  const active = ref(false)
  let timer: ReturnType<typeof setTimeout> | undefined
  let deadline = 0
  let run = 0

  async function tick(id: number) {
    let value: T
    try {
      value = await fn()
    } catch {
      if (id === run) stop()
      return
    }
    if (id !== run || !active.value) return
    if (opts.until(value) || Date.now() >= deadline) return stop()
    timer = setTimeout(() => void tick(id), opts.intervalMs ?? 2000)
  }

  function start() {
    stop()
    active.value = true
    deadline = Date.now() + (opts.timeoutMs ?? 300_000)
    void tick(++run)
  }

  function stop() {
    run++
    active.value = false
    clearTimeout(timer)
  }

  onScopeDispose(stop)
  return { active, start, stop }
}
