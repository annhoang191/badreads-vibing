<script setup lang="ts">
const props = defineProps<{ numerator: number; denominator: number; label: string }>()
</script>

<template>
  <p class="text-xs text-gray-600" data-testid="coverage-note">
    Based on {{ props.numerator }} of {{ props.denominator }} {{ props.label }}
  </p>
</template>
