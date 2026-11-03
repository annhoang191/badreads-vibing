import { memoryStorage } from './memoryStorage'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import * as authApi from '@/api/auth'
import { ApiError } from '@/api/client'
import router from '@/router'
import LoginView from '@/views/LoginView.vue'

vi.mock('@/api/auth')

async function submit(wrapper: ReturnType<typeof mount>) {
  await wrapper.get('#email').setValue('a@b.co')
  await wrapper.get('#password').setValue('secretpassword')
  await wrapper.get('form').trigger('submit')
  await flushPromises()
}

describe('LoginView', () => {
  beforeEach(async () => {
    vi.stubGlobal('localStorage', memoryStorage())
    vi.resetAllMocks()
    setActivePinia(createPinia())
    await router.replace('/login?redirect=/')
  })

  it.each([
    ['invalid_credentials', 401, 'Email or password is incorrect.'],
    ['rate_limited', 429, 'Too many attempts. Wait a few minutes.'],
    ['boom', 500, 'Something went wrong. Try again.'],
  ])('maps %s to a message', async (code, status, text) => {
    vi.mocked(authApi.login).mockRejectedValue(new ApiError(status, code, 'raw'))
    const wrapper = mount(LoginView, { global: { plugins: [router] } })
    await submit(wrapper)
    expect(wrapper.get('[role="alert"]').text()).toBe(text)
  })

  it('redirects on success', async () => {
    vi.mocked(authApi.login).mockResolvedValue({
      token: 't',
      user: { id: 1, email_address: 'a@b.co', created_at: '' },
    })
    await router.replace('/login?redirect=/')
    const wrapper = mount(LoginView, { global: { plugins: [router] } })
    await submit(wrapper)
    expect(router.currentRoute.value.path).toBe('/')
  })
})
