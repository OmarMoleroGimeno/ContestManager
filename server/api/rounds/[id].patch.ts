import { defineEventHandler, createError, getRouterParam, readBody } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  
  if (!id) throw createError({ statusCode: 400, statusMessage: 'Missing ID' })

  const { data, error } = await client
    .from('rounds')
    .update(body)
    .eq('id', id)
    .select()
    .single()
    
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
