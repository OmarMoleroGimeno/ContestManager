import { defineEventHandler, createError, getRouterParam, readBody } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const roundId = getRouterParam(event, 'id')
  const body = await readBody(event) // { participantIds: string[] }
  
  if (!roundId || !body.participantIds) throw createError({ statusCode: 400, statusMessage: 'Missing ID or participantIds' })

  const roundParticipants = body.participantIds.map((pid: string, idx: number) => ({
    round_id: roundId,
    participant_id: pid,
    order: idx + 1,
    is_qualified: false 
  }))

  const { error } = await client
    .from('round_participants')
    .insert(roundParticipants)
    
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return { success: true }
})
