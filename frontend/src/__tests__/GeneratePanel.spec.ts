import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import GeneratePanel from '@/components/recommendations/GeneratePanel.vue'
import { quota } from './recsFixtures'

const base = { quota: quota(), disabled: false, busy: false, hasBatch: false }

describe('GeneratePanel', () => {
  it('emits generate and shows remaining quota', async () => {
    const wrapper = mount(GeneratePanel, { props: base })
    expect(wrapper.get('[data-testid="quota"]').text()).toContain('4 of 5 left today')
    await wrapper.get('button').trigger('click')
    expect(wrapper.emitted('generate')).toHaveLength(1)
  })

  it('is disabled when told so and shows the reset hint at zero remaining', async () => {
    const wrapper = mount(GeneratePanel, {
      props: {
        ...base,
        disabled: true,
        quota: quota({ remaining: 0, resets_at: '2026-11-04T10:00:00Z' }),
      },
    })
    expect(wrapper.get('button').attributes('disabled')).toBeDefined()
    expect(wrapper.get('[data-testid="quota"]').text()).toContain('0 of 5 left today')
    expect(wrapper.get('[data-testid="quota"]').text()).toContain('resets')
    await wrapper.get('button').trigger('click')
    expect(wrapper.emitted('generate')).toBeUndefined()
  })
})
