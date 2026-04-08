import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const id = getRouterParam(event, 'id')
  
  if (!id) throw createError({ statusCode: 400, statusMessage: 'Missing ID' })

  // 1. Get participant's category_id
  const { data: participant, error: partError } = await client
    .from('participants')
    .select('category_id')
    .eq('id', id)
    .single()
    
  if (partError || !participant) throw createError({ statusCode: 404, statusMessage: 'Participant not found' })
  
  // 2. Check for non-pending rounds in that category
  const { data: rounds, error: roundsError } = await client
    .from('rounds')
    .select('status')
    .eq('category_id', participant.category_id)
    .neq('status', 'pending')
    
  if (roundsError) throw createError({ statusCode: 500, statusMessage: roundsError.message })
  
  if (rounds && rounds.length > 0) {
    throw createError({ 
      statusCode: 403, 
      statusMessage: 'No se puede eliminar el participante porque las rondas ya han comenzado o finalizado.' 
    })
  }
  
  // 3. Delete participant
  const { error: deleteError } = await client
    .from('participants')
    .delete()
    .eq('id', id)
    
  if (deleteError) throw createError({ statusCode: 500, statusMessage: deleteError.message })
  
  return { success: true }
})
