import { defineEventHandler, createError } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const user = event.context.user
  if (!user) throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })

  const client = serverSupabaseAdmin()

  // Contests where user is a participant
  const { data: participantContests, error: pError } = await client
    .from('participants')
    .select(`
      contest_id,
      category_id,
      name,
      status,
      categories!inner(name),
      contests!inner(id, name, slug, description, type, status, starts_at, ends_at, organization_id)
    `)
    .eq('user_id', user.id)

  if (pError) throw createError({ statusCode: 500, statusMessage: pError.message })

  // Contests where user is a judge — match by user_id OR email (for legacy records without user_id)
  const { data: judgeContests, error: jError } = await client
    .from('contest_members')
    .select(`
      contest_id,
      role,
      contests!inner(id, name, slug, description, type, status, starts_at, ends_at, organization_id)
    `)
    .or(`user_id.eq.${user.id},email.eq.${user.email}`)
    .eq('role', 'judge')

  if (jError) throw createError({ statusCode: 500, statusMessage: jError.message })

  return {
    asParticipant: participantContests ?? [],
    asJudge: judgeContests ?? []
  }
})
