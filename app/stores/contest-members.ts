import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { ContestMember } from '~~/types'
import { apiClient } from '~/api/apiClient'

export const useContestMembersStore = defineStore('contest-members', () => {
  const items = ref<ContestMember[]>([])
  const fetched = ref(new Set<string>())

  function byContest(contestId: string) {
    return items.value.filter(i => i.contest_id === contestId)
  }

  function _merge(data: ContestMember[]) {
    for (const item of data) {
      const idx = items.value.findIndex(i => i.id === item.id)
      if (idx !== -1) items.value[idx] = item
      else items.value.push(item)
    }
  }

  function invalidate(ctxId?: string) {
    if (ctxId) fetched.value.delete(ctxId)
    else fetched.value.clear()
  }

  async function fetch(contestId: string): Promise<ContestMember[]> {
    if (fetched.value.has(contestId)) return byContest(contestId)
    const data = await apiClient<ContestMember[]>(`/api/contests/${contestId}/members`)
    _merge(data || [])
    fetched.value.add(contestId)
    return byContest(contestId)
  }

  async function fetchFresh(contestId: string): Promise<ContestMember[]> {
    invalidate(contestId)
    return fetch(contestId)
  }

  async function create(contestId: string, payload: any): Promise<ContestMember> {
    const data = await apiClient<ContestMember>(`/api/contests/${contestId}/members`, { method: 'POST', body: payload })
    items.value.push(data)
    return data
  }

  async function remove(contestId: string, memberId: string): Promise<void> {
    await apiClient(`/api/contests/${contestId}/members/${memberId}`, { method: 'DELETE' })
    items.value = items.value.filter(i => i.id !== memberId)
  }

  return { items, fetched, fetch, create, remove, byContest, invalidate }
})
