import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import StatTiles from '@/components/insights/StatTiles.vue'
import { snapshot } from './insightsFixtures'

const m = snapshot().metrics

describe('StatTiles', () => {
  it('shows totals, rating and pace', () => {
    const wrapper = mount(StatTiles, {
      props: { totals: m.totals, averageRating: m.average_rating, pace: m.pace },
    })
    const text = wrapper.findAll('[data-testid="stat-tile"]').map((t) => t.text())
    expect(text).toContain('Books read240')
    expect(text).toContain('Pages read70,000')
    expect(text).toContain('Average rating4.12')
    expect(text).toContain('Books per month (last 12)3.5')
    expect(wrapper.text()).toContain('Best month: 2026-03')
  })

  it('shows n/a without ratings', () => {
    const wrapper = mount(StatTiles, {
      props: { totals: m.totals, averageRating: null, pace: { ...m.pace, best_month: null } },
    })
    expect(wrapper.text()).toContain('n/a')
    expect(wrapper.text()).not.toContain('Best month')
  })
})
