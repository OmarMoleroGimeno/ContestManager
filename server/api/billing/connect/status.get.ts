import { defineEventHandler, createError } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'
import { getStripe } from '~~/server/utils/stripe'

export default defineEventHandler(async (event) => {
  const user = event.context.user
  if (!user) throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })

  const admin = serverSupabaseAdmin()
  const { data: org, error: orgErr } = await admin
    .from('organizations')
    .select('id, stripe_account_id, stripe_onboarding_done, stripe_charges_enabled, stripe_payouts_enabled')
    .eq('owner_id', user.id)
    .maybeSingle()
  if (orgErr) throw createError({ statusCode: 500, statusMessage: orgErr.message })
  if (!org) throw createError({ statusCode: 404, statusMessage: 'organization_not_found' })

  if (!org.stripe_account_id) {
    return {
      connected: false,
      onboarding_done: false,
      charges_enabled: false,
      payouts_enabled: false,
    }
  }

  const stripe = getStripe()
  const acc = await stripe.accounts.retrieve(org.stripe_account_id)
  const done    = !!acc.details_submitted
  const charges = !!acc.charges_enabled
  const payouts = !!acc.payouts_enabled

  // Sync DB
  if (
    done !== org.stripe_onboarding_done ||
    charges !== org.stripe_charges_enabled ||
    payouts !== org.stripe_payouts_enabled
  ) {
    await admin.from('organizations').update({
      stripe_onboarding_done: done,
      stripe_charges_enabled: charges,
      stripe_payouts_enabled: payouts,
    }).eq('id', org.id)
  }

  return {
    connected: true,
    onboarding_done: done,
    charges_enabled: charges,
    payouts_enabled: payouts,
    account_id: org.stripe_account_id,
  }
})
