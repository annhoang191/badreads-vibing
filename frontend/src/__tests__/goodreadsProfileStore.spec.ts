import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import * as profileApi from '@/api/goodreadsProfile'
import * as importsApi from '@/api/imports'
import { ApiError } from '@/api/client'
import { extractGoodreadsUserId, useGoodreadsProfileStore } from '@/stores/goodreadsProfile'
import { useImportsStore } from '@/stores/imports'
import type { GoodreadsProfile } from '@/types/api'
import { baseImport } from './fixtures'

vi.mock('@/api/goodreadsProfile')
vi.mock('@/api/imports')

const profile: GoodreadsProfile = {
  goodreads_user_id: '12345',
  rss_enabled: true,
  last_synced_at: null,
  last_error: null,
  consecutive_failures: 0,
}

describe('extractGoodreadsUserId', () => {
  it('accepts bare digits and profile URLs', () => {
    expect(extractGoodreadsUserId(' 12345 ')).toBe('12345')
    expect(extractGoodreadsUserId('https://www.goodreads.com/user/show/12345-jane')).toBe('12345')
    expect(extractGoodreadsUserId('goodreads.com/user/show/987')).toBe('987')
  })
  it('returns null otherwise', () => {
    expect(extractGoodreadsUserId('jane')).toBeNull()
    expect(extractGoodreadsUserId('')).toBeNull()
  })
})

describe('goodreadsProfile store', () => {
  beforeEach(() => {
    vi.resetAllMocks()
    setActivePinia(createPinia())
  })

  it('load stores the profile, or null on 204', async () => {
    vi.mocked(profileApi.get).mockResolvedValue(profile)
    const store = useGoodreadsProfileStore()
    await store.load()
    expect(store.profile).toEqual(profile)
    vi.mocked(profileApi.get).mockResolvedValue(null)
    await store.load()
    expect(store.profile).toBeNull()
  })

  it('save extracts the id from a URL before calling the API', async () => {
    vi.mocked(profileApi.update).mockResolvedValue(profile)
    const store = useGoodreadsProfileStore()
    const ok = await store.save('https://www.goodreads.com/user/show/12345-jane', true)
    expect(ok).toBe(true)
    expect(profileApi.update).toHaveBeenCalledWith('12345', true)
    expect(store.profile).toEqual(profile)
  })

  it('save flags invalid input without calling the API', async () => {
    const store = useGoodreadsProfileStore()
    expect(await store.save('nope', true)).toBe(false)
    expect(store.invalidInput).toBe(true)
    expect(profileApi.update).not.toHaveBeenCalled()
  })

  it('save exposes the ApiError code', async () => {
    vi.mocked(profileApi.update).mockRejectedValue(
      new ApiError(422, 'profile_not_public', 'private'),
    )
    const store = useGoodreadsProfileStore()
    expect(await store.save('12345', true)).toBe(false)
    expect((store.saveError as ApiError).code).toBe('profile_not_public')
  })

  it('sync hands the import to the imports store for polling', async () => {
    vi.mocked(profileApi.sync).mockResolvedValue({ ...baseImport, source: 'rss' })
    vi.mocked(importsApi.get).mockReturnValue(new Promise(() => {}))
    const store = useGoodreadsProfileStore()
    expect(await store.sync()).toBe(true)
    expect(useImportsStore().current?.source).toBe('rss')
  })

  it('sync exposes rate_limited', async () => {
    vi.mocked(profileApi.sync).mockRejectedValue(new ApiError(429, 'rate_limited', 'slow'))
    const store = useGoodreadsProfileStore()
    expect(await store.sync()).toBe(false)
    expect((store.syncError as ApiError).code).toBe('rate_limited')
  })
})
