import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import AuthForm from '@/components/auth/AuthForm.vue'

describe('AuthForm', () => {
  it('emits submit with trimmed credentials', async () => {
    const wrapper = mount(AuthForm, { props: { mode: 'login' } })
    await wrapper.get('#email').setValue(' a@b.co ')
    await wrapper.get('#password').setValue('secretpassword')
    await wrapper.get('form').trigger('submit')
    expect(wrapper.emitted('submit')).toEqual([
      [{ email_address: 'a@b.co', password: 'secretpassword' }],
    ])
  })

  it('shows the password hint only in register mode', () => {
    expect(mount(AuthForm, { props: { mode: 'register' } }).text()).toContain('10 characters')
    expect(mount(AuthForm, { props: { mode: 'login' } }).text()).not.toContain('10 characters')
  })

  it('renders error text and field errors, and disables when busy', () => {
    const wrapper = mount(AuthForm, {
      props: {
        mode: 'register',
        busy: true,
        errorText: 'Boom',
        fieldErrors: { email_address: ['is taken'], password: ['is too short'] },
      },
    })
    expect(wrapper.get('[role="alert"]').text()).toBe('Boom')
    expect(wrapper.text()).toContain('is taken')
    expect(wrapper.text()).toContain('is too short')
    expect(wrapper.get('button').attributes('disabled')).toBeDefined()
  })
})
