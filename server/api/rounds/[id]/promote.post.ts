import { defineEventHandler, createError, getRouterParam, readBody } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const roundId = getRouterParam(event, 'id')
  const body = await readBody(event) 
  
  if (!roundId || !body.participantIds) throw createError({ statusCode: 400, statusMessage: 'Missing ID or participantIds' })

  // 1. Get current round info
  const { data: currentRound, error: roundError } = await client
    .from('rounds')
    .select('*')
    .eq('id', roundId)
    .single()
    
  if (roundError || !currentRound) throw createError({ statusCode: 404, statusMessage: 'Round not found' })

  // 2. Close current round (Mark participants as qualified in current round)
  await client.from('rounds').update({ status: 'closed' }).eq('id', roundId)
  
  // Mark these participants as qualified in the current round record
  await client.from('round_participants')
    .update({ is_qualified: true })
    .eq('round_id', roundId)
    .in('participant_id', body.participantIds)

  // 3. Find/Create next round
  let { data: nextRound } = await client
    .from('rounds')
    .select('*')
    .eq('category_id', currentRound.category_id)
    .eq('order', currentRound.order + 1)
    .single()
    
  if (!nextRound) {
    const { data: created, error: createErrorMsg } = await client
      .from('rounds')
      .insert({
        category_id: currentRound.category_id,
        name: body.nextRoundName || `Ronda ${currentRound.order + 1}`,
        order: currentRound.order + 1,
        status: 'pending',
        scoring_type: currentRound.scoring_type
      })
      .select()
      .single()
      
    if (createErrorMsg) throw createError({ statusCode: 500, statusMessage: createErrorMsg.message })
    nextRound = created
  }

  // 4. Add participants to next round
  const roundParticipants = body.participantIds.map((pid: string, idx: number) => ({
    round_id: nextRound!.id,
    participant_id: pid,
    order: idx + 1,
    is_qualified: false 
  }))

  const { error: insertError } = await client
    .from('round_participants')
    .insert(roundParticipants)
    
  if (insertError) throw createError({ statusCode: 500, statusMessage: insertError.message })

  return { success: true, nextRoundId: nextRound.id }
})
