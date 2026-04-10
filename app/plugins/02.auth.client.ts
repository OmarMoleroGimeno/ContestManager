import { useAuthStore } from '~/stores/auth'

// Initialize auth state before any route middleware runs
export default defineNuxtPlugin(async () => {
  const authStore = useAuthStore()
  await authStore.init()
})
