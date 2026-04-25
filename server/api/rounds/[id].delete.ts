import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseAdmin()
  const id = getRouterParam(event, 'id')
  if (!id) throw createError({ statusCode: 400, statusMessage: 'Missing ID' })

  // Fetch round to delete
  const { data: target, error: tErr } = await client
    .from('rounds')
    .select('id, category_id, order, is_ranking')
    .eq('id', id)
    .single()
  if (tErr || !target) throw createError({ statusCode: 404, statusMessage: 'Round not found' })

  // Max order in category
  const { data: siblings, error: sErr } = await client
    .from('rounds')
    .select('id, order, status')
    .eq('category_id', target.category_id)
    .order('order', { ascending: false })
  if (sErr) throw createError({ statusCode: 500, statusMessage: sErr.message })

  const list = siblings || []
  const maxOrder = list[0]?.order ?? target.order
  if (target.order !== maxOrder) {
    throw createError({ statusCode: 400, statusMessage: 'Solo se puede eliminar la ronda más reciente' })
  }

  // Delete (FKs cascade: scores, round_participants, etc.)
  const { error: dErr } = await client.from('rounds').delete().eq('id', id)
  if (dErr) throw createError({ statusCode: 500, statusMessage: dErr.message })

  // Previous round becomes active (clear is_final too — user reopening final round)
  const prev = list.find(r => r.id !== id)
  if (prev) {
    const { error: uErr } = await client
      .from('rounds')
      .update({ status: 'active', closed_at: null, is_final: false })
      .eq('id', prev.id)
    if (uErr) throw createError({ statusCode: 500, statusMessage: uErr.message })
  }

  // If deleted round was ranking, reopen category
  let categoryReopened = false
  if ((target as any).is_ranking) {
    const { error: cErr } = await client
      .from('categories')
      .update({ status: 'active' })
      .eq('id', target.category_id)
    if (!cErr) categoryReopened = true
  }

  return { deleted: id, reactivated: prev?.id ?? null, categoryReopened }
})
