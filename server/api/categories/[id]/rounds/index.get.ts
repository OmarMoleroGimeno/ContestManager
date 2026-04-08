import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const categoryId = getRouterParam(event, 'id')
  
  const { data, error } = await client.from('rounds')
    .select('*')
    .eq('category_id', categoryId)
    .order('order', { ascending: true })
    
  if (error) {
    throw createError({
      statusCode: 500,
      statusMessage: error.message
    })
  }
  
  return data
})
