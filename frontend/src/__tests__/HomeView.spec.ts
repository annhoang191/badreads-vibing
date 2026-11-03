import { describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import HomeView from '@/views/HomeView.vue'

vi.mock('@/api/health', () => ({
  getHealth: vi.fn<() => Promise<{ status: string }>>().mockResolvedValue({ status: 'ok' }),
}))

describe('HomeView', () => {
  it('shows API status once the health check resolves', async () => {
    const wrapper = mount(HomeView)
    await flushPromises()
    expect(wrapper.get('[data-testid="api-status"]').text()).toContain('ok')
  })
})
