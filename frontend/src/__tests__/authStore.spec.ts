import { memoryStorage } from './memoryStorage'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import * as authApi from '@/api/auth'
import { ApiError } from '@/api/client'
import { TOKEN_KEY, useAuthStore } from '@/stores/auth'
import type { User } from '@/types/api'

vi.mock('@/api/auth')

const user: User = { id: 1, email_address: 'a@b.co', created_at: '2026-01-01T00:00:00Z' }
const creds = { email_address: 'a@b.co', password: 'secretpassword' }

describe('auth store', () => {
  beforeEach(() => {
    vi.stubGlobal('localStorage', memoryStorage())
    vi.resetAllMocks()
    setActivePinia(createPinia())
  })

  it('login stores and persists the session', async () => {
    vi.mocked(authApi.login).mockResolvedValue({ token: 't1', user })
    const store = useAuthStore()
    expect(await store.login(creds)).toBeNull()
    expect(store.isAuthenticated).toBe(true)
    expect(localStorage.getItem(TOKEN_KEY)).toBe('t1')
  })

  it('login returns the ApiError and stays logged out on failure', async () => {
    vi.mocked(authApi.login).mockRejectedValue(new ApiError(401, 'invalid_credentials', 'x'))
    const store = useAuthStore()
    const err = await store.login(creds)
    expect(err).toBeInstanceOf(ApiError)
    expect(store.isAuthenticated).toBe(false)
    expect(localStorage.getItem(TOKEN_KEY)).toBeNull()
  })

  it('register persists the session', async () => {
    vi.mocked(authApi.register).mockResolvedValue({ token: 't2', user })
    const store = useAuthStore()
    await store.register(creds)
    expect(store.token).toBe('t2')
    expect(localStorage.getItem(TOKEN_KEY)).toBe('t2')
  })

  it('logout clears state even if the API call fails', async () => {
    vi.mocked(authApi.login).mockResolvedValue({ token: 't1', user })
    vi.mocked(authApi.logout).mockRejectedValue(new Error('offline'))
    const store = useAuthStore()
    await store.login(creds)
    await store.logout()
    expect(store.isAuthenticated).toBe(false)
    expect(localStorage.getItem(TOKEN_KEY)).toBeNull()
  })

  it('restore loads the user from a stored token', async () => {
    localStorage.setItem(TOKEN_KEY, 'stored')
    vi.mocked(authApi.me).mockResolvedValue({ user, stats: { books: 0, last_import_at: null } })
    const store = useAuthStore()
    await store.restore()
    expect(store.isAuthenticated).toBe(true)
    expect(store.token).toBe('stored')
  })

  it('restore clears a bad token', async () => {
    localStorage.setItem(TOKEN_KEY, 'bad')
    vi.mocked(authApi.me).mockRejectedValue(new ApiError(401, 'unauthorized', 'x'))
    const store = useAuthStore()
    await store.restore()
    expect(store.isAuthenticated).toBe(false)
    expect(localStorage.getItem(TOKEN_KEY)).toBeNull()
  })

  it('restore does nothing without a stored token', async () => {
    const store = useAuthStore()
    await store.restore()
    expect(authApi.me).not.toHaveBeenCalled()
  })
})
