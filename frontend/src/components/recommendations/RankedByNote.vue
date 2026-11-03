<script setup lang="ts">
defineProps<{ rankedBy: 'agent' | 'heuristic' | null }>()
</script>

<template>
  <p v-if="rankedBy === 'heuristic'" class="text-sm text-gray-600">
    Ranked by our matching rules — AI ranking was unavailable for this batch.
  </p>
</template>
