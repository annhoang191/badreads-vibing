<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { ApiError } from '@/api/client'
import ImportStatusCard from '@/components/imports/ImportStatusCard.vue'
import { useGoodreadsProfileStore } from '@/stores/goodreadsProfile'
import { useImportsStore } from '@/stores/imports'

const store = useGoodreadsProfileStore()
const imports = useImportsStore()

const input = ref('')
const rssEnabled = ref(true)
const saved = ref(false)

watch(
  () => store.profile,
  (p) => {
    if (!p) return
    input.value = p.goodreads_user_id
    rssEnabled.value = p.rss_enabled
  },
  { immediate: true },
)

function describe(error: Error | null, messages: Record<string, string>) {
  if (!error) return null
  if (error instanceof ApiError) return messages[error.code] ?? error.message
  return 'Something went wrong. Please try again.'
}

const saveMessage = computed(() =>
  store.invalidInput
    ? 'Enter your numeric Goodreads user ID or paste your profile URL (goodreads.com/user/show/12345).'
    : describe(store.saveError, {
        profile_not_public:
          'We could not read that profile. Make sure it exists and your Goodreads profile and shelves are public.',
      }),
)
const syncMessage = computed(() =>
  describe(store.syncError, {
    import_in_progress: 'A sync or import is already running.',
    rate_limited: 'You can sync at most once every 10 minutes. Try again later.',
  }),
)
const lastSynced = computed(() =>
  store.profile?.last_synced_at ? new Date(store.profile.last_synced_at).toLocaleString() : 'never',
)

async function onSave() {
  saved.value = false
  saved.value = await store.save(input.value, rssEnabled.value)
}

onMounted(() => {
  void store.load()
  void imports.loadHistory()
})
</script>

<template>
  <main class="mx-auto max-w-2xl space-y-10 p-4 md:p-8">
    <h1 class="text-3xl font-bold">Settings</h1>

    <section aria-labelledby="rss-heading">
      <h2 id="rss-heading" class="text-xl font-semibold">Goodreads RSS sync</h2>
      <p class="mt-1 text-sm text-gray-600">
        Keep your library up to date from your public shelves. Your Goodreads profile and shelves
        must be public for this to work.
      </p>

      <form class="mt-4 space-y-3" @submit.prevent="onSave">
        <div>
          <label for="profile-input" class="block text-sm font-medium"
            >Profile URL or user ID</label
          >
          <input
            id="profile-input"
            v-model="input"
            type="text"
            class="mt-1 w-full rounded border border-gray-400 px-3 py-2"
            placeholder="https://www.goodreads.com/user/show/12345-jane"
            :aria-invalid="!!saveMessage"
            aria-describedby="save-error"
          />
        </div>
        <label class="flex items-center gap-2 text-sm">
          <input v-model="rssEnabled" type="checkbox" />
          Sync automatically every 6 hours
        </label>
        <p v-if="saveMessage" id="save-error" role="alert" class="text-sm text-red-700">
          {{ saveMessage }}
        </p>
        <p v-else-if="saved" role="status" class="text-sm text-green-700">Saved.</p>
        <button
          type="submit"
          class="rounded bg-indigo-700 px-4 py-2 text-white disabled:opacity-50"
          :disabled="store.saving"
        >
          {{ store.saving ? 'Saving…' : 'Save' }}
        </button>
      </form>

      <div v-if="store.profile" class="mt-6 space-y-2">
        <p class="text-sm" data-testid="last-synced">Last synced: {{ lastSynced }}</p>
        <p
          v-if="store.profile.last_error"
          class="text-sm text-red-700"
          role="alert"
          data-testid="last-error"
        >
          {{ store.profile.last_error }}
        </p>
        <button
          type="button"
          class="rounded border border-gray-400 px-3 py-1 text-sm disabled:opacity-50"
          :disabled="store.syncing || imports.inProgress"
          @click="store.sync()"
        >
          Sync now
        </button>
        <p v-if="syncMessage" role="alert" class="text-sm text-red-700">{{ syncMessage }}</p>
        <ImportStatusCard v-if="imports.current && imports.inProgress" :import="imports.current" />
      </div>
    </section>

    <section aria-labelledby="history-heading">
      <h2 id="history-heading" class="text-xl font-semibold">Import history</h2>
      <p v-if="!imports.history.length" class="mt-2 text-sm text-gray-600">No imports yet.</p>
      <ul v-else class="mt-3 space-y-3">
        <li v-for="item in imports.history" :key="item.id">
          <p class="text-xs text-gray-600">
            {{ item.source === 'rss' ? 'RSS sync' : 'CSV upload' }},
            {{ new Date(item.created_at).toLocaleString() }}
          </p>
          <ImportStatusCard :import="item" />
        </li>
      </ul>
    </section>
  </main>
</template>
