<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { ApiError } from '@/api/client'
import CsvDropzone from '@/components/imports/CsvDropzone.vue'
import ExportInstructions from '@/components/imports/ExportInstructions.vue'
import ImportStatusCard from '@/components/imports/ImportStatusCard.vue'
import { useImportsStore } from '@/stores/imports'

const imports = useImportsStore()

const errorText = computed(() => {
  const e = imports.error
  if (!e) return null
  if (!(e instanceof ApiError)) return 'Something went wrong. Try again.'
  switch (e.code) {
    case 'invalid_goodreads_export':
      return `That file doesn't look like a Goodreads export. ${e.message}`
    case 'invalid_file':
      return 'Please choose a .csv file under 10 MB.'
    case 'import_in_progress':
      return 'An import is already running.'
    default:
      return e.message
  }
})

onMounted(() => imports.resume())
</script>

<template>
  <main class="mx-auto max-w-xl space-y-6 p-8">
    <h1 class="text-2xl font-bold">Import your library</h1>
    <ExportInstructions />
    <CsvDropzone :disabled="imports.uploading || imports.inProgress" @select="imports.upload" />
    <p v-if="errorText" role="alert" class="text-red-700">{{ errorText }}</p>
    <ImportStatusCard v-if="imports.current" :import="imports.current" />
    <p v-if="imports.current?.status === 'completed'" class="flex gap-4">
      <RouterLink to="/library" class="text-indigo-700 underline">View your library</RouterLink>
      <RouterLink to="/" class="text-indigo-700 underline">Go to the dashboard</RouterLink>
    </p>
  </main>
</template>
