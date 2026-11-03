<script setup lang="ts">
import { computed } from 'vue'
import { Bar as ChartComponent } from 'vue-chartjs'
import { Chart as ChartJS, Tooltip, BarElement, CategoryScale, LinearScale } from 'chart.js'
import type { ChartOptions } from 'chart.js'
import ChartDataTable from './ChartDataTable.vue'

ChartJS.register(Tooltip, BarElement, CategoryScale, LinearScale)

const props = defineProps<{ books: { year: number | null; count: number }[] }>()

const rows = computed<[string, number][]>(() =>
  props.books.map(({ year, count }): [string, number] => [
    year === null ? 'Undated' : String(year),
    count,
  ]),
)
const labels = computed(() => rows.value.map(([label]) => label))
const values = computed(() => rows.value.map(([, value]) => value))

const chartData = computed(() => ({
  labels: labels.value,
  datasets: [{ label: 'Books read per year', data: values.value, backgroundColor: '#4f46e5' }],
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
    <figcaption class="mb-2 font-medium">Books read per year</figcaption>
    <div class="h-64">
      <ChartComponent
        :data="chartData"
        :options="chartOptions"
        role="img"
        aria-label="Books read per year chart; a data table follows"
      />
    </div>
    <ChartDataTable caption="Books read per year" :headers="['Year', 'Books']" :rows="rows" />
  </figure>
</template>
