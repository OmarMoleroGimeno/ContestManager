import { defineStore } from 'pinia'
import { ref } from 'vue'
import { createClient } from '@supabase/supabase-js'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<any>(null)
  const session = ref<any>(null)
  
  const init = async () => {
    const config = useRuntimeConfig()
    const supabaseUrl = config.public.supabaseUrl as string
    const supabaseKey = config.public.supabaseAnonKey as string
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    const { data: { session: currentSession } } = await supabase.auth.getSession()
    session.value = currentSession
    user.value = currentSession?.user || null
    
    supabase.auth.onAuthStateChange((_event, newSession) => {
      session.value = newSession
      user.value = newSession?.user || null
    })
  }

  const signIn = async (email: string) => {
    const config = useRuntimeConfig()
    const supabase = createClient(config.public.supabaseUrl, config.public.supabaseAnonKey)
    return await supabase.auth.signInWithOtp({ email })
  }

  const signOut = async () => {
    const config = useRuntimeConfig()
    const supabase = createClient(config.public.supabaseUrl, config.public.supabaseAnonKey)
    await supabase.auth.signOut()
    user.value = null
    session.value = null
  }

  return { user, session, init, signIn, signOut }
})
