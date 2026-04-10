<script setup lang="ts">
import { Trophy, Users, Calendar, Activity } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { getStatusClasses, getTypeClasses } from '@/utils/styles'

const authStore = useAuthStore()
const { data, error } = await useFetch('/api/my/contests', {
  server: false,
  headers: computed(() => ({
    Authorization: `Bearer ${authStore.session?.access_token ?? ''}`
  }))
})

const asParticipant = computed(() => (data.value as any)?.asParticipant ?? [])
const asJudge = computed(() => (data.value as any)?.asJudge ?? [])

function formatDate(date: string | null) {
  if (!date) return 'Sin fecha'
  return new Date(date).toLocaleDateString('es-ES', { day: 'numeric', month: 'short', year: 'numeric' })
}

function statusLabel(status: string) {
  const map: Record<string, string> = { draft: 'Borrador', active: 'Activo', finished: 'Finalizado', cancelled: 'Cancelado' }
  return map[status] ?? status
}
</script>

<template>
  <div class="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-500">
    <!-- Header -->
    <div>
      <h1 class="text-3xl font-bold tracking-tight">Mis Concursos</h1>
      <p class="text-muted-foreground mt-1">Los concursos en los que participas o evalúas como jurado.</p>
    </div>

    <!-- Error -->
    <div v-if="error" class="rounded-lg border border-red-200 bg-red-50 dark:bg-red-950/20 p-4 text-sm text-red-600 dark:text-red-400">
      No se pudo cargar la información. Intenta recargar la página.
    </div>

    <!-- As Participant -->
    <section class="space-y-4">
      <div class="flex items-center gap-2">
        <div class="w-8 h-8 rounded-lg bg-emerald-100 dark:bg-emerald-950/40 flex items-center justify-center">
          <Trophy class="w-4 h-4 text-emerald-600 dark:text-emerald-400" />
        </div>
        <div>
          <h2 class="text-lg font-bold tracking-tight">Como Participante</h2>
          <p class="text-xs text-muted-foreground">Concursos en los que estás inscrito como competidor.</p>
        </div>
        <Badge variant="secondary" class="ml-auto">{{ asParticipant.length }}</Badge>
      </div>

      <div v-if="asParticipant.length" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <NuxtLink
          v-for="entry in asParticipant"
          :key="entry.contest_id + entry.category_id"
          :to="`/my-contests/${entry.contests.slug}`"
          class="block group"
        >
          <Card class="shadow-sm border-border group-hover:border-emerald-400 transition-all cursor-pointer h-full">
            <CardHeader class="pb-3">
              <div class="flex items-start justify-between gap-2">
                <CardTitle class="text-base leading-tight">{{ entry.contests.name }}</CardTitle>
                <Badge
                  class="shrink-0 capitalize text-[10px] px-2 py-0.5 font-bold border-2 rounded-md"
                  :class="getStatusClasses(entry.contests.status)"
                >
                  {{ statusLabel(entry.contests.status) }}
                </Badge>
              </div>
              <CardDescription class="line-clamp-2 mt-1">{{ entry.contests.description || 'Sin descripción.' }}</CardDescription>
            </CardHeader>
            <CardContent class="space-y-3 pt-0">
              <!-- Category -->
              <div class="flex items-center gap-2 text-sm">
                <div class="px-2 py-0.5 rounded bg-muted text-muted-foreground font-medium text-xs">
                  Categoría: {{ entry.categories.name }}
                </div>
                <div class="px-2 py-0.5 rounded bg-emerald-50 dark:bg-emerald-950/30 text-emerald-700 dark:text-emerald-400 font-medium text-xs border border-emerald-200 dark:border-emerald-800">
                  {{ entry.status === 'active' ? 'Activo' : 'Eliminado' }}
                </div>
              </div>
              <!-- Dates -->
              <div class="flex items-center gap-1.5 text-xs text-muted-foreground">
                <Calendar class="w-3.5 h-3.5" />
                {{ formatDate(entry.contests.starts_at) }} — {{ formatDate(entry.contests.ends_at) }}
              </div>
            </CardContent>
          </Card>
        </NuxtLink>
      </div>

      <div v-else class="rounded-xl border-2 border-dashed border-border bg-muted/30 py-12 text-center">
        <Trophy class="w-10 h-10 text-muted-foreground/40 mx-auto mb-3" />
        <p class="text-sm text-muted-foreground">No estás inscrito en ningún concurso como participante.</p>
      </div>
    </section>

    <!-- As Judge -->
    <section class="space-y-4">
      <div class="flex items-center gap-2">
        <div class="w-8 h-8 rounded-lg bg-blue-100 dark:bg-blue-950/40 flex items-center justify-center">
          <Users class="w-4 h-4 text-blue-600 dark:text-blue-400" />
        </div>
        <div>
          <h2 class="text-lg font-bold tracking-tight">Como Jurado</h2>
          <p class="text-xs text-muted-foreground">Concursos en los que tienes rol de evaluador.</p>
        </div>
        <Badge variant="secondary" class="ml-auto">{{ asJudge.length }}</Badge>
      </div>

      <div v-if="asJudge.length" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <NuxtLink
          v-for="entry in asJudge"
          :key="entry.contest_id"
          :to="`/my-contests/${entry.contests.slug}`"
          class="block group"
        >
          <Card class="shadow-sm border-border group-hover:border-blue-400 transition-all cursor-pointer h-full">
            <CardHeader class="pb-3">
              <div class="flex items-start justify-between gap-2">
                <CardTitle class="text-base leading-tight">{{ entry.contests.name }}</CardTitle>
                <Badge
                  class="shrink-0 capitalize text-[10px] px-2 py-0.5 font-bold border-2 rounded-md"
                  :class="getStatusClasses(entry.contests.status)"
                >
                  {{ statusLabel(entry.contests.status) }}
                </Badge>
              </div>
              <CardDescription class="line-clamp-2 mt-1">{{ entry.contests.description || 'Sin descripción.' }}</CardDescription>
            </CardHeader>
            <CardContent class="space-y-3 pt-0">
              <div class="flex items-center gap-2">
                <Badge variant="outline" class="text-xs font-bold border-blue-200 dark:border-blue-800 text-blue-700 dark:text-blue-400">
                  <Activity class="w-3 h-3 mr-1" /> Jurado
                </Badge>
                <Badge
                  variant="outline"
                  class="text-[10px] font-bold capitalize border-2 rounded-md"
                  :class="getTypeClasses(entry.contests.type)"
                >
                  {{ entry.contests.type }}
                </Badge>
              </div>
              <div class="flex items-center gap-1.5 text-xs text-muted-foreground">
                <Calendar class="w-3.5 h-3.5" />
                {{ formatDate(entry.contests.starts_at) }} — {{ formatDate(entry.contests.ends_at) }}
              </div>
            </CardContent>
          </Card>
        </NuxtLink>
      </div>

      <div v-else class="rounded-xl border-2 border-dashed border-border bg-muted/30 py-12 text-center">
        <Users class="w-10 h-10 text-muted-foreground/40 mx-auto mb-3" />
        <p class="text-sm text-muted-foreground">No tienes rol de jurado en ningún concurso actualmente.</p>
      </div>
    </section>
  </div>
</template>
