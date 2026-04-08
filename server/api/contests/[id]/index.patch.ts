import { defineEventHandler, createError, getRouterParam, readBody } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const idOrSlug = getRouterParam(event, 'id')
  const body = await readBody(event)
  
  const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(idOrSlug || '')
  
  let query = client.from('contests').update(body)
  
  if (isUUID) {
    query = query.eq('id', idOrSlug)
  } else {
    query = query.eq('slug', idOrSlug)
  }

  const { data, error } = await query.select().single()
  
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
