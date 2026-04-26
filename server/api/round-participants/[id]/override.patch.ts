import { defineEventHandler, createError, getRouterParam, readBody } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseAdmin()
  const id = getRouterParam(event, 'id')
  if (!id) throw createError({ statusCode: 400, statusMessage: 'Missing ID' })

  const body = await readBody(event)
  const { final_score_override, final_score_override_notes, admin_user_id, admin_user_name } = body

  if (!admin_user_id) throw createError({ statusCode: 400, statusMessage: 'admin_user_id required' })

  // Read existing for audit
  const { data: existing } = await client
    .from('round_participants')
    .select('final_score_override, round_id, participant_id')
    .eq('id', id)
    .single()

  if (!existing) throw createError({ statusCode: 404, statusMessage: 'Round participant not found' })

  const isRemoving = final_score_override === null || final_score_override === undefined

  const { data, error } = await client
    .from('round_participants')
    .update({
      final_score_override: isRemoving ? null : Number(final_score_override),
      final_score_override_by: isRemoving ? null : admin_user_id,
      final_score_override_at: isRemoving ? null : new Date().toISOString(),
      final_score_override_notes: isRemoving ? null : (final_score_override_notes ?? null),
    })
    .eq('id', id)
    .select()
    .single()

  if (error) throw createError({ statusCode: 500, statusMessage: error.message })

  // Audit log
  await client.from('score_audit_logs').insert({
    round_id: existing.round_id,
    participant_id: existing.participant_id,
    judge_id: null,
    changed_by: admin_user_id,
    changed_by_name: admin_user_name ?? null,
    action: isRemoving ? 'override_removed' : 'override_set',
    old_value: existing.final_score_override ? Number(existing.final_score_override) : null,
    new_value: isRemoving ? null : Number(final_score_override),
    notes: final_score_override_notes ?? null,
    is_admin_action: true,
  })

  return data
})
