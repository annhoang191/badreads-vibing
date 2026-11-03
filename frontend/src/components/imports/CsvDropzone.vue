<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{ disabled?: boolean }>()
const emit = defineEmits<{ select: [file: File] }>()

const dragging = ref(false)
const input = ref<HTMLInputElement | null>(null)

function pick(file: File | undefined) {
  if (file && !props.disabled) emit('select', file)
}

function onChange(event: Event) {
  const el = event.target as HTMLInputElement
  pick(el.files?.[0])
  el.value = ''
}

function onDrop(event: DragEvent) {
  dragging.value = false
  pick(event.dataTransfer?.files[0])
}
</script>

<template>
  <div
    data-testid="dropzone"
    class="rounded-lg border-2 border-dashed p-8 text-center"
    :class="[
      dragging ? 'border-indigo-500 bg-indigo-50' : 'border-gray-300',
      props.disabled ? 'opacity-60' : '',
    ]"
    @dragover.prevent="dragging = !props.disabled"
    @dragleave.prevent="dragging = false"
    @drop.prevent="onDrop"
  >
    <p class="text-gray-700">Drag your Goodreads CSV here, or</p>
    <button
      type="button"
      class="mt-3 rounded bg-indigo-700 px-4 py-2 text-white disabled:opacity-50"
      :disabled="props.disabled"
      @click="input?.click()"
    >
      Choose a .csv file
    </button>
    <input
      ref="input"
      type="file"
      accept=".csv,text/csv"
      class="sr-only"
      aria-label="Goodreads CSV file"
      :disabled="props.disabled"
      @change="onChange"
    />
  </div>
</template>
