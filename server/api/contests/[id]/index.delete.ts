import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const idOrSlug = getRouterParam(event, 'id')
  
  if (!idOrSlug) throw createError({ statusCode: 400, statusMessage: 'ID or Slug is required' })

  const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(idOrSlug)
  
  let query = client.from('contests').delete()
  
  if (isUUID) {
    query = query.eq('id', idOrSlug)
  } else {
    query = query.eq('slug', idOrSlug)
  }

  const { error } = await query
  
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  
  return { success: true }
})
