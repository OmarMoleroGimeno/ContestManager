import { defineEventHandler, createError, getRouterParam, readBody } from 'h3'
import { serverSupabaseClient, serverSupabaseAdmin } from '~~/server/utils/supabase'
import { sendRankingPublishedEmail } from '~~/server/utils/email'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const admin = serverSupabaseAdmin()
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)

  if (!id) throw createError({ statusCode: 400, statusMessage: 'Missing ID' })

  // Read current state before update to detect is_published transition
  const { data: prev } = await client
    .from('rounds')
    .select('is_published, is_ranking, category_id')
    .eq('id', id)
    .single()

  const { data, error } = await client
    .from('rounds')
    .update(body)
    .eq('id', id)
    .select()
    .single()

  if (error) throw createError({ statusCode: 500, statusMessage: error.message })

  // Send ranking_published emails (fire-and-forget)
  if (!prev?.is_published && data.is_published && data.is_ranking) {
    const { data: catInfo } = await admin
      .from('categories')
      .select('name, contests(name, slug)')
      .eq('id', data.category_id)
      .single()

    const contestName = (catInfo as any)?.contests?.name ?? ''
    const contestSlug = (catInfo as any)?.contests?.slug ?? null
    const categoryName = catInfo?.name ?? ''

    const { data: participants } = await admin
      .from('participants')
      .select('email, first_name, name')
      .eq('category_id', data.category_id)
      .eq('status', 'active')
      .not('email', 'is', null)

    for (const p of participants ?? []) {
      if (!p.email) continue
      sendRankingPublishedEmail({
        to: p.email,
        first_name: p.first_name || p.name,
        contest_name: contestName,
        category_name: categoryName,
        contest_slug: contestSlug,
      }).catch(() => {})
    }
  }

  return data
})
