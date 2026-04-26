<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { ArrowLeft, Mail, Calendar, Trophy, ShieldCheck, User as UserIcon } from 'lucide-vue-next'

const route = useRoute()
const authStore = useAuthStore()
const userId = computed(() => route.params.id as string)

const { data, pending, error } = useFetch<any>(() => `/api/profiles/${userId.value}`, {
  server: false,
  lazy: true,
  headers: computed(() => ({
    Authorization: `Bearer ${authStore.session?.access_token ?? ''}`,
  })),
  watch: [computed(() => authStore.session?.access_token), userId],
})

const profile = computed(() => data.value?.profile)
const participations = computed<any[]>(() => data.value?.participations ?? [])

const initials = computed(() => {
  const name = profile.value?.full_name || profile.value?.email || ''
  return name.split(/\s+/).filter(Boolean).map((n: string) => n[0]).join('').toUpperCase().slice(0, 2) || '·'
})

const fmtDate = (iso?: string | null) => {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })
}

const statusVariant = (s: string) => ({
  active: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-400',
  eliminated: 'bg-red-100 text-red-700 dark:bg-red-950/40 dark:text-red-400',
  pending: 'bg-amber-100 text-amber-700 dark:bg-amber-950/40 dark:text-amber-400',
}[s] || 'bg-zinc-100 text-zinc-700 dark:bg-zinc-900 dark:text-zinc-300')
</script>

<template>
  <div class="max-w-5xl mx-auto space-y-6">
    <Button variant="ghost" size="sm" @click="$router.back()" class="gap-2 -ml-2">
      <ArrowLeft class="w-4 h-4" /> Volver
    </Button>

    <div v-if="pending && !data" class="py-24 text-center text-sm text-zinc-500">Cargando perfil...</div>
    <div v-else-if="error" class="py-24 text-center text-sm text-red-500">
      {{ (error as any)?.statusMessage === 'forbidden' ? 'No tienes acceso a este perfil' : 'Error al cargar perfil' }}
    </div>
    <template v-else-if="profile">
      <!-- Header -->
      <Card class="border-2 border-zinc-100 dark:border-zinc-800 rounded-2xl overflow-hidden">
        <CardHeader class="bg-gradient-to-br from-zinc-50 to-white dark:from-zinc-950 dark:to-zinc-900 px-8 py-8">
          <div class="flex items-center gap-6">
            <div class="w-20 h-20 rounded-2xl bg-zinc-200 dark:bg-zinc-800 overflow-hidden flex items-center justify-center text-2xl font-bold text-zinc-600 dark:text-zinc-300 shrink-0">
              <img v-if="profile.avatar_url" :src="profile.avatar_url" :alt="profile.full_name" class="w-full h-full object-cover">
              <span v-else>{{ initials }}</span>
            </div>
            <div class="flex-1 min-w-0">
              <h1 class="text-2xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100 truncate">
                {{ profile.full_name || 'Sin nombre' }}
              </h1>
              <div class="flex items-center gap-3 mt-2 flex-wrap">
                <Badge
                  :class="profile.account_type === 'org_owner'
                    ? 'bg-purple-100 text-purple-700 dark:bg-purple-950/40 dark:text-purple-400 border-0 font-bold uppercase tracking-widest text-[9px]'
                    : 'bg-blue-100 text-blue-700 dark:bg-blue-950/40 dark:text-blue-400 border-0 font-bold uppercase tracking-widest text-[9px]'"
                >
                  <ShieldCheck v-if="profile.account_type === 'org_owner'" class="w-2.5 h-2.5 mr-1" />
                  <UserIcon v-else class="w-2.5 h-2.5 mr-1" />
                  {{ profile.account_type === 'org_owner' ? 'Organizador' : 'Participante' }}
                </Badge>
                <span v-if="profile.email" class="flex items-center gap-1.5 text-xs text-zinc-500">
                  <Mail class="w-3.5 h-3.5" /> {{ profile.email }}
                </span>
                <span class="flex items-center gap-1.5 text-xs text-zinc-500">
                  <Calendar class="w-3.5 h-3.5" /> Registrado {{ fmtDate(profile.created_at) }}
                </span>
              </div>
            </div>
          </div>
        </CardHeader>
      </Card>

      <!-- Participations -->
      <Card class="border-2 border-zinc-100 dark:border-zinc-800 rounded-2xl">
        <CardHeader class="px-8 py-5 border-b-2 border-zinc-50 dark:border-zinc-900">
          <CardTitle class="text-[10px] font-bold uppercase tracking-widest flex items-center gap-2">
            <Trophy class="w-3.5 h-3.5" /> Participaciones ({{ participations.length }})
          </CardTitle>
        </CardHeader>
        <CardContent class="p-0">
          <div v-if="!participations.length" class="px-8 py-12 text-center text-sm text-zinc-500">
            Sin participaciones
          </div>
          <div v-else class="divide-y divide-zinc-100 dark:divide-zinc-900">
            <NuxtLink
              v-for="p in participations"
              :key="p.id"
              :to="p.contest ? `/contests/${p.contest.slug}/categories/${p.category?.id ?? ''}` : '#'"
              class="flex items-center gap-4 px-8 py-4 hover:bg-zinc-50 dark:hover:bg-zinc-900/50 transition-colors"
            >
              <div class="flex-1 min-w-0">
                <div class="text-sm font-bold text-zinc-900 dark:text-zinc-100 truncate">
                  {{ p.contest?.name || '—' }}
                </div>
                <div class="text-xs text-zinc-500 mt-0.5">
                  {{ p.category?.name || 'Sin categoría' }}
                  <span v-if="p.dni"> · {{ p.dni }}</span>
                  <span v-if="p.country"> · {{ p.country }}</span>
                </div>
              </div>
              <Badge :class="statusVariant(p.status) + ' border-0 font-bold uppercase tracking-widest text-[9px]'">
                {{ p.status }}
              </Badge>
              <span class="text-[10px] text-zinc-400 font-mono">{{ fmtDate(p.created_at) }}</span>
            </NuxtLink>
          </div>
        </CardContent>
      </Card>
    </template>
  </div>
</template>
