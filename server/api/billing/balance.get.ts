import { defineEventHandler, createError } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const user = event.context.user
  if (!user) throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
  const admin = serverSupabaseAdmin()

  const { data: org, error: orgErr } = await admin
    .from('organizations')
    .select('id, name, ticket_balance, activation_balance')
    .eq('owner_id', user.id)
    .maybeSingle()
  if (orgErr) throw createError({ statusCode: 500, statusMessage: orgErr.message })
  if (!org) throw createError({ statusCode: 404, statusMessage: 'organization_not_found' })

  const { data: tx, error: txErr } = await admin
    .from('billing_transactions')
    .select('id, entity, delta, reason, plan, amount_cents, balance_after, created_at, contest_id, participant_id')
    .eq('organization_id', org.id)
    .order('created_at', { ascending: false })
    .limit(100)
  if (txErr) throw createError({ statusCode: 500, statusMessage: txErr.message })

  return { organization: org, transactions: tx ?? [] }
})
