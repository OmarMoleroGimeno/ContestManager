import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const user = event.context.user
  if (!user) throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })

  const client = serverSupabaseAdmin()
  const idOrSlug = getRouterParam(event, 'id')

  const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(idOrSlug || '')

  // Scope by user's organization to avoid collisions on (slug) across orgs.
  const { data: org } = await client
    .from('organizations')
    .select('id')
    .eq('owner_id', user.id)
    .maybeSingle()

  let query = client.from('contests').select('*, organizations(*)').limit(1)
  if (isUUID) {
    query = query.eq('id', idOrSlug)
  } else {
    query = query.eq('slug', idOrSlug)
    if (org?.id) query = query.eq('organization_id', org.id)
  }

  const { data, error } = await query.maybeSingle()

  if (error || !data) {
    throw createError({ statusCode: 404, statusMessage: 'Contest not found' })
  }

  return data
})
