import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const idOrSlug = getRouterParam(event, 'id')
  
  // Try to find by UUID first if it looks like one, otherwise slug
  const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(idOrSlug || '')
  
  let query = client.from('contests').select('*, organizations(*)')
  
  if (isUUID) {
    query = query.eq('id', idOrSlug)
  } else {
    query = query.eq('slug', idOrSlug)
  }

  const { data, error } = await query.single()
  
  if (error || !data) {
    throw createError({ statusCode: 404, statusMessage: 'Contest not found' })
  }
  
  return data
})
