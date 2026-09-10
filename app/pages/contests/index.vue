<script setup lang="ts">
import { Plus, Layers } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import ContestCard from '~/components/contest/ContestCard.vue'
import { contestsApi } from '~/api/modules/ContestsApi'
import { toast } from 'vue-sonner'

import { useContestStore } from '~/stores/contest'
import { storeToRefs } from 'pinia'

const contestStore = useContestStore()
const { contests } = storeToRefs(contestStore)

await useAsyncData('contests-list', () => contestStore.fetchContests())

const handleDelete = async (id: string) => {
  try {
    await contestStore.deleteContest(id)
    toast.success('Concurso eliminado con éxito')
  } catch (error) {
    console.error(error)
    toast.error('Hubo un error al eliminar el concurso')
  }
}
</script>

<template>
  <div class="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
    <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
      <div class="space-y-1">
        <h1 class="text-3xl font-bold tracking-tight">Mis Concursos</h1>
        <p class="text-muted-foreground">Administra y organiza todas tus competencias desde aquí.</p>
      </div>
      <NuxtLink to="/contests/new">
        <Button class="bg-zinc-900 hover:bg-zinc-800 shadow-md shadow-zinc-900/20 text-white gap-2">
          <Plus class="w-4 h-4" />
          Nuevo Concurso
        </Button>
      </NuxtLink>
    </div>
    
    <div v-if="contests.length" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-6 gap-4">
      <ContestCard
        v-for="c in contests"
        :key="c.id"
        :contest="c"
        :to="`/contests/${c.slug}`"
        deletable
        @delete="handleDelete"
      />
    </div>

    <!-- Empty state -->
    <div v-else class="rounded-xl border-2 border-dashed border-border bg-muted/30 py-16 text-center">
      <Layers class="w-12 h-12 text-muted-foreground/40 mx-auto mb-4" />
      <p class="text-base font-semibold text-muted-foreground">Sin concursos</p>
      <p class="text-sm text-muted-foreground/70 mt-1">Crea tu primer concurso para empezar a organizar competencias.</p>
    </div>
  </div>
</template>