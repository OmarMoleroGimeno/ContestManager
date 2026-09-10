import type { SupabaseClient } from '@supabase/supabase-js'
import { useAuthStore } from '~/stores/auth'

/**
 * HTTP client based on Nuxt's $fetch.
 * Automatically injects the Supabase session token for authenticated requests.
 */
export const apiClient = $fetch.create({
  async onRequest({ options }) {
    if (!import.meta.client) return

    let token: string | undefined

    // Ask Supabase for the session rather than reading the cached one from the
    // store: `getSession()` transparently refreshes an expired access token.
    // A tab left open past the token lifetime (or backgrounded, where the
    // refresh timer gets throttled) would otherwise keep sending a stale JWT
    // and every request would come back 401.
    try {
      const supabase = useNuxtApp().$supabase as SupabaseClient | undefined
      if (supabase) {
        const { data } = await supabase.auth.getSession()
        token = data.session?.access_token
      }
    } catch {
      // No Nuxt context / plugin not ready — fall back below.
    }

    if (!token) {
      try {
        token = useAuthStore().session?.access_token
      } catch {
        // Pinia not available; send the request unauthenticated.
      }
    }

    if (token) {
      options.headers = {
        ...(options.headers as Record<string, string> || {}),
        Authorization: `Bearer ${token}`
      }
    }
  },

  onResponseError({ response }) {
    console.error(`[API Error ${response.status}]`, response._data)
  }
})
