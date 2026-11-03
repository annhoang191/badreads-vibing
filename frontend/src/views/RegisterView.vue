<script setup lang="ts">
import { computed, ref } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { ApiError } from '@/api/client'
import AuthForm from '@/components/auth/AuthForm.vue'
import { useAuthStore } from '@/stores/auth'
import type { Credentials } from '@/types/api'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()
const error = ref<Error | null>(null)

const fieldErrors = computed(() => {
  const e = error.value
  if (!(e instanceof ApiError) || e.code !== 'unprocessable') return undefined
  return e.details as { email_address?: string[]; password?: string[] }
})

const errorText = computed(() => {
  const e = error.value
  if (!e || fieldErrors.value) return null
  if (e instanceof ApiError && e.code === 'rate_limited')
    return 'Too many attempts. Wait a few minutes.'
  return 'Something went wrong. Try again.'
})

async function onSubmit(credentials: Credentials) {
  error.value = await auth.register(credentials)
  if (error.value) return
  const redirect = route.query.redirect
  await router.push(
    typeof redirect === 'string' && redirect.startsWith('/') && !redirect.startsWith('//')
      ? redirect
      : '/',
  )
}
</script>

<template>
  <main class="mx-auto max-w-sm p-8">
    <AuthForm
      mode="register"
      :busy="auth.loading"
      :error-text="errorText"
      :field-errors="fieldErrors"
      @submit="onSubmit"
    >
      <template #footer>
        Already have an account?
        <RouterLink to="/login" class="text-indigo-700 underline">Log in</RouterLink>
      </template>
    </AuthForm>
  </main>
</template>
