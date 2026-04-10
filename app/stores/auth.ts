import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { User, Session, SupabaseClient } from '@supabase/supabase-js'
import type { Organization, Profile } from '~/types'

export type { Profile }

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const session = ref<Session | null>(null)
  const profile = ref<Profile | null>(null)
  const organization = ref<Organization | null>(null)
  const loading = ref(false)
  let authListener: { subscription: { unsubscribe: () => void } } | null = null

  // ─── Computed ─────────────────────────────────────────────────────────────
  const isAuthenticated = computed(() => !!user.value)
  const isOrgOwner = computed(() => profile.value?.account_type === 'org_owner')
  const needsOnboarding = computed(
    () => isAuthenticated.value && !profile.value?.full_name
  )
  const needsOrgSetup = computed(
    () => isAuthenticated.value && isOrgOwner.value && !organization.value
  )
  const displayName = computed(
    () => profile.value?.full_name || user.value?.email || 'Usuario'
  )
  const initials = computed(() =>
    displayName.value
      .split(' ')
      .map((n) => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2)
  )

  // ─── Helpers ──────────────────────────────────────────────────────────────
  const getSupabase = (): SupabaseClient => {
    const nuxtApp = useNuxtApp()
    return nuxtApp.$supabase as SupabaseClient
  }

  // ─── Data fetching ────────────────────────────────────────────────────────
  const fetchProfile = async () => {
    if (!user.value) return
    const supabase = getSupabase()
    const { data } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.value.id)
      .single()
    profile.value = data ?? null
  }

  const fetchOrganization = async () => {
    if (!user.value) return
    const supabase = getSupabase()
    const { data } = await supabase
      .from('organizations')
      .select('*')
      .eq('owner_id', user.value.id)
      .maybeSingle()
    organization.value = data ?? null
  }

  // ─── Init (client-only, called from auth.client.ts plugin) ───────────────
  const init = async () => {
    if (import.meta.server) return
    const supabase = getSupabase()
    if (!supabase) return

    // Avoid registering duplicate listeners on hot-reload / multiple init calls
    if (authListener) {
      authListener.subscription.unsubscribe()
      authListener = null
    }

    const { data: { session: currentSession }, error: sessionError } = await supabase.auth.getSession()

    if (sessionError || !currentSession) {
      // Clear any stale/corrupt session from localStorage
      await supabase.auth.signOut()
      session.value = null
      user.value = null
    } else {
      session.value = currentSession
      user.value = currentSession.user ?? null
    }

    if (user.value) {
      await Promise.all([fetchProfile(), fetchOrganization()])
    }

    const { data: listener } = supabase.auth.onAuthStateChange(async (event, newSession) => {
      if (event === 'SIGNED_OUT' || event === 'TOKEN_REFRESHED' && !newSession) {
        session.value = null
        user.value = null
        profile.value = null
        organization.value = null
        return
      }

      session.value = newSession
      user.value = newSession?.user ?? null

      if (user.value && (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED' || event === 'USER_UPDATED')) {
        await Promise.all([fetchProfile(), fetchOrganization()])
      }
    })
    authListener = listener
  }

  // ─── Auth actions ─────────────────────────────────────────────────────────
  const signIn = async (email: string, password: string) => {
    return getSupabase().auth.signInWithPassword({ email, password })
  }

  const signUp = async (email: string, password: string) => {
    return getSupabase().auth.signUp({ email, password })
  }

  const signOut = async () => {
    await getSupabase().auth.signOut()
    user.value = null
    session.value = null
    profile.value = null
    organization.value = null
  }

  // ─── Profile / Org mutations ──────────────────────────────────────────────
  const updateProfile = async (
    data: Partial<Omit<Profile, 'id' | 'created_at' | 'updated_at'>>
  ) => {
    if (!user.value) return { data: null, error: new Error('No user') }
    const { data: updated, error } = await getSupabase()
      .from('profiles')
      .upsert({ id: user.value.id, ...data })
      .select()
      .single()
    if (!error && updated) profile.value = updated as Profile
    return { data: updated, error }
  }

  const createOrganization = async (name: string, slug: string) => {
    if (!user.value) return { data: null, error: new Error('No user') }
    const { data, error } = await getSupabase()
      .from('organizations')
      .insert({ owner_id: user.value.id, name, slug })
      .select()
      .single()
    if (!error && data) organization.value = data as Organization
    return { data, error }
  }

  return {
    user,
    session,
    profile,
    organization,
    loading,
    isAuthenticated,
    isOrgOwner,
    needsOnboarding,
    needsOrgSetup,
    displayName,
    initials,
    init,
    signIn,
    signUp,
    signOut,
    fetchProfile,
    fetchOrganization,
    updateProfile,
    createOrganization
  }
})
