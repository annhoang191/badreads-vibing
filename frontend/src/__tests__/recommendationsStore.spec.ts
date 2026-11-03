import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import * as recsApi from '@/api/recommendations'
import { ApiError } from '@/api/client'
import { useRecommendationsStore } from '@/stores/recommendations'
import { batch, quota } from './recsFixtures'

vi.mock('@/api/recommendations')

const pending = batch({ status: 'pending', recommendations: [] })

describe('recommendations store', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.resetAllMocks()
    setActivePinia(createPinia())
  })
  afterEach(() => vi.useRealTimers())

  it('load resumes polling when the latest batch is in progress', async () => {
    vi.mocked(recsApi.latest).mockResolvedValue({ batch: pending, quota: quota() })
    vi.mocked(recsApi.getBatch).mockResolvedValue(batch())
    const store = useRecommendationsStore()
    await store.load()
    await vi.advanceTimersByTimeAsync(0)
    expect(store.inProgress).toBe(false)
    expect(recsApi.getBatch).toHaveBeenCalledWith(1)
    expect(store.recommendations).toHaveLength(10)
  })

  it('load does not poll for a completed batch', async () => {
    vi.mocked(recsApi.latest).mockResolvedValue({ batch: batch(), quota: quota() })
    const store = useRecommendationsStore()
    await store.load()
    await vi.advanceTimersByTimeAsync(5000)
    expect(recsApi.getBatch).not.toHaveBeenCalled()
    expect(store.recommendations).toHaveLength(10)
  })

  it('generate polls until completed and populates recommendations', async () => {
    vi.mocked(recsApi.latest).mockResolvedValue({ batch: null, quota: quota({ remaining: 3 }) })
    vi.mocked(recsApi.generate).mockResolvedValue({
      batch: pending,
      quota: quota({ remaining: 3 }),
    })
    vi.mocked(recsApi.getBatch)
      .mockResolvedValueOnce({ ...pending, status: 'processing' })
      .mockResolvedValue(batch())
    const store = useRecommendationsStore()
    await store.generate()
    await vi.advanceTimersByTimeAsync(0)
    expect(store.inProgress).toBe(true)
    expect(store.canGenerate).toBe(false)
    await vi.advanceTimersByTimeAsync(2000)
    expect(store.inProgress).toBe(false)
    expect(store.recommendations).toHaveLength(10)
    expect(store.canGenerate).toBe(true)
  })

  it('reports timedOut after the polling timeout', async () => {
    vi.mocked(recsApi.latest).mockResolvedValue({ batch: pending, quota: quota() })
    vi.mocked(recsApi.getBatch).mockResolvedValue(pending)
    const store = useRecommendationsStore()
    await store.load()
    await vi.advanceTimersByTimeAsync(0)
    expect(store.timedOut).toBe(false)
    await vi.advanceTimersByTimeAsync(121_000)
    expect(store.timedOut).toBe(true)
  })

  it.each([
    ['not_enough_data', 422, { required: 10, have: 3 }],
    ['rate_limited', 429, { retry_after: 600 }],
    ['batch_in_progress', 409, {}],
  ])('exposes the %s code on generate failure', async (code, status, details) => {
    vi.mocked(recsApi.generate).mockRejectedValue(new ApiError(status, code, 'x', details))
    const store = useRecommendationsStore()
    await store.generate()
    expect(store.error).toBeInstanceOf(ApiError)
    expect((store.error as ApiError).code).toBe(code)
    expect(recsApi.getBatch).not.toHaveBeenCalled()
  })

  it('canGenerate requires remaining quota', async () => {
    vi.mocked(recsApi.latest).mockResolvedValue({
      batch: batch(),
      quota: quota({ remaining: 0 }),
    })
    const store = useRecommendationsStore()
    expect(store.canGenerate).toBe(false)
    await store.load()
    expect(store.canGenerate).toBe(false)
  })
})
