import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseAdmin()
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

  // 2. Get judges from contest_members (email + full_name stored directly)
  const { data: judgeMembers, error: judgesError } = await client
    .from('contest_members')
    .select('id, user_id, email, full_name')
    .eq('contest_id', contestId)
    .eq('role', 'judge')

  if (judgesError) throw createError({ statusCode: 500, statusMessage: judgesError.message })

  // 2b. Enrich with profile names for judges who have a user_id
  const userIds = (judgeMembers ?? []).filter(j => j.user_id).map(j => j.user_id as string)
  let profileMap: Record<string, string> = {}
  if (userIds.length > 0) {
    const { data: profiles } = await client
      .from('profiles')
      .select('id, full_name')
      .in('id', userIds)
    for (const p of profiles ?? []) {
      if (p.full_name) profileMap[p.id] = p.full_name
    }
  }

  const judges = (judgeMembers ?? []).map(j => ({
    id: j.id,
    user_id: j.user_id,
    name: (j.user_id && profileMap[j.user_id]) || j.full_name || j.email || `Juez`,
    email: j.email
  }))

  const judgeCount = judges.length

  // 3. Get all scores for the round
  const { data: scores, error: scoresError } = await client
    .from('scores')
    .select('participant_id, judge_id, value, notes, promote, submitted_at')
    .eq('round_id', roundId)

  if (scoresError) throw createError({ statusCode: 500, statusMessage: scoresError.message })

  // 4. Summarize per participant
  const summary: Record<string, { total: number; count: number; promotes: number; judgeScores: any[] }> = {}

  for (const s of scores ?? []) {
    if (!summary[s.participant_id]) {
      summary[s.participant_id] = { total: 0, count: 0, promotes: 0, judgeScores: [] }
    }
    const entry = summary[s.participant_id]!
    entry.total += Number(s.value)
    entry.count += 1
    if (s.promote) entry.promotes += 1
    entry.judgeScores.push({
      judge_id: s.judge_id,
      value: s.value,
      notes: s.notes,
      promote: s.promote ?? false,
      submitted_at: s.submitted_at
    })
  }

  const participant_summaries = Object.entries(summary).map(([participantId, val]) => ({
    participant_id: participantId,
    average: val.count > 0 ? val.total / val.count : 0,
    total: val.total,
    promotes: val.promotes,
    score_count: val.count,
    is_fully_scored: judgeCount > 0 ? val.count >= judgeCount : val.count > 0,
    missing_judges: Math.max(0, judgeCount - val.count),
    judge_details: val.judgeScores
  }))

  return {
    judges,
    participant_summaries,
    all_scored: participant_summaries.length > 0 && participant_summaries.every(r => r.is_fully_scored)
  }
})
