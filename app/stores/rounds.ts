import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { Round } from '~~/types'
import { apiClient } from '~/api/apiClient'

export const useRoundsStore = defineStore('rounds', () => {
  const items = ref<Round[]>([])
  const fetched = ref(new Set<string>())
  const contestRoundIds = ref<Record<string, string[]>>({})

  function byContest(contestId: string) {
    const ids = contestRoundIds.value[contestId] || []
    return items.value.filter(i => ids.includes(i.id))
  }

  function byCategory(categoryId: string) {
    return items.value.filter(i => i.category_id === categoryId)
  }

  function _merge(data: Round[]) {
    for (const item of data) {
      const idx = items.value.findIndex(i => i.id === item.id)
      if (idx !== -1) items.value[idx] = item
      else items.value.push(item)
    }
  }

  function invalidate(ctxId?: string) {
    if (ctxId) {
      fetched.value.delete(ctxId)
      delete contestRoundIds.value[ctxId]
    } else {
      fetched.value.clear()
      contestRoundIds.value = {}
    }
  }

  async function fetch(contestId: string): Promise<Round[]> {
    if (fetched.value.has(contestId)) return byContest(contestId)
    const data = await apiClient<Round[]>(`/api/contests/${contestId}/rounds`)
    _merge(data || [])
    contestRoundIds.value[contestId] = (data || []).map(r => r.id)
    fetched.value.add(contestId)
    return byContest(contestId)
  }

  async function update(id: string, payload: any): Promise<Round> {
    const data = await apiClient<Round>(`/api/rounds/${id}`, { method: 'PATCH', body: payload })
    const idx = items.value.findIndex(i => i.id === id)
    if (idx !== -1) items.value[idx] = { ...items.value[idx], ...data }
    return data
  }

  async function startRound(id: string): Promise<Round> {
    return update(id, { status: 'active', started_at: new Date().toISOString() })
  }

  async function createForCategory(categoryId: string, payload: any): Promise<Round> {
    const data = await apiClient<Round>(`/api/categories/${categoryId}/rounds`, { method: 'POST', body: payload })
    items.value.push(data)
    return data
  }

  async function remove(id: string): Promise<{ deleted: string; reactivated: string | null }> {
    const res = await apiClient<{ deleted: string; reactivated: string | null }>(`/api/rounds/${id}`, { method: 'DELETE' })
    items.value = items.value.filter(i => i.id !== id)
    if (res?.reactivated) {
      const idx = items.value.findIndex(i => i.id === res.reactivated)
      if (idx !== -1) items.value[idx] = { ...items.value[idx], status: 'active', closed_at: null } as Round
    }
    return res
  }

  return { items, fetched, contestRoundIds, fetch, update, startRound, createForCategory, remove, byContest, byCategory, invalidate }
})
