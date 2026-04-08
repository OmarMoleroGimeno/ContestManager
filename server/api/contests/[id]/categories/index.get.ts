import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const id = getRouterParam(event, 'id')
  const { data, error } = await client.from('categories').select('*').eq('contest_id', id).order('order', { ascending: true })
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
