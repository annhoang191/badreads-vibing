<script setup lang="ts">
import { computed, ref } from 'vue'
import type { Credentials } from '@/types/api'

const props = defineProps<{
  mode: 'login' | 'register'
  busy?: boolean
  errorText?: string | null
  fieldErrors?: { email_address?: string[]; password?: string[] }
}>()
const emit = defineEmits<{ submit: [credentials: Credentials] }>()

const email = ref('')
const password = ref('')

const isRegister = computed(() => props.mode === 'register')
const title = computed(() => (isRegister.value ? 'Create your account' : 'Log in'))
const submitLabel = computed(() => (isRegister.value ? 'Create account' : 'Log in'))

function onSubmit() {
  emit('submit', { email_address: email.value.trim(), password: password.value })
}
</script>

<template>
  <form class="space-y-4" novalidate @submit.prevent="onSubmit">
    <h1 class="text-2xl font-bold">{{ title }}</h1>

    <p v-if="props.errorText" role="alert" class="rounded bg-red-50 p-3 text-sm text-red-700">
      {{ props.errorText }}
    </p>

    <div>
      <label for="email" class="block text-sm font-medium">Email</label>
      <input
        id="email"
        v-model="email"
        type="email"
        name="email_address"
        autocomplete="email"
        required
        :aria-invalid="!!props.fieldErrors?.email_address"
        aria-describedby="email-error"
        class="mt-1 w-full rounded border border-gray-400 px-3 py-2"
      />
      <p v-if="props.fieldErrors?.email_address" id="email-error" class="mt-1 text-sm text-red-700">
        {{ props.fieldErrors.email_address.join(' ') }}
      </p>
    </div>

    <div>
      <label for="password" class="block text-sm font-medium">Password</label>
      <input
        id="password"
        v-model="password"
        type="password"
        name="password"
        :autocomplete="isRegister ? 'new-password' : 'current-password'"
        required
        :minlength="isRegister ? 10 : undefined"
        :aria-invalid="!!props.fieldErrors?.password"
        aria-describedby="password-hint password-error"
        class="mt-1 w-full rounded border border-gray-400 px-3 py-2"
      />
      <p v-if="isRegister" id="password-hint" class="mt-1 text-sm text-gray-600">
        At least 10 characters.
      </p>
      <p v-if="props.fieldErrors?.password" id="password-error" class="mt-1 text-sm text-red-700">
        {{ props.fieldErrors.password.join(' ') }}
      </p>
    </div>

    <button
      type="submit"
      :disabled="props.busy"
      class="w-full rounded bg-indigo-700 px-4 py-2 font-medium text-white disabled:opacity-60"
    >
      {{ props.busy ? 'Please wait…' : submitLabel }}
    </button>

    <p class="text-sm text-gray-600">
      <slot name="footer" />
    </p>
  </form>
</template>
