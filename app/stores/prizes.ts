import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { Prize } from '~~/types'

export const usePrizesStore = defineStore('prizes', () => {
  const items = ref<Prize[]>([])

  function byCategory(categoryId: string) {
    return items.value.filter(i => i.category_id === categoryId)
  }

  async function create(payload: { category_id: string; description: string }): Promise<Prize> {
    const data = await ($fetch as any)('/api/prizes', { method: 'POST', body: payload }) as Prize
    items.value.push(data)
    return data
  }

  async function remove(id: string): Promise<void> {
    await ($fetch as any)(`/api/prizes/${id}`, { method: 'DELETE' })
    items.value = items.value.filter(i => i.id !== id)
  }

  return { items, create, remove, byCategory }
})
