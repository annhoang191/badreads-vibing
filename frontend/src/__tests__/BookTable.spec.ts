import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import BookTable from '@/components/library/BookTable.vue'
import { userBook } from './fixtures'

describe('BookTable', () => {
  it('renders a row per book with cover alt text and rating label', () => {
    const wrapper = mount(BookTable, {
      props: { rows: [userBook(1), userBook(2, { my_rating: null, exclusive_shelf: 'to-read' })] },
    })
    expect(wrapper.findAll('tbody tr')).toHaveLength(2)
    expect(wrapper.text()).toContain('Book 1')
    expect(wrapper.text()).toContain('Author 2')
    expect(wrapper.get('img').attributes('alt')).toBe('Cover of Book 1')
    const ratings = wrapper.findAll('[role="img"]')
    expect(ratings[0]!.attributes('aria-label')).toBe('Rated 4 out of 5')
    expect(ratings[0]!.text()).toBe('★★★★☆')
    expect(ratings[1]!.attributes('aria-label')).toBe('Not rated')
    expect(wrapper.text()).toContain('To read')
  })
})
