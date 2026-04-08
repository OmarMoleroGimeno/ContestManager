import { defineEventHandler, createError, getRouterParam, readBody } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const categoryId = getRouterParam(event, 'id')
  const body = await readBody(event)
  
  // Ensure the body has the category_id
  const roundData = {
    ...body,
    category_id: categoryId
  }

  const { data, error } = await client.from('rounds').insert(roundData).select().single()
  
  if (error) {
    throw createError({
      statusCode: 500,
      statusMessage: error.message
    })
  }
  
  return data
})
