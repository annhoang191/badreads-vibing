import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, RouterLinkStub } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import * as insightsApi from '@/api/insights'
import { useAuthStore } from '@/stores/auth'
import HomeView from '@/views/HomeView.vue'
import { snapshot } from './insightsFixtures'

vi.mock('@/api/insights')
vi.mock('vue-chartjs', () => {
  const stub = { template: '<canvas />' }
  return { Bar: stub, Line: stub, Doughnut: stub }
})

const mountHome = () => mount(HomeView, { global: { stubs: { RouterLink: RouterLinkStub } } })

describe('HomeView', () => {
  beforeEach(() => {
    vi.resetAllMocks()
    setActivePinia(createPinia())
    useAuthStore().stats = { books: 3, last_import_at: null }
  })

  it('shows an import call-to-action and no insights when the user has no books', async () => {
    useAuthStore().stats = { books: 0, last_import_at: null }
    const wrapper = mountHome()
    await flushPromises()
    expect(wrapper.find('[data-testid="import-cta"]').exists()).toBe(true)
    expect(insightsApi.get).not.toHaveBeenCalled()
  })

  it('hides the call-to-action when books exist', async () => {
    vi.mocked(insightsApi.get).mockResolvedValue(snapshot())
    const wrapper = mountHome()
    await flushPromises()
    expect(wrapper.find('[data-testid="import-cta"]').exists()).toBe(false)
  })

  it('shows a skeleton while loading', () => {
    vi.mocked(insightsApi.get).mockReturnValue(new Promise(() => {}))
    const wrapper = mountHome()
    expect(wrapper.find('[data-testid="insights-loading"]').exists()).toBe(true)
  })

  it('shows the computing state and requests a refresh on 204', async () => {
    vi.mocked(insightsApi.get).mockResolvedValue(null)
    vi.mocked(insightsApi.refresh).mockResolvedValue({})
    const wrapper = mountHome()
    await flushPromises()
    expect(wrapper.get('[data-testid="insights-computing"]').text()).toContain(
      'Insights are being computed',
    )
    expect(insightsApi.refresh).toHaveBeenCalledTimes(1)
  })

  it('shows an error state', async () => {
    vi.mocked(insightsApi.get).mockRejectedValue(new Error('network'))
    const wrapper = mountHome()
    await flushPromises()
    expect(wrapper.find('[data-testid="insights-error"]').exists()).toBe(true)
  })

  it('renders the full dashboard', async () => {
    vi.mocked(insightsApi.get).mockResolvedValue(snapshot())
    const wrapper = mountHome()
    await flushPromises()
    const dash = wrapper.get('[data-testid="insights-dashboard"]')
    expect(dash.text()).toContain('Ursula Le Guin')
    expect(dash.text()).toContain('science fiction')
    expect(dash.text()).toContain('Based on 212 of 240 read books with a date')
    expect(dash.findAll('table')).toHaveLength(5)
    expect(wrapper.text()).toContain('Refresh insights')
  })
})
