import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import router from '@/router'
import * as authApi from '@/api/auth'
import { useAuthStore } from '@/stores/auth'

vi.mock('@/api/auth')
vi.mock('@/api/health', () => ({
  getHealth: vi.fn<() => Promise<{ status: string }>>().mockResolvedValue({ status: 'ok' }),
}))

describe('router guard', () => {
  beforeEach(async () => {
    setActivePinia(createPinia())
    await router.replace('/login')
  })

  it('redirects unauthenticated users to login with a redirect param', async () => {
    await router.push('/')
    expect(router.currentRoute.value.path).toBe('/login')
    expect(router.currentRoute.value.query.redirect).toBe('/')
  })

  it('redirects authenticated users away from login and register', async () => {
    const store = useAuthStore()
    store.token = 't'
    store.user = { id: 1, email_address: 'a@b.co', created_at: '' }
    await router.push('/register')
    expect(router.currentRoute.value.path).toBe('/')
    await router.push('/login')
    expect(router.currentRoute.value.path).toBe('/')
  })

  it('redirects a user with zero books from / to onboarding', async () => {
    const store = useAuthStore()
    store.token = 't'
    store.user = { id: 1, email_address: 'a@b.co', created_at: '' }
    store.stats = { books: 0, last_import_at: null }
    await router.push('/')
    expect(router.currentRoute.value.path).toBe('/onboarding')
  })

  it('fetches stats when unknown and keeps users with books on /', async () => {
    const store = useAuthStore()
    store.token = 't'
    store.user = { id: 1, email_address: 'a@b.co', created_at: '' }
    vi.mocked(authApi.me).mockResolvedValue({
      user: store.user,
      stats: { books: 5, last_import_at: null },
    })
    await router.push('/')
    expect(router.currentRoute.value.path).toBe('/')
  })

  it('registers library as an authenticated route', async () => {
    await router.push('/library')
    expect(router.currentRoute.value.path).toBe('/login')
  })
})
