import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const memberId = getRouterParam(event, 'memberId')
  
  const { error } = await client.from('contest_members').delete().eq('id', memberId)
  
  if (error) {
    throw createError({
      statusCode: 500,
      statusMessage: error.message
    })
  }
  
  return { success: true }
})
