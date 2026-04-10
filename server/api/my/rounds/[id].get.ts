import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const user = event.context.user
  if (!user) throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })

  const roundId = getRouterParam(event, 'id')
  if (!roundId) throw createError({ statusCode: 400, statusMessage: 'Missing round id' })

  const client = serverSupabaseAdmin()

  // Get the round with its category and contest
  const { data: round, error: roundError } = await client
    .from('rounds')
    .select(`
      id, name, order, status, scoring_type, max_score, started_at, closed_at, category_id,
      categories!inner(
        id, name, description, contest_id,
        contests!inner(id, name, slug, description, type, status, starts_at, ends_at)
      )
    `)
    .eq('id', roundId)
    .single()

  if (roundError || !round) throw createError({ statusCode: 404, statusMessage: 'Round not found' })

  const category = (round as any).categories
  const contest = category.contests

  // Find the participant record for this user in this contest/category
  const { data: myParticipant, error: pError } = await client
    .from('participants')
    .select('id, name, status')
    .eq('user_id', user.id)
    .eq('contest_id', contest.id)
    .eq('category_id', category.id)
    .maybeSingle()

  if (pError) throw createError({ statusCode: 500, statusMessage: pError.message })
  
  let isJudge = false
  if (!myParticipant) {
    // Try by user_id first, then by email (for records added without user_id)
    const { data: memberByUserId } = await client
      .from('contest_members')
      .select('id, role')
      .eq('contest_id', contest.id)
      .eq('user_id', user.id)
      .eq('role', 'judge')
      .maybeSingle()

    if (memberByUserId) {
      isJudge = true
    } else if (user.email) {
      const { data: memberByEmail } = await client
        .from('contest_members')
        .select('id, role')
        .eq('contest_id', contest.id)
        .eq('email', user.email)
        .eq('role', 'judge')
        .is('user_id', null)
        .maybeSingle()
      if (memberByEmail) isJudge = true
    }

    if (!isJudge) throw createError({ statusCode: 403, statusMessage: 'Not a participant or judge in this round' })
  }

  // Get my slot in the round
  let mySlot = null
  if (myParticipant) {
    const { data } = await client
      .from('round_participants')
      .select('id, order, scheduled_at, location, is_qualified')
      .eq('round_id', roundId)
      .eq('participant_id', myParticipant.id)
      .maybeSingle()
      
    mySlot = data
  }

  // Get all participants in this round (public info — name and slot only)
  const { data: allSlots } = await client
    .from('round_participants')
    .select(`
      id, participant_id, order, scheduled_at, location, is_qualified,
      participants!inner(id, name, first_name, last_name, country)
    `)
    .eq('round_id', roundId)
    .order('order', { ascending: true })

  // Get my scores if round is closed or active
  let myScores: any[] = []
  if (myParticipant) {
    const { data } = await client
      .from('scores')
      .select('id, value, criteria_scores, notes, submitted_at, judge_id')
      .eq('round_id', roundId)
      .eq('participant_id', myParticipant.id)
    myScores = data ?? []
  } else if (isJudge) {
    const { data } = await client
      .from('scores')
      .select('id, participant_id, value, criteria_scores, notes, submitted_at')
      .eq('round_id', roundId)
      .eq('judge_id', user.id)
    myScores = data ?? []
  }

  // Get score criteria for this round
  const { data: criteria } = await client
    .from('score_criteria')
    .select('id, name, weight, max_value, order')
    .eq('round_id', roundId)
    .order('order', { ascending: true })

  // Compute average score if any scores exist
  const avgScore = myScores?.length
    ? myScores.reduce((sum: number, s: any) => sum + s.value, 0) / myScores.length
    : null

  return {
    round: {
      ...round,
      categories: undefined,
    },
    category: {
      id: category.id,
      name: category.name,
      description: category.description,
    },
    contest,
    myParticipant: myParticipant ?? null,
    isJudge,
    mySlot: mySlot ?? null,
    allSlots: allSlots ?? [],
    myScores: myScores ?? [],
    criteria: criteria ?? [],
    avgScore
  }
})
