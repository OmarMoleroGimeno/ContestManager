import { defineEventHandler, createError, getRouterParam, readBody } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  
  // Validation for dynamic rounds
  const { data: contest } = await client.from('contests').select('is_rounds_dynamic').eq('id', id).single()
  
  if (contest?.is_rounds_dynamic) {
    // Check if there are active rounds
    const { data: activeRounds } = await client.from('rounds')
      .select('id, categories!inner(contest_id)')
      .eq('categories.contest_id', id)
      .eq('status', 'active')
      
    if (activeRounds && activeRounds.length > 0) {
      throw createError({ statusCode: 400, statusMessage: 'Cannot create a new dynamic round while another is active' })
    }
  }

  const { data, error } = await client.from('rounds').insert(body).select().single()
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
