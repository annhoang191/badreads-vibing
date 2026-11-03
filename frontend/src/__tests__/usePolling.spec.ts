import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { effectScope } from 'vue'
import { usePolling } from '@/composables/usePolling'

describe('usePolling', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('polls every interval until the predicate is satisfied', async () => {
    const fn = vi.fn<() => Promise<number>>()
    fn.mockResolvedValueOnce(1).mockResolvedValueOnce(2).mockResolvedValue(3)
    const p = usePolling(fn, { until: (n) => n >= 3 })
    p.start()
    await vi.advanceTimersByTimeAsync(0)
    expect(fn).toHaveBeenCalledTimes(1)
    expect(p.active.value).toBe(true)
    await vi.advanceTimersByTimeAsync(2000)
    expect(fn).toHaveBeenCalledTimes(2)
    await vi.advanceTimersByTimeAsync(2000)
    expect(fn).toHaveBeenCalledTimes(3)
    expect(p.active.value).toBe(false)
    await vi.advanceTimersByTimeAsync(10_000)
    expect(fn).toHaveBeenCalledTimes(3)
  })

  it('stops after the timeout', async () => {
    const fn = vi.fn<() => Promise<number>>().mockResolvedValue(0)
    const p = usePolling(fn, { until: () => false, timeoutMs: 5000 })
    p.start()
    await vi.advanceTimersByTimeAsync(20_000)
    expect(p.active.value).toBe(false)
    expect(fn.mock.calls.length).toBeLessThanOrEqual(4)
  })

  it('stops when the scope is disposed', async () => {
    const fn = vi.fn<() => Promise<number>>().mockResolvedValue(0)
    const scope = effectScope()
    const p = scope.run(() => usePolling(fn, { until: () => false }))!
    p.start()
    await vi.advanceTimersByTimeAsync(0)
    scope.stop()
    await vi.advanceTimersByTimeAsync(10_000)
    expect(fn).toHaveBeenCalledTimes(1)
    expect(p.active.value).toBe(false)
  })

  it('stops when fn rejects', async () => {
    const fn = vi.fn<() => Promise<number>>().mockRejectedValue(new Error('x'))
    const p = usePolling(fn, { until: () => false })
    p.start()
    await vi.advanceTimersByTimeAsync(5000)
    expect(fn).toHaveBeenCalledTimes(1)
    expect(p.active.value).toBe(false)
  })
})
