import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, RouterLinkStub } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import * as recsApi from '@/api/recommendations'
import { ApiError } from '@/api/client'
import RecommendationsView from '@/views/RecommendationsView.vue'
import { batch, quota } from './recsFixtures'

vi.mock('@/api/recommendations')

async function mountView() {
  const wrapper = mount(RecommendationsView, {
    global: { stubs: { RouterLink: RouterLinkStub } },
  })
  await flushPromises()
  return wrapper
}

describe('RecommendationsView', () => {
  beforeEach(() => {
    vi.resetAllMocks()
    setActivePinia(createPinia())
  })

  it('explains the feature when there is no batch', async () => {
    vi.mocked(recsApi.latest).mockResolvedValue({ batch: null, quota: quota() })
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('picks 10 books')
    expect(wrapper.text()).toContain('4 of 5 left today')
  })

  it('shows skeletons while processing', async () => {
    const processing = batch({ status: 'processing', recommendations: [] })
    vi.mocked(recsApi.latest).mockResolvedValue({ batch: processing, quota: quota() })
    vi.mocked(recsApi.getBatch).mockResolvedValue(processing)
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('Finding books for you')
    expect(wrapper.findAll('[data-testid="skeleton-card"]').length).toBeGreaterThan(0)
  })

  it('renders 10 cards and the heuristic note when completed', async () => {
    vi.mocked(recsApi.latest).mockResolvedValue({
      batch: batch({ ranked_by: 'heuristic' }),
      quota: quota(),
    })
    const wrapper = await mountView()
    expect(wrapper.findAll('article')).toHaveLength(10)
    expect(wrapper.text()).toContain('AI ranking was unavailable')
  })

  it('shows the failure message', async () => {
    vi.mocked(recsApi.latest).mockResolvedValue({
      batch: batch({ status: 'failed', recommendations: [], error_message: 'Boom' }),
      quota: quota(),
    })
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('Boom')
  })

  it('maps not_enough_data to a message with a library link', async () => {
    vi.mocked(recsApi.latest).mockResolvedValue({ batch: null, quota: quota() })
    vi.mocked(recsApi.generate).mockRejectedValue(
      new ApiError(422, 'not_enough_data', 'x', { required: 10, have: 3 }),
    )
    const wrapper = await mountView()
    await wrapper.get('button').trigger('click')
    await flushPromises()
    expect(wrapper.get('[role="alert"]').text()).toContain(
      "Rate at least 10 books you've read to get recommendations (you have 3).",
    )
    expect(wrapper.getComponent(RouterLinkStub).props('to')).toBe('/library')
  })

  it('humanizes retry_after for rate_limited', async () => {
    vi.mocked(recsApi.latest).mockResolvedValue({ batch: null, quota: quota() })
    vi.mocked(recsApi.generate).mockRejectedValue(
      new ApiError(429, 'rate_limited', 'x', { retry_after: 7200 }),
    )
    const wrapper = await mountView()
    await wrapper.get('button').trigger('click')
    await flushPromises()
    expect(wrapper.get('[role="alert"]').text()).toContain('Try again in 2 hours.')
  })
})
