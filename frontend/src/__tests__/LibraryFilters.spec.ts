import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import LibraryFilters from '@/components/library/LibraryFilters.vue'
import { DEFAULT_FILTERS } from '@/stores/library'

describe('LibraryFilters', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('debounces search input by 300ms', async () => {
    const wrapper = mount(LibraryFilters, {
      props: { modelValue: { ...DEFAULT_FILTERS, page: 4 } },
    })
    const input = wrapper.get('input[name="q"]')
    await input.setValue('d')
    await input.setValue('du')
    vi.advanceTimersByTime(299)
    expect(wrapper.emitted('update:modelValue')).toBeUndefined()
    vi.advanceTimersByTime(1)
    const events = wrapper.emitted('update:modelValue')!
    expect(events).toHaveLength(1)
    expect(events[0]![0]).toMatchObject({ q: 'du', page: 1 })
  })

  it('emits immediately for selects', async () => {
    const wrapper = mount(LibraryFilters, { props: { modelValue: DEFAULT_FILTERS } })
    await wrapper.get('select[name="shelf"]').setValue('read')
    await wrapper.get('select[name="rating"]').setValue('unrated')
    await wrapper.get('select[name="sort"]').setValue('title')
    const events = wrapper.emitted('update:modelValue')!
    expect(events[0]![0]).toMatchObject({ shelf: 'read' })
    expect(events[1]![0]).toMatchObject({ rating: 'unrated' })
    expect(events[2]![0]).toMatchObject({ sort: 'title' })
  })

  it('emits the year on change', async () => {
    const wrapper = mount(LibraryFilters, { props: { modelValue: DEFAULT_FILTERS } })
    await wrapper.get('input[name="year"]').setValue('2024')
    expect(wrapper.emitted('update:modelValue')![0]![0]).toMatchObject({ year: '2024' })
  })
})
