<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { getHealth } from '@/api/health'
import { useAsync } from '@/composables/useAsync'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()

const { data, error, run } = useAsync(getHealth)

const apiStatus = computed(() => (error.value ? 'down' : data.value ? 'ok' : 'checking'))

onMounted(() => run())
</script>

<template>
  <main class="mx-auto max-w-2xl p-8">
    <h1 class="text-3xl font-bold">Shelfsight</h1>
    <p class="mt-2 text-gray-600">Understand your reading. Find your next book.</p>
    <p v-if="auth.stats?.books === 0" class="mt-6" data-testid="import-cta">
      <RouterLink to="/onboarding" class="rounded bg-indigo-700 px-4 py-2 text-white"
        >Import your library</RouterLink
      >
    </p>
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
