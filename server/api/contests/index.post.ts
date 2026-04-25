import { defineEventHandler, createError, readBody } from 'h3'
import { serverSupabaseAdmin } from '~~/server/utils/supabase'
import type { Database, ContestFormPayload } from '~~/types'

export default defineEventHandler(async (event) => {
  const user = event.context.user
  if (!user) throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })

  const client = serverSupabaseAdmin()
  const body = await readBody<ContestFormPayload>(event)

  if (!body.name) throw createError({ statusCode: 400, statusMessage: "El nombre es obligatorio" })

  // Get the user's organization
  let { data: orgData, error: orgError } = await client
    .from('organizations')
    .select('id')
    .eq('owner_id', user.id)
    .limit(1)
    .single()

  if (!orgData) {
    // Dev fallback: create org if none exists
    const { data: newOrg, error: orgErr } = await client.from('organizations').insert({
      name: 'Default Org',
      slug: 'default-org-' + Date.now(),
      owner_id: user.id,
    }).select('id').single()

    if (orgErr) throw createError({ statusCode: 500, statusMessage: orgErr.message })
    orgData = newOrg
  }

  // Extraemos variables que necesitan mapeo personalizado
  const { short_description, prizes, rules, ...restBody } = body

  // Create slug from name, ensure unique within org
  const baseSlug = restBody.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
  let slug = baseSlug
  let suffix = 1
  while (true) {
    const { data: existing } = await client
      .from('contests')
      .select('id')
      .eq('slug', slug)
      .eq('organization_id', orgData!.id)
      .maybeSingle()
    if (!existing) break
    slug = `${baseSlug}-${++suffix}`
  }

  const { data, error } = await client.from('contests').insert({
    name: restBody.name,
    starts_at: restBody.starts_at || null,
    ends_at: restBody.ends_at || null,
    organization_id: orgData!.id,
    slug,
    description: short_description || null,
    settings: {
      prizes: prizes || null,
      rules: rules || null
    }
  }).select().single()

  if (error) throw createError({ statusCode: 500, statusMessage: error.message })
  return data
})
