<script setup lang="ts">
import { computed } from 'vue'
import type { InsightsSnapshot } from '@/types/api'

type Metrics = InsightsSnapshot['metrics']
const props = defineProps<{
  totals: Metrics['totals']
  averageRating: Metrics['average_rating']
  pace: Metrics['pace']
}>()

const tiles = computed(() => [
  { label: 'Books read', value: props.totals.read.toLocaleString('en-US') },
  { label: 'Pages read', value: props.totals.pages_read.toLocaleString('en-US') },
  {
    label: 'Average rating',
    value: props.averageRating === null ? 'n/a' : props.averageRating.toFixed(2),
  },
  { label: 'Books per month (last 12)', value: props.pace.books_per_month_12m.toFixed(1) },
  { label: 'Currently reading', value: String(props.totals.currently_reading) },
  { label: 'To read', value: String(props.totals.to_read) },
])
</script>

<template>
  <dl class="grid grid-cols-2 gap-3 md:grid-cols-3">
    <div
      v-for="tile in tiles"
      :key="tile.label"
      class="rounded border border-gray-300 bg-white p-4"
      data-testid="stat-tile"
    >
      <dt class="text-sm text-gray-600">{{ tile.label }}</dt>
      <dd class="mt-1 text-2xl font-semibold">{{ tile.value }}</dd>
    </div>
  </dl>
  <p v-if="props.pace.best_month" class="mt-2 text-sm text-gray-600">
    Best month: {{ props.pace.best_month.month }} ({{ props.pace.best_month.count }} books)
  </p>
</template>
