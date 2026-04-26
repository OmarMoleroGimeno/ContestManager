import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useScoresStore = defineStore('scores', () => {
  const summaries = ref<Record<string, any>>({})
  const fetchedRounds = ref(new Set<string>())

  function invalidateSummary(roundId: string) {
    fetchedRounds.value.delete(roundId)
  }

  async function fetchSummary(roundId: string): Promise<any> {
    if (fetchedRounds.value.has(roundId)) return summaries.value[roundId]
    const data = await ($fetch as any)(`/api/rounds/${roundId}/scores/summary`) as any
    summaries.value[roundId] = data
    fetchedRounds.value.add(roundId)
    return summaries.value[roundId]
  }

  async function upsertScore(payload: { round_id: string; participant_id: string; judge_id: string; value: number; notes?: string; promote?: boolean }): Promise<any> {
    const data = await ($fetch as any)('/api/scores', { method: 'POST', body: payload }) as any
    invalidateSummary(payload.round_id)
    return data
  }

  return { summaries, fetchedRounds, fetchSummary, invalidateSummary, upsertScore }
})
