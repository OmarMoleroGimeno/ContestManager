import { createClient } from '@supabase/supabase-js'
import type { H3Event } from 'h3'

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
