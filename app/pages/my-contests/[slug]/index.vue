<script setup lang="ts">
import { ArrowLeft, Trophy, Calendar, MapPin, Clock, CheckCircle2, XCircle, AlertCircle, ChevronRight, Layers } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { getStatusClasses } from '@/utils/styles'

const route = useRoute()
const authStore = useAuthStore()

const { data, error } = await useFetch(`/api/my/contests/${route.params.slug}`, {
  server: false,
  headers: computed(() => ({
    Authorization: `Bearer ${authStore.session?.access_token ?? ''}`
  }))
})

const contest = computed(() => (data.value as any)?.contest ?? null)
const participantEntries = computed(() => (data.value as any)?.participant ?? [])
const rounds = computed(() => (data.value as any)?.rounds ?? [])
const member = computed(() => (data.value as any)?.member ?? null)
const isJudge = computed(() => member.value?.role === 'judge')
const categories = computed(() => (data.value as any)?.categories ?? [])

// Group rounds by category
const roundsByCategory = computed(() => {
  const map: Record<string, { category: any; rounds: any[] }> = {}
  
  for (const cat of categories.value) {
    if (!map[cat.id]) {
      map[cat.id] = { category: cat, rounds: [] }
    }
  }
  
  for (const round of rounds.value) {
    if (map[round.category_id]) {
      map[round.category_id].rounds.push(round)
    }
  }
  return Object.values(map)
})

function formatDate(date: string | null, opts: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short', year: 'numeric' }) {
  if (!date) return 'Sin fecha'
  return new Date(date).toLocaleDateString('es-ES', opts)
}

function formatDateTime(date: string | null) {
  if (!date) return 'Sin fecha'
  return new Date(date).toLocaleString('es-ES', {
    day: 'numeric', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit'
  })
}

function statusLabel(status: string) {
  const map: Record<string, string> = {
    draft: 'Borrador', active: 'Activo', finished: 'Finalizado', cancelled: 'Cancelado',
    pending: 'Pendiente', closed: 'Cerrado'
  }
  return map[status] ?? status
}

function roundStatusIcon(status: string) {
  if (status === 'active') return CheckCircle2
  if (status === 'closed') return XCircle
  return AlertCircle
}

function roundStatusClass(status: string) {
  if (status === 'active') return 'text-emerald-600 dark:text-emerald-400'
  if (status === 'closed') return 'text-zinc-500 dark:text-zinc-400'
  return 'text-amber-500 dark:text-amber-400'
}
</script>

<template>
  <div class="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500 max-w-4xl mx-auto">

    <!-- Error -->
    <div v-if="error" class="rounded-lg border border-red-200 bg-red-50 dark:bg-red-950/20 p-4 text-sm text-red-600 dark:text-red-400">
      No se pudo cargar el concurso. Puede que no estés inscrito o el concurso no existe.
    </div>

    <template v-if="contest">
      <!-- Header -->
      <div class="space-y-4">
        <div class="flex items-center gap-3">
          <NuxtLink to="/my-contests" class="p-2 hover:scale-110 transition-transform">
            <ArrowLeft class="w-5 h-5 text-muted-foreground" />
          </NuxtLink>
          <div class="flex-1">
            <div class="flex flex-wrap items-center gap-2">
              <h1 class="text-3xl font-bold tracking-tight uppercase">{{ contest.name }}</h1>
              <Badge
                class="capitalize px-3 py-1 font-bold tracking-tight shadow-sm border-2 rounded-md"
                :class="getStatusClasses(contest.status)"
              >
                {{ statusLabel(contest.status) }}
              </Badge>
            </div>
            <p class="text-muted-foreground mt-1 max-w-2xl">{{ contest.description || 'Sin descripción.' }}</p>
          </div>
        </div>

        <!-- Dates -->
        <div class="flex flex-wrap items-center gap-6 text-sm text-muted-foreground">
          <div class="flex items-center gap-1.5">
            <Calendar class="w-4 h-4" />
            <span>{{ formatDate(contest.starts_at) }} — {{ formatDate(contest.ends_at) }}</span>
          </div>
        </div>
      </div>

      <!-- Participant entries by category -->
      <div v-if="roundsByCategory.length" class="space-y-8">
        <div
          v-for="group in roundsByCategory"
          :key="group.category.id"
          class="space-y-4"
        >
          <!-- Category header -->
          <div class="flex items-center gap-3 border-b border-border pb-3">
            <div class="p-2 rounded-lg bg-emerald-100 dark:bg-emerald-950/40">
              <Layers class="w-4 h-4 text-emerald-600 dark:text-emerald-400" />
            </div>
            <div>
              <h2 class="text-lg font-bold tracking-tight">{{ group.category.name }}</h2>
              <p v-if="group.category.description" class="text-xs text-muted-foreground">{{ group.category.description }}</p>
            </div>
            <Badge
              variant="outline"
              class="ml-auto text-[10px] font-bold border-2 capitalize"
              :class="getStatusClasses(group.category.status)"
            >
              {{ statusLabel(group.category.status) }}
            </Badge>
          </div>

          <!-- Rounds list -->
          <div v-if="group.rounds.length" class="space-y-3">
            <NuxtLink
              v-for="round in group.rounds"
              :key="round.id"
              :to="`/my-contests/${contest.slug}/rounds/${round.id}`"
              class="block"
            >
              <Card class="group hover:border-emerald-400 transition-all cursor-pointer shadow-sm">
                <CardContent class="p-5">
                  <div class="flex items-center gap-4">
                    <!-- Status icon -->
                    <div class="shrink-0">
                      <component
                        :is="roundStatusIcon(round.status)"
                        class="w-5 h-5"
                        :class="roundStatusClass(round.status)"
                      />
                    </div>

                    <!-- Round info -->
                    <div class="flex-1 min-w-0">
                      <div class="flex flex-wrap items-center gap-2">
                        <span class="font-bold text-base">{{ round.name }}</span>
                        <Badge
                          variant="secondary"
                          class="text-[10px] font-bold uppercase tracking-widest"
                          :class="round.status === 'active' ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-400' : ''"
                        >
                          {{ statusLabel(round.status) }}
                        </Badge>
                      </div>

                      <!-- My slot info -->
                      <div v-if="round.my_slot" class="flex flex-wrap items-center gap-4 mt-2 text-sm text-muted-foreground">
                        <div v-if="round.my_slot.order !== null" class="flex items-center gap-1.5">
                          <Trophy class="w-3.5 h-3.5" />
                          <span>Turno #{{ round.my_slot.order }}</span>
                        </div>
                        <div v-if="round.my_slot.scheduled_at" class="flex items-center gap-1.5">
                          <Clock class="w-3.5 h-3.5" />
                          <span>{{ formatDateTime(round.my_slot.scheduled_at) }}</span>
                        </div>
                        <div v-if="round.my_slot.location" class="flex items-center gap-1.5">
                          <MapPin class="w-3.5 h-3.5" />
                          <span>{{ round.my_slot.location }}</span>
                        </div>
                        <Badge
                          v-if="round.my_slot.is_qualified !== null"
                          class="text-[10px] font-bold border-2"
                          :class="round.my_slot.is_qualified ? 'bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950/40 dark:text-emerald-400 dark:border-emerald-800' : 'bg-red-50 text-red-700 border-red-200 dark:bg-red-950/40 dark:text-red-400 dark:border-red-800'"
                        >
                          {{ round.my_slot.is_qualified ? 'Clasificado' : 'Eliminado' }}
                        </Badge>
                      </div>
                      <div v-else class="mt-1 text-xs text-muted-foreground/70 italic">
                        Aún sin turno asignado
                      </div>
                    </div>

                    <!-- Arrow -->
                    <ChevronRight class="w-4 h-4 text-muted-foreground group-hover:text-foreground transition-colors shrink-0" />
                  </div>
                </CardContent>
              </Card>
            </NuxtLink>
          </div>

          <!-- No rounds yet -->
          <div v-else class="rounded-xl border-2 border-dashed border-border bg-muted/30 py-8 text-center">
            <p class="text-sm text-muted-foreground">No hay rondas creadas en esta categoría aún.</p>
          </div>
        </div>
      </div>

      <!-- Judge view (no rounds started yet) -->
      <div v-else-if="isJudge" class="space-y-4">
        <!-- Show categories even if no rounds started -->
        <div v-if="categories.length" class="space-y-4">
          <div
            v-for="cat in categories"
            :key="cat.id"
            class="rounded-xl border-2 border-dashed border-border bg-muted/30 p-6"
          >
            <div class="flex items-center gap-3 mb-2">
              <Layers class="w-5 h-5 text-muted-foreground/60" />
              <h3 class="font-bold text-base">{{ cat.name }}</h3>
              <Badge variant="outline" class="ml-auto text-[10px] font-bold border-2 capitalize" :class="getStatusClasses(cat.status)">
                {{ statusLabel(cat.status) }}
              </Badge>
            </div>
            <p class="text-sm text-muted-foreground">Las rondas de evaluación aún no han comenzado en esta categoría.</p>
          </div>
        </div>
        <div v-else class="rounded-xl border-2 border-dashed border-border bg-muted/30 py-12 text-center">
          <Trophy class="w-10 h-10 text-muted-foreground/40 mx-auto mb-3" />
          <p class="text-sm text-muted-foreground">El organizador aún no ha creado categorías en este concurso.</p>
        </div>
      </div>

      <!-- No participant data and not a judge -->
      <div v-else class="rounded-xl border-2 border-dashed border-border bg-muted/30 py-12 text-center">
        <Trophy class="w-10 h-10 text-muted-foreground/40 mx-auto mb-3" />
        <p class="text-sm text-muted-foreground">No estás inscrito como participante en ninguna categoría de este concurso.</p>
      </div>
    </template>
  </div>
</template>
