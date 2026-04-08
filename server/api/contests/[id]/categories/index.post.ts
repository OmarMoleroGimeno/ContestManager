import { defineEventHandler, createError, getRouterParam, readBody } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  
  const { data, error } = await client.from('categories').insert({ ...body, contest_id: id }).select().single()
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
