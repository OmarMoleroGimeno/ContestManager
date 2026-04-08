import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const id = getRouterParam(event, 'id') // contest_id
  
  // We need rounds mapped to categories inside this contest
  const { data, error } = await client.from('rounds').select('*, categories!inner(*)').eq('categories.contest_id', id).order('order', { ascending: true })
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
