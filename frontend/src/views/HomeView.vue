<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import BooksPerMonthChart from '@/components/charts/BooksPerMonthChart.vue'
import BooksPerYearChart from '@/components/charts/BooksPerYearChart.vue'
import LengthBucketsChart from '@/components/charts/LengthBucketsChart.vue'
import PublicationDecadesChart from '@/components/charts/PublicationDecadesChart.vue'
import RatingDistributionChart from '@/components/charts/RatingDistributionChart.vue'
import CoverageNote from '@/components/insights/CoverageNote.vue'
import RatingVsCrowd from '@/components/insights/RatingVsCrowd.vue'
import StatTiles from '@/components/insights/StatTiles.vue'
import TbrSummary from '@/components/insights/TbrSummary.vue'
import TopList from '@/components/insights/TopList.vue'
import { useAuthStore } from '@/stores/auth'
import { useInsightsStore } from '@/stores/insights'

const auth = useAuthStore()
const insights = useInsightsStore()

const noBooks = computed(() => auth.stats?.books === 0)
const snapshot = computed(() => insights.snapshot)
const showSkeleton = computed(() => !insights.loaded && !insights.error && !snapshot.value)
const showError = computed(() => !!insights.error && !snapshot.value && !insights.refreshing)
const showComputing = computed(() => insights.loaded && !snapshot.value && !showError.value)
const m = computed(() => snapshot.value?.metrics)

const authorRows = computed(() =>
  (m.value?.top_authors ?? []).map((a) => ({
    label: a.author,
    value: `${a.count} books${a.mean_rating === null ? '' : `, avg ${a.mean_rating.toFixed(2)}`}`,
  })),
)
const subjectRows = computed(() =>
  (m.value?.top_subjects ?? []).map((s) => ({
    label: s.subject,
    value: `${s.count} books`,
  })),
)

onMounted(async () => {
  if (noBooks.value) return
  await insights.load()
  // Not computed yet (204): ask for it and poll until it appears.
  if (insights.loaded && !insights.snapshot) await insights.refresh()
})
</script>

<template>
  <main class="mx-auto max-w-5xl p-4 md:p-8">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <h1 class="text-3xl font-bold">Dashboard</h1>
      <button
        v-if="snapshot"
        type="button"
        class="rounded border border-gray-400 px-3 py-1 text-sm disabled:opacity-50"
        :disabled="insights.refreshing"
        @click="insights.refresh()"
      >
        {{ insights.refreshing ? 'Refreshing…' : 'Refresh insights' }}
      </button>
    </div>

    <p v-if="noBooks" class="mt-6" data-testid="import-cta">
      <RouterLink to="/onboarding" class="rounded bg-indigo-700 px-4 py-2 text-white"
        >Import your library</RouterLink
      >
    </p>

    <div v-else-if="showSkeleton" class="mt-6 space-y-3" data-testid="insights-loading">
      <div class="h-24 animate-pulse rounded bg-gray-200"></div>
      <div class="h-64 animate-pulse rounded bg-gray-200"></div>
    </div>

    <div v-else-if="showError" class="mt-6" role="alert" data-testid="insights-error">
      <p class="text-red-700">Could not load your insights.</p>
      <button
        type="button"
        class="mt-2 rounded border border-gray-400 px-3 py-1 text-sm"
        @click="insights.load()"
      >
        Try again
      </button>
    </div>

    <p
      v-else-if="showComputing"
      class="mt-6 text-gray-700"
      role="status"
      data-testid="insights-computing"
    >
      Insights are being computed…
    </p>

    <div v-else-if="snapshot && m" class="mt-6 space-y-6" data-testid="insights-dashboard">
      <p v-if="insights.error" role="alert" class="text-sm text-red-700">
        Could not refresh insights. Showing the last computed results.
      </p>
      <StatTiles :totals="m.totals" :average-rating="m.average_rating" :pace="m.pace" />
      <CoverageNote
        :numerator="snapshot.coverage.with_pages"
        :denominator="snapshot.coverage.read_total"
        label="read books with a page count"
      />

      <div class="grid gap-6 md:grid-cols-2">
        <div class="rounded border border-gray-300 bg-white p-4">
          <BooksPerYearChart :books="m.books_per_year" />
          <CoverageNote
            :numerator="snapshot.coverage.dated"
            :denominator="snapshot.coverage.read_total"
            label="read books with a date"
          />
        </div>
        <div class="rounded border border-gray-300 bg-white p-4">
          <BooksPerMonthChart :months="m.books_per_month" />
        </div>
        <div class="rounded border border-gray-300 bg-white p-4">
          <RatingDistributionChart :distribution="m.rating_distribution" />
          <CoverageNote
            :numerator="snapshot.coverage.rated"
            :denominator="snapshot.coverage.read_total"
            label="read books with a rating"
          />
        </div>
        <div class="rounded border border-gray-300 bg-white p-4">
          <LengthBucketsChart :buckets="m.length_buckets" />
        </div>
        <div class="rounded border border-gray-300 bg-white p-4">
          <PublicationDecadesChart :decades="m.publication_decades" />
        </div>
        <div class="rounded border border-gray-300 bg-white p-4">
          <TopList title="Top authors" :rows="authorRows" />
        </div>
        <div class="rounded border border-gray-300 bg-white p-4">
          <TopList title="Top subjects" :rows="subjectRows" />
          <CoverageNote
            :numerator="snapshot.coverage.enriched"
            :denominator="snapshot.coverage.read_total"
            label="read books with subject data"
          />
        </div>
        <div class="rounded border border-gray-300 bg-white p-4">
          <TbrSummary :tbr="m.tbr" />
        </div>
        <div class="rounded border border-gray-300 bg-white p-4 md:col-span-2">
          <RatingVsCrowd
            :mean-diff="m.rating_vs_crowd.mean_diff"
            :higher="m.rating_vs_crowd.higher"
            :lower="m.rating_vs_crowd.lower"
          />
        </div>
      </div>
    </div>
  </main>
</template>
