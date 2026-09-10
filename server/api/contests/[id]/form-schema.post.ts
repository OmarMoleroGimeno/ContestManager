// server/api/contests/[id]/form-schema.post.ts
// Save/create form schema for a contest (organizers only)

import { defineEventHandler, createError, getRouterParam, readBody } from 'h3'
import { serverSupabaseAdmin, requireOrgOwnerOrMember, internalError } from '~~/server/utils/supabase'
import { FormSchemaBodySchema } from '~~/server/utils/schemas'
import type { FormField } from '~/types/inscription-form'

interface FormSchemaBody {
  fields: FormField[]
  isPublished?: boolean
}

export default defineEventHandler(async (event) => {
  const contestId = getRouterParam(event, 'id')
  if (!contestId) throw createError({ statusCode: 400, statusMessage: 'Missing contest ID' })

  // Auth gate — require org owner or contest member
  await requireOrgOwnerOrMember(event, contestId)

  const rawBody = await readBody(event)
  const parsedBody = FormSchemaBodySchema.safeParse(rawBody)
  if (!parsedBody.success) {
    throw createError({ statusCode: 400, statusMessage: 'Invalid fields', data: parsedBody.error.issues })
  }
  const body = { ...(rawBody as FormSchemaBody), fields: parsedBody.data.fields as FormField[] }

  const client = serverSupabaseAdmin()

  // Get current version
  const { data: currentSchema } = await client
    .from('inscription_form_schemas')
    .select('version')
    .eq('contest_id', contestId)
    .order('version', { ascending: false })
    .limit(1)
    .single()

  const newVersion = (currentSchema?.version || 0) + 1

  // Create new schema
  const { data, error } = await client
    .from('inscription_form_schemas')
    .insert({
      contest_id: contestId,
      version: newVersion,
      is_published: body.isPublished || false,
      schema_json: body.fields,
    })
    .select()
    .single()

  if (error) {
    throw internalError(event, error, 'inscription_form_schemas.insert')
  }

  return data
})
