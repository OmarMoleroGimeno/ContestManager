import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const roundId = getRouterParam(event, 'roundId')
  
  const { data, error } = await client.from('scores').select('*').eq('round_id', roundId)
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
