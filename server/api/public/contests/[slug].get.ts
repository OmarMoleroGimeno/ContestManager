import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const slug = getRouterParam(event, 'slug')
  if (!slug) throw createError({ statusCode: 400, statusMessage: 'Missing slug' })

  const client = serverSupabaseAdmin()
  const [contestRes, categoriesRes] = await Promise.all([
    client.rpc('get_public_contest_by_slug', { p_slug: slug }),
    client.rpc('get_public_categories_by_slug', { p_slug: slug }),
  ])

  if (contestRes.error) throw createError({ statusCode: 500, statusMessage: contestRes.error.message })
  const contest = (contestRes.data as any[])?.[0]
  if (!contest) throw createError({ statusCode: 404, statusMessage: 'Concurso no encontrado' })

  if (categoriesRes.error) throw createError({ statusCode: 500, statusMessage: categoriesRes.error.message })

  return { contest, categories: categoriesRes.data ?? [] }
})
