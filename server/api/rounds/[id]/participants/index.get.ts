import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const roundId = getRouterParam(event, 'id')
  
  if (!roundId) throw createError({ statusCode: 400, statusMessage: 'Missing Round ID' })

  const { data, error } = await client
    .from('round_participants')
    .select(`
      *,
      participant:participants(*)
    `)
    .eq('round_id', roundId)
    .order('order', { ascending: true })
    
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
