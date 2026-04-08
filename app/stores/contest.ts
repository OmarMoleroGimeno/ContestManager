import { defineStore } from 'pinia'
import { ref } from 'vue'
import { contestsApi } from '../api/modules/ContestsApi'
import { organizationsApi } from '../api/modules/OrganizationsApi'
import type { Contest, Category, Round, Participant, ContestFormPayload, Prize, Rehearsal, ContestMember, JudgePoolMember } from '~~/types'

export const useContestStore = defineStore('contest', () => {
  const contests = ref<Contest[]>([])
  const currentContest = ref<Contest | null>(null)
  const categories = ref<Category[]>([])
  const rounds = ref<Round[]>([])
  const participants = ref<Participant[]>([])
  const members = ref<ContestMember[]>([])
  const judgePool = ref<JudgePoolMember[]>([])
  const roundParticipantsMap = ref<Record<string, any[]>>({})
  const roundSummariesMap = ref<Record<string, any>>({})
  const prizes = ref<Prize[]>([])
  const rehearsals = ref<Rehearsal[]>([])

  const fetchContests = async () => {
    try {
      const data = await contestsApi.fetchContests()
      contests.value = data || []
      return data
    } catch (e) {
      console.error("Error fetching contests", e)
    }
  }

  const fetchContest = async (slug: string) => {
    try {
      const contestData = await ($fetch as any)(`/api/contests/${slug}`) as Contest
      currentContest.value = contestData
      
      if (currentContest.value?.id) {
        const [cats, rnds, parts, mems] = await Promise.all([
          ($fetch as any)(`/api/contests/${currentContest.value.id}/categories`),
          ($fetch as any)(`/api/contests/${currentContest.value.id}/rounds`),
          ($fetch as any)(`/api/contests/${currentContest.value.id}/participants`),
          ($fetch as any)(`/api/contests/${currentContest.value.id}/members`)
        ])
        
        categories.value = cats || []
        rounds.value = rnds || []
        participants.value = parts || []
        members.value = mems || []
      }
    } catch (e) {
      console.error("Error fetching contest data", e)
    }
  }

  const createContest = async (payload: ContestFormPayload) => {
    try {
      const data = await contestsApi.createContest(payload)
      if (data) {
        currentContest.value = data
        contests.value.push(data)
        return data
      }
      throw new Error('No data returned')
    } catch (e) {
      console.error("Error creating contest", e)
      throw e
    }
  }

  const createCategory = async (name: string, extra: Partial<Category> = {}) => {
    if (!currentContest.value?.id) return
    try {
      const data = await ($fetch as any)(`/api/contests/${currentContest.value.id}/categories`, {
        method: 'POST',
        body: { name, ...extra, contest_id: currentContest.value.id }
      })
      if (data) {
        // Refresh categories
        const cats = await ($fetch as any)(`/api/contests/${currentContest.value.id}/categories`) as Category[]
        categories.value = cats || []
        return data
      }
    } catch (e) {
      console.error("Error creating category", e)
      throw e
    }
  }

  const updateContest = async (payload: Partial<Contest>) => {
    if (!currentContest.value?.slug) return
    try {
      const data = await $fetch(`/api/contests/${currentContest.value.slug}` as string, {
        method: 'PATCH',
        body: payload
      })
      if (data) {
        const updated = { ...currentContest.value, ...data } as Contest
        currentContest.value = updated
        
        // Update in list if exists
        const index = contests.value.findIndex(c => c.id === updated.id)
        if (index !== -1) {
          contests.value[index] = updated
        }
        return data
      }
    } catch (e) {
      console.error("Error updating contest", e)
      throw e
    }
  }

  const addParticipant = async (payload: Partial<Participant>) => {
    if (!currentContest.value?.id) return
    try {
      const data = await $fetch(`/api/contests/${currentContest.value.id}/participants` as any, {
        method: 'POST',
        body: { ...payload, contest_id: currentContest.value.id, status: 'active' }
      })
      if (data) {
        // Refresh participants
        const parts = await ($fetch as any)(`/api/contests/${currentContest.value.id}/participants`) as Participant[]
        participants.value = parts || []
        return data
      }
    } catch (e) {
      console.error("Error adding participant", e)
      throw e
    }
  }

  const updateCategory = async (id: string, payload: Partial<Category>) => {
    try {
      const data = await $fetch(`/api/categories/${id}` as any, {
        method: 'PATCH',
        body: payload
      })
      if (data) {
        const index = categories.value.findIndex(c => c.id === id)
        if (index !== -1) categories.value[index] = { ...categories.value[index], ...data } as Category
        return data
      }
    } catch (e) {
      console.error("Error updating category", e)
      throw e
    }
  }

  const updateParticipant = async (id: string, payload: Partial<Participant>) => {
    try {
      const data = await $fetch(`/api/participants/${id}` as any, {
        method: 'PATCH',
        body: payload
      })
      if (data) {
        const index = participants.value.findIndex(p => p.id === id)
        if (index !== -1) participants.value[index] = { ...participants.value[index], ...data } as Participant
        return data
      }
    } catch (e) {
      console.error("Error updating participant", e)
      throw e
    }
  }

  const addPrize = async (payload: { category_id: string, description: string }) => {
    try {
      const data = await $fetch('/api/prizes' as any, {
        method: 'POST',
        body: payload
      })
      if (data) {
        prizes.value.push(data as Prize)
        return data
      }
    } catch (e) {
      console.error("Error adding prize", e)
      throw e
    }
  }

  const updateRoundParticipant = async (roundId: string, participantId: string, payload: { scheduled_at?: string, location?: string, order?: number }) => {
    try {
      const data = await $fetch(`/api/rounds/${roundId}/participants/${participantId}` as any, {
        method: 'PATCH',
        body: payload
      })
      return data
    } catch (e) {
      console.error("Error updating round participant", e)
      throw e
    }
  }

  const fetchRoundParticipants = async (roundId: string) => {
    try {
      const data = await $fetch(`/api/rounds/${roundId}/participants` as any)
      roundParticipantsMap.value[roundId] = data as any[]
      return data
    } catch (e) {
      console.error("Error fetching round participants", e)
    }
  }

  const fetchRoundSummary = async (roundId: string) => {
    try {
      const data = await $fetch(`/api/rounds/${roundId}/scores/summary` as any)
      roundSummariesMap.value[roundId] = data
      return data
    } catch (e) {
      console.error("Error fetching round summary", e)
    }
  }

  const startRound = async (roundId: string) => {
    try {
      await $fetch(`/api/rounds/${roundId}` as any, {
        method: 'PATCH',
        body: { status: 'active', started_at: new Date().toISOString() }
      })
      // Refresh rounds
      const index = rounds.value.findIndex(r => r.id === roundId)
      if (index !== -1 && rounds.value[index]) rounds.value[index].status = 'active'
    } catch (e) {
      console.error("Error starting round", e)
    }
  }

  const promoteParticipants = async (roundId: string, participantIds: string[], nextRoundName?: string) => {
    try {
      const data = await $fetch(`/api/rounds/${roundId}/promote` as any, {
        method: 'POST',
        body: { participantIds, nextRoundName }
      })
      // Refresh rounds and current state if needed
      if (currentContest.value?.id) {
        const rnds = await ($fetch as any)(`/api/contests/${currentContest.value.id}/rounds`) as Round[]
        rounds.value = rnds || []
      }
      return data
    } catch (e) {
      console.error("Error promoting participants", e)
      throw e
    }
  }

  const createRound = async (categoryId: string, name: string, order: number) => {
    try {
      const data = await $fetch(`/api/categories/${categoryId}/rounds` as any, {
        method: 'POST',
        body: { name, order, status: 'active', scoring_type: 'numeric' }
      })
      if (data) {
        // Refresh rounds
        if (currentContest.value?.id) {
          const rnds = await ($fetch as any)(`/api/contests/${currentContest.value.id}/rounds`) as Round[]
          rounds.value = rnds || []
        }
        return data
      }
    } catch (e) {
      console.error("Error creating round", e)
      throw e
    }
  }

  const deleteParticipant = async (id: string) => {
    try {
      await $fetch(`/api/participants/${id}` as any, {
        method: 'DELETE'
      })
      participants.value = participants.value.filter(p => p.id !== id)
      return { success: true }
    } catch (e) {
      console.error("Error deleting participant", e)
      throw e
    }
  }

  const deleteContest = async (id: string) => {
    try {
      await contestsApi.deleteContest(id)
      contests.value = contests.value.filter(c => c.id !== id)
    } catch (e) {
      console.error("Error deleting contest", e)
      throw e
    }
  }

  const fetchJudgePool = async (orgId: string) => {
    try {
      const data = await organizationsApi.fetchJudgePool(orgId)
      judgePool.value = data || []
      return data
    } catch (e) {
      console.error("Error fetching judge pool", e)
    }
  }

  const saveToJudgePool = async (orgId: string, judge: Partial<JudgePoolMember>) => {
    try {
      const data = await organizationsApi.saveToJudgePool(orgId, judge)
      if (data) {
        await fetchJudgePool(orgId)
        return data
      }
    } catch (e) {
      console.error("Error saving to judge pool", e)
      throw e
    }
  }

  const deleteFromJudgePool = async (orgId: string, judgeId: string) => {
    try {
      await organizationsApi.deleteFromJudgePool(orgId, judgeId)
      judgePool.value = judgePool.value.filter((j: JudgePoolMember) => j.id !== judgeId)
    } catch (e) {
      console.error("Error deleting from judge pool", e)
      throw e
    }
  }

  const removeMember = async (memberId: string) => {
    if (!currentContest.value?.id) return
    try {
      await $fetch(`/api/contests/${currentContest.value.id}/members/${memberId}` as any, {
        method: 'DELETE'
      })
      members.value = members.value.filter(m => m.id !== memberId)
    } catch (e) {
      console.error("Error removing member from contest", e)
      throw e
    }
  }

  return { 
    contests, currentContest, categories, rounds, participants, prizes, rehearsals,
    fetchContests, fetchContest, createContest, createCategory, updateContest, deleteContest,
    addParticipant, updateCategory, updateParticipant, addPrize, updateRoundParticipant,
    createRound, deleteParticipant,
    roundParticipantsMap, roundSummariesMap, members, judgePool,
    fetchRoundParticipants, fetchRoundSummary, startRound, promoteParticipants,
    fetchJudgePool, saveToJudgePool, deleteFromJudgePool, removeMember
  }
})
