<script setup lang="ts">
import { computed } from 'vue'
import { Line as ChartComponent } from 'vue-chartjs'
import {
  Chart as ChartJS,
  Tooltip,
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale,
} from 'chart.js'
import type { ChartOptions } from 'chart.js'
import ChartDataTable from './ChartDataTable.vue'

ChartJS.register(Tooltip, LineElement, PointElement, CategoryScale, LinearScale)

const props = defineProps<{ months: { month: string; count: number }[] }>()

const rows = computed<[string, number][]>(() =>
  props.months.map(({ month, count }): [string, number] => [month, count]),
)
const labels = computed(() => rows.value.map(([label]) => label))
const values = computed(() => rows.value.map(([, value]) => value))

const chartData = computed(() => ({
  labels: labels.value,
  datasets: [
    {
      label: 'Books read per month',
      data: values.value,
      borderColor: '#4f46e5',
      backgroundColor: '#4f46e5',
      tension: 0.2,
    },
  ],
}))
const chartOptions: ChartOptions<'line'> = {
  responsive: true,
  maintainAspectRatio: false,
  scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
  plugins: { legend: { display: false } },
}
</script>

<template>
  <figure>
    <figcaption class="mb-2 font-medium">Books read per month</figcaption>
    <div class="h-64">
      <ChartComponent
        :data="chartData"
        :options="chartOptions"
        role="img"
        aria-label="Books read per month chart; a data table follows"
      />
    </div>
    <ChartDataTable caption="Books read per month" :headers="['Month', 'Books']" :rows="rows" />
  </figure>
</template>
