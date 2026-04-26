import { defineEventHandler, createError, getRouterParam, readBody } from 'h3'
import { serverSupabaseClient, serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const user = event.context.user
  if (!user) throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })

  const client = serverSupabaseClient(event)
  const admin  = serverSupabaseAdmin()
  const id = getRouterParam(event, 'id')
  if (!id) throw createError({ statusCode: 400, statusMessage: 'Missing ID' })

  // Block edit if parent contest is active or terminal
  const { data: row } = await admin
    .from('participants')
    .select('contests:contest_id(status)')
    .eq('id', id)
    .single() as any
  const status = row?.contests?.status
  if (status && ['active','finished','cancelled'].includes(status)) {
    throw createError({ statusCode: 409, statusMessage: 'El concurso ya está en curso. No se pueden gestionar inscripciones.' })
  }

  const body = await readBody(event)
  const { data, error } = await client
    .from('participants').update(body).eq('id', id).select().single()
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
