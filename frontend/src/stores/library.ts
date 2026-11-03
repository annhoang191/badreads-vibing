import { defineStore } from 'pinia'
import { ref } from 'vue'
import * as booksApi from '@/api/books'
import { useAsync } from '@/composables/useAsync'
import type { BookFilters, PageMeta, UserBook } from '@/types/api'

export const DEFAULT_FILTERS: BookFilters = {
  shelf: '',
  tag: '',
  rating: '',
  year: '',
  q: '',
  sort: 'date_read',
  page: 1,
}

export const useLibraryStore = defineStore('library', () => {
  const filters = ref<BookFilters>({ ...DEFAULT_FILTERS })
  const rows = ref<UserBook[]>([])
  const meta = ref<PageMeta | null>(null)
  const { loading, error, run } = useAsync(booksApi.list)

  async function load() {
    const f = filters.value
    const result = await run({
      shelf: f.shelf,
      tag: f.tag,
      rating: f.rating,
      year: f.year,
      q: f.q,
      sort: f.sort,
      page: f.page,
    })
    if (result) {
      rows.value = result.data
      meta.value = result.meta
    }
  }

  /** Merges filters; any change other than `page` resets to page 1. */
  function setFilters(partial: Partial<BookFilters>) {
    const resetPage = !('page' in partial)
    filters.value = { ...filters.value, ...partial, ...(resetPage ? { page: 1 } : {}) }
  }

  return { filters, rows, meta, loading, error, load, setFilters }
})
