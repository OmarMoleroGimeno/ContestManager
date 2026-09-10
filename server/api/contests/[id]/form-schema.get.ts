// server/api/contests/[id]/form-schema.get.ts
// Get form schema for a contest (organizers only)

import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseAdmin, requireOrgOwnerOrMember, internalError } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const contestId = getRouterParam(event, 'id')
  if (!contestId) throw createError({ statusCode: 400, statusMessage: 'Missing contest ID' })

  // Auth gate — require org owner or contest member
  await requireOrgOwnerOrMember(event, contestId)

  const client = serverSupabaseAdmin()

  // Get latest schema (published or draft)
  const { data, error } = await client
    .from('inscription_form_schemas')
    .select('*')
    .eq('contest_id', contestId)
    .order('version', { ascending: false })
    .limit(1)
    .single()

  if (error && error.code !== 'PGRST116') { // PGRST116 = not found
    throw internalError(event, error, 'inscription_form_schemas.select')
  }

  return data || null
})
