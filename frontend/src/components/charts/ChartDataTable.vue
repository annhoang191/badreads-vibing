<script setup lang="ts">
const props = defineProps<{
  caption: string
  headers: [string, string]
  rows: [string, number][]
}>()
</script>

<template>
  <details class="mt-2 text-sm">
    <summary class="cursor-pointer text-indigo-700">View data as table</summary>
    <table class="mt-2 w-full text-left">
      <caption class="sr-only">
        {{
          props.caption
        }}
      </caption>
      <thead>
        <tr>
          <th scope="col" class="border-b border-gray-300 py-1">{{ props.headers[0] }}</th>
          <th scope="col" class="border-b border-gray-300 py-1 text-right">
            {{ props.headers[1] }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="[label, value] in props.rows" :key="label">
          <th scope="row" class="py-0.5 font-normal">{{ label }}</th>
          <td class="py-0.5 text-right">{{ value }}</td>
        </tr>
      </tbody>
    </table>
  </details>
</template>
