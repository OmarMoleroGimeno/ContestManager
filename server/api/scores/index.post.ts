import { defineEventHandler, createError, readBody } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseAdmin()
  const body = await readBody(event)

  const { round_id, participant_id, judge_id, value, notes, promote } = body

  if (!round_id || !participant_id || !judge_id) {
    throw createError({ statusCode: 400, statusMessage: 'round_id, participant_id and judge_id are required' })
  }

  if (value === undefined || value === null || isNaN(Number(value))) {
    throw createError({ statusCode: 400, statusMessage: 'value is required and must be a number' })
  }

  // Check if score already exists for this judge/participant/round (upsert)
  const { data, error } = await client
    .from('scores')
    .upsert(
      {
        round_id,
        participant_id,
        judge_id,
        value: Number(value),
        notes: notes ?? null,
        promote: promote ?? false,
        submitted_at: new Date().toISOString()
      },
      { onConflict: 'round_id,participant_id,judge_id' }
    )
    .select()
    .single()

  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
