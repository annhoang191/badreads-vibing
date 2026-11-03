<script setup lang="ts">
import { computed } from 'vue'
import { Doughnut as ChartComponent } from 'vue-chartjs'
import { Chart as ChartJS, Tooltip, ArcElement, Legend } from 'chart.js'
import type { ChartOptions } from 'chart.js'
import ChartDataTable from './ChartDataTable.vue'

ChartJS.register(Tooltip, ArcElement, Legend)

const props = defineProps<{
  buckets: {
    under_200: number
    from_200_to_349: number
    from_350_to_499: number
    over_500: number
    unknown: number
  }
}>()

const rows = computed<[string, number][]>(() => [
  ['Under 200 pages', props.buckets.under_200],
  ['200 to 349 pages', props.buckets.from_200_to_349],
  ['350 to 499 pages', props.buckets.from_350_to_499],
  ['500+ pages', props.buckets.over_500],
  ['Unknown', props.buckets.unknown],
])
const labels = computed(() => rows.value.map(([label]) => label))
const values = computed(() => rows.value.map(([, value]) => value))

const chartData = computed(() => ({
  labels: labels.value,
  datasets: [
    {
      label: 'Book length',
      data: values.value,
      backgroundColor: ['#4338ca', '#0f766e', '#b45309', '#be123c', '#6b7280'],
    },
  ],
}))
const chartOptions: ChartOptions<'doughnut'> = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { position: 'bottom' } },
}
</script>

<template>
  <figure>
    <figcaption class="mb-2 font-medium">Book length</figcaption>
    <div class="h-64">
      <ChartComponent
        :data="chartData"
        :options="chartOptions"
        role="img"
        aria-label="Book length chart; a data table follows"
      />
    </div>
    <ChartDataTable caption="Book length" :headers="['Length', 'Books']" :rows="rows" />
  </figure>
</template>
