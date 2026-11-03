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

const errorText = computed(() => {
  const e = error.value
  if (!e) return null
  if (e instanceof ApiError && e.code === 'invalid_credentials')
    return 'Email or password is incorrect.'
  if (e instanceof ApiError && e.code === 'rate_limited')
    return 'Too many attempts. Wait a few minutes.'
  return 'Something went wrong. Try again.'
})

async function onSubmit(credentials: Credentials) {
  error.value = await auth.login(credentials)
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
    <AuthForm mode="login" :busy="auth.loading" :error-text="errorText" @submit="onSubmit">
      <template #footer>
        New here?
        <RouterLink to="/register" class="text-indigo-700 underline">Create an account</RouterLink>
      </template>
    </AuthForm>
  </main>
</template>
