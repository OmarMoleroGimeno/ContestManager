import { defineEventHandler, createError, getRouterParam } from 'h3'
import { serverSupabaseClient } from '~~/server/utils/supabase'

export default defineEventHandler(async (event) => {
  const client = serverSupabaseClient(event)
  const organizationId = getRouterParam(event, 'orgId')

  if (!organizationId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Organization ID is required'
    })
  }

  const { data, error } = await client
    .from('judge_pool_members')
    .select(`
      id,
      organization_id,
      created_at,
      judge:judges (
        id,
        full_name,
        email,
        specialty
      )
    `)
    .eq('organization_id', organizationId)
    .order('created_at', { ascending: false })

  if (error) {
    throw createError({
      statusCode: 500,
      statusMessage: error.message
    })
  }

  // Aplanamos la respuesta para que el frontend no tenga que cambiar
  return (data || []).map(item => {
    const j = Array.isArray(item.judge) ? item.judge[0] : item.judge
    return {
      id: item.id,
      organization_id: item.organization_id,
      created_at: item.created_at,
      judge_id: j?.id,
      full_name: (j as any)?.full_name,
      email: (j as any)?.email,
      specialty: (j as any)?.specialty
    }
  })
})
