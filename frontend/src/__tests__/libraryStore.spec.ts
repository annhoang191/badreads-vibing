import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import * as booksApi from '@/api/books'
import { useLibraryStore } from '@/stores/library'
import { userBook } from './fixtures'

vi.mock('@/api/books')

describe('library store', () => {
  beforeEach(() => {
    vi.resetAllMocks()
    setActivePinia(createPinia())
  })

  it('load fetches with current filters and stores rows and meta', async () => {
    const meta = { page: 1, per_page: 25, total: 1, total_pages: 1 }
    vi.mocked(booksApi.list).mockResolvedValue({ data: [userBook(1)], meta })
    const store = useLibraryStore()
    store.setFilters({ shelf: 'read', q: 'dune' })
    await store.load()
    expect(booksApi.list).toHaveBeenCalledWith(
      expect.objectContaining({ shelf: 'read', q: 'dune', sort: 'date_read', page: 1 }),
    )
    expect(store.rows).toHaveLength(1)
    expect(store.meta).toEqual(meta)
  })

  it('setFilters resets the page unless page is being set', () => {
    const store = useLibraryStore()
    store.setFilters({ page: 3 })
    expect(store.filters.page).toBe(3)
    store.setFilters({ shelf: 'to-read' })
    expect(store.filters.page).toBe(1)
    expect(store.filters.shelf).toBe('to-read')
  })

  it('keeps an error and old rows when loading fails', async () => {
    vi.mocked(booksApi.list).mockRejectedValue(new Error('boom'))
    const store = useLibraryStore()
    await store.load()
    expect(store.error).toBeInstanceOf(Error)
    expect(store.loading).toBe(false)
  })
})
