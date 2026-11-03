import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import * as importsApi from '@/api/imports'
import * as authApi from '@/api/auth'
import { ApiError } from '@/api/client'
import { useImportsStore } from '@/stores/imports'
import { baseImport } from './fixtures'

vi.mock('@/api/imports')
vi.mock('@/api/auth')

const file = new File(['a'], 'a.csv', { type: 'text/csv' })

describe('imports store', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.resetAllMocks()
    setActivePinia(createPinia())
  })
  afterEach(() => vi.useRealTimers())

  it('uploads, polls to completion, and refreshes /me stats', async () => {
    vi.mocked(importsApi.create).mockResolvedValue(baseImport)
    vi.mocked(importsApi.get)
      .mockResolvedValueOnce({ ...baseImport, status: 'processing' })
      .mockResolvedValue({ ...baseImport, status: 'completed' })
    vi.mocked(authApi.me).mockResolvedValue({
      user: { id: 1, email_address: 'a@b.co', created_at: '' },
      stats: { books: 3, last_import_at: null },
    })
    const store = useImportsStore()
    await store.upload(file)
    await vi.advanceTimersByTimeAsync(0)
    expect(store.inProgress).toBe(true)
    expect(store.current?.status).toBe('processing')
    await vi.advanceTimersByTimeAsync(2000)
    expect(store.current?.status).toBe('completed')
    expect(store.inProgress).toBe(false)
    expect(authApi.me).toHaveBeenCalledTimes(1)
    await vi.advanceTimersByTimeAsync(10_000)
    expect(importsApi.get).toHaveBeenCalledTimes(2)
  })

  it('exposes the ApiError code on upload failure', async () => {
    vi.mocked(importsApi.create).mockRejectedValue(
      new ApiError(422, 'invalid_goodreads_export', 'Missing Title'),
    )
    const store = useImportsStore()
    await store.upload(file)
    expect(store.current).toBeNull()
    expect(store.error).toBeInstanceOf(ApiError)
    expect((store.error as ApiError).code).toBe('invalid_goodreads_export')
  })

  it('resume picks up an in-progress import', async () => {
    const running = { ...baseImport, status: 'processing' as const }
    vi.mocked(importsApi.list).mockResolvedValue([running])
    vi.mocked(importsApi.get).mockResolvedValue({ ...running, status: 'failed' })
    const store = useImportsStore()
    await store.resume()
    expect(store.current?.id).toBe(1)
    await vi.advanceTimersByTimeAsync(0)
    expect(importsApi.get).toHaveBeenCalledWith(1)
    expect(store.current?.status).toBe('failed')
    expect(authApi.me).not.toHaveBeenCalled()
  })

  it('resume ignores a finished import', async () => {
    vi.mocked(importsApi.list).mockResolvedValue([{ ...baseImport, status: 'completed' }])
    const store = useImportsStore()
    await store.resume()
    expect(store.current).toBeNull()
    expect(store.history).toHaveLength(1)
  })
})
