import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useRoundParticipantsStore = defineStore('round-participants', () => {
  const byRound = ref<Record<string, any[]>>({})
  const fetched = ref(new Set<string>())

  function invalidate(roundId?: string) {
    if (roundId) {
      fetched.value.delete(roundId)
      delete byRound.value[roundId]
    } else {
      fetched.value.clear()
      byRound.value = {}
    }
  }

  async function fetch(roundId: string): Promise<any[]> {
    if (fetched.value.has(roundId)) return byRound.value[roundId] || []
    const data = await ($fetch as any)(`/api/rounds/${roundId}/participants`) as any[]
    byRound.value[roundId] = data || []
    fetched.value.add(roundId)
    return byRound.value[roundId]
  }

  async function update(id: string, payload: any): Promise<any> {
    const data = await ($fetch as any)(`/api/round-participants/${id}`, { method: 'PATCH', body: payload }) as any
    for (const roundId of Object.keys(byRound.value)) {
      const arr = byRound.value[roundId]
      const idx = arr.findIndex((rp: any) => rp.id === id)
      if (idx !== -1) {
        byRound.value[roundId][idx] = { ...byRound.value[roundId][idx], ...data }
      }
    }
    return data
  }

  return { byRound, fetched, fetch, update, invalidate }
})
