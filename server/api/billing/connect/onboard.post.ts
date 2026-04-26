import { defineEventHandler, createError } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'
import { getStripe } from '~~/server/utils/stripe'

export default defineEventHandler(async (event) => {
  const user = event.context.user
  if (!user) throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })

  const admin = serverSupabaseAdmin()
  const { data: org, error: orgErr } = await admin
    .from('organizations')
    .select('id, name, stripe_account_id')
    .eq('owner_id', user.id)
    .maybeSingle()
  if (orgErr) throw createError({ statusCode: 500, statusMessage: orgErr.message })
  if (!org) throw createError({ statusCode: 404, statusMessage: 'organization_not_found' })

  const config = useRuntimeConfig()
  const baseUrl = config.appBaseUrl || 'http://localhost:3000'
  const stripe = getStripe()

  let accountId = org.stripe_account_id
  if (!accountId) {
    const account = await stripe.accounts.create({
      type: 'express',
      email: user.email ?? undefined,
      business_profile: { name: org.name },
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
      metadata: { organization_id: org.id },
    })
    accountId = account.id
    const { error: upErr } = await admin
      .from('organizations')
      .update({ stripe_account_id: accountId })
      .eq('id', org.id)
    if (upErr) throw createError({ statusCode: 500, statusMessage: upErr.message })
  }

  const link = await stripe.accountLinks.create({
    account: accountId,
    refresh_url: `${baseUrl}/billing?connect=refresh`,
    return_url:  `${baseUrl}/billing?connect=return`,
    type: 'account_onboarding',
  })

  return { url: link.url }
})
