import { createApp } from 'vue'
import { createPinia } from 'pinia'

import './style.css'
import App from './App.vue'
import router from './router'
import { onUnauthorized } from '@/api/client'
import { useAuthStore } from '@/stores/auth'

async function boot() {
  const app = createApp(App)
  app.use(createPinia())

  const auth = useAuthStore()
  onUnauthorized(() => {
    const wasAuthenticated = auth.isAuthenticated
    auth.clear()
    if (wasAuthenticated) void router.push({ name: 'login' })
  })
  await auth.restore()

  app.use(router)
  app.mount('#app')
}

void boot()
