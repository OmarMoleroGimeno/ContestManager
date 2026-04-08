<script setup lang="ts">
import { Trophy, Users, Activity, BarChart3 } from 'lucide-vue-next'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import ContestCard from '~/components/contest/ContestCard.vue'

const { data: contests } = await useFetch('/api/contests')
</script>

<template>
  <div class="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
    <div class="flex items-center justify-between">
      <div>
        <h2 class="text-3xl font-bold tracking-tight">Resumen</h2>
        <p class="text-muted-foreground">Bienvenido de nuevo, aquí está el estado de tus concursos.</p>
      </div>
    </div>
    
    <!-- Metrics -->
    <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
      <Card class="shadow-sm">
        <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle class="text-sm font-medium">Concursos Activos</CardTitle>
          <Trophy class="h-4 w-4 text-zinc-900" />
        </CardHeader>
        <CardContent>
          <div class="text-3xl font-bold">{{ contests?.length || 0 }}</div>
          <p class="text-xs text-muted-foreground">+2 recientes</p>
        </CardContent>
      </Card>
      <Card class="shadow-sm">
        <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle class="text-sm font-medium">Participantes</CardTitle>
          <Users class="h-4 w-4 text-emerald-500" />
        </CardHeader>
        <CardContent>
          <div class="text-3xl font-bold">142</div>
          <p class="text-xs text-muted-foreground">En todas las categorías</p>
        </CardContent>
      </Card>
      <Card class="shadow-sm">
        <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle class="text-sm font-medium">Calificaciones</CardTitle>
          <Activity class="h-4 w-4 text-orange-500" />
        </CardHeader>
        <CardContent>
          <div class="text-3xl font-bold">1,893</div>
          <p class="text-xs text-muted-foreground">Registradas esta semana</p>
        </CardContent>
      </Card>
      <Card class="shadow-sm">
        <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle class="text-sm font-medium">Promedio General</CardTitle>
          <BarChart3 class="h-4 w-4 text-blue-500" />
        </CardHeader>
        <CardContent>
          <div class="text-3xl font-bold">8.4</div>
          <p class="text-xs text-muted-foreground">Puntos de un max 10</p>
        </CardContent>
      </Card>
    </div>

    <!-- Recent Contests -->
    <div class="space-y-4">
      <h3 class="text-xl font-bold tracking-tight">Actividad Reciente</h3>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <ContestCard v-for="c in contests" :key="c.id" :contest="c" />
        <div v-if="!contests?.length" class="col-span-full py-12 text-center text-muted-foreground border-2 border-dashed rounded-lg">
          Aún no hay concursos activos. Crea uno para comenzar.
        </div>
      </div>
    </div>
  </div>
</template>