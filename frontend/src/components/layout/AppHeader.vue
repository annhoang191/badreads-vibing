<script setup lang="ts">
import { RouterLink } from 'vue-router'

const props = defineProps<{ email: string; links: { to: string; label: string }[] }>()
const emit = defineEmits<{ logout: [] }>()
</script>

<template>
  <header class="border-b border-gray-200 bg-white">
    <div class="mx-auto flex max-w-5xl items-center justify-between gap-4 p-4">
      <nav aria-label="Main" class="flex gap-4">
        <RouterLink
          v-for="link in props.links"
          :key="link.to"
          :to="link.to"
          class="text-sm font-medium text-gray-700 hover:text-indigo-700"
          active-class="text-indigo-700 underline"
        >
          {{ link.label }}
        </RouterLink>
      </nav>
      <div class="flex items-center gap-3 text-sm">
        <span class="text-gray-600" data-testid="header-email">{{ props.email }}</span>
        <button
          type="button"
          class="rounded border border-gray-400 px-3 py-1"
          @click="emit('logout')"
        >
          Log out
        </button>
      </div>
    </div>
  </header>
</template>
