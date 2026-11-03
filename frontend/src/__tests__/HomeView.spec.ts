import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { RouterLinkStub } from '@vue/test-utils'
import { useAuthStore } from '@/stores/auth'
import HomeView from '@/views/HomeView.vue'

vi.mock('@/api/health', () => ({
  getHealth: vi.fn<() => Promise<{ status: string }>>().mockResolvedValue({ status: 'ok' }),
}))

describe('HomeView', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('shows API status once the health check resolves', async () => {
    const wrapper = mount(HomeView, { global: { stubs: { RouterLink: RouterLinkStub } } })
    await flushPromises()
    expect(wrapper.get('[data-testid="api-status"]').text()).toContain('ok')
  })

  it('shows an import call-to-action when the user has no books', async () => {
    useAuthStore().stats = { books: 0, last_import_at: null }
    const wrapper = mount(HomeView, { global: { stubs: { RouterLink: RouterLinkStub } } })
    await flushPromises()
    expect(wrapper.find('[data-testid="import-cta"]').exists()).toBe(true)
  })

  it('hides the call-to-action when books exist', async () => {
    useAuthStore().stats = { books: 3, last_import_at: null }
    const wrapper = mount(HomeView, { global: { stubs: { RouterLink: RouterLinkStub } } })
    await flushPromises()
    expect(wrapper.find('[data-testid="import-cta"]').exists()).toBe(false)
  })
})
