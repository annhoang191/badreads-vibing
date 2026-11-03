import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import RecommendationCard from '@/components/recommendations/RecommendationCard.vue'
import { recommendation } from './recsFixtures'

describe('RecommendationCard', () => {
  it('shows the reason, score label and book details', () => {
    const wrapper = mount(RecommendationCard, { props: { recommendation: recommendation(1) } })
    expect(wrapper.text()).toContain('Why this book')
    expect(wrapper.get('[data-testid="reason"]').text()).toBe('Because you loved Book 1.')
    expect(wrapper.find('[aria-label="Match score 92 out of 100"]').exists()).toBe(true)
    expect(wrapper.text()).toContain('Rec 1')
    expect(wrapper.text()).toContain('320 pages')
    expect(wrapper.get('img').attributes('alt')).toBe('Cover of Rec 1')
  })

  it('opens Open Library in a new tab safely', () => {
    const wrapper = mount(RecommendationCard, { props: { recommendation: recommendation(1) } })
    const a = wrapper.get('a')
    expect(a.attributes('href')).toBe('https://openlibrary.org/works/OL1W')
    expect(a.attributes('target')).toBe('_blank')
    expect(a.attributes('rel')).toContain('noopener')
  })

  it('renders a placeholder without a cover and no link without a url', () => {
    const r = recommendation(2)
    r.book.cover_url = null
    r.book.open_library_url = null
    const wrapper = mount(RecommendationCard, { props: { recommendation: r } })
    expect(wrapper.find('img').exists()).toBe(false)
    expect(wrapper.find('[data-testid="cover-placeholder"]').exists()).toBe(true)
    expect(wrapper.find('a').exists()).toBe(false)
  })
})
