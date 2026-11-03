<script setup lang="ts">
import type { InsightsSnapshot } from '@/types/api'

const props = defineProps<{ tbr: InsightsSnapshot['metrics']['tbr'] }>()
</script>

<template>
  <section>
    <h2 class="mb-2 font-medium">To-read pile</h2>
    <p class="text-sm">
      {{ props.tbr.size }} books waiting<template v-if="props.tbr.median_age_days !== null">
        , median age {{ props.tbr.median_age_days }} days</template
      >.
    </p>
    <template v-if="props.tbr.oldest.length">
      <h3 class="mt-2 text-sm font-medium">Waiting longest</h3>
      <ul class="text-sm">
        <li v-for="b in props.tbr.oldest" :key="b.book_id" class="py-0.5">
          {{ b.title }}
          <span class="text-gray-600">
            by {{ b.author }}<template v-if="b.date_added"> (added {{ b.date_added }})</template>
          </span>
        </li>
      </ul>
    </template>
  </section>
</template>
