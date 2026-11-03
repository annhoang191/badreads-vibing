<script setup lang="ts">
import { computed } from 'vue'
import { Bar as ChartComponent } from 'vue-chartjs'
import { Chart as ChartJS, Tooltip, BarElement, CategoryScale, LinearScale } from 'chart.js'
import type { ChartOptions } from 'chart.js'
import ChartDataTable from './ChartDataTable.vue'

ChartJS.register(Tooltip, BarElement, CategoryScale, LinearScale)

const props = defineProps<{
  distribution: { '1': number; '2': number; '3': number; '4': number; '5': number; unrated: number }
}>()

const rows = computed<[string, number][]>(() => [
  ...(['1', '2', '3', '4', '5'] as const).map((k): [string, number] => [
    `${k} star${k === '1' ? '' : 's'}`,
    props.distribution[k],
  ]),
  ['Unrated', props.distribution.unrated],
])
const labels = computed(() => rows.value.map(([label]) => label))
const values = computed(() => rows.value.map(([, value]) => value))

const chartData = computed(() => ({
  labels: labels.value,
  datasets: [{ label: 'Rating distribution', data: values.value, backgroundColor: '#4f46e5' }],
}))
const chartOptions: ChartOptions<'bar'> = {
  responsive: true,
  maintainAspectRatio: false,
  scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
  plugins: { legend: { display: false } },
}
</script>

<template>
  <figure>
    <figcaption class="mb-2 font-medium">Rating distribution</figcaption>
    <div class="h-64">
      <ChartComponent
        :data="chartData"
        :options="chartOptions"
        role="img"
        aria-label="Rating distribution chart; a data table follows"
      />
    </div>
    <ChartDataTable caption="Rating distribution" :headers="['Rating', 'Books']" :rows="rows" />
  </figure>
</template>
