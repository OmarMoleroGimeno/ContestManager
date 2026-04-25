import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { JudgePoolMember } from '~~/types'
import { organizationsApi } from '~/api/modules/OrganizationsApi'
import { useAuthStore } from '~/stores/auth'

export const useJudgePoolStore = defineStore('judge-pool', () => {
  const items = ref<JudgePoolMember[]>([])
  const orgId = ref<string | null>(null)
  const isFetching = ref(false)
  const fetched = ref(false)

  const total = computed(() => items.value.length)

  // ── Resolve org from auth store (no extra fetch needed) ───────────────────
  function resolveOrg(): string | null {
    if (orgId.value) return orgId.value
    const authStore = useAuthStore()
    const id = (authStore.organization as any)?.id ?? null
    if (id) orgId.value = id
    return orgId.value
  }

  // ── Fetch pool ─────────────────────────────────────────────────────────────
  async function fetchPool(force = false): Promise<JudgePoolMember[]> {
    if (fetched.value && !force) return items.value
    const id = resolveOrg()
    if (!id) return []
    isFetching.value = true
    try {
      const data = await organizationsApi.fetchJudgePool(id)
      items.value = data || []
      fetched.value = true
      return items.value
    } finally {
      isFetching.value = false
    }
  }

  // ── Add judge ──────────────────────────────────────────────────────────────
  async function addJudge(payload: { full_name: string; email: string; specialty?: string }): Promise<JudgePoolMember> {
    const id = resolveOrg()
    if (!id) throw new Error('No org found')
    const data = await organizationsApi.saveToJudgePool(id, payload)
    items.value.unshift(data)
    return data
  }

  // ── Remove judge ───────────────────────────────────────────────────────────
  async function removeJudge(memberId: string): Promise<void> {
    const id = resolveOrg()
    if (!id) return
    await organizationsApi.deleteFromJudgePool(id, memberId)
    items.value = items.value.filter(j => j.id !== memberId)
  }

  // ── Invalidate ─────────────────────────────────────────────────────────────
  function invalidate() {
    fetched.value = false
    items.value = []
  }

  return {
    items, orgId, total, isFetching, fetched,
    resolveOrg, fetchPool, addJudge, removeJudge, invalidate,
  }
})
