<script setup lang="ts">
import { Trophy, Users, Layers } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import ContestCard from '~/components/contest/ContestCard.vue'

const authStore = useAuthStore()
const { data, error } = await useFetch('/api/my/contests', {
  server: false,
  headers: computed(() => ({
    Authorization: `Bearer ${authStore.session?.access_token ?? ''}`
  })),
  watch: [computed(() => authStore.session?.access_token)]
})

const contests = computed(() => (data.value as any)?.contests ?? [])

function roleCount(myCategories: any[], role: string) {
  return (myCategories || []).filter((c: any) => c.role === role).length
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

    <!-- Contest grid -->
    <div v-if="contests.length" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-6 gap-4">
      <ContestCard
        v-for="entry in contests"
        :key="entry.contest.id"
        :contest="entry.contest"
        :to="`/my-contests/${entry.contest.slug}`"
        :status-labels="{ draft: 'No empezado' }"
      >
        <template #badges>
          <Badge
            v-if="roleCount(entry.myCategories, 'participant') > 0"
            class="text-[10px] font-bold border-none gap-1 bg-emerald-100 text-emerald-800 dark:bg-emerald-900 dark:text-emerald-300"
          >
            <Trophy class="w-2.5 h-2.5" />
            {{ roleCount(entry.myCategories, 'participant') }} participante
          </Badge>
          <Badge
            v-if="roleCount(entry.myCategories, 'judge') > 0"
            class="text-[10px] font-bold border-none gap-1 bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"
          >
            <Users class="w-2.5 h-2.5" />
            {{ roleCount(entry.myCategories, 'judge') }} jurado
          </Badge>
        </template>
      </ContestCard>
    </div>

    <!-- Empty state -->
    <div v-else-if="!error" class="rounded-xl border-2 border-dashed border-border bg-muted/30 py-16 text-center">
      <Layers class="w-12 h-12 text-muted-foreground/40 mx-auto mb-4" />
      <p class="text-base font-semibold text-muted-foreground">Sin concursos</p>
      <p class="text-sm text-muted-foreground/70 mt-1">No estás inscrito en ningún concurso aún.</p>
    </div>
  </div>
</template>
