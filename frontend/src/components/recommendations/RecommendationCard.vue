<script setup lang="ts">
import type { Recommendation } from '@/types/api'

defineProps<{ recommendation: Recommendation }>()
</script>

<template>
  <article class="flex flex-col gap-3 rounded border border-gray-300 bg-white p-4">
    <div class="flex gap-3">
      <img
        v-if="recommendation.book.cover_url"
        :src="recommendation.book.cover_url"
        :alt="`Cover of ${recommendation.book.title}`"
        class="h-28 w-20 shrink-0 rounded object-cover"
        loading="lazy"
      />
      <div
        v-else
        data-testid="cover-placeholder"
        class="flex h-28 w-20 shrink-0 items-center justify-center rounded bg-gray-200 text-xs text-gray-600"
        aria-hidden="true"
      >
        No cover
      </div>
      <div class="min-w-0">
        <h3 class="font-semibold">{{ recommendation.book.title }}</h3>
        <p class="text-sm text-gray-700">{{ recommendation.book.author }}</p>
        <p class="mt-1 text-xs text-gray-600">
          <span v-if="recommendation.book.year">{{ recommendation.book.year }}</span>
          <span v-if="recommendation.book.year && recommendation.book.num_pages"> · </span>
          <span v-if="recommendation.book.num_pages"
            >{{ recommendation.book.num_pages }} pages</span
          >
        </p>
        <div
          class="mt-2 h-2 w-24 overflow-hidden rounded bg-gray-200"
          role="img"
          :aria-label="`Match score ${recommendation.score} out of 100`"
        >
          <div
            class="h-full bg-indigo-700"
            :style="{ width: `${Math.min(100, Math.max(0, recommendation.score))}%` }"
          ></div>
        </div>
      </div>
    </div>
    <div>
      <h4 class="text-xs font-semibold tracking-wide text-gray-600 uppercase">Why this book</h4>
      <p class="mt-1 text-sm" data-testid="reason">{{ recommendation.reason }}</p>
    </div>
    <a
      v-if="recommendation.book.open_library_url"
      :href="recommendation.book.open_library_url"
      target="_blank"
      rel="noopener noreferrer"
      class="mt-auto text-sm text-indigo-700 underline"
    >
      View on Open Library<span class="sr-only"> (opens in a new tab)</span>
    </a>
  </article>
</template>
