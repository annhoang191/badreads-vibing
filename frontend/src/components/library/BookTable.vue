<script setup lang="ts">
import type { Shelf, UserBook } from '@/types/api'

const props = defineProps<{ rows: UserBook[] }>()

const SHELF_LABELS: Record<Shelf, string> = {
  read: 'Read',
  'currently-reading': 'Reading',
  'to-read': 'To read',
}

function stars(rating: number | null) {
  const n = rating ?? 0
  return '★'.repeat(n) + '☆'.repeat(5 - n)
}

const ratingLabel = (rating: number | null) => (rating ? `Rated ${rating} out of 5` : 'Not rated')
</script>

<template>
  <table class="w-full text-left text-sm">
    <caption class="sr-only">
      Your books
    </caption>
    <thead class="border-b border-gray-300">
      <tr>
        <th scope="col" class="p-2"><span class="sr-only">Cover</span></th>
        <th scope="col" class="p-2">Title</th>
        <th scope="col" class="p-2">Author</th>
        <th scope="col" class="p-2">Shelf</th>
        <th scope="col" class="p-2">My rating</th>
        <th scope="col" class="p-2">Date read</th>
        <th scope="col" class="p-2">Pages</th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="row in props.rows" :key="row.id" class="border-b border-gray-200">
        <td class="p-2">
          <img
            v-if="row.book.cover_url"
            :src="row.book.cover_url"
            :alt="`Cover of ${row.book.title}`"
            class="h-12 w-8 object-cover"
            loading="lazy"
          />
          <div v-else class="h-12 w-8 bg-gray-200" aria-hidden="true"></div>
        </td>
        <td class="p-2 font-medium">{{ row.book.title }}</td>
        <td class="p-2">{{ row.book.author }}</td>
        <td class="p-2">
          <span class="rounded bg-gray-100 px-2 py-0.5 text-xs">{{
            SHELF_LABELS[row.exclusive_shelf]
          }}</span>
        </td>
        <td class="p-2">
          <span :aria-label="ratingLabel(row.my_rating)" role="img">{{
            stars(row.my_rating)
          }}</span>
        </td>
        <td class="p-2">{{ row.date_read ?? '—' }}</td>
        <td class="p-2">{{ row.book.num_pages ?? '—' }}</td>
      </tr>
    </tbody>
  </table>
</template>
