<script setup lang="ts">
import { onScopeDispose, ref, watch } from 'vue'
import type { BookFilters } from '@/types/api'

const props = defineProps<{ modelValue: BookFilters }>()
const emit = defineEmits<{ 'update:modelValue': [value: BookFilters] }>()

const search = ref(props.modelValue.q)
let timer: ReturnType<typeof setTimeout> | undefined

watch(
  () => props.modelValue.q,
  (q) => {
    search.value = q
  },
)

function update(partial: Partial<BookFilters>) {
  emit('update:modelValue', { ...props.modelValue, ...partial, page: 1 })
}

function onSearch() {
  clearTimeout(timer)
  timer = setTimeout(() => update({ q: search.value }), 300)
}

onScopeDispose(() => clearTimeout(timer))

const field = 'rounded border border-gray-300 px-2 py-1 text-sm'
</script>

<template>
  <form class="flex flex-wrap items-end gap-3" role="search" @submit.prevent>
    <label class="flex flex-col text-sm">
      Search
      <input
        v-model="search"
        type="search"
        name="q"
        :class="field"
        placeholder="Title or author"
        @input="onSearch"
      />
    </label>
    <label class="flex flex-col text-sm">
      Shelf
      <select
        name="shelf"
        :class="field"
        :value="props.modelValue.shelf"
        @change="
          update({ shelf: ($event.target as HTMLSelectElement).value as BookFilters['shelf'] })
        "
      >
        <option value="">All</option>
        <option value="read">Read</option>
        <option value="currently-reading">Currently reading</option>
        <option value="to-read">To read</option>
      </select>
    </label>
    <label class="flex flex-col text-sm">
      Rating
      <select
        name="rating"
        :class="field"
        :value="props.modelValue.rating"
        @change="
          update({ rating: ($event.target as HTMLSelectElement).value as BookFilters['rating'] })
        "
      >
        <option value="">Any</option>
        <option v-for="n in [5, 4, 3, 2, 1]" :key="n" :value="String(n)">{{ n }} stars</option>
        <option value="unrated">Unrated</option>
      </select>
    </label>
    <label class="flex flex-col text-sm">
      Year read
      <input
        type="number"
        name="year"
        :class="[field, 'w-24']"
        :value="props.modelValue.year"
        @change="update({ year: ($event.target as HTMLInputElement).value })"
      />
    </label>
    <label class="flex flex-col text-sm">
      Sort by
      <select
        name="sort"
        :class="field"
        :value="props.modelValue.sort"
        @change="
          update({ sort: ($event.target as HTMLSelectElement).value as BookFilters['sort'] })
        "
      >
        <option value="date_read">Date read</option>
        <option value="date_added">Date added</option>
        <option value="title">Title</option>
        <option value="my_rating">My rating</option>
        <option value="num_pages">Pages</option>
      </select>
    </label>
  </form>
</template>
