import { defineEventHandler, createError, getRouterParam, readBody } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseAdmin()
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)

  // If no user_id provided but email is given, look up the user in auth.users
  let userId = body.user_id ?? null
  if (!userId && body.email) {
    const { data: authUser } = await client.auth.admin.getUserByEmail(body.email)
    if (authUser?.user?.id) {
      userId = authUser.user.id
    }
  }

  const { data, error } = await client
    .from('contest_members')
    .insert({ ...body, contest_id: id, user_id: userId })
    .select()
    .single()

  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
