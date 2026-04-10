<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { Plus, Users, Trash2, Mail, GraduationCap, Search, ChevronUp, ChevronDown, ArrowUpDown } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { useContestStore } from '~/stores/contest'
import { storeToRefs } from 'pinia'
import { toast } from 'vue-sonner'


const contestStore = useContestStore()
const { judgePool } = storeToRefs(contestStore)

const isLoading = ref(true)
const isAdding = ref(false)
const searchQuery = ref('')
const selectedOrgId = ref<string | null>(null)

const newJudge = ref({
  full_name: '',
  email: '',
  specialty: ''
})

const isDialogOpen = ref(false)
const sortField = ref<string>('full_name')
const sortDirection = ref<'asc' | 'desc'>('asc')

function toggleSort(field: string) {
  if (sortField.value === field) {
    sortDirection.value = sortDirection.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortField.value = field
    sortDirection.value = 'asc'
  }
}

const sortedJudges = computed(() => {
  const result = [...filteredJudges.value]
  
  result.sort((a: any, b: any) => {
    const aValue = a[sortField.value]?.toLowerCase() || ''
    const bValue = b[sortField.value]?.toLowerCase() || ''
    
    if (aValue < bValue) return sortDirection.value === 'asc' ? -1 : 1
    if (aValue > bValue) return sortDirection.value === 'asc' ? 1 : -1
    return 0
  })
  
  return result
})

async function loadData() {
  isLoading.value = true
  try {
    const organizations = await ($fetch as any)('/api/organizations') as any[]
    if (organizations && organizations.length > 0) {
      selectedOrgId.value = organizations[0].id
      await contestStore.fetchJudgePool(selectedOrgId.value!)
    }
  } catch (error) {
    console.error('Error loading judge pool:', error)
    toast.error('No se pudo cargar el pool de jueces')
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  loadData()
})

const filteredJudges = computed(() => {
  if (!searchQuery.value) return judgePool.value
  const query = searchQuery.value.toLowerCase()
  return judgePool.value.filter(j => 
    j.full_name.toLowerCase().includes(query) || 
    j.email.toLowerCase().includes(query) || 
    j.specialty?.toLowerCase().includes(query)
  )
})

async function handleAddJudge() {
  if (!selectedOrgId.value) return
  if (!newJudge.value.full_name || !newJudge.value.email) {
    toast.error('Por favor, completa los campos obligatorios')
    return
  }

  isAdding.value = true
  try {
    await contestStore.saveToJudgePool(selectedOrgId.value, newJudge.value)
    toast.success('Jurado añadido con éxito')
    newJudge.value = { full_name: '', email: '', specialty: '' }
    isDialogOpen.value = false
  } catch (error) {
    console.error('Error adding judge:', error)
    toast.error('Hubo un error al añadir al jurado')
  } finally {
    isAdding.value = false
  }
}

async function handleDeleteJudge(id: string) {
  if (!selectedOrgId.value) return
  if (!confirm('¿Estás seguro de que quieres eliminar a este jurado del pool?')) return

  try {
    await contestStore.deleteFromJudgePool(selectedOrgId.value, id)
    toast.success('Jurado eliminado correctamente')
  } catch (error) {
    console.error('Error deleting judge:', error)
    toast.error('No se pudo eliminar al jurado')
  }
}
</script>

<template>
  <div class="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
    <!-- Header -->
    <div class="space-y-1">
      <h1 class="text-3xl font-bold tracking-tight">Pool de Jurados</h1>
      <p class="text-muted-foreground">Gestiona la base de datos de jueces de tu organización para asignarlos a concursos.</p>
    </div>

    <!-- Main Content -->
    <Card class="border border-zinc-200 dark:border-zinc-800 shadow-sm overflow-hidden bg-transparent">
      <CardHeader class="pb-3 border-b border-zinc-200 dark:border-zinc-800 bg-muted/50">
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div>
            <CardTitle>Miembros del Pool</CardTitle>
            <CardDescription>Tienes {{ judgePool.length }} jueces registrados actualmente.</CardDescription>
          </div>
          <div class="flex flex-col sm:flex-row items-center gap-3 w-full sm:w-auto">
            <div class="relative w-full sm:w-64">
              <Search class="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
              <Input
                type="search"
                placeholder="Buscar jurado..."
                v-model="searchQuery"
                class="pl-9 h-9 bg-background/50 border border-zinc-200 dark:border-zinc-700 focus-visible:ring-zinc-900"
              />
            </div>
            
            <Dialog v-model:open="isDialogOpen">
              <DialogTrigger as-child>
                <Button size="sm" class="gap-2 bg-card text-foreground border-border border-2 rounded-md transition-all font-bold uppercase tracking-tight text-[10px] px-6 shadow-sm hover:bg-muted">
                  <Plus class="w-4 h-4" />
                  Nuevo Jurado
                </Button>
              </DialogTrigger>
              <DialogContent class="sm:max-w-[425px]">
                <DialogHeader>
                  <DialogTitle>Añadir Nuevo Jurado</DialogTitle>
                  <DialogDescription>
                    Introduce los datos del juez para añadirlo al pool de tu organización.
                  </DialogDescription>
                </DialogHeader>
                <div class="grid gap-6 py-4">
                  <div class="space-y-2">
                    <Label for="name" class="text-sm font-bold">Nombre Completo</Label>
                    <Input id="name" v-model="newJudge.full_name" placeholder="Ej. Juan Pérez" />
                  </div>
                  <div class="space-y-2">
                    <Label for="email" class="text-sm font-bold">Correo Electrónico</Label>
                    <Input id="email" type="email" v-model="newJudge.email" placeholder="juan@ejemplo.com" />
                  </div>
                  <div class="space-y-2">
                    <Label for="specialty" class="text-sm font-bold">Especialidad (Opcional)</Label>
                    <Input id="specialty" v-model="newJudge.specialty" placeholder="Ej. Técnica Vocal, Jazz, etc." />
                  </div>
                </div>
                <DialogFooter>
                  <Button type="button" variant="outline" @click="isDialogOpen = false">Cancelar</Button>
                  <Button :disabled="isAdding" @click="handleAddJudge">
                    {{ isAdding ? 'Añadiendo...' : 'Añadir Jurado' }}
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </div>
        </div>
      </CardHeader>
      <CardContent class="p-0">
        <div v-if="isLoading" class="p-12 flex flex-col items-center justify-center gap-4">
          <div class="h-8 w-8 animate-spin rounded-full border-4 border-zinc-900 border-t-transparent"></div>
          <p class="text-muted-foreground animate-pulse">Cargando jurados...</p>
        </div>
        
        <div v-else-if="filteredJudges.length === 0" class="p-12 text-center space-y-4">
          <div class="w-16 h-16 bg-muted rounded-full flex items-center justify-center mx-auto text-muted-foreground border-2 border-dashed">
            <Users class="w-8 h-8" />
          </div>
          <div>
            <h3 class="text-lg font-semibold">No se encontraron jurados</h3>
            <p class="text-muted-foreground">Comienza añadiendo tu primer jurado al pool para usarlo en tus concursos.</p>
          </div>
          <Button size="sm" @click="isDialogOpen = true" class="mt-2 gap-2 bg-card text-foreground border-border border-2 rounded-md transition-all font-bold uppercase tracking-tight text-[10px] px-6 shadow-sm hover:bg-muted">
            <Plus class="w-4 h-4" />
            Añadir mi primer jurado
          </Button>
        </div>

        <Table v-else>
          <TableHeader>
            <TableRow class="!bg-muted/50 hover:!bg-muted/50 border-b border-zinc-200 dark:border-zinc-800">
              <TableHead 
                class="w-[300px] px-6 text-zinc-900 dark:text-zinc-100 font-bold uppercase tracking-tighter text-[11px] cursor-pointer"
                @click="toggleSort('full_name')"
              >
                <div class="flex items-center">
                  Nombre
                  <component 
                    :is="sortField === 'full_name' ? (sortDirection === 'asc' ? ChevronUp : ChevronDown) : ArrowUpDown" 
                    class="ml-2 h-3.5 w-3.5 opacity-70"
                  />
                </div>
              </TableHead>
              <TableHead 
                class="px-6 text-zinc-900 dark:text-zinc-100 font-bold uppercase tracking-tighter text-[11px] cursor-pointer"
                @click="toggleSort('email')"
              >
                <div class="flex items-center">
                  Email
                  <component 
                    :is="sortField === 'email' ? (sortDirection === 'asc' ? ChevronUp : ChevronDown) : ArrowUpDown" 
                    class="ml-2 h-3.5 w-3.5 opacity-70"
                  />
                </div>
              </TableHead>
              <TableHead 
                class="px-6 text-zinc-900 dark:text-zinc-100 font-bold uppercase tracking-tighter text-[11px] cursor-pointer"
                @click="toggleSort('specialty')"
              >
                <div class="flex items-center">
                  Especialidad
                  <component 
                    :is="sortField === 'specialty' ? (sortDirection === 'asc' ? ChevronUp : ChevronDown) : ArrowUpDown" 
                    class="ml-2 h-3.5 w-3.5 opacity-70"
                  />
                </div>
              </TableHead>
              <TableHead class="text-right px-6 text-zinc-900 dark:text-zinc-100 font-bold uppercase tracking-tighter text-[11px]">Acciones</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            <TableRow v-for="judge in sortedJudges" :key="judge.id" class="group transition-colors border-b border-zinc-200 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-900/50">
              <TableCell class="font-medium px-6 py-4">
                <div class="flex items-center gap-3">
                  <div class="w-9 h-9 rounded-full bg-zinc-100 dark:bg-zinc-800 flex items-center justify-center text-zinc-900 dark:text-zinc-100 font-bold text-xs shadow-sm">
                    {{ judge.full_name?.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase() || '??' }}
                  </div>
                  {{ judge.full_name }}
                </div>
              </TableCell>
              <TableCell class="px-6">
                <div class="flex items-center gap-2 text-muted-foreground">
                  <Mail class="w-4 h-4" />
                  {{ judge.email }}
                </div>
              </TableCell>
              <TableCell class="px-6">
                <div v-if="judge.specialty" class="flex items-center gap-2">
                  <GraduationCap class="w-4 h-4 text-zinc-400" />
                  <span class="text-sm border px-2 py-0.5 rounded-full bg-zinc-50 dark:bg-zinc-900 font-medium">{{ judge.specialty }}</span>
                </div>
                <span v-else class="text-xs text-muted-foreground italic">No especificada</span>
              </TableCell>
              <TableCell class="text-right px-6">
                <Button 
                  variant="ghost" 
                  size="icon" 
                  @click="handleDeleteJudge(judge.id)"
                  class="text-zinc-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-950/20 transition-all opacity-0 group-hover:opacity-100"
                >
                  <Trash2 class="w-4 h-4" />
                </Button>
              </TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </CardContent>
    </Card>

    <!-- Info Section -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6 pt-4">
      <div class="p-6 rounded-2xl bg-gradient-to-br from-zinc-900 to-zinc-800 text-white shadow-lg overflow-hidden relative">
        <div class="relative z-10 space-y-3">
          <h3 class="text-xl font-bold flex items-center gap-2">
            <Users class="w-5 h-5 text-zinc-400" />
            ¿Cómo funciona el Pool?
          </h3>
          <p class="text-zinc-300 text-sm leading-relaxed">
            El pool de jurados es un repositorio centralizado de jueces para tu organización. 
            Al añadir jueces aquí, podrás asignarlos rápidamente a cualquier concurso que crees, 
            ahorrándote tiempo de configuración y manteniendo la consistencia de tus evaluaciones.
          </p>
        </div>
        <div class="absolute -right-8 -bottom-8 opacity-10">
          <Users class="w-48 h-48" />
        </div>
      </div>
      
      <div class="p-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-950 shadow-sm flex flex-col justify-center gap-3">
        <h3 class="text-lg font-bold">Próximos Pasos: Automatización</h3>
        <p class="text-muted-foreground text-sm leading-relaxed">
          Estamos trabajando en una funcionalidad para que los jueces puedan postularse automáticamente
          a tu pool mediante un enlace público, permitiendo escalar tu base de datos de jurados de forma masiva.
        </p>
        <div class="mt-2">
          <Button variant="link" class="p-0 text-zinc-900 dark:text-white font-bold h-auto">Ver hoja de ruta →</Button>
        </div>
      </div>
    </div>
  </div>
</template>
