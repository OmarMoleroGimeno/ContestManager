<script setup lang="ts">
import { ref } from 'vue'
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { MoreHorizontal, CalendarClock, Users, Trash, AlertTriangle } from 'lucide-vue-next'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog'

const props = defineProps({
  contest: { type: Object, required: true }
})

const emit = defineEmits<{
  (e: 'delete', id: string): void
}>()

const isDeleteDialogOpen = ref(false)

const getStatusColor = (status: string) => {
  switch(status) {
    case 'active': return 'bg-emerald-100 text-emerald-800 dark:bg-emerald-900 dark:text-emerald-300'
    case 'draft': return 'bg-zinc-100 text-zinc-800 dark:bg-zinc-800 dark:text-zinc-300'
    case 'finished': return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300'
    case 'cancelled': return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300'
    default: return 'bg-zinc-100 text-zinc-800'
  }
}
</script>

<template>
  <Card class="group overflow-hidden border-border dark:shadow-none hover:shadow-lg transition-all duration-300 hover:border-zinc-700 bg-card">
    <CardHeader class="pb-3 border-b border-border bg-muted/30">
      <div class="flex justify-between items-start">
        <div class="space-y-1">
          <Badge :class="getStatusColor(contest.status)" class="capitalize border-none shadow-none font-medium text-xs mb-1">
            {{ contest.status }}
          </Badge>
          <CardTitle class="text-lg font-bold group-hover:text-foreground transition-colors">{{ contest.name }}</CardTitle>
          <CardDescription class="line-clamp-2 text-sm h-10">{{ contest.description || 'Sin descripción' }}</CardDescription>
        </div>

        <AlertDialog v-model:open="isDeleteDialogOpen">
          <AlertDialogTrigger asChild>
            <Button variant="ghost" size="icon" class="h-8 w-8 text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors">
              <Trash class="w-4 h-4" />
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent class="border-border">
            <AlertDialogHeader>
              <div class="flex items-center gap-3">
                <div class="p-2 bg-destructive/10 rounded-full h-fit">
                  <AlertTriangle class="w-5 h-5 text-destructive" />
                </div>
                <AlertDialogTitle>¿Estás completamente seguro?</AlertDialogTitle>
              </div>
              <AlertDialogDescription class="pt-2 text-zinc-600 dark:text-zinc-400">
                Esta acción es irreversible. Al eliminar el concurso <strong class="text-zinc-900 dark:text-zinc-100">"{{ contest.name }}"</strong> se borrarán todos los datos asociados de forma permanente.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel class="h-9">Cancelar</AlertDialogCancel>
              <AlertDialogAction 
                @click="emit('delete', contest.id)" 
                class="h-9 bg-red-600 hover:bg-red-700 text-white shadow-md shadow-red-600/20"
              >
                Eliminar permanentemente
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </div>
    </CardHeader>
    <CardContent class="py-4">
      <div class="flex items-center justify-between text-sm text-muted-foreground">
        <div class="flex items-center gap-1.5">
          <CalendarClock class="w-4 h-4" />
          <span>{{ new Date(contest.created_at).toLocaleDateString('es-ES') }}</span>
        </div>
        <div class="flex items-center gap-1.5">
          <Users class="w-4 h-4" />
          <span class="capitalize">{{ contest.type }}</span>
        </div>
      </div>
    </CardContent>
    <CardFooter class="pt-0 pb-4 px-6 flex gap-3">
      <NuxtLink :to="`/contests/${contest.slug}`" class="w-full">
        <Button class="w-full bg-zinc-900 hover:bg-zinc-800 text-white transition-all shadow-sm">
          Administrar
        </Button>
      </NuxtLink>
    </CardFooter>
  </Card>
</template>