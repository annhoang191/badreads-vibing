<script setup lang="ts">
import { computed } from 'vue'
import type { BookDiff } from '@/types/api'

const props = defineProps<{ meanDiff: number | null; higher: BookDiff[]; lower: BookDiff[] }>()

const sentence = computed(() => {
  if (props.meanDiff === null) return 'Not enough rated books to compare with the crowd yet.'
  const abs = Math.abs(props.meanDiff).toFixed(2)
  if (props.meanDiff === 0) return 'You rate in line with the Goodreads crowd on average.'
  return props.meanDiff > 0
    ? `You rate books ${abs} stars higher than the crowd on average.`
    : `You rate books ${abs} stars lower than the crowd on average.`
})
</script>

<template>
  <section>
    <h2 class="mb-2 font-medium">You vs. the crowd</h2>
    <p class="text-sm" data-testid="crowd-sentence">{{ sentence }}</p>
    <div class="mt-3 grid gap-4 sm:grid-cols-2">
      <div
        v-for="group in [
          { title: 'You liked more', books: props.higher },
          { title: 'You liked less', books: props.lower },
        ]"
        :key="group.title"
      >
        <h3 class="text-sm font-medium">{{ group.title }}</h3>
        <ul v-if="group.books.length" class="mt-1 text-sm">
          <li v-for="b in group.books" :key="b.book_id" class="py-0.5">
            {{ b.title }}
            <span class="text-gray-600">
              by {{ b.author }}: you {{ b.my_rating }}, crowd {{ b.avg_rating.toFixed(2) }}
            </span>
          </li>
        </ul>
        <p v-else class="text-sm text-gray-600">None.</p>
      </div>
    </div>
  </section>
</template>
