import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import * as profileApi from '@/api/goodreadsProfile'
import * as importsApi from '@/api/imports'
import { ApiError } from '@/api/client'
import SettingsView from '@/views/SettingsView.vue'
import { baseImport } from './fixtures'

vi.mock('@/api/goodreadsProfile')
vi.mock('@/api/imports')

describe('SettingsView', () => {
  beforeEach(() => {
    vi.resetAllMocks()
    setActivePinia(createPinia())
    vi.mocked(profileApi.get).mockResolvedValue(null)
    vi.mocked(importsApi.list).mockResolvedValue([])
  })

  it('shows a profile_not_public message when saving fails', async () => {
    vi.mocked(profileApi.update).mockRejectedValue(
      new ApiError(422, 'profile_not_public', 'private'),
    )
    const wrapper = mount(SettingsView)
    await flushPromises()
    await wrapper.get('#profile-input').setValue('https://www.goodreads.com/user/show/12345-jane')
    await wrapper.get('form').trigger('submit')
    await flushPromises()
    expect(profileApi.update).toHaveBeenCalledWith('12345', true)
    expect(wrapper.get('#save-error').text()).toContain('public')
  })

  it('shows a validation error for unparseable input', async () => {
    const wrapper = mount(SettingsView)
    await flushPromises()
    await wrapper.get('#profile-input').setValue('jane')
    await wrapper.get('form').trigger('submit')
    await flushPromises()
    expect(profileApi.update).not.toHaveBeenCalled()
    expect(wrapper.get('#save-error').text()).toContain('user ID')
  })

  it('shows the saved profile, last error and import history', async () => {
    vi.mocked(profileApi.get).mockResolvedValue({
      goodreads_user_id: '12345',
      rss_enabled: false,
      last_synced_at: null,
      last_error: 'Feed unreachable',
      consecutive_failures: 3,
    })
    vi.mocked(importsApi.list).mockResolvedValue([{ ...baseImport, status: 'completed' }])
    const wrapper = mount(SettingsView)
    await flushPromises()
    expect((wrapper.get('#profile-input').element as HTMLInputElement).value).toBe('12345')
    expect(wrapper.get('[data-testid="last-error"]').text()).toBe('Feed unreachable')
    expect(wrapper.text()).toContain('goodreads.csv')
  })
})
