import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const roundId = getRouterParam(event, 'id')
  
  if (!roundId) throw createError({ statusCode: 400, statusMessage: 'Missing Round ID' })

  // 1. Get round info to find contest_id
  const { data: roundData, error: roundError } = await client
    .from('rounds')
    .select('category_id, categories!inner(contest_id)')
    .eq('id', roundId)
    .single()
    
  if (roundError || !roundData) throw createError({ statusCode: 404, statusMessage: 'Round not found' })
  const contestId = (roundData.categories as any).contest_id

  // 2. Get judges with profile info
  const { data: judges, error: judgesError } = await client
    .from('contest_members')
    .select('id, user_id, profile:profiles(full_name, email)')
    .eq('contest_id', contestId)
    .eq('role', 'judge')
    
  if (judgesError) throw createError({ statusCode: 500, statusMessage: 'Error fetching judges' })
  const judgeCount = judges?.length || 0

  // 3. Get all scores for the round with details
  const { data: scores, error: scoresError } = await client
    .from('scores')
    .select('participant_id, judge_id, value, notes, criteria_scores, submitted_at')
    .eq('round_id', roundId)
    
  if (scoresError) throw createError({ statusCode: 500, statusMessage: scoresError.message })

  // 4. Summarize
  const summary: Record<string, { total: number, count: number, judgeScores: any[] }> = {}
  
  scores?.forEach(s => {
    if (!summary[s.participant_id]) {
      summary[s.participant_id] = { total: 0, count: 0, judgeScores: [] }
    }
    const entry = summary[s.participant_id]!
    entry.total += s.value
    entry.count += 1
    entry.judgeScores.push({
      judge_id: s.judge_id,
      value: s.value,
      notes: s.notes,
      criteria_scores: s.criteria_scores,
      submitted_at: s.submitted_at
    })
  })

  const result = Object.entries(summary).map(([participantId, val]) => ({
    participant_id: participantId,
    average: val.count > 0 ? val.total / val.count : 0,
    total: val.total,
    score_count: val.count,
    is_fully_scored: judgeCount > 0 ? val.judgeScores.length >= judgeCount : true,
    missing_judges: Math.max(0, judgeCount - val.judgeScores.length),
    judge_details: val.judgeScores
  }))

  return {
    judges: judges?.map(j => ({
      id: j.id,
      user_id: j.user_id,
      name: (j.profile as any)?.full_name || `Juez ${j.user_id.substring(0, 4)}`,
      email: (j.profile as any)?.email
    })),
    participant_summaries: result,
    all_scored: result.length > 0 && result.every(r => r.is_fully_scored)
  }
})
