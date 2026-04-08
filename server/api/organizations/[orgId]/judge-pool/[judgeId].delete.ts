import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const organizationId = getRouterParam(event, 'orgId')
  const judgeId = getRouterParam(event, 'judgeId')

  if (!judgeId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Judge ID is required'
    })
  }

  const { error } = await client
    .from('judge_pool_members')
    .delete()
    .eq('id', judgeId)

  if (error) {
    throw createError({
      statusCode: 500,
      statusMessage: error.message
    })
  }

  return { success: true }
})
