<script setup lang="ts">
import type { PageMeta } from '@/types/api'

defineOptions({ name: 'PaginationControls' })

const props = defineProps<{ meta: PageMeta }>()
const emit = defineEmits<{ change: [page: number] }>()
</script>

<template>
  <nav aria-label="Pagination" class="flex items-center justify-between text-sm">
    <button
      type="button"
      class="rounded border border-gray-400 px-3 py-1 disabled:opacity-50"
      :disabled="props.meta.page <= 1"
      @click="emit('change', props.meta.page - 1)"
    >
      Previous
    </button>
    <span>Page {{ props.meta.page }} of {{ Math.max(props.meta.total_pages, 1) }}</span>
    <button
      type="button"
      class="rounded border border-gray-400 px-3 py-1 disabled:opacity-50"
      :disabled="props.meta.page >= props.meta.total_pages"
      @click="emit('change', props.meta.page + 1)"
    >
      Next
    </button>
  </nav>
</template>
