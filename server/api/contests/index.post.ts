import { defineEventHandler, createError, readBody } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'
import type { Database, ContestFormPayload } from '~~/types'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const body = await readBody<ContestFormPayload>(event)
  
  if (!body.name) throw createError({ statusCode: 400, statusMessage: "El nombre es obligatorio" })

  // Buscar primero la organización por defecto del usuario (o crear si no la hay para dev)
  let { data: orgData } = await client.from('organizations').select('id').limit(1).single()
  
  if (!orgData) {
    // Modo de desarrollo: autogenerar org si está vacío
    const { data: newOrg, error: orgErr } = await client.from('organizations').insert({ 
      name: 'Default Org',
      slug: 'default-org-' + Date.now()
    }).select('id').single()
    
    if (orgErr) throw createError({ statusCode: 500, statusMessage: orgErr.message })
    orgData = newOrg
  }

  // Extraemos variables que necesitan mapeo personalizado
  const { short_description, prizes, rules, ...restBody } = body

  // Create slug from name
  const slug = restBody.name.toLowerCase().replace(/[^a-z0-9]+/g, '-')

  const { data, error } = await client.from('contests').insert({
    name: restBody.name,
    starts_at: restBody.starts_at || null,
    ends_at: restBody.ends_at || null,
    organization_id: orgData.id,
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
