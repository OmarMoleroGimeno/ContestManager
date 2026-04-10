import { createClient } from '@supabase/supabase-js'
import type { SupabaseClient } from '@supabase/supabase-js'

let supabaseInstance: SupabaseClient | null = null

export default defineNuxtPlugin(async (nuxtApp) => {
  const config = useRuntimeConfig()

  if (!supabaseInstance) {
    supabaseInstance = createClient(
      config.public.supabaseUrl as string,
      config.public.supabaseAnonKey as string,
      {
        auth: {
          persistSession: true,
          autoRefreshToken: true,
          detectSessionInUrl: true,
          storageKey: 'contest-saas-auth'
        }
      }
    )
  }

  return {
    provide: {
      supabase: supabaseInstance
    }
  }
})
