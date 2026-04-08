<script setup lang="ts">
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { ArrowLeft, Users, ListTree, Layers, Activity, Calendar, CalendarClock, Settings2, Trophy, Swords, CalendarRange, Zap, Lock } from 'lucide-vue-next'
import CreateCategoryDialog from '~/components/contest/CreateCategoryDialog.vue'
import EditContestDrawer from '~/components/contest/EditContestDrawer.vue'
import { useContestStore } from '@/stores/contest'
import { storeToRefs } from 'pinia'
import { getStatusClasses, getTypeClasses, getModeClasses, getTierClasses } from '@/utils/styles'

const route = useRoute()
const contestStore = useContestStore()
const { currentContest, categories, participants, rounds } = storeToRefs(contestStore)

await contestStore.fetchContest(route.params.slug as string)

// State management for Edit Drawer
const isDrawerOpen = ref(false)

const getParticipantsCount = (categoryId: string) => {
  return participants.value?.filter(p => p.category_id === categoryId).length || 0
}

const formatDate = (date: string | null | undefined, options: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short', year: 'numeric' }) => {
  if (!date) return 'Sin fecha'
  return new Date(date).toLocaleDateString('es-ES', options)
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
    <!-- Header -->
    <div class="flex items-start justify-between">
      <div class="flex gap-4">
        <div>
          <div class="flex flex-wrap items-center gap-3">
            <NuxtLink to="/contests" class="p-2 hover:scale-110 transition-transform">
              <ArrowLeft class="w-5 h-5 text-muted-foreground" />
            </NuxtLink>
            <h1 class="text-3xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100 uppercase">{{ currentContest?.name || 'Cargando...' }}</h1>
            <div v-if="currentContest" class="flex flex-wrap gap-2">
              <Badge 
                class="capitalize px-3 py-1 font-bold tracking-tight shadow-sm border-2 rounded-md"
                :class="getStatusClasses(currentContest.status)"
              >
                <Activity class="w-3.5 h-3.5 mr-1.5" />
                {{ currentContest.status === 'draft' ? 'Borrador' : currentContest.status }}
              </Badge>
              
              <Badge 
                variant="outline" 
                class="capitalize px-3 py-1 font-semibold border-2 rounded-md"
                :class="getTypeClasses(currentContest.type)"
              >
                <Trophy class="w-3.5 h-3.5 mr-1.5" />
                {{ currentContest.type }}
              </Badge>
              
              <Badge 
                variant="outline" 
                class="capitalize px-3 py-1 font-bold italic transition-all gap-1.5 border-2 rounded-md"
                :class="getModeClasses(contestSettings.mode)"
              >
                <component 
                  :is="contestSettings.mode === 'tournament' ? Swords : CalendarRange" 
                  class="w-3.5 h-3.5" 
                />
                {{ contestSettings.mode === 'tournament' ? 'Torneo' : 'Estándar' }}
              </Badge>
              
              <Badge 
                v-if="contestSettings.mode === 'standard'" 
                variant="secondary" 
                class="px-3 py-1 font-bold text-[9px] uppercase tracking-widest border-2 gap-1 shadow-sm rounded-md"
                :class="getTierClasses(currentContest.is_rounds_dynamic)"
              >
                <component :is="currentContest.is_rounds_dynamic ? Zap : Lock" class="w-2.5 h-2.5" />
                {{ currentContest.is_rounds_dynamic ? 'Dinámico' : 'Fijo' }}
              </Badge>
            </div>
          </div>
          <p class="text-muted-foreground mt-2 max-w-2xl leading-relaxed">{{ currentContest?.description || 'Sin descripción provista para este concurso.' }}</p>
          
        </div>
      </div>
      <div class="flex items-center gap-6">
        <!-- Metadatos -->
        <div v-if="currentContest" class="hidden md:flex flex-wrap items-center gap-6 text-[11px] text-zinc-500 uppercase font-bold tracking-tighter">
          <div class="flex items-center gap-1.5 opacity-70 hover:opacity-100 transition-opacity">
            <CalendarClock class="w-3.5 h-3.5" />
            <span>Creado:</span>
            <span class="text-zinc-900 dark:text-zinc-300">{{ formatDate(currentContest.created_at) }}</span>
          </div>
          <div class="flex items-center gap-1.5 opacity-70 hover:opacity-100 transition-opacity">
            <Calendar class="w-3.5 h-3.5" />
            <span>Duración:</span>
            <span class="text-zinc-900 dark:text-zinc-300">{{ formatDate(currentContest.starts_at, { day: '2-digit', month: '2-digit', year: 'numeric' }) }} - {{ formatDate(currentContest.ends_at, { day: '2-digit', month: '2-digit', year: 'numeric' }) }}</span>
          </div>
        </div>

        <Button 
          variant="outline" 
          size="sm" 
          class="gap-2 bg-zinc-50 text-zinc-700 border-zinc-200 dark:bg-zinc-950/50 dark:text-zinc-400 dark:border-zinc-500/30 hover:bg-zinc-100 dark:hover:bg-zinc-900 font-bold border-2 rounded-md transition-all uppercase tracking-tighter text-[10px]"
          @click="isDrawerOpen = true"
        >
          <Settings2 class="w-4 h-4" /> Configurar
        </Button>
      </div>
    </div>

    <!-- Categories Section (Main) -->
    <div class="space-y-6 pt-4">
      <div class="flex justify-between items-end border-b border-border pb-6">
        <div>
          <h2 class="text-2xl font-bold text-zinc-900 dark:text-zinc-100 flex items-center gap-2">
            <ListTree class="w-6 h-6 text-zinc-500" />
            Categorías
          </h2>
          <p class="text-sm text-muted-foreground mt-1">
            Gestiona las <span class="font-bold text-zinc-900 dark:text-zinc-100">{{ categories?.length || 0 }}</span> categorías y sus <span class="font-bold text-zinc-900 dark:text-zinc-100">{{ participants?.length || 0 }}</span> participantes.
          </p>
        </div>
        <CreateCategoryDialog />
      </div>

      <div v-if="categories?.length" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 pt-2">
        <NuxtLink 
          v-for="cat in categories" 
          :key="cat.id" 
          :to="`/contests/${currentContest?.slug}/categories/${cat.id}`"
        >
          <Card class="group shadow-sm border-border hover:border-zinc-700 transition-all cursor-pointer overflow-hidden relative bg-card">
            <CardHeader class="p-6">
              <div class="flex justify-between items-start mb-6">
                 <div class="p-3 bg-muted rounded-xl group-hover:bg-zinc-900 group-hover:text-white transition-all duration-300 shadow-sm">
                   <ListTree class="w-6 h-6" />
                 </div>
                 <div class="flex flex-col items-end gap-2">
                   <Badge variant="secondary" class="bg-muted text-zinc-700 border-border dark:bg-muted dark:text-zinc-400 font-bold px-2.5 py-1 text-[10px] border-2 rounded-md tracking-tight">
                     {{ getParticipantsCount(cat.id) }} PARTICIPANTES
                   </Badge>
                   <Badge 
                    v-if="currentContest?.is_rounds_dynamic" 
                    class="bg-orange-50 text-orange-700 border-orange-200 dark:bg-orange-950/40 dark:text-orange-400 dark:border-orange-500/30 text-[9px] h-5 border-2 rounded-md font-bold px-2"
                   >
                    DINÁMICO
                   </Badge>
                   <Badge 
                    v-else 
                    class="bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950/40 dark:text-blue-400 dark:border-blue-500/30 text-[9px] h-5 border-2 rounded-md font-bold px-2"
                   >
                    FIJO
                   </Badge>
                 </div>
              </div>
              <div class="space-y-1">
                <CardTitle class="text-xl font-bold group-hover:text-zinc-900 dark:group-hover:text-white transition-colors">{{ cat.name }}</CardTitle>
                <CardDescription class="line-clamp-2 min-h-[40px]">{{ cat.description || 'Sin descripción adicional para esta categoría.' }}</CardDescription>
              </div>
            </CardHeader>
            <div class="absolute bottom-0 left-0 h-1 bg-zinc-900 dark:bg-zinc-100 scale-x-0 group-hover:scale-x-100 transition-transform duration-500 origin-left w-full"></div>
          </Card>
        </NuxtLink>
      </div>

      <Card v-else class="border-2 border-border border-dashed bg-muted/30 h-72 flex items-center justify-center rounded-2xl">
         <CardContent class="flex flex-col items-center justify-center text-center p-0">
            <div class="w-20 h-20 rounded-full bg-card shadow-md border border-border flex items-center justify-center mb-6">
              <ListTree class="w-10 h-10 text-zinc-200" />
            </div>
            <h4 class="font-bold text-2xl text-zinc-900 dark:text-zinc-100 tracking-tight">Crea tu primera categoría</h4>
            <p class="text-zinc-500 text-sm mt-2 max-w-xs px-4">Divide tu concurso en grupos para organizar mejor a los participantes.</p>
            <div class="mt-8">
              <CreateCategoryDialog />
            </div>
         </CardContent>
      </Card>
    </div>

    <!-- Edit Drawer Component -->
    <EditContestDrawer 
      v-if="currentContest"
      v-model:open="isDrawerOpen" 
      :contest="currentContest" 
    />
  </div>
</template>