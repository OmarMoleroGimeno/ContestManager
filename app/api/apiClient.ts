import { useAuthStore } from '~/stores/auth'

/**
 * HTTP client based on Nuxt's $fetch.
 * Automatically injects the Supabase session token for authenticated requests.
 */
export const apiClient = $fetch.create({
  onRequest({ options }) {
    if (import.meta.client) {
      const authStore = useAuthStore()
      const token = authStore.session?.access_token
      if (token) {
        options.headers = {
          ...(options.headers as Record<string, string> || {}),
          Authorization: `Bearer ${token}`
        }
      }
    }
  },

  onResponseError({ response }) {
    console.error(`[API Error ${response.status}]`, response._data)
  }
})
