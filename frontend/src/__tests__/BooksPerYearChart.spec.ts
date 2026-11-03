import { describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import BooksPerYearChart from '@/components/charts/BooksPerYearChart.vue'

vi.mock('vue-chartjs', () => ({ Bar: { template: '<canvas />' } }))

describe('BooksPerYearChart', () => {
  it('renders an accessible table alternative', () => {
    const wrapper = mount(BooksPerYearChart, {
      props: {
        books: [
          { year: 2024, count: 30 },
          { year: null, count: 5 },
        ],
      },
    })
    expect(wrapper.get('caption').text()).toBe('Books read per year')
    const rows = wrapper.findAll('tbody tr').map((r) => [r.get('th').text(), r.get('td').text()])
    expect(rows).toEqual([
      ['2024', '30'],
      ['Undated', '5'],
    ])
  })
})
