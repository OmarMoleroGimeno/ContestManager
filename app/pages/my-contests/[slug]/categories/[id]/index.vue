<script setup lang="ts">
import { ArrowLeft, Trophy, MapPin, Clock, CheckCircle2, XCircle, AlertCircle, ChevronRight, Layers, Users } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent } from '@/components/ui/card'
import { getStatusClasses } from '@/utils/styles'

const route = useRoute()
const authStore = useAuthStore()
const { setMeta, clearMeta } = useBreadcrumbMeta()
onUnmounted(() => clearMeta())

const { data, error, pending } = useFetch(`/api/my/contests/${route.params.slug}`, {
  server: false,
  lazy: true,
  headers: computed(() => ({
    Authorization: `Bearer ${authStore.session?.access_token ?? ''}`
  })),
  watch: [computed(() => authStore.session?.access_token)]
})

const contest = computed(() => (data.value as any)?.contest ?? null)
const categories = computed(() => (data.value as any)?.categories ?? [])
const participantEntries = computed(() => (data.value as any)?.participant ?? [])
const rounds = computed(() => (data.value as any)?.rounds ?? [])
const category = computed(() => categories.value.find((c: any) => c.id === route.params.id) ?? null)
const categoryRounds = computed(() => rounds.value.filter((r: any) => r.category_id === route.params.id))

watch(contest, (c) => { if (c?.name) setMeta({ contest: c.name }) }, { immediate: true })
watch(category, (c: any) => { if (c?.name) setMeta({ category: c.name }) }, { immediate: true })

const role = computed<'participant' | 'judge'>(() =>
  participantEntries.value.some((p: any) => p.category_id === route.params.id) ? 'participant' : 'judge'
)

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
  <div class="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500 max-w-[1400px] mx-auto">
    <div v-if="error" class="rounded-lg border border-red-200 bg-red-50 dark:bg-red-950/20 p-4 text-sm text-red-600 dark:text-red-400">
      No se pudo cargar la categoría.
    </div>

    <template v-if="contest && category">
      <!-- Header -->
      <div class="flex items-start gap-3">
        <NuxtLink :to="`/my-contests/${contest.slug}`" class="p-1 rounded-md hover:bg-muted/60 text-muted-foreground hover:text-foreground transition-colors shrink-0 mt-1">
          <ArrowLeft class="w-4 h-4" />
        </NuxtLink>
        <div class="flex-1 min-w-0">
          <div class="flex flex-wrap items-center gap-2">
            <h1 class="text-2xl font-bold tracking-tight">{{ category.name }}</h1>
            <Badge
              class="text-[9px] font-bold uppercase tracking-wide border px-1.5 py-0"
              :class="role === 'judge'
                ? 'bg-blue-50 dark:bg-blue-950/30 text-blue-700 dark:text-blue-300 border-blue-200 dark:border-blue-800'
                : 'bg-emerald-50 dark:bg-emerald-950/30 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800'"
            >
              {{ role === 'judge' ? 'Jurado' : 'Participante' }}
            </Badge>
            <Badge variant="outline" class="text-[10px] font-bold border-2 capitalize" :class="getStatusClasses(category.status)">
              {{ statusLabel(category.status) }}
            </Badge>
          </div>
          <p class="text-sm text-muted-foreground mt-0.5">{{ contest.name }}</p>
          <p v-if="category.description" class="text-sm text-muted-foreground mt-1">{{ category.description }}</p>
        </div>
      </div>

      <!-- Rounds -->
      <div v-if="categoryRounds.length" class="space-y-3">
        <div class="flex items-center gap-2">
          <Layers class="w-4 h-4 text-muted-foreground" />
          <h2 class="text-sm font-bold uppercase tracking-widest text-muted-foreground">Rondas</h2>
        </div>
        <NuxtLink
          v-for="round in categoryRounds"
          :key="round.id"
          :to="`/my-contests/${contest.slug}/categories/${category.id}/rounds/${round.id}`"
          class="block"
        >
          <Card class="group hover:border-emerald-400 transition-all cursor-pointer shadow-sm">
            <CardContent class="p-5">
              <div class="flex items-center gap-4">
                <div class="shrink-0">
                  <component
                    :is="roundStatusIcon(round.status)"
                    class="w-5 h-5"
                    :class="roundStatusClass(round.status)"
                  />
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex flex-wrap items-center gap-2">
                    <span class="font-bold text-base">{{ round.name }}</span>
                    <Badge
                      variant="outline"
                      class="text-[10px] font-bold uppercase tracking-widest border-2"
                      :class="getStatusClasses(round.status)"
                    >
                      {{ statusLabel(round.status) }}
                    </Badge>
                    <Badge v-if="round.is_ranking" class="text-[10px] font-bold bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-300 border-none">
                      Ranking
                    </Badge>
                  </div>
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
                  <div v-else-if="role === 'participant'" class="mt-1 text-xs text-muted-foreground/70 italic">
                    Aún sin turno asignado
                  </div>
                </div>
                <ChevronRight class="w-4 h-4 text-muted-foreground group-hover:text-foreground transition-colors shrink-0" />
              </div>
            </CardContent>
          </Card>
        </NuxtLink>
      </div>

      <div v-else class="rounded-xl border-2 border-dashed border-border bg-muted/30 py-10 text-center">
        <Users class="w-10 h-10 text-muted-foreground/40 mx-auto mb-3" />
        <p class="text-sm text-muted-foreground">{{ role === 'judge' ? 'Las rondas aún no han comenzado en esta categoría.' : 'No hay rondas creadas en esta categoría aún.' }}</p>
      </div>
    </template>
  </div>
</template>
