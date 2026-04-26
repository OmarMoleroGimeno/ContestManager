import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { Category } from '~~/types'
import { apiClient } from '~/api/apiClient'

export const useCategoriesStore = defineStore('categories', () => {
  const items = ref<Category[]>([])
  const fetched = ref(new Set<string>())

  function byContest(contestId: string) {
    return items.value.filter(i => i.contest_id === contestId)
  }

  function _merge(data: Category[]) {
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

  async function fetch(contestId: string): Promise<Category[]> {
    if (fetched.value.has(contestId)) return byContest(contestId)
    const data = await apiClient<Category[]>(`/api/contests/${contestId}/categories`)
    _merge(data || [])
    fetched.value.add(contestId)
    return byContest(contestId)
  }

  async function create(contestId: string, payload: any): Promise<Category> {
    const data = await apiClient<Category>(`/api/contests/${contestId}/categories`, { method: 'POST', body: payload })
    items.value.push(data)
    return data
  }

  async function update(id: string, payload: any): Promise<Category> {
    const data = await apiClient<Category>(`/api/categories/${id}`, { method: 'PATCH', body: payload })
    const idx = items.value.findIndex(i => i.id === id)
    if (idx !== -1) items.value[idx] = { ...items.value[idx], ...data }
    return data
  }

  async function remove(id: string): Promise<void> {
    await apiClient(`/api/categories/${id}`, { method: 'DELETE' })
    items.value = items.value.filter(i => i.id !== id)
  }

  return { items, fetched, fetch, create, update, remove, byContest, invalidate }
})
