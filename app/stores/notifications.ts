import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useNotificationsStore = defineStore('notifications', () => {
  const items = ref<any[]>([])
  const loaded = ref(false)

  async function fetch(): Promise<void> {
    // TODO: implement when /api/notifications endpoint exists
  }

  async function markRead(id: string): Promise<void> {
    const data = await ($fetch as any)(`/api/notifications/${id}`, { method: 'PATCH', body: { read: true } }) as any
    const idx = items.value.findIndex(i => i.id === id)
    if (idx !== -1) items.value[idx] = { ...items.value[idx], ...data }
  }

  async function markAllRead(): Promise<void> {
    for (const item of items.value) {
      if (!item.read) {
        const data = await ($fetch as any)(`/api/notifications/${item.id}`, { method: 'PATCH', body: { read: true } }) as any
        const idx = items.value.findIndex(i => i.id === item.id)
        if (idx !== -1) items.value[idx] = { ...items.value[idx], ...data }
      }
    }
  }

  function push(item: any): void {
    items.value.push(item)
  }

  return { items, loaded, fetch, markRead, markAllRead, push }
})
