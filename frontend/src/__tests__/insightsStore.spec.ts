import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import * as insightsApi from '@/api/insights'
import { ApiError } from '@/api/client'
import { useInsightsStore } from '@/stores/insights'
import { snapshot } from './insightsFixtures'

vi.mock('@/api/insights')

describe('insights store', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.resetAllMocks()
    setActivePinia(createPinia())
  })
  afterEach(() => vi.useRealTimers())

  it('treats a 204 as loaded with no snapshot', async () => {
    vi.mocked(insightsApi.get).mockResolvedValue(null)
    const store = useInsightsStore()
    await store.load()
    expect(store.loaded).toBe(true)
    expect(store.snapshot).toBeNull()
    expect(store.error).toBeNull()
  })

  it('exposes load errors', async () => {
    vi.mocked(insightsApi.get).mockRejectedValue(new ApiError(500, 'boom', 'x'))
    const store = useInsightsStore()
    await store.load()
    expect(store.loaded).toBe(false)
    expect((store.error as ApiError).code).toBe('boom')
  })

  it('refresh polls until computed_at changes, then stops', async () => {
    const old = snapshot()
    const fresh = snapshot({ computed_at: '2026-11-02T10:00:00Z' })
    vi.mocked(insightsApi.get).mockResolvedValueOnce(old)
    vi.mocked(insightsApi.refresh).mockResolvedValue({})
    const store = useInsightsStore()
    await store.load()

    vi.mocked(insightsApi.get).mockResolvedValueOnce(old).mockResolvedValue(fresh)
    await store.refresh()
    await vi.advanceTimersByTimeAsync(0)
    expect(store.refreshing).toBe(true)
    await vi.advanceTimersByTimeAsync(2000)
    expect(store.snapshot?.computed_at).toBe(fresh.computed_at)
    expect(store.refreshing).toBe(false)
    const calls = vi.mocked(insightsApi.get).mock.calls.length
    await vi.advanceTimersByTimeAsync(10_000)
    expect(insightsApi.get).toHaveBeenCalledTimes(calls)
  })

  it('refresh from an empty state polls until a snapshot appears', async () => {
    vi.mocked(insightsApi.get).mockResolvedValueOnce(null).mockResolvedValueOnce(null)
    vi.mocked(insightsApi.refresh).mockResolvedValue({})
    const store = useInsightsStore()
    await store.load()
    await store.refresh()
    await vi.advanceTimersByTimeAsync(0)
    expect(store.refreshing).toBe(true)
    vi.mocked(insightsApi.get).mockResolvedValue(snapshot())
    await vi.advanceTimersByTimeAsync(2000)
    expect(store.snapshot).not.toBeNull()
    expect(store.refreshing).toBe(false)
  })

  it('gives up after two minutes', async () => {
    const old = snapshot()
    vi.mocked(insightsApi.get).mockResolvedValue(old)
    vi.mocked(insightsApi.refresh).mockResolvedValue({})
    const store = useInsightsStore()
    await store.load()
    await store.refresh()
    await vi.advanceTimersByTimeAsync(121_000)
    expect(store.refreshing).toBe(false)
  })

  it('does not poll when the refresh request fails', async () => {
    vi.mocked(insightsApi.refresh).mockRejectedValue(new ApiError(500, 'boom', 'x'))
    const store = useInsightsStore()
    await store.refresh()
    expect(store.refreshing).toBe(false)
    expect(insightsApi.get).not.toHaveBeenCalled()
  })
})
