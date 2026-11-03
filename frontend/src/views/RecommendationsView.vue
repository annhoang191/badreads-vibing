<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { ApiError } from '@/api/client'
import GeneratePanel from '@/components/recommendations/GeneratePanel.vue'
import RankedByNote from '@/components/recommendations/RankedByNote.vue'
import RecommendationCard from '@/components/recommendations/RecommendationCard.vue'
import { useRecommendationsStore } from '@/stores/recommendations'

const store = useRecommendationsStore()

function humanize(seconds: number) {
  const minutes = Math.ceil(seconds / 60)
  if (minutes < 60) return `${Math.max(1, minutes)} minute${minutes === 1 ? '' : 's'}`
  const hours = Math.ceil(minutes / 60)
  return `${hours} hour${hours === 1 ? '' : 's'}`
}

const notEnoughData = computed(() => {
  const e = store.error
  return e instanceof ApiError && e.code === 'not_enough_data' ? Number(e.details.have ?? 0) : null
})

const errorMessage = computed(() => {
  const e = store.error
  if (!e) return null
  if (!(e instanceof ApiError)) return 'Something went wrong. Please try again.'
  if (e.code === 'not_enough_data') {
    return `Rate at least 10 books you've read to get recommendations (you have ${notEnoughData.value}).`
  }
  if (e.code === 'rate_limited') {
    return `Daily limit reached. Try again in ${humanize(Number(e.details.retry_after ?? 0))}.`
  }
  if (e.code === 'batch_in_progress') return 'Recommendations are already being generated.'
  return e.message
})

onMounted(() => void store.load())
</script>

<template>
  <main class="mx-auto max-w-6xl space-y-6 p-4 md:p-8">
    <h1 class="text-3xl font-bold">Recommendations</h1>

    <GeneratePanel
      :quota="store.quota"
      :disabled="!store.canGenerate"
      :busy="store.generating || store.inProgress"
      :has-batch="!!store.batch"
      @generate="store.generate()"
    />

    <p v-if="errorMessage" role="alert" class="text-sm text-red-700">
      {{ errorMessage }}
      <RouterLink v-if="notEnoughData !== null" to="/library" class="underline"
        >Go to your library</RouterLink
      >
    </p>

    <p v-if="store.loading && !store.loaded" role="status">Loading…</p>

    <section v-else-if="store.inProgress || store.generating" aria-live="polite">
      <template v-if="store.timedOut">
        <p role="status">This is taking longer than usual. Check back in a little while.</p>
      </template>
      <template v-else>
        <p role="status">Finding books for you… this can take up to a minute</p>
        <div class="mt-4 grid gap-4 md:grid-cols-2 lg:grid-cols-3" aria-hidden="true">
          <div
            v-for="n in 6"
            :key="n"
            data-testid="skeleton-card"
            class="h-56 animate-pulse rounded bg-gray-200"
          ></div>
        </div>
      </template>
    </section>

    <section v-else-if="store.batch?.status === 'failed'">
      <p role="alert" class="text-red-700">
        {{ store.batch.error_message ?? 'We could not generate recommendations.' }}
      </p>
      <p v-if="store.canGenerate" class="mt-1 text-sm">Use the button above to try again.</p>
    </section>

    <section v-else-if="store.batch?.status === 'completed'" class="space-y-4">
      <RankedByNote :ranked-by="store.batch.ranked_by" />
      <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <RecommendationCard v-for="r in store.recommendations" :key="r.id" :recommendation="r" />
      </div>
    </section>

    <section v-else-if="store.loaded">
      <p class="text-gray-700">
        Shelfsight looks at the books you've read and rated, then picks 10 books you're likely to
        enjoy next, each with a short explanation of why. You need at least 10 rated books.
      </p>
    </section>
  </main>
</template>
