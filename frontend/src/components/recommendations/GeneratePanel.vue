<script setup lang="ts">
import { computed } from 'vue'
import type { RecommendationQuota } from '@/types/api'

const props = defineProps<{
  quota: RecommendationQuota | null
  disabled: boolean
  busy: boolean
  hasBatch: boolean
}>()
const emit = defineEmits<{ generate: [] }>()

const resetsAt = computed(() =>
  props.quota?.resets_at ? new Date(props.quota.resets_at).toLocaleString() : null,
)
</script>

<template>
  <div class="flex flex-wrap items-center gap-4">
    <button
      type="button"
      class="rounded bg-indigo-700 px-4 py-2 text-white disabled:opacity-50"
      :disabled="disabled"
      @click="emit('generate')"
    >
      {{ busy ? 'Generating…' : hasBatch ? 'Get new recommendations' : 'Get recommendations' }}
    </button>
    <p v-if="quota" class="text-sm text-gray-700" data-testid="quota">
      {{ quota.remaining }} of {{ quota.limit }} left today
      <span v-if="quota.remaining === 0 && resetsAt"> · resets {{ resetsAt }}</span>
    </p>
  </div>
</template>
