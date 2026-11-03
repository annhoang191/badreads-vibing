import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import * as authApi from '@/api/auth'
import { setAuthToken } from '@/api/client'
import { useAsync } from '@/composables/useAsync'
import type { AuthResponse, Credentials, MeStats, User } from '@/types/api'

export const TOKEN_KEY = 'shelfsight.token'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const token = ref<string | null>(null)
  const stats = ref<MeStats | null>(null)
  const isAuthenticated = computed(() => !!token.value && !!user.value)

  const registerCall = useAsync(authApi.register)
  const loginCall = useAsync(authApi.login)
  const loading = computed(() => registerCall.loading.value || loginCall.loading.value)

  function setSession(session: AuthResponse) {
    token.value = session.token
    user.value = session.user
    setAuthToken(session.token)
    localStorage.setItem(TOKEN_KEY, session.token)
  }

  function clear() {
    token.value = null
    user.value = null
    stats.value = null
    setAuthToken(null)
    localStorage.removeItem(TOKEN_KEY)
  }

  /** Runs the call; on failure returns the error instead of throwing. */
  async function authenticate(call: typeof registerCall, credentials: Credentials) {
    const session = await call.run(credentials)
    if (session) setSession(session)
    return call.error.value
  }

  const register = (credentials: Credentials) => authenticate(registerCall, credentials)
  const login = (credentials: Credentials) => authenticate(loginCall, credentials)

  async function logout() {
    try {
      await authApi.logout()
    } catch {
      // The session is cleared locally either way.
    }
    clear()
  }

  async function fetchMe() {
    const result = await authApi.me()
    user.value = result.user
    stats.value = result.stats
    return result
  }

  async function restore() {
    const stored = localStorage.getItem(TOKEN_KEY)
    if (!stored) return
    token.value = stored
    setAuthToken(stored)
    try {
      await fetchMe()
    } catch {
      clear()
    }
  }

  return {
    user,
    token,
    stats,
    isAuthenticated,
    loading,
    register,
    login,
    logout,
    fetchMe,
    restore,
    clear,
  }
})
