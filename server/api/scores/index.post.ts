import { defineEventHandler, createError, readBody } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const body = await readBody(event)
  
  // Calculate weighted sum value based on criteria_scores
  // Body example: { round_id, participant_id, judge_id, criteria_scores: { "id": score, ... } }
  let value = 0
  if (body.criteria_scores) {
     const criteriaIds = Object.keys(body.criteria_scores)
     if (criteriaIds.length > 0) {
       const { data: criteria } = await client.from('score_criteria').select('id, weight').in('id', criteriaIds)
       if (criteria) {
         for (const crit of criteria) {
            value += (body.criteria_scores[crit.id] || 0) * Number(crit.weight)
         }
       }
     }
  }
  
  const { data, error } = await client.from('scores').insert({ ...body, value }).select().single()
  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
