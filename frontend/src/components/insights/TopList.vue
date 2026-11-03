<script setup lang="ts">
const props = defineProps<{
  title: string
  rows: { label: string; value: string }[]
  emptyText?: string
}>()
</script>

<template>
  <section>
    <h2 class="mb-2 font-medium">{{ props.title }}</h2>
    <ol v-if="props.rows.length" class="list-decimal pl-5 text-sm">
      <li v-for="row in props.rows" :key="row.label" class="py-0.5">
        <span class="font-medium">{{ row.label }}</span>
        <span class="text-gray-600"> · {{ row.value }}</span>
      </li>
    </ol>
    <p v-else class="text-sm text-gray-600">{{ props.emptyText ?? 'Nothing to show yet.' }}</p>
  </section>
</template>
