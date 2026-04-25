import { createClient } from '@supabase/supabase-js'
import type { H3Event } from 'h3'
import { getHeader } from 'h3'

export const serverSupabaseAdmin = () => {
  const url = process.env.SUPABASE_URL || ''
  const serviceKey = process.env.SUPABASE_SERVICE_KEY || ''
  return createClient(url, serviceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  })
}

export const serverSupabaseClient = (event: H3Event) => {
  // Bypass RLS para desarrollo: usamos el service key siempre
  return serverSupabaseAdmin()
}

/**
 * Supabase client scoped to the caller's JWT. Required for RPCs/queries that
 * rely on `auth.uid()` (e.g. SECURITY DEFINER functions that validate the user).
 */
export const serverSupabaseUser = (event: H3Event) => {
  const url = process.env.SUPABASE_URL || ''
  const anonKey = process.env.SUPABASE_ANON_KEY || ''
  const authHeader = getHeader(event, 'authorization') || ''
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : ''
  return createClient(url, anonKey, {
    global: { headers: token ? { Authorization: `Bearer ${token}` } : {} },
    auth: { persistSession: false, autoRefreshToken: false }
  })
}
