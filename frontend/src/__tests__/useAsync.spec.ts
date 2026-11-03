import { describe, expect, it, vi } from 'vitest'
import { ApiError } from '@/api/client'
import { useAsync } from '@/composables/useAsync'

describe('useAsync', () => {
  it('stores data and toggles loading', async () => {
    const fn = vi.fn<(n: number) => Promise<number>>().mockResolvedValue(42)
    const { data, loading, error, run } = useAsync(fn)

    const pending = run(7)
    expect(loading.value).toBe(true)
    await expect(pending).resolves.toBe(42)

    expect(fn).toHaveBeenCalledWith(7)
    expect(data.value).toBe(42)
    expect(error.value).toBeNull()
    expect(loading.value).toBe(false)
  })

  it('captures ApiError without throwing', async () => {
    const err = new ApiError(422, 'unprocessable', 'Validation failed')
    const { data, error, run } = useAsync(vi.fn<() => Promise<never>>().mockRejectedValue(err))

    await expect(run()).resolves.toBeUndefined()
    expect(error.value).toBe(err)
    expect(data.value).toBeNull()
  })

  it('ignores a stale response that settles after a newer call', async () => {
    let resolveSlow!: (v: string) => void
    const fn = vi
      .fn<(label: string) => Promise<string>>()
      .mockImplementationOnce(() => new Promise((r) => (resolveSlow = r)))
      .mockResolvedValueOnce('fast')
    const { data, loading, run } = useAsync(fn)

    const slow = run('slow')
    await run('fast')
    resolveSlow('slow')
    await slow

    expect(data.value).toBe('fast')
    expect(loading.value).toBe(false)
  })
})
