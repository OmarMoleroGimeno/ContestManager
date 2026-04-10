import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const user = event.context.user
  if (!user) throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })

  const slug = getRouterParam(event, 'slug')
  if (!slug) throw createError({ statusCode: 400, statusMessage: 'Missing slug' })

  const client = serverSupabaseAdmin()

  // Get the contest by slug
  const { data: contest, error: contestError } = await client
    .from('contests')
    .select('id, name, slug, description, type, status, starts_at, ends_at, settings, is_rounds_dynamic')
    .eq('slug', slug)
    .single()

  if (contestError || !contest) throw createError({ statusCode: 404, statusMessage: 'Contest not found' })

  // Get participant entries for this user in this contest
  const { data: participantEntries, error: pError } = await client
    .from('participants')
    .select(`
      id,
      name,
      status,
      category_id,
      categories!inner(id, name, description, status)
    `)
    .eq('contest_id', contest.id)
    .eq('user_id', user.id)

  if (pError) throw createError({ statusCode: 500, statusMessage: pError.message })

  // If user is not a participant, check if they're a judge/member
  // Try by user_id first, then by email (for legacy records added without user_id)
  let memberEntry: { id: string; role: string } | null = null
  const { data: memberByUserId } = await client
    .from('contest_members')
    .select('id, role')
    .eq('contest_id', contest.id)
    .eq('user_id', user.id)
    .maybeSingle()

  if (memberByUserId) {
    memberEntry = memberByUserId
  } else if (user.email) {
    const { data: memberByEmail } = await client
      .from('contest_members')
      .select('id, role')
      .eq('contest_id', contest.id)
      .eq('email', user.email)
      .is('user_id', null)
      .maybeSingle()
    memberEntry = memberByEmail ?? null
  }

  if (!participantEntries?.length && !memberEntry) {
    throw createError({ statusCode: 403, statusMessage: 'Not enrolled in this contest' })
  }

  // Get categories and rounds
  let categoryIds: string[] = []
  let categories: any[] = []

  if (memberEntry?.role === 'judge') {
    // Judges can see all categories in the contest
    const { data: contestCats } = await client
      .from('categories')
      .select('id, name, description, status')
      .eq('contest_id', contest.id)
    
    categories = contestCats ?? []
    categoryIds = categories.map((c: any) => c.id)
  } else {
    // Participants only see categories they are enrolled in
    categories = (participantEntries ?? []).map((p: any) => p.categories)
    categoryIds = categories.map((c: any) => c.id)
  }

  // Deduplicate categories
  const uniqueCategoriesMap = new Map()
  for (const c of categories) {
    if (c) uniqueCategoriesMap.set(c.id, c)
  }
  categories = Array.from(uniqueCategoriesMap.values())

  let rounds: any[] = []

  if (categoryIds.length > 0) {
    const { data: roundsData } = await client
      .from('rounds')
      .select('id, name, order, status, scoring_type, max_score, started_at, closed_at, category_id')
      .in('category_id', categoryIds)
      .order('order', { ascending: true })

    rounds = roundsData ?? []

    // For each round, check if the participant is enrolled and get their schedule
    const roundIds = rounds.map((r: any) => r.id)
    const participantIds = (participantEntries ?? []).map((p: any) => p.id)

    if (roundIds.length > 0 && participantIds.length > 0) {
      const { data: roundParticipants } = await client
        .from('round_participants')
        .select('round_id, participant_id, order, scheduled_at, location, is_qualified')
        .in('round_id', roundIds)
        .in('participant_id', participantIds)

      // Attach round_participant info to each round (will be null for judges)
      rounds = rounds.map((r: any) => ({
        ...r,
        my_slot: (roundParticipants ?? []).find(
          (rp: any) => rp.round_id === r.id && participantIds.includes(rp.participant_id)
        ) ?? null
      }))
    }
  }

  return {
    contest,
    participant: participantEntries ?? [],
    member: memberEntry ?? null,
    categories,
    rounds
  }
})
