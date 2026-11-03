<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { getHealth } from '@/api/health'

const apiStatus = ref<'checking' | 'ok' | 'down'>('checking')

onMounted(async () => {
  try {
    await getHealth()
    apiStatus.value = 'ok'
  } catch {
    apiStatus.value = 'down'
  }
})
</script>

<template>
  <main class="mx-auto max-w-2xl p-8">
    <h1 class="text-3xl font-bold">Shelfsight</h1>
    <p class="mt-2 text-gray-600">Understand your reading. Find your next book.</p>
    <p class="mt-6 text-sm" data-testid="api-status">
      API:
      <span
        :class="{
          'text-green-600': apiStatus === 'ok',
          'text-red-600': apiStatus === 'down',
          'text-gray-500': apiStatus === 'checking',
        }"
        >{{ apiStatus }}</span
      >
    </p>
  </main>
</template>
