import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const token = getRouterParam(event, 'token')
  if (!token) throw createError({ statusCode: 400, statusMessage: 'Missing token' })

  const client = serverSupabaseAdmin()

  const [contestRes, categoriesRes] = await Promise.all([
    client.rpc('get_contest_by_token', { p_token: token }),
    client.rpc('get_categories_for_token', { p_token: token }),
  ])

  if (contestRes.error) throw createError({ statusCode: 500, statusMessage: contestRes.error.message })
  const contest = (contestRes.data as any[])?.[0]
  if (!contest) throw createError({ statusCode: 404, statusMessage: 'Contest not found' })

  if (categoriesRes.error) throw createError({ statusCode: 500, statusMessage: categoriesRes.error.message })

  return {
    contest,
    categories: categoriesRes.data ?? [],
  }
})
