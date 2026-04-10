<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { 
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger 
} from '@/components/ui/dialog'
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger,
} from '@/components/ui/alert-dialog'
import { 
  Drawer, DrawerContent, DrawerDescription, DrawerFooter, DrawerHeader, DrawerTitle, DrawerTrigger 
} from '@/components/ui/drawer'
import { Checkbox } from '@/components/ui/checkbox'
import { Textarea } from '@/components/ui/textarea'
import { Progress } from '@/components/ui/progress'
import {
  NumberField,
  NumberFieldContent,
  NumberFieldDecrement,
  NumberFieldIncrement,
  NumberFieldInput
} from '@/components/ui/number-field'
import {
  ArrowLeft, Users, UserPlus, Search,
  Trash2, Trophy, Settings, Settings2, Layers, Plus, Play, Eye, UserCheck, Activity, Swords, CalendarRange, Medal, Sparkles, Link, ClipboardCheck,
  ChevronLeft, ChevronRight, Check, Pencil, Save, X
} from 'lucide-vue-next'
import {
  Carousel, CarouselContent, CarouselItem, CarouselNext, CarouselPrevious
} from '@/components/ui/carousel'
import { Separator } from '@/components/ui/separator'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { DatePicker } from '@/components/ui/date-picker'
import MotionButton from '@/components/ui/MotionButton.vue'
import type { DateValue } from '@internationalized/date'
import { useContestStore } from '@/stores/contest'
import { storeToRefs } from 'pinia'
import { toast } from 'vue-sonner'
import { getStatusClasses, getTypeClasses } from '@/utils/styles'
import type { JudgePoolMember } from '~~/types'
import JudgePoolTable from '@/components/judge-pool/JudgePoolTable.vue'
import PromotionTable from '@/components/promotion/PromotionTable.vue'
import ParticipantsTable from '@/components/participants/ParticipantsTable.vue'
import JudgesTable from '@/components/judges/JudgesTable.vue'

const route = useRoute()
const contestStore = useContestStore()
const { 
  currentContest, categories, participants, rounds, members,
  roundParticipantsMap, roundSummariesMap, judgePool 
} = storeToRefs(contestStore)

onMounted(async () => {
  if (!currentContest.value || currentContest.value.slug !== route.params.slug) {
    await contestStore.fetchContest(route.params.slug as string)
  }
  if (currentContest.value?.organization_id) {
    await contestStore.fetchJudgePool(currentContest.value.organization_id)
  }
})

const categoryId = route.params.id as string
const selectedRoundId = ref('')
const isCreatingRound = ref(false)
const isJudgeMatrixOpen = ref(false)
const newRoundName = ref('')

const categoryRounds = computed(() => rounds.value.filter(r => r.category_id === categoryId).sort((a, b) => a.order - b.order))
const categoryJudges = computed(() => members.value.filter(m => m.role === 'judge') as any[])
const categoryParticipants = computed(() => participants.value?.filter(p => p.category_id === categoryId) || [])

// Round logic
const currentRoundParticipants = computed(() => roundParticipantsMap.value[selectedRoundId.value] || [])
const currentRoundSummary = computed(() => roundSummariesMap.value[selectedRoundId.value])
const currentRound = computed(() => rounds.value.find(r => r.id === selectedRoundId.value))

watch(selectedRoundId, (newId) => {
  if (newId) {
    contestStore.fetchRoundParticipants(newId)
    contestStore.fetchRoundSummary(newId)
  }
}, { immediate: true })

// Real-time: refresh summary whenever a judge submits or updates a score
useRoundScoresRealtime(selectedRoundId, (roundId) => {
  contestStore.fetchRoundSummary(roundId)
})

const getParticipantScoreProgress = (pId: string) => {
  const summary = currentRoundSummary.value?.participant_summaries?.find((s: any) => s.participant_id === pId)
  return {
    count: summary?.score_count || 0,
    total: categoryJudges.value.length,
    isCompleted: summary?.is_fully_scored || false
  }
}

const roundStats = computed(() => {
  if (!currentRoundSummary.value) return { completion: 0 }
  const totalPossible = currentRoundParticipants.value.length * categoryJudges.value.length
  const actual = (currentRoundSummary.value?.participant_summaries || []).reduce((acc: number, s: any) => acc + (s.score_count || 0), 0)
  return { completion: totalPossible > 0 ? Math.round((actual / totalPossible) * 100) : 0 }
})

// Setup Phase Logic (Judges)
const isInvitingJudge = ref(false)
const isJudgePoolOpen = ref(false)
const newJudgeForm = ref({ email: '', full_name: '', specialty: '' })

// Judge Pool Pagination & Search
const judgePoolSearchQuery = ref('')
const judgePoolPage = ref(1)
const judgePoolPerPage = 5

const filteredJudgePool = computed(() => {
  // First, filter out judges who are already in the contest
  const existingMemberEmails = new Set(
    members.value
      ?.map(m => m.email)
      .filter((e): e is string => !!e) || []
  )
  const availablePool = judgePool.value.filter(j => !existingMemberEmails.has(j.email))
  
  if (!judgePoolSearchQuery.value) return availablePool
  
  const q = judgePoolSearchQuery.value.toLowerCase()
  return availablePool.filter(j => 
    j.full_name?.toLowerCase().includes(q) || 
    j.email?.toLowerCase().includes(q) ||
    j.specialty?.toLowerCase().includes(q)
  )
})

const totalPoolPages = computed(() => Math.ceil(filteredJudgePool.value.length / judgePoolPerPage))
const paginatedJudgePool = computed(() => {
  const start = (judgePoolPage.value - 1) * judgePoolPerPage
  return filteredJudgePool.value.slice(start, start + judgePoolPerPage)
})

watch(judgePoolSearchQuery, () => {
  judgePoolPage.value = 1
})

const selectedPoolIds = ref<string[]>([])
const isAddingBulk = ref(false)

const selectedPoolJudgesCount = computed(() => selectedPoolIds.value.length)

// Promotion Modal State
const promotionSearchQuery = ref('')
const promotionPage = ref(1)
const promotionPerPage = 5
const selectedPromotionIds = ref<string[]>([])

const filteredPromotionParticipants = computed(() => {
  const query = promotionSearchQuery.value.toLowerCase().trim()
  const participantsList = currentRoundSummary.value?.participant_summaries || []
  
  return [...participantsList]
    .sort((a, b) => b.average - a.average)
    .filter(s => {
      const p = participants.value.find(part => part.id === s.participant_id)
      if (!p) return false
      return p.name.toLowerCase().includes(query) || (p.email && p.email.toLowerCase().includes(query))
    })
})

const paginatedPromotionParticipants = computed(() => {
  const start = (promotionPage.value - 1) * promotionPerPage
  return filteredPromotionParticipants.value.slice(start, start + promotionPerPage)
})

const totalPromotionPages = computed(() => Math.ceil(filteredPromotionParticipants.value.length / promotionPerPage))

const selectedPromotionCount = computed(() => selectedPromotionIds.value.length)

const handleBulkAddFromPool = async () => {
  if (selectedPoolIds.value.length === 0 || !currentContest.value?.id) return
  isAddingBulk.value = true
  try {
    const selectedIds = selectedPoolIds.value
    const selectedJudges = judgePool.value.filter(j => selectedIds.includes(j.id))
    
    // Perform bulk insertion
    await Promise.all(selectedJudges.map(judge => 
      $fetch(`/api/contests/${currentContest.value!.id}/members` as any, {
        method: 'POST', body: { 
          email: judge.email, 
          full_name: judge.full_name,
          role: 'judge' 
        }
      })
    ))

    toast.success(`${selectedIds.length} jueces añadidos correctamente`)
    const mems = await ($fetch as any)(`/api/contests/${currentContest.value.id}/members`)
    members.value = mems || []
    isJudgePoolOpen.value = false
    selectedPoolIds.value = []
  } catch (e) {
    toast.error('Error al añadir jueces en lote')
  } finally {
    isAddingBulk.value = false
  }
}

const handleInviteJudge = async () => {
  if (!newJudgeForm.value.email.trim() || !currentContest.value?.id) return
  isInvitingJudge.value = true
  try {
    // invite to contest
    await $fetch(`/api/contests/${currentContest.value.id}/members` as any, {
      method: 'POST', body: { 
        email: newJudgeForm.value.email, 
        full_name: newJudgeForm.value.full_name,
        role: 'judge' 
      }
    })
    
    // Also save to pool if they have a name
    if (newJudgeForm.value.full_name.trim() && currentContest.value.organization_id) {
       await contestStore.saveToJudgePool(currentContest.value.organization_id, {
          email: newJudgeForm.value.email,
          full_name: newJudgeForm.value.full_name,
          specialty: newJudgeForm.value.specialty
       })
    }

    toast.success('Invitación enviada y guardado en el pool')
    newJudgeForm.value = { email: '', full_name: '', specialty: '' }
    const mems = await ($fetch as any)(`/api/contests/${currentContest.value.id}/members`)
    members.value = mems || []
  } catch (e) { toast.error('Error al invitar') } finally { isInvitingJudge.value = false }
}

const handleSelectFromPool = async (judge: JudgePoolMember) => {
  if (!currentContest.value?.id) return
  try {
    await $fetch(`/api/contests/${currentContest.value.id}/members` as any, {
      method: 'POST', body: { 
        email: judge.email, 
        full_name: judge.full_name,
        role: 'judge' 
      }
    })
    toast.success(`${judge.full_name} añadido al concurso`)
    const mems = await ($fetch as any)(`/api/contests/${currentContest.value.id}/members`)
    members.value = mems || []
    isJudgePoolOpen.value = false
  } catch (e) { toast.error('Error al añadir') }
}

// Registration Link logic
const copyRegistrationLink = () => {
  const url = `${window.location.origin}/register/${categoryId}`
  navigator.clipboard.writeText(url)
  toast.success('Enlace de inscripción copiado al portapapeles', {
    description: 'De momento es un enlace de prueba.',
    icon: Link
  })
}

const handleStartCategory = async () => {
  try {
    const data = await contestStore.createRound(categoryId, 'Ronda 1', 1) as any
    if (!data) return
    await $fetch(`/api/rounds/${data.id}/participants/bulk` as any, {
      method: 'POST', body: { participantIds: categoryParticipants.value.map(p => p.id) }
    })
    selectedRoundId.value = data.id
    toast.success('Categoría iniciada')
  } catch (e) { toast.error('Error al iniciar') }
}

// Search & Filter
const searchQuery = ref('')
const filteredParticipants = computed(() => {
  if (!searchQuery.value) return categoryParticipants.value
  const q = searchQuery.value.toLowerCase()
  return categoryParticipants.value.filter(p => p.name.toLowerCase().includes(q) || p.dni?.toLowerCase().includes(q))
})

// Participant Modal
const isAddDialogOpen = ref(false)
const isAdding = ref(false)
const newParticipant = ref({ name: '', first_name: '', last_name: '', dni: '', email: '', country: '' })
const birthdateValue = ref<DateValue>()
const handleAddParticipant = async () => {
  if (!newParticipant.value.name.trim()) return
  isAdding.value = true
  try {
    await contestStore.addParticipant({ ...newParticipant.value, birthdate: birthdateValue.value?.toString(), category_id: categoryId })
    toast.success('Inscrito correctamente')
    isAddDialogOpen.value = false
  } catch (e) { toast.error('Error al inscribir') } finally { isAdding.value = false }
}

// Category Config
const isConfigDrawerOpen = ref(false)
const configForm = ref({ name: '', description: '', min_age: null as number|null, max_age: null as number|null })
const category = computed(() => categories.value?.find(c => c.id === categoryId))
watch(category, (v) => { if (v) configForm.value = { name: v.name, description: v.description || '', min_age: v.min_age, max_age: v.max_age } }, { immediate: true })
const handleUpdateCategory = async () => {
  if (!category.value) return
  if (!category.value.name.trim()) {
    toast.error('El nombre es obligatorio')
    return
  }
  try {
    await contestStore.updateCategory(categoryId, { name: category.value.name, min_age: category.value.min_age, max_age: category.value.max_age })
    toast.success('Configuración actualizada')
    isConfigDrawerOpen.value = false
  } catch (e) { toast.error('Error al actualizar') }
}

// Promotion
const isPromotionModalOpen = ref(false)
const promotionLimit = ref(5)
const isPromoting = ref(false)
const isNextRoundFinal = ref(false)
const handlePromote = async () => {
  isPromoting.value = true
  try {
    const selectedIds = selectedPromotionIds.value

    if (selectedIds.length === 0) return

    const currentRnd = categoryRounds.value.find(r => r.id === selectedRoundId.value)
    const order = (currentRnd?.order || 0) + 1
    const nextName = isNextRoundFinal.value ? 'Gran Final' : `Ronda ${order}`
    await contestStore.promoteParticipants(selectedRoundId.value, selectedIds, nextName)
    toast.success('Promovidos con éxito')
    isPromotionModalOpen.value = false
    selectedRoundId.value = ''
    selectedPromotionIds.value = []
    isNextRoundFinal.value = false
  } catch (e) { toast.error('Error al promover') } finally { isPromoting.value = false }
}
watch(promotionSearchQuery, () => {
  promotionPage.value = 1
})

const isParticipantDetailOpen = ref(false)
const selectedParticipantId = ref<string|null>(null)
const openParticipantDetails = (id: string) => { selectedParticipantId.value = id; isParticipantDetailOpen.value = true }
const currentParticipantDetails = computed(() => {
  if (!selectedParticipantId.value || !currentRoundSummary.value) return null
  return { ...currentRoundSummary.value.participant_summaries.find((s:any) => s.participant_id === selectedParticipantId.value), participant: participants.value.find(p => p.id === selectedParticipantId.value) }
})

// ── Participant detail modal: editable scores per judge ──────────────────────
const editingJudgeId = ref<string|null>(null)
const editDraft = ref<{ value: number; notes: string; promote: boolean }>({ value: 0, notes: '', promote: false })
const isSavingScore = ref(false)

const startEditing = (score: any) => {
  editingJudgeId.value = score.judge_id
  editDraft.value = { value: Number(score.value), notes: score.notes || '', promote: score.promote ?? false }
}
const cancelEditing = () => { editingJudgeId.value = null }

const saveEditedScore = async (judgeId: string) => {
  if (!selectedParticipantId.value || !selectedRoundId.value) return
  isSavingScore.value = true
  try {
    await $fetch('/api/scores' as any, {
      method: 'POST',
      body: {
        round_id: selectedRoundId.value,
        participant_id: selectedParticipantId.value,
        judge_id: judgeId,
        value: editDraft.value.value,
        notes: editDraft.value.notes,
        promote: editDraft.value.promote
      }
    })
    toast.success('Puntuación actualizada')
    editingJudgeId.value = null
    await contestStore.fetchRoundSummary(selectedRoundId.value)
  } catch (e: any) {
    toast.error('Error al guardar: ' + (e?.data?.statusMessage || e?.message || 'Error desconocido'))
  } finally {
    isSavingScore.value = false
  }
}

// ── Judge detail modal: all scores + pending participants ─────────────────────
const isJudgeDetailOpen = ref(false)
const selectedJudgeUserId = ref<string|null>(null)
const editingParticipantId = ref<string|null>(null)
const judgeEditDraft = ref<{ value: number; notes: string; promote: boolean }>({ value: 0, notes: '', promote: false })
const isSavingJudgeScore = ref(false)

const openJudgeDetails = (judgeUserId: string) => {
  selectedJudgeUserId.value = judgeUserId
  editingParticipantId.value = null
  isJudgeDetailOpen.value = true
}

const currentJudgeDetails = computed(() => {
  if (!selectedJudgeUserId.value || !currentRoundSummary.value) return null
  const judgeId = selectedJudgeUserId.value
  const judge = categoryJudges.value.find((j: any) => j.user_id === judgeId)
  const scored: any[] = []
  const pending: any[] = []
  for (const rp of currentRoundParticipants.value) {
    const pSummary = currentRoundSummary.value.participant_summaries?.find((s: any) => s.participant_id === rp.participant_id)
    const score = pSummary?.judge_details?.find((d: any) => d.judge_id === judgeId)
    const participant = participants.value.find(p => p.id === rp.participant_id)
    if (score) {
      scored.push({ participant, score })
    } else {
      pending.push({ participant })
    }
  }
  return { judge, scored, pending }
})

const startEditingParticipant = (item: any) => {
  editingParticipantId.value = item.participant.id
  judgeEditDraft.value = { value: Number(item.score.value), notes: item.score.notes || '', promote: item.score.promote ?? false }
}
const cancelEditingParticipant = () => { editingParticipantId.value = null }

const saveJudgeScore = async (participantId: string) => {
  if (!selectedJudgeUserId.value || !selectedRoundId.value) return
  isSavingJudgeScore.value = true
  try {
    await $fetch('/api/scores' as any, {
      method: 'POST',
      body: {
        round_id: selectedRoundId.value,
        participant_id: participantId,
        judge_id: selectedJudgeUserId.value,
        value: judgeEditDraft.value.value,
        notes: judgeEditDraft.value.notes,
        promote: judgeEditDraft.value.promote
      }
    })
    toast.success('Puntuación actualizada')
    editingParticipantId.value = null
    await contestStore.fetchRoundSummary(selectedRoundId.value)
  } catch (e: any) {
    toast.error('Error al guardar: ' + (e?.data?.statusMessage || e?.message || 'Error desconocido'))
  } finally {
    isSavingJudgeScore.value = false
  }
}

const handleStartRound = async (id: string) => { await contestStore.startRound(id); toast.success('Ronda iniciada') }
const handleCreateRound = async () => {
  if (!newRoundName.value.trim()) return
  try {
    await contestStore.createRound(categoryId, newRoundName.value, categoryRounds.value.length + 1)
    toast.success('Ronda creada')
    isCreatingRound.value = false
  } catch (e) { toast.error('Error') }
}
const handleDeleteParticipant = async (id: string) => { try { await contestStore.deleteParticipant(id); toast.success('Eliminado') } catch (e) { toast.error('Error') } }

// Bulk selection state
const selectedParticipantIds = ref<string[]>([])
const selectedJudgeIds = ref<string[]>([])

const handleBulkDeleteParticipants = async () => {
  const ids = [...selectedParticipantIds.value]
  if (!confirm(`¿Eliminar ${ids.length} participantes?`)) return
  try {
    await Promise.all(ids.map(id => contestStore.deleteParticipant(id)))
    toast.success(`${ids.length} participantes eliminados`)
  } catch (e) { toast.error('Error al eliminar participantes') }
}

const handleBulkRemoveJudges = async () => {
  const ids = [...selectedJudgeIds.value]
  if (!confirm(`¿Quitar ${ids.length} jurados de la mesa?`)) return
  try {
    await Promise.all(ids.map(id => contestStore.removeMember(id)))
    toast.success(`${ids.length} jurados retirados`)
  } catch (e) { toast.error('Error al retirar jurados') }
}
const handleRemoveJudge = async (memberId: string) => {
  try {
    await contestStore.removeMember(memberId)
    toast.success('Jurado retirado con éxito')
  } catch (e) {
    toast.error('Error al retirar al jurado')
  }
}

const contestSettings = computed(() => {
  const s = currentContest.value?.settings as any
  return {
    mode: s?.mode || 'standard',
    rounds_count: s?.rounds_count || 1
  }
})
</script>

<template>
  <div class="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500 max-w-[1400px] mx-auto">
    <!-- Header (Hidden when in Round Detail) -->
    <div v-if="!selectedRoundId" class="flex items-start justify-between">
      <div class="flex gap-4">
        <div>
          <div class="flex flex-wrap items-center gap-3">
            <NuxtLink :to="`/contests/${route.params.slug}`" class="p-2 hover:scale-110 transition-transform">
              <ArrowLeft class="w-5 h-5 text-muted-foreground" />
            </NuxtLink>
            <h1 class="text-3xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100 uppercase">{{ category?.name || 'Cargando...' }}</h1>
            <div v-if="category" class="flex flex-wrap gap-2">
              <Badge 
                variant="secondary" 
                class="font-bold px-3 py-1 border-2 rounded-md shadow-sm"
                :class="getStatusClasses('active')"
              >
                <Users class="w-3.5 h-3.5 mr-1.5" />
                {{ categoryParticipants.length }} Participantes
              </Badge>
              <Badge 
                v-if="category.min_age || category.max_age"
                variant="outline" 
                class="font-bold px-3 py-1 border-2 rounded-md shadow-sm"
              >
                <Activity class="w-3.5 h-3.5 mr-1.5" />
                {{ category.min_age || 0 }}-{{ category.max_age || '∞' }} Años
              </Badge>
            </div>
          </div>
          <p class="text-muted-foreground mt-2 max-w-2xl leading-relaxed">
            {{ categoryRounds.length === 0 ? 'Fase de Inscripción y Preparación - Configura participantes y mesa de jurado.' : 'Categoría en Curso - Evaluación por Rondas operativas.' }}
          </p>
        </div>
      </div>

      <div class="flex items-center gap-6">
        <!-- Metadatos de la Categoría -->
        <div v-if="category" class="hidden md:flex flex-wrap items-center gap-6 text-[11px] text-zinc-500 uppercase font-bold tracking-tighter">
          <div class="flex items-center gap-1.5 opacity-70 hover:opacity-100 transition-opacity">
            <Layers class="w-3.5 h-3.5" />
            <span>Fases:</span>
            <span class="text-zinc-900 dark:text-zinc-300">{{ categoryRounds.length }} / {{ contestSettings.rounds_count }}</span>
          </div>
          <div class="flex items-center gap-1.5 opacity-70 hover:opacity-100 transition-opacity">
            <Trophy class="w-3.5 h-3.5" />
            <span>Estado:</span>
            <span class="text-zinc-900 dark:text-zinc-300">{{ categoryRounds.length === 0 ? 'INSCRIPCIÓN' : 'EJECUCIÓN' }}</span>
          </div>
        </div>

        <Button 
          variant="outline" 
          size="sm"
          class="gap-2 bg-zinc-50 text-zinc-700 border-zinc-200 dark:bg-zinc-950/50 dark:text-zinc-400 dark:border-zinc-500/30 hover:bg-zinc-100 dark:hover:bg-zinc-900 font-bold border-2 rounded-md transition-all uppercase tracking-tighter text-[10px]"
          @click="isConfigDrawerOpen = true"
        >
          <Settings2 class="w-4 h-4" /> Configuración
        </Button>

      </div>
    </div>

    <!-- PHASE 1: SETUP -->
    <div v-if="categoryRounds.length === 0" class="space-y-8 animate-in fade-in slide-in-from-top-10 duration-700">
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch">
        <!-- Participants Table (Left: 7/12) -->
        <div class="lg:col-span-7 flex flex-col">
          <div class="mb-4 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 rounded-lg bg-zinc-100 dark:bg-zinc-800 flex items-center justify-center">
                <UserPlus class="w-4 h-4 text-zinc-500" />
              </div>
              <h3 class="font-bold uppercase tracking-tighter text-sm">Listado de Participantes</h3>
            </div>
            <div class="flex items-center gap-2">
              <Transition
                enter-active-class="transition-all duration-200 ease-out"
                enter-from-class="opacity-0 scale-95"
                leave-active-class="transition-all duration-150 ease-in"
                leave-to-class="opacity-0 scale-95"
              >
                <Button
                  v-if="selectedParticipantIds.length > 0"
                  size="sm"
                  variant="destructive"
                  class="h-8 font-bold uppercase text-[9px] tracking-widest px-3 gap-1.5"
                  @click="handleBulkDeleteParticipants"
                >
                  <Trash2 class="w-3.5 h-3.5" /> Eliminar {{ selectedParticipantIds.length }}
                </Button>
              </Transition>
              <Button size="sm" variant="outline" class="h-8 border-2 font-bold uppercase text-[9px] tracking-widest px-3" @click="isAddDialogOpen = true">
                <Plus class="w-3.5 h-3.5 mr-1" /> Nuevo
              </Button>
            </div>
          </div>

          <Card class="overflow-hidden border-2 border-zinc-100 dark:border-zinc-800 bg-white dark:bg-zinc-950/50 shadow-sm flex flex-col rounded-2xl">
            <ParticipantsTable
              :data="categoryParticipants"
              flush
              @update:selection="selectedParticipantIds = $event"
              @delete="handleDeleteParticipant"
            />
          </Card>
        </div>

        <!-- Judges Table (Right: 5/12) -->
        <div class="lg:col-span-5 flex flex-col">
          <div class="mb-4 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 rounded-lg bg-zinc-100 dark:bg-zinc-800 flex items-center justify-center">
                <Medal class="w-4 h-4 text-zinc-500" />
              </div>
              <h3 class="font-bold uppercase tracking-tighter text-sm">Mesa de Jurado</h3>
            </div>
            <div class="flex items-center gap-2">
              <Transition
                enter-active-class="transition-all duration-200 ease-out"
                enter-from-class="opacity-0 scale-95"
                leave-active-class="transition-all duration-150 ease-in"
                leave-to-class="opacity-0 scale-95"
              >
                <Button
                  v-if="selectedJudgeIds.length > 0"
                  size="sm"
                  variant="destructive"
                  class="h-8 font-bold uppercase text-[9px] tracking-widest px-3 gap-1.5"
                  @click="handleBulkRemoveJudges"
                >
                  <Trash2 class="w-3.5 h-3.5" /> Quitar {{ selectedJudgeIds.length }}
                </Button>
              </Transition>
              <Dialog v-model:open="isJudgePoolOpen">
                <DialogTrigger as-child>
                  <Button variant="ghost" size="sm" class="h-8 font-extrabold uppercase text-[9px] tracking-widest px-3 text-blue-600 dark:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/30">
                    <Users class="w-3.5 h-3.5 mr-1" /> Pool
                  </Button>
                </DialogTrigger>
                <DialogContent class="max-w-2xl bg-white dark:bg-zinc-950 border-2 border-zinc-200 dark:border-zinc-800 rounded-3xl p-0 overflow-hidden shadow-2xl">
                  <DialogHeader class="p-8 border-b-2 border-zinc-50 dark:border-zinc-900 bg-zinc-50/50 dark:bg-zinc-900/50 text-left">
                    <div class="flex items-center justify-between gap-6">
                      <div>
                        <DialogTitle class="text-xl font-bold uppercase tracking-tight">Pool de Jueces</DialogTitle>
                        <DialogDescription class="text-[10px] text-zinc-400 font-bold uppercase tracking-widest mt-1">Reutiliza jueces de concursos anteriores de la organización</DialogDescription>
                      </div>
                    </div>
                  </DialogHeader>
                  <div class="overflow-hidden">
                    <JudgePoolTable
                      :data="filteredJudgePool"
                      flush
                      @update:selection="selectedPoolIds = $event"
                    />
                  </div>
                  <DialogFooter class="p-8 border-t-2 border-zinc-50 dark:border-zinc-900 bg-zinc-50/50 dark:bg-zinc-900/50">
                    <Button
                      variant="default"
                      size="sm"
                      class="w-full h-12 bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 font-black uppercase text-xs tracking-[0.2em] shadow-xl rounded-2xl flex items-center justify-center gap-3 disabled:opacity-30 disabled:cursor-not-allowed transition-all active:scale-95"
                      :disabled="isAddingBulk || selectedPoolIds.length === 0"
                      @click="handleBulkAddFromPool"
                    >
                      <Plus v-if="!isAddingBulk" class="w-5 h-5" />
                      <Activity v-else class="w-5 h-5 animate-spin" />
                      {{ selectedPoolIds.length > 0 ? `Añadir ${selectedPoolIds.length} seleccionados` : 'Seleccionar jueces' }}
                    </Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>
              <Dialog>
                <DialogTrigger as-child>
                  <Button size="sm" class="h-8 bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 font-bold uppercase text-[9px] tracking-widest px-3">
                    <Plus class="w-3.5 h-3.5 mr-1" /> Invitar
                  </Button>
                </DialogTrigger>
                <DialogContent class="bg-white dark:bg-zinc-950 rounded-2xl border-2 dark:border-zinc-800">
                  <DialogHeader>
                    <DialogTitle>Invitar Juez</DialogTitle>
                    <DialogDescription>Añade un juez directamente a este concurso.</DialogDescription>
                  </DialogHeader>
                  <div class="space-y-4 py-4">
                    <div class="space-y-2">
                      <Label class="text-xs font-bold uppercase tracking-widest">Nombre completo</Label>
                      <Input v-model="newJudgeForm.full_name" placeholder="Ej. Juan Pérez" />
                    </div>
                    <div class="space-y-2">
                      <Label class="text-xs font-bold uppercase tracking-widest">Email</Label>
                      <Input v-model="newJudgeForm.email" placeholder="email@ejemplo.com" />
                    </div>
                  </div>
                  <DialogFooter>
                    <Button
                      class="w-full bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 font-bold uppercase tracking-widest text-[10px]"
                      :disabled="isInvitingJudge || !newJudgeForm.email"
                      @click="handleInviteJudge"
                    >
                      Enviar Invitación
                    </Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>
            </div>
          </div>

          <Card class="overflow-hidden border-2 border-zinc-100 dark:border-zinc-800 bg-white dark:bg-zinc-950/50 shadow-sm flex flex-col rounded-2xl">
            <JudgesTable
              :data="categoryJudges"
              flush
              @update:selection="selectedJudgeIds = $event"
              @delete="handleRemoveJudge"
            />
          </Card>
        </div>
      </div>

      <div class="flex justify-center pt-16 border-t-2 border-dashed border-zinc-100 dark:border-zinc-800">
        <MotionButton 
          label="Iniciar"
          :disabled="categoryParticipants.length < 1 || categoryJudges.length < 1"
          @click="handleStartCategory"
          class="shadow-2xl hover:scale-105 transition-all"
        />
      </div>
    </div>

    <!-- PHASE 2: EXECUTION -->
    <div v-else class="space-y-10 animate-in fade-in slide-in-from-right-10 duration-700">
      <!-- Carousel Overview -->
      <div v-if="!selectedRoundId" class="py-12 space-y-12">
        <div class="px-16">
          <Carousel :opts="{ align: 'start' }" class="w-full">
            <CarouselContent class="-ml-6">
              <CarouselItem v-for="r in categoryRounds" :key="r.id" class="pl-6 basis-full sm:basis-1/2 md:basis-1/3 lg:basis-1/4">
                <Card 
                  class="cursor-pointer border-2 shadow-sm rounded-2xl overflow-hidden active:scale-95 transition-all h-[210px] group relative" 
                  :class="[
                    r.status === 'active' 
                      ? 'bg-white dark:bg-blue-950/20 border-blue-500/30' 
                      : 'bg-white dark:bg-zinc-900/40 border-zinc-100 dark:border-zinc-800 hover:border-zinc-900 dark:hover:border-zinc-500'
                  ]"
                  @click="selectedRoundId = r.id"
                >
                  <CardContent class="p-8 flex flex-col justify-between h-full relative z-10">
                    <div class="flex items-center justify-between">
                      <div 
                        :class="[
                          'w-10 h-10 rounded-xl flex items-center justify-center border-2 transition-all duration-500 group-hover:scale-110 shadow-sm', 
                          r.status === 'active' 
                            ? 'bg-zinc-900 dark:bg-blue-500 text-white border-zinc-900 dark:border-blue-400' 
                            : 'bg-zinc-50 dark:bg-zinc-800 text-zinc-300 dark:text-zinc-600 border-zinc-100 dark:border-zinc-700'
                        ]"
                      >
                        <Play v-if="r.status === 'active'" class="w-5 h-5 fill-current"/>
                        <Layers v-else class="w-5 h-5"/>
                      </div>
                      <Badge 
                        variant="outline" 
                        class="text-[10px] uppercase font-bold px-3 py-1 rounded-md border-2"
                        :class="r.status === 'active' ? 'bg-blue-50 dark:bg-blue-900/40 border-blue-200 dark:border-blue-500/30 text-blue-700 dark:text-blue-400' : 'bg-zinc-50 dark:bg-zinc-800 border-zinc-200 dark:border-zinc-700 text-zinc-500'"
                      >
                        Etapa {{ r.order }}
                      </Badge>
                    </div>
                    <div>
                      <h3 class="font-bold text-lg tracking-tight uppercase truncate text-zinc-900 dark:text-zinc-100">{{ r.name }}</h3>
                      <div class="flex items-center gap-2 mt-1.5">
                        <div v-if="r.status === 'active'" class="w-2 h-2 bg-blue-500 rounded-full animate-pulse shadow-[0_0_8px_rgba(59,130,246,0.5)]" />
                        <p :class="['text-[10px] font-bold uppercase tracking-widest', r.status === 'active' ? 'text-blue-600 dark:text-blue-400' : 'text-zinc-400']">
                          {{ r.status === 'active' ? 'En Directo' : r.status === 'closed' ? 'Finalizada' : 'Pendiente' }}
                        </p>
                      </div>
                    </div>
                  </CardContent>
                  <div v-if="r.status === 'active'" class="absolute inset-0 bg-gradient-to-br from-blue-500/5 to-transparent dark:from-blue-500/10 pointer-events-none" />
                </Card>
              </CarouselItem>
            </CarouselContent>
            <CarouselPrevious class="-left-12 h-10 w-10 shadow-lg border-2 border-zinc-100 dark:border-zinc-800 dark:bg-zinc-900" />
            <CarouselNext class="-right-12 h-10 w-10 shadow-lg border-2 border-zinc-100 dark:border-zinc-800 dark:bg-zinc-900" />
          </Carousel>
        </div>
      </div>
      
      <!-- Round Detail Detail -->
      <div v-else class="animate-in fade-in slide-in-from-bottom-10 duration-700 space-y-10">
        <div class="flex items-center justify-between border-b-2 border-zinc-100 dark:border-zinc-800 pb-8">
          <div class="flex items-center gap-6">
            <button class="p-2 hover:scale-110 transition-transform" @click="selectedRoundId = ''">
              <ArrowLeft class="w-5 h-5 text-muted-foreground" />
            </button>
            <div>
              <div class="flex items-center gap-4">
                <h2 class="text-2xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100 leading-none uppercase">{{ currentRound?.name }}</h2>
                <Badge 
                  variant="secondary" 
                  class="font-bold px-3 py-0.5 h-6 rounded-md border-2"
                  :class="getStatusClasses('active')"
                >
                  Fase {{ currentRound?.order }}
                </Badge>
              </div>
              <p class="text-[11px] font-bold text-zinc-400 uppercase tracking-widest mt-1.5 flex items-center gap-2">
                <Sparkles class="w-3.5 h-3.5 text-blue-500"/> Gabinete de Calificaciones Técnica
              </p>
            </div>
          </div>
          <Button 
            variant="outline" 
            class="rounded-md gap-2 font-bold text-[10px] uppercase tracking-widest h-10 px-6 shadow-sm border-2 dark:border-zinc-800 dark:hover:bg-zinc-900" 
            @click="isJudgeMatrixOpen = true"
          >
             <Swords class="w-4 h-4" /> Matriz de Resultados
          </Button>
        </div>

        <div class="grid grid-cols-12 gap-12">
          <div class="col-span-12 lg:col-span-8 space-y-8">
            <Card class="border-2 border-zinc-100 dark:border-zinc-800 shadow-sm rounded-2xl overflow-hidden bg-white dark:bg-zinc-950/50">
              <CardHeader class="border-b-2 border-zinc-50 dark:border-zinc-900 bg-zinc-50/30 dark:bg-zinc-900/30 px-8 py-6">
                <div class="flex items-center gap-4">
                  <div class="w-10 h-10 bg-zinc-900 dark:bg-zinc-100 rounded-xl flex items-center justify-center shadow-lg border-2 border-transparent">
                    <Users class="w-5 h-5 text-white dark:text-zinc-900"/>
                  </div>
                  <div>
                    <CardTitle class="text-lg font-bold tracking-tight text-zinc-900 dark:text-zinc-100 leading-none uppercase">Ranking Oficial</CardTitle>
                    <CardDescription class="text-[11px] font-bold uppercase tracking-widest text-zinc-400 mt-1.5">Auditoría en tiempo real del desempeño del jurado</CardDescription>
                  </div>
                </div>
              </CardHeader>
              <div class="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow class="bg-zinc-50/10 dark:bg-zinc-950/20 border-zinc-50 dark:border-zinc-900">
                      <TableHead class="pl-8 text-[10px] font-bold uppercase tracking-widest py-4 text-zinc-400">Aspirante</TableHead>
                      <TableHead class="text-center text-[10px] font-bold uppercase tracking-widest text-zinc-400">Estado Mesa</TableHead>
                      <TableHead class="text-right pr-8 text-[10px] font-bold uppercase tracking-widest text-zinc-400">Media Técnica</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    <TableRow 
                      v-for="rp in currentRoundParticipants" 
                      :key="rp.id" 
                      class="group hover:bg-zinc-50/50 dark:hover:bg-zinc-900/30 cursor-pointer transition-all border-zinc-50 dark:border-zinc-900 last:border-0" 
                      @click="openParticipantDetails(rp.participant_id)"
                    >
                      <TableCell class="pl-8 py-4">
                        <div class="flex items-center gap-4">
                          <div class="w-10 h-10 rounded-xl bg-zinc-50 dark:bg-zinc-900 border-2 border-zinc-100 dark:border-zinc-800 flex items-center justify-center text-[10px] font-bold group-hover:scale-110 transition-all duration-300 shadow-sm text-zinc-400">
                            {{ rp.participant?.name.substring(0,2).toUpperCase() }}
                          </div>
                          <div class="flex flex-col">
                            <span class="text-sm font-bold text-zinc-900 dark:text-zinc-100 leading-tight">{{ rp.participant?.name }}</span>
                            <span class="text-[10px] text-zinc-400 font-bold uppercase tracking-widest mt-1">{{ rp.participant?.dni || '----' }}</span>
                          </div>
                        </div>
                      </TableCell>
                      <TableCell class="text-center">
                        <div class="flex flex-col items-center gap-1.5">
                          <span class="text-[11px] font-black tracking-widest text-zinc-900 dark:text-zinc-100">
                            {{ getParticipantScoreProgress(rp.participant_id).count }} / {{ getParticipantScoreProgress(rp.participant_id).total }}
                          </span>
                          <div class="w-24 h-1.5 bg-zinc-100 dark:bg-zinc-800 rounded-full overflow-hidden shadow-inner">
                            <div 
                              :class="['h-full transition-all duration-1000', getParticipantScoreProgress(rp.participant_id).isCompleted ? 'bg-emerald-500' : 'bg-blue-500']" 
                              :style="{ width: `${(getParticipantScoreProgress(rp.participant_id).count / (getParticipantScoreProgress(rp.participant_id).total || 1)) * 100}%` }"
                            />
                          </div>
                        </div>
                      </TableCell>
                      <TableCell class="text-right pr-8">
                        <div class="flex flex-col items-end gap-1">
                          <span :class="['text-xl font-bold tracking-tight', getParticipantScoreProgress(rp.participant_id).isCompleted ? 'text-zinc-900 dark:text-zinc-100' : 'text-zinc-200 dark:text-zinc-800']">
                            {{ currentRoundSummary?.participant_summaries.find((s:any) => s.participant_id === rp.participant_id)?.average.toFixed(2) || '0.00' }}
                          </span>
                          <div class="flex items-center gap-1 flex-wrap justify-end">
                            <Badge v-if="getParticipantScoreProgress(rp.participant_id).isCompleted" variant="outline" class="h-4 text-[8px] bg-emerald-50 dark:bg-emerald-950/40 border-emerald-200 dark:border-emerald-500/30 text-emerald-600 dark:text-emerald-400 rounded-md font-bold uppercase tracking-widest shadow-sm">Auditado</Badge>
                            <Badge
                              v-if="(currentRoundSummary?.participant_summaries.find((s:any) => s.participant_id === rp.participant_id)?.promotes ?? 0) > 0"
                              class="h-4 text-[8px] bg-blue-50 dark:bg-blue-950/40 border-blue-200 dark:border-blue-700 text-blue-600 dark:text-blue-400 rounded-md font-bold uppercase tracking-widest shadow-sm border"
                            >
                              +{{ currentRoundSummary?.participant_summaries.find((s:any) => s.participant_id === rp.participant_id)?.promotes }} prom.
                            </Badge>
                          </div>
                        </div>
                      </TableCell>
                    </TableRow>
                  </TableBody>
                </Table>
              </div>
            </Card>
          </div>

          <div class="col-span-12 lg:col-span-4 space-y-6">
            <Card class="p-8 border-2 border-zinc-100 dark:border-zinc-800 rounded-2xl space-y-6 shadow-sm bg-white dark:bg-zinc-950/50">
              <div class="space-y-4">
                <div class="flex items-center justify-between">
                  <span class="text-[10px] font-bold uppercase tracking-widest text-zinc-400">Progreso Operativo Fase</span>
                  <span class="text-2xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100">{{ roundStats.completion }}%</span>
                </div>
                <Progress :model-value="roundStats.completion" class="h-2 rounded-full overflow-hidden bg-zinc-100 dark:bg-zinc-900" />
              </div>
              <div v-if="currentRound?.status !== 'closed'" class="pt-2">
                <Button 
                  class="w-full h-11 bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 rounded-md font-bold uppercase tracking-widest text-[10px] shadow-lg border-2 border-zinc-800 dark:border-zinc-200 active:scale-95 transition-all hover:scale-[1.02]" 
                  :disabled="!currentRoundSummary?.all_scored" 
                  @click="isPromotionModalOpen = true"
                >
                  Finalizar &amp; Promover
                </Button>
              </div>
              <div v-else class="pt-2">
                <div class="w-full h-11 bg-zinc-50 dark:bg-zinc-900 border-2 border-zinc-100 dark:border-zinc-800 rounded-md flex items-center justify-center gap-2 opacity-50 cursor-not-allowed">
                  <Badge variant="outline" class="border-2 border-zinc-200 dark:border-zinc-800 text-zinc-400 font-bold uppercase text-[9px] tracking-widest">Etapa Archivada</Badge>
                </div>
              </div>
            </Card>

            <Card class="border-2 border-zinc-100 dark:border-zinc-800 rounded-2xl overflow-hidden bg-white dark:bg-zinc-950/50 shadow-sm">
              <CardHeader class="px-8 py-5 border-b-2 border-zinc-50 dark:border-zinc-900 bg-zinc-50/50 dark:bg-zinc-900/30">
                <CardTitle class="text-[10px] font-bold uppercase tracking-widest text-zinc-900 dark:text-zinc-100">Estado de Mesa Jurado</CardTitle>
              </CardHeader>
              <div class="p-4 space-y-3">
                <div
                  v-for="j in categoryJudges"
                  :key="j.id"
                  class="p-4 rounded-xl border-2 border-zinc-100 dark:border-zinc-800 bg-white dark:bg-zinc-900 flex items-center justify-between group hover:border-zinc-900 dark:hover:border-zinc-500 transition-all duration-300 cursor-pointer"
                  @click="openJudgeDetails(j.user_id)"
                >
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-xl bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 text-[10px] font-bold flex items-center justify-center group-hover:rotate-6 transition-transform shadow-lg shadow-zinc-900/5">
                      {{ (j as any).profile?.full_name?.substring(0,2) || (j as any).email?.substring(0,2) }}
                    </div>
                    <div class="flex flex-col">
                      <span class="text-[13px] font-bold text-zinc-900 dark:text-zinc-100 truncate max-w-[150px] leading-tight">{{ (j as any).profile?.full_name || (j as any).email }}</span>
                      <span class="text-[9px] font-bold text-zinc-400 uppercase tracking-widest mt-0.5">Jurado Certificado</span>
                    </div>
                  </div>
                  <div class="flex flex-col items-end">
                    <span class="text-xs font-black text-zinc-900 dark:text-zinc-100">
                      {{ currentRoundSummary?.participant_summaries.filter((s:any) => s.judge_details?.some((d:any) => d.judge_id === j.user_id)).length || 0 }} / {{ currentRoundParticipants.length }}
                    </span>
                  </div>
                </div>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </div>

    <!-- GLOBAL DIALOGS -->
    <Dialog v-model:open="isParticipantDetailOpen" @update:open="(v) => { if (!v) cancelEditing() }">
      <DialogContent class="max-w-2xl rounded-2xl overflow-hidden p-0 border border-zinc-200 dark:border-zinc-800 shadow-xl bg-white dark:bg-zinc-950">
        <!-- Header: clean card style matching the rest of the app -->
        <div class="p-6 border-b border-zinc-100 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900/50 flex items-center gap-4">
          <div class="w-11 h-11 rounded-xl bg-zinc-900 dark:bg-zinc-100 flex items-center justify-center shadow-sm shrink-0">
            <Users class="w-5 h-5 text-white dark:text-zinc-900" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 mb-0.5">Puntuaciones del participante</p>
            <h2 class="text-xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100 truncate uppercase">
              {{ currentParticipantDetails?.participant?.name }}
            </h2>
          </div>
          <div class="text-right shrink-0">
            <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 mb-0.5">Media</p>
            <span class="text-3xl font-black tracking-tighter text-zinc-900 dark:text-zinc-100">
              {{ currentParticipantDetails?.average?.toFixed(2) ?? '—' }}
            </span>
          </div>
        </div>

        <!-- Editable table -->
        <div class="p-6 space-y-3 max-h-[60vh] overflow-y-auto">
          <div
            v-for="s in currentParticipantDetails?.judge_details"
            :key="s.judge_id"
            class="rounded-xl border border-zinc-100 dark:border-zinc-800 bg-white dark:bg-zinc-900/30 overflow-hidden"
          >
            <!-- Judge row header -->
            <div class="flex items-center justify-between px-4 py-3 bg-zinc-50 dark:bg-zinc-800/50 border-b border-zinc-100 dark:border-zinc-800">
              <div class="flex items-center gap-2">
                <Avatar class="w-7 h-7">
                  <AvatarFallback class="text-[10px] font-bold bg-zinc-200 dark:bg-zinc-700 text-zinc-700 dark:text-zinc-300">
                    {{ ((currentRoundSummary?.judges?.find((j:any) => j.user_id === s.judge_id) as any)?.name || 'J').charAt(0).toUpperCase() }}
                  </AvatarFallback>
                </Avatar>
                <span class="text-sm font-semibold text-zinc-800 dark:text-zinc-200">
                  {{ (currentRoundSummary?.judges?.find((j:any) => j.user_id === s.judge_id) as any)?.name || 'Jurado' }}
                </span>
              </div>
              <!-- Edit / Save / Cancel buttons -->
              <div v-if="editingJudgeId === s.judge_id" class="flex gap-1.5">
                <Button size="sm" variant="ghost" class="h-7 px-2 text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300" @click="cancelEditing">
                  <X class="w-3.5 h-3.5 mr-1" /> Cancelar
                </Button>
                <Button size="sm" class="h-7 px-3 bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 hover:bg-zinc-700 dark:hover:bg-zinc-300" :disabled="isSavingScore" @click="saveEditedScore(s.judge_id)">
                  <Save class="w-3.5 h-3.5 mr-1" /> {{ isSavingScore ? 'Guardando…' : 'Guardar' }}
                </Button>
              </div>
              <Button v-else size="sm" variant="ghost" class="h-7 px-2 text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-300" @click="startEditing(s)">
                <Pencil class="w-3.5 h-3.5 mr-1" /> Editar
              </Button>
            </div>

            <!-- Row body: view mode -->
            <div v-if="editingJudgeId !== s.judge_id" class="grid grid-cols-3 gap-4 px-4 py-3 text-sm">
              <div>
                <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 mb-1">Nota</p>
                <Badge variant="secondary" class="font-black rounded-md px-3 py-1 text-base border-2 shadow-sm" :class="getStatusClasses('active')">
                  {{ Number(s.value).toFixed(1) }}
                </Badge>
              </div>
              <div>
                <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 mb-1">Promociona</p>
                <Badge v-if="s.promote" class="bg-blue-100 text-blue-700 border-blue-300 dark:bg-blue-950/40 dark:text-blue-300 dark:border-blue-700 font-bold border-2 text-[10px] uppercase tracking-wide">
                  Sí
                </Badge>
                <span v-else class="text-zinc-300 dark:text-zinc-600 text-xs font-medium">No</span>
              </div>
              <div>
                <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 mb-1">Observaciones</p>
                <p class="text-[12px] text-zinc-500 dark:text-zinc-400 italic leading-relaxed">
                  {{ s.notes || 'Sin observaciones.' }}
                </p>
              </div>
            </div>

            <!-- Row body: edit mode -->
            <div v-else class="px-4 py-4 space-y-4">
              <div class="grid grid-cols-2 gap-4">
                <!-- Score input -->
                <div class="space-y-1.5">
                  <Label class="text-[10px] font-bold uppercase tracking-widest text-zinc-500">Nota</Label>
                  <Input
                    v-model.number="editDraft.value"
                    type="number"
                    min="0"
                    :max="currentRound?.max_score ?? 10"
                    step="0.1"
                    class="text-center font-black text-xl h-12 border-2 border-zinc-200 dark:border-zinc-700 focus:border-zinc-900 dark:focus:border-zinc-100 rounded-xl"
                  />
                </div>
                <!-- Promote toggle -->
                <div class="space-y-1.5">
                  <Label class="text-[10px] font-bold uppercase tracking-widest text-zinc-500">Promocionar</Label>
                  <div
                    class="h-12 rounded-xl border-2 flex items-center justify-between px-4 cursor-pointer transition-all select-none"
                    :class="editDraft.promote
                      ? 'border-blue-400 bg-blue-50 dark:bg-blue-950/30 dark:border-blue-600'
                      : 'border-zinc-200 dark:border-zinc-700 bg-zinc-50 dark:bg-zinc-800/30'"
                    @click="editDraft.promote = !editDraft.promote"
                  >
                    <span class="text-sm font-semibold" :class="editDraft.promote ? 'text-blue-700 dark:text-blue-300' : 'text-zinc-400'">
                      {{ editDraft.promote ? 'Sí, promocionar' : 'No promocionar' }}
                    </span>
                    <div
                      class="w-5 h-5 rounded-md border-2 flex items-center justify-center transition-all"
                      :class="editDraft.promote ? 'bg-blue-500 border-blue-500' : 'border-zinc-300 dark:border-zinc-600'"
                    >
                      <Check v-if="editDraft.promote" class="w-3 h-3 text-white" />
                    </div>
                  </div>
                </div>
              </div>
              <!-- Notes -->
              <div class="space-y-1.5">
                <Label class="text-[10px] font-bold uppercase tracking-widest text-zinc-500">Observaciones</Label>
                <Textarea
                  v-model="editDraft.notes"
                  placeholder="Añade observaciones sobre este participante…"
                  rows="3"
                  class="resize-none border-2 border-zinc-200 dark:border-zinc-700 focus:border-zinc-900 dark:focus:border-zinc-100 rounded-xl text-sm"
                />
              </div>
            </div>
          </div>

          <!-- Empty state -->
          <div v-if="!currentParticipantDetails?.judge_details?.length" class="text-center py-10 text-zinc-400">
            <ClipboardCheck class="w-10 h-10 mx-auto mb-3 opacity-30" />
            <p class="text-sm font-medium">Ningún jurado ha puntuado aún</p>
          </div>
        </div>
      </DialogContent>
    </Dialog>

    <!-- Judge detail dialog -->
    <Dialog v-model:open="isJudgeDetailOpen" @update:open="(v) => { if (!v) cancelEditingParticipant() }">
      <DialogContent class="max-w-3xl rounded-2xl overflow-hidden p-0 border border-zinc-200 dark:border-zinc-800 shadow-xl bg-white dark:bg-zinc-950">
        <!-- Header -->
        <div class="p-6 border-b border-zinc-100 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900/50 flex items-center gap-4">
          <div class="w-11 h-11 rounded-xl bg-zinc-900 dark:bg-zinc-100 flex items-center justify-center shadow-sm shrink-0 text-white dark:text-zinc-900 text-[11px] font-black">
            {{ ((currentJudgeDetails?.judge as any)?.profile?.full_name || (currentJudgeDetails?.judge as any)?.email || 'J').substring(0,2).toUpperCase() }}
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 mb-0.5">Ficha de Jurado</p>
            <h2 class="text-xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100 truncate uppercase">
              {{ (currentJudgeDetails?.judge as any)?.profile?.full_name || (currentJudgeDetails?.judge as any)?.full_name || (currentJudgeDetails?.judge as any)?.email }}
            </h2>
          </div>
          <div class="flex gap-6 shrink-0 text-right">
            <div>
              <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 mb-0.5">Calificados</p>
              <span class="text-2xl font-black text-emerald-600 dark:text-emerald-400">{{ currentJudgeDetails?.scored.length ?? 0 }}</span>
            </div>
            <div>
              <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 mb-0.5">Pendientes</p>
              <span class="text-2xl font-black" :class="(currentJudgeDetails?.pending.length ?? 0) > 0 ? 'text-amber-500' : 'text-zinc-300 dark:text-zinc-700'">
                {{ currentJudgeDetails?.pending.length ?? 0 }}
              </span>
            </div>
          </div>
        </div>

        <div class="max-h-[65vh] overflow-y-auto">
          <!-- Scored participants table -->
          <div v-if="currentJudgeDetails?.scored.length" class="p-6 space-y-3">
            <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 pb-1">Participantes calificados</p>
            <div
              v-for="item in currentJudgeDetails.scored"
              :key="item.participant.id"
              class="rounded-xl border border-zinc-100 dark:border-zinc-800 bg-white dark:bg-zinc-900/30 overflow-hidden"
            >
              <!-- Participant row header -->
              <div class="flex items-center justify-between px-4 py-3 bg-zinc-50 dark:bg-zinc-800/50 border-b border-zinc-100 dark:border-zinc-800">
                <div class="flex items-center gap-2.5">
                  <div class="w-7 h-7 rounded-lg bg-zinc-200 dark:bg-zinc-700 flex items-center justify-center text-[9px] font-black text-zinc-600 dark:text-zinc-400">
                    {{ item.participant?.name?.substring(0,2).toUpperCase() }}
                  </div>
                  <span class="text-sm font-bold text-zinc-800 dark:text-zinc-200 uppercase">{{ item.participant?.name }}</span>
                </div>
                <div v-if="editingParticipantId === item.participant.id" class="flex gap-1.5">
                  <Button size="sm" variant="ghost" class="h-7 px-2 text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300" @click="cancelEditingParticipant">
                    <X class="w-3.5 h-3.5 mr-1" /> Cancelar
                  </Button>
                  <Button size="sm" class="h-7 px-3 bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 hover:bg-zinc-700 dark:hover:bg-zinc-300" :disabled="isSavingJudgeScore" @click="saveJudgeScore(item.participant.id)">
                    <Save class="w-3.5 h-3.5 mr-1" /> {{ isSavingJudgeScore ? 'Guardando…' : 'Guardar' }}
                  </Button>
                </div>
                <Button v-else size="sm" variant="ghost" class="h-7 px-2 text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-300" @click="startEditingParticipant(item)">
                  <Pencil class="w-3.5 h-3.5 mr-1" /> Editar
                </Button>
              </div>

              <!-- View mode -->
              <div v-if="editingParticipantId !== item.participant.id" class="grid grid-cols-3 gap-4 px-4 py-3 text-sm">
                <div>
                  <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 mb-1">Nota</p>
                  <Badge variant="secondary" class="font-black rounded-md px-3 py-1 text-base border-2 shadow-sm" :class="getStatusClasses('active')">
                    {{ Number(item.score.value).toFixed(1) }}
                  </Badge>
                </div>
                <div>
                  <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 mb-1">Promociona</p>
                  <Badge v-if="item.score.promote" class="bg-blue-100 text-blue-700 border-blue-300 dark:bg-blue-950/40 dark:text-blue-300 dark:border-blue-700 font-bold border-2 text-[10px] uppercase tracking-wide">Sí</Badge>
                  <span v-else class="text-zinc-300 dark:text-zinc-600 text-xs font-medium">No</span>
                </div>
                <div>
                  <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 mb-1">Observaciones</p>
                  <p class="text-[12px] text-zinc-500 dark:text-zinc-400 italic leading-relaxed">{{ item.score.notes || 'Sin observaciones.' }}</p>
                </div>
              </div>

              <!-- Edit mode -->
              <div v-else class="px-4 py-4 space-y-4">
                <div class="grid grid-cols-2 gap-4">
                  <div class="space-y-1.5">
                    <Label class="text-[10px] font-bold uppercase tracking-widest text-zinc-500">Nota</Label>
                    <Input
                      v-model.number="judgeEditDraft.value"
                      type="number" min="0" :max="currentRound?.max_score ?? 10" step="0.1"
                      class="text-center font-black text-xl h-12 border-2 border-zinc-200 dark:border-zinc-700 focus:border-zinc-900 dark:focus:border-zinc-100 rounded-xl"
                    />
                  </div>
                  <div class="space-y-1.5">
                    <Label class="text-[10px] font-bold uppercase tracking-widest text-zinc-500">Promocionar</Label>
                    <div
                      class="h-12 rounded-xl border-2 flex items-center justify-between px-4 cursor-pointer transition-all select-none"
                      :class="judgeEditDraft.promote ? 'border-blue-400 bg-blue-50 dark:bg-blue-950/30 dark:border-blue-600' : 'border-zinc-200 dark:border-zinc-700 bg-zinc-50 dark:bg-zinc-800/30'"
                      @click="judgeEditDraft.promote = !judgeEditDraft.promote"
                    >
                      <span class="text-sm font-semibold" :class="judgeEditDraft.promote ? 'text-blue-700 dark:text-blue-300' : 'text-zinc-400'">
                        {{ judgeEditDraft.promote ? 'Sí, promocionar' : 'No promocionar' }}
                      </span>
                      <div class="w-5 h-5 rounded-md border-2 flex items-center justify-center transition-all" :class="judgeEditDraft.promote ? 'bg-blue-500 border-blue-500' : 'border-zinc-300 dark:border-zinc-600'">
                        <Check v-if="judgeEditDraft.promote" class="w-3 h-3 text-white" />
                      </div>
                    </div>
                  </div>
                </div>
                <div class="space-y-1.5">
                  <Label class="text-[10px] font-bold uppercase tracking-widest text-zinc-500">Observaciones</Label>
                  <Textarea
                    v-model="judgeEditDraft.notes"
                    placeholder="Añade observaciones sobre este participante…"
                    rows="3"
                    class="resize-none border-2 border-zinc-200 dark:border-zinc-700 focus:border-zinc-900 dark:focus:border-zinc-100 rounded-xl text-sm"
                  />
                </div>
              </div>
            </div>
          </div>

          <!-- Pending participants -->
          <div v-if="currentJudgeDetails?.pending.length" class="px-6 pb-6 space-y-2" :class="currentJudgeDetails?.scored.length ? 'pt-0' : 'pt-6'">
            <p class="text-[10px] font-bold uppercase tracking-widest text-amber-500 pb-1">Pendientes de calificar</p>
            <div
              v-for="item in currentJudgeDetails.pending"
              :key="item.participant.id"
              class="flex items-center gap-3 px-4 py-3 rounded-xl border border-amber-100 dark:border-amber-900/30 bg-amber-50/50 dark:bg-amber-950/10"
            >
              <div class="w-7 h-7 rounded-lg bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center text-[9px] font-black text-amber-600 dark:text-amber-400">
                {{ item.participant?.name?.substring(0,2).toUpperCase() }}
              </div>
              <span class="text-sm font-semibold text-zinc-700 dark:text-zinc-300 uppercase">{{ item.participant?.name }}</span>
              <span class="ml-auto text-[10px] font-bold text-amber-500 uppercase tracking-widest">Sin calificar</span>
            </div>
          </div>

          <!-- Empty state: judge hasn't scored anything yet -->
          <div v-if="!currentJudgeDetails?.scored.length && !currentJudgeDetails?.pending.length" class="text-center py-12 text-zinc-400">
            <ClipboardCheck class="w-10 h-10 mx-auto mb-3 opacity-30" />
            <p class="text-sm font-medium">No hay participantes en esta ronda</p>
          </div>
        </div>
      </DialogContent>
    </Dialog>

    <Dialog v-model:open="isJudgeMatrixOpen">
      <DialogContent class="max-w-5xl rounded-2xl overflow-hidden p-0 shadow-2xl border-2 border-zinc-100 dark:border-zinc-800 bg-white dark:bg-zinc-950">
        <div class="bg-zinc-50 dark:bg-zinc-900/50 p-8 border-b-2 border-zinc-100 dark:border-zinc-800 flex items-center gap-6">
          <div class="w-12 h-12 bg-zinc-900 dark:bg-zinc-100 rounded-xl flex items-center justify-center shadow-lg border-2 border-transparent">
            <Layers class="w-6 h-6 text-white dark:text-zinc-900"/>
          </div>
          <div>
            <h2 class="text-2xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100 uppercase">Matriz Operativa de Resultados</h2>
            <p class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 mt-1.5 px-0.5">Control integral de dispersión por mesa de jurado</p>
          </div>
        </div>
        <div class="p-8 max-h-[60vh] overflow-auto">
          <div class="rounded-xl border-2 border-zinc-100 dark:border-zinc-800 overflow-hidden shadow-sm bg-white dark:bg-transparent">
            <Table>
              <TableHeader class="bg-zinc-50/50 dark:bg-zinc-900/50">
                <TableRow class="border-zinc-100 dark:border-zinc-800 hover:bg-transparent">
                  <TableHead class="pl-8 py-6 text-[10px] font-bold uppercase tracking-widest text-zinc-400">Aspirante</TableHead>
                  <TableHead v-for="j in currentRoundSummary?.judges" :key="j.user_id" class="text-center text-[10px] font-bold uppercase tracking-widest text-zinc-400 border-x border-zinc-100 dark:border-zinc-800">
                    {{ (j.name || '').split(' ')[0] }}
                  </TableHead>
                  <TableHead class="text-center text-[10px] font-bold uppercase tracking-widest text-blue-500 dark:text-blue-400 border-x border-zinc-100 dark:border-zinc-800">
                    Promo.
                  </TableHead>
                  <TableHead class="text-right pr-8 text-[10px] font-bold uppercase tracking-widest text-zinc-900 dark:text-zinc-100 bg-zinc-100/50 dark:bg-zinc-800/50">
                    Media
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                <TableRow
                  v-for="s in currentRoundSummary?.participant_summaries"
                  :key="s.participant_id"
                  class="border-zinc-50 dark:border-zinc-900 hover:bg-zinc-50/30 dark:hover:bg-zinc-900/30 transition-all last:border-0"
                >
                  <TableCell class="pl-8 py-4 font-bold text-sm text-zinc-900 dark:text-zinc-100">{{ participants.find(p => p.id === s.participant_id)?.name }}</TableCell>
                  <TableCell v-for="j in currentRoundSummary?.judges" :key="j.user_id" class="text-center text-sm font-medium text-zinc-400 border-x border-zinc-50 dark:border-zinc-900">
                    <div class="flex flex-col items-center gap-0.5">
                      <span>{{ s.judge_details?.find((d:any) => d.judge_id === j.user_id)?.value?.toFixed(1) || '-' }}</span>
                      <span v-if="s.judge_details?.find((d:any) => d.judge_id === j.user_id)?.promote" class="text-[9px] text-blue-500 font-bold">▲</span>
                    </div>
                  </TableCell>
                  <TableCell class="text-center border-x border-zinc-50 dark:border-zinc-900">
                    <span v-if="s.promotes > 0" class="text-xs font-black text-blue-600 dark:text-blue-400">{{ s.promotes }}</span>
                    <span v-else class="text-zinc-300 dark:text-zinc-700 text-xs">—</span>
                  </TableCell>
                  <TableCell class="text-right pr-8 font-black text-lg text-zinc-900 dark:text-zinc-100 bg-zinc-50/30 dark:bg-zinc-800/30">
                    {{ s.average.toFixed(2) }}
                  </TableCell>
                </TableRow>
              </TableBody>
            </Table>
          </div>
        </div>
        <div class="p-6 bg-zinc-50 dark:bg-zinc-900 border-t-2 border-zinc-100 dark:border-zinc-800 flex justify-end">
          <Button 
            variant="outline" 
            class="rounded-md h-10 px-8 font-bold text-[10px] uppercase tracking-widest shadow-sm border-2 dark:border-zinc-700" 
            @click="isJudgeMatrixOpen = false"
          >
            Cerrar Matriz
          </Button>
        </div>
      </DialogContent>
    </Dialog>

    <!-- Add Participant Modal: Standard Aesthetic -->
    <Dialog v-model:open="isAddDialogOpen">
      <DialogContent class="max-w-lg rounded-2xl p-0 overflow-hidden shadow-2xl bg-white dark:bg-zinc-950 border-2 border-zinc-200 dark:border-zinc-800 animate-in zoom-in-95 duration-300">
        <DialogHeader class="p-6 border-b-2 border-zinc-50 dark:border-zinc-900 bg-zinc-50/50 dark:bg-zinc-900/50 text-left">
          <div class="flex items-center gap-4">
            <div class="w-10 h-10 bg-zinc-900 dark:bg-zinc-100 rounded-xl flex items-center justify-center shrink-0 shadow-lg">
              <UserPlus class="w-5 h-5 text-white dark:text-zinc-900"/>
            </div>
            <div>
              <DialogTitle class="text-xl font-bold uppercase tracking-tight">Inscribir Participante</DialogTitle>
              <DialogDescription class="text-[10px] text-zinc-400 font-bold uppercase tracking-widest">Registro directo en la categoría actual</DialogDescription>
            </div>
          </div>
        </DialogHeader>

        <div class="p-6 space-y-6">
          <div class="grid gap-2">
            <Label class="text-[10px] font-bold uppercase text-zinc-400 tracking-widest px-1">Nombre Completo / Alias</Label>
            <Input 
              v-model="newParticipant.name" 
              placeholder="Ej. Alexander von Humboldt" 
              class="rounded-md h-11 bg-zinc-50 dark:bg-zinc-900/50 border-2 border-zinc-100 dark:border-zinc-800 font-bold px-4 transition-all focus:ring-2 focus:ring-zinc-900 dark:focus:ring-zinc-100"
            />
          </div>

          <div class="grid grid-cols-2 gap-6">
            <div class="grid gap-2">
              <Label class="text-[10px] font-bold uppercase text-zinc-400 tracking-widest px-1">Documento ID</Label>
              <Input 
                v-model="newParticipant.dni" 
                placeholder="00000000X" 
                class="rounded-md h-10 bg-zinc-50 dark:bg-zinc-900/50 border-2 border-zinc-100 dark:border-zinc-800 px-4 font-medium"
              />
            </div>

            <div class="grid gap-2">
              <Label class="text-[10px] font-bold uppercase text-zinc-400 tracking-widest px-1">Fecha Nacimiento</Label>
              <DatePicker v-model="birthdateValue" class="w-full" />
            </div>

            <div class="grid gap-2">
              <Label class="text-[10px] font-bold uppercase text-zinc-400 tracking-widest px-1">Email</Label>
              <Input 
                v-model="newParticipant.email" 
                placeholder="email@ejemplo.com" 
                class="rounded-md h-10 bg-zinc-50 dark:bg-zinc-900/50 border-2 border-zinc-100 dark:border-zinc-800 px-4 font-medium"
              />
            </div>

            <div class="grid gap-2">
              <Label class="text-[10px] font-bold uppercase text-zinc-400 tracking-widest px-1">Procedencia</Label>
              <Input 
                v-model="newParticipant.country" 
                placeholder="Ej. Madrid / Club ABC" 
                class="rounded-md h-10 bg-zinc-50 dark:bg-zinc-900/50 border-2 border-zinc-100 dark:border-zinc-800 px-4 font-medium"
              />
            </div>
          </div>
        </div>

        <DialogFooter class="p-4 border-t-2 border-zinc-50 dark:border-zinc-900 bg-zinc-50/30 dark:bg-zinc-900/30 gap-3 flex-row justify-end">
          <Button 
            variant="ghost" 
            size="sm"
            class="rounded-md font-bold h-9 px-4 uppercase text-[9px] tracking-widest" 
            @click="isAddDialogOpen = false"
          >
            Cancelar
          </Button>
          <Button 
            size="sm"
            class="bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 rounded-md px-6 h-9 font-bold shadow-md border-2 border-transparent active:scale-95 uppercase text-[9px] tracking-widest transition-all" 
            :disabled="isAdding || !newParticipant.name" 
            @click="handleAddParticipant"
          >
            {{ isAdding ? 'Inscribiendo...' : 'Confirmar Registro' }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>

    <Dialog v-model:open="isPromotionModalOpen">
      <DialogContent class="max-w-2xl rounded-3xl p-0 overflow-hidden shadow-2xl bg-white dark:bg-zinc-950 border-2 border-zinc-200 dark:border-zinc-800 animate-in zoom-in-95 duration-300">
        <DialogHeader class="p-8 border-b-2 border-zinc-50 dark:border-zinc-900 bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 text-left">
          <div class="flex items-center justify-between gap-6">
            <div class="flex items-center gap-5">
              <div class="w-12 h-12 bg-white/20 dark:bg-zinc-900/20 rounded-2xl flex items-center justify-center shadow-inner border border-white/30">
                <Trophy class="w-6 h-6 text-white dark:text-zinc-900" />
              </div>
              <div>
                <DialogTitle class="text-2xl font-black uppercase tracking-tighter">Promoción de Rondas</DialogTitle>
                <DialogDescription class="text-[10px] text-white/70 dark:text-zinc-500 font-bold uppercase tracking-widest mt-1">Selección estratégica de cupos finalistas</DialogDescription>
              </div>
            </div>
            
            <div class="relative w-64 group">
              <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-white/50 dark:text-zinc-400 group-focus-within:text-white dark:group-focus-within:text-zinc-900 transition-colors" />
              <Input 
                v-model="promotionSearchQuery"
                placeholder="Filtrar aspirantes..." 
                class="pl-9 h-10 bg-white/10 dark:bg-zinc-900/10 border-white/20 dark:border-zinc-300 text-xs rounded-xl focus-visible:ring-white dark:focus-visible:ring-zinc-900 transition-all shadow-sm placeholder:text-white/50"
              />
            </div>
          </div>
        </DialogHeader>

        <div class="p-8 space-y-8">
          <div class="grid grid-cols-2 gap-6">
            <div class="flex items-center justify-between p-6 bg-zinc-50 dark:bg-zinc-900 rounded-2xl border-2 border-zinc-100 dark:border-zinc-800 shadow-inner">
               <div class="flex flex-col">
                 <span class="text-sm font-bold tracking-tight text-zinc-900 dark:text-zinc-100">Cupos Siguiente Fase</span>
                 <span class="text-[9px] text-zinc-400 font-bold uppercase tracking-widest mt-1">Límite recomendado</span>
               </div>
               <Input v-model.number="promotionLimit" type="number" class="w-16 text-center font-bold h-10 rounded-xl text-xl border-2 border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-950 shadow-sm"/>
            </div>

            <div class="p-6 bg-zinc-50 dark:bg-zinc-900 rounded-2xl border-2 border-zinc-100 dark:border-zinc-800 flex items-center justify-between shadow-inner">
               <div class="flex flex-col">
                 <span class="text-sm font-bold text-zinc-900 dark:text-zinc-100 tracking-tight">Gran Final</span>
                 <span class="text-[9px] text-zinc-400 font-bold uppercase tracking-widest mt-1">Marcar etapa como definitiva</span>
               </div>
               <Checkbox v-model:checked="isNextRoundFinal" class="w-6 h-6 rounded-md border-2" />
            </div>
          </div>
          
          <div class="mt-4 max-h-[400px] overflow-auto px-1">
            <PromotionTable 
              :data="filteredPromotionParticipants" 
              @update:selection="selectedPromotionIds = $event"
            />
          </div>
        </div>

        <DialogFooter class="p-8 border-t-2 border-zinc-50 dark:border-zinc-900 bg-zinc-50/50 dark:bg-zinc-900/50 flex items-center justify-end gap-4">
          <Button variant="ghost" class="rounded-xl font-bold h-11 px-6 uppercase text-[10px] tracking-widest" @click="isPromotionModalOpen = false">Cancelar</Button>
          <Button 
            class="bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 font-bold h-11 rounded-xl px-10 transition-all active:scale-95 shadow-lg border-2 border-transparent uppercase text-[10px] tracking-widest hover:scale-[1.02] disabled:opacity-30 disabled:cursor-not-allowed" 
            :disabled="isPromoting || selectedPromotionCount === 0" 
            @click="handlePromote"
          >
            <Activity v-if="isPromoting" class="w-4 h-4 mr-2 animate-spin" />
            {{ isPromoting ? 'Promoviendo...' : `Cerrar & Promover ${selectedPromotionCount}` }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
    
    <Drawer v-model:open="isConfigDrawerOpen">
      <DrawerContent v-if="category" class="bg-white dark:bg-zinc-950 border-t-2 border-zinc-100 dark:border-zinc-800">
        <div class="mx-auto w-full max-w-2xl px-6 py-8">
          <DrawerHeader>
            <DrawerTitle>Configuración de Categoría</DrawerTitle>
            <DrawerDescription>Ajusta el nombre y restricciones de edad para los participantes.</DrawerDescription>
          </DrawerHeader>
          
          <div class="p-6 space-y-8">
            <div class="grid gap-3">
              <Label class="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-zinc-400">
                <Medal class="w-3.5 h-3.5" /> Nombre de la Categoría
              </Label>
              <Input 
                v-model="category.name" 
                class="h-12 rounded-xl border-2 border-zinc-100 dark:border-zinc-800 bg-zinc-50/50 dark:bg-zinc-900/40 font-medium px-4 focus-visible:ring-zinc-900 dark:focus-visible:ring-zinc-100 transition-colors"
                placeholder="Ej: Juvenil A"
              />
            </div>
            
            <div class="grid grid-cols-2 gap-6">
              <div class="grid gap-3">
                <Label class="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-zinc-400">
                  <Activity class="w-3.5 h-3.5" /> Edad Mínima
                </Label>
                <NumberField 
                  :model-value="category.min_age ?? 0" 
                  :min="0"
                  :max="100"
                  @update:model-value="category.min_age = $event"
                >
                  <NumberFieldContent>
                    <NumberFieldDecrement />
                    <NumberFieldInput class="h-12 border-2 rounded-xl bg-zinc-50/50 dark:bg-zinc-900/40 font-medium px-4" />
                    <NumberFieldIncrement />
                  </NumberFieldContent>
                </NumberField>
              </div>
              <div class="grid gap-3">
                <Label class="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-zinc-400">
                  <Activity class="w-3.5 h-3.5" /> Edad Máxima
                </Label>
                <NumberField 
                  :model-value="category.max_age ?? 0" 
                  :min="0"
                  :max="100"
                  @update:model-value="category.max_age = $event"
                >
                  <NumberFieldContent>
                    <NumberFieldDecrement />
                    <NumberFieldInput class="h-12 border-2 rounded-xl bg-zinc-50/50 dark:bg-zinc-900/40 font-medium px-4" />
                    <NumberFieldIncrement />
                  </NumberFieldContent>
                </NumberField>
              </div>
            </div>
          </div>
          
          <DrawerFooter class="pt-6 border-t-2 border-zinc-100 dark:border-zinc-800 flex-row justify-end gap-4 px-6 pb-8">
            <Button variant="ghost" class="rounded-xl h-12 px-8 font-bold uppercase text-[11px] tracking-widest" @click="isConfigDrawerOpen = false">Descartar</Button>
            <Button 
              class="bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 rounded-xl h-12 px-12 font-bold shadow-lg border-2 border-transparent active:scale-95 uppercase text-[11px] tracking-widest hover:scale-[1.02] transition-all" 
              @click="handleUpdateCategory"
            >
              Guardar Cambios
            </Button>
          </DrawerFooter>
        </div>
      </DrawerContent>
    </Drawer>
  </div>
</template>
