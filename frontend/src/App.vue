<script setup lang="ts">
import { computed } from 'vue'
import { RouterView, useRoute, useRouter } from 'vue-router'
import AppHeader from '@/components/layout/AppHeader.vue'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const router = useRouter()
useRoute() // re-evaluate links on navigation

const NAV = [
  { to: '/', label: 'Dashboard' },
  { to: '/library', label: 'Library' },
  { to: '/recommendations', label: 'Recommendations' },
  { to: '/settings', label: 'Settings' },
]
// Only link to routes that exist, so unbuilt pages don't trigger router warnings.
const links = computed(() => NAV.filter((l) => router.getRoutes().some((r) => r.path === l.to)))

async function onLogout() {
  await auth.logout()
  await router.push({ name: 'login' })
}
</script>

<template>
  <AppHeader
    v-if="auth.isAuthenticated && auth.user"
    :email="auth.user.email_address"
    :links="links"
    @logout="onLogout"
  />
  <RouterView />
</template>
