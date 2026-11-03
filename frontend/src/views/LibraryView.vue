<script setup lang="ts">
import { onMounted } from 'vue'
import { RouterLink, useRoute, useRouter, type LocationQuery } from 'vue-router'
import Pagination from '@/components/common/Pagination.vue'
import BookTable from '@/components/library/BookTable.vue'
import LibraryFilters from '@/components/library/LibraryFilters.vue'
import { DEFAULT_FILTERS, useLibraryStore } from '@/stores/library'
import type { BookFilters } from '@/types/api'

const route = useRoute()
const router = useRouter()
const library = useLibraryStore()

const str = (v: LocationQuery[string] | undefined) => (typeof v === 'string' ? v : '')

function fromQuery(query: LocationQuery): BookFilters {
  const page = Number(str(query.page))
  return {
    shelf: str(query.shelf) as BookFilters['shelf'],
    tag: str(query.tag),
    rating: str(query.rating) as BookFilters['rating'],
    year: str(query.year),
    q: str(query.q),
    sort: (str(query.sort) || DEFAULT_FILTERS.sort) as BookFilters['sort'],
    page: Number.isInteger(page) && page > 0 ? page : 1,
  }
}

function toQuery(f: BookFilters) {
  const query: Record<string, string> = {}
  for (const key of ['shelf', 'tag', 'rating', 'year', 'q'] as const) {
    if (f[key]) query[key] = f[key]
  }
  if (f.sort !== DEFAULT_FILTERS.sort) query.sort = f.sort
  if (f.page > 1) query.page = String(f.page)
  return query
}

async function apply(partial: Partial<BookFilters>) {
  library.setFilters(partial)
  await router.replace({ query: toQuery(library.filters) })
  await library.load()
}

onMounted(() => {
  library.setFilters({ ...fromQuery(route.query) })
  return library.load()
})

const hasFilters = () => {
  const f = library.filters
  return [f.shelf, f.tag, f.rating, f.year, f.q].some(Boolean)
}
</script>

<template>
  <main class="mx-auto max-w-5xl space-y-4 p-8">
    <h1 class="text-2xl font-bold">Library</h1>
    <LibraryFilters :model-value="library.filters" @update:model-value="apply" />
    <p v-if="library.error" role="alert" class="text-red-700">
      Couldn't load your books. Please try again.
    </p>
    <p v-else-if="library.loading && !library.rows.length" role="status">Loading…</p>
    <template v-else-if="library.rows.length">
      <BookTable :rows="library.rows" />
      <Pagination v-if="library.meta" :meta="library.meta" @change="apply({ page: $event })" />
    </template>
    <p v-else-if="hasFilters()">No books match these filters.</p>
    <p v-else>
      No books yet —
      <RouterLink to="/onboarding" class="text-indigo-700 underline"
        >import your Goodreads library</RouterLink
      >
    </p>
  </main>
</template>
