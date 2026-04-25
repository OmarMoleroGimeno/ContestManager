import { defineEventHandler, createError } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const user = event.context.user
  if (!user) throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })

  const client = serverSupabaseAdmin()

  // Get user's organization(s)
  const { data: orgs } = await client
    .from('organizations')
    .select('id')
    .eq('owner_id', user.id)

  const orgIds = (orgs || []).map((o: any) => o.id)
  if (orgIds.length === 0) return []

  const { data, error } = await client
    .from('contests')
    .select('*')
    .in('organization_id', orgIds)
    .order('created_at', { ascending: false })

  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
