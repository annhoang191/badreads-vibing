<script setup lang="ts">
import { computed } from 'vue'
import type { Import } from '@/types/api'

const MAX_ERRORS = 5
const props = defineProps<{ import: Import }>()

const label = computed(
  () =>
    ({
      pending: 'Queued',
      processing: 'Importing…',
      completed: 'Done',
      failed: 'Failed',
    })[props.import.status],
)
const stats = computed(() => props.import.stats)
const errors = computed(() => (stats.value?.errors ?? []).slice(0, MAX_ERRORS))
const extraErrors = computed(() => (stats.value?.errors?.length ?? 0) - errors.value.length)
</script>

<template>
  <section class="rounded border border-gray-300 p-4" aria-live="polite">
    <p class="font-medium">{{ label }}</p>
    <p v-if="props.import.filename" class="text-sm text-gray-500">{{ props.import.filename }}</p>
    <ul v-if="stats" class="mt-2 text-sm text-gray-700">
      <li v-if="stats.rows_total !== undefined">{{ stats.rows_total }} rows read</li>
      <li>{{ stats.books_created ?? 0 }} books added</li>
      <li>{{ stats.books_updated ?? 0 }} books updated</li>
      <li>{{ stats.rows_skipped ?? 0 }} rows skipped</li>
    </ul>
    <p v-if="props.import.error_message" class="mt-2 text-sm text-red-700">
      {{ props.import.error_message }}
    </p>
    <div v-if="errors.length" class="mt-2 text-sm">
      <p class="font-medium">Problem rows</p>
      <ul class="list-disc pl-5 text-gray-700">
        <li v-for="e in errors" :key="e.row">Row {{ e.row }}: {{ e.reason }}</li>
      </ul>
      <p v-if="extraErrors > 0" class="text-gray-500">and {{ extraErrors }} more</p>
    </div>
  </section>
</template>
