<script setup lang="ts">
import { 
  Drawer, 
  DrawerContent, 
  DrawerDescription, 
  DrawerFooter, 
  DrawerHeader, 
  DrawerTitle 
} from '@/components/ui/drawer'
import { 
  Select, 
  SelectContent, 
  SelectItem, 
  SelectTrigger, 
  SelectValue 
} from '@/components/ui/select'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { RangeCalendar } from '@/components/ui/range-calendar'
import {
  NumberField,
  NumberFieldContent,
  NumberFieldDecrement,
  NumberFieldIncrement,
  NumberFieldInput,
} from '@/components/ui/number-field'
import { Settings2, Save, Target, Plus, Layers, CalendarRange } from 'lucide-vue-next'
import { parseDate } from '@internationalized/date'
import { type DateRange } from 'reka-ui'
import { useContestStore } from '@/stores/contest'
import { toast } from 'vue-sonner'

const props = defineProps<{
  open: boolean
  contest: any
}>()

const emit = defineEmits<{
  'update:open': [value: boolean]
  'updated': []
}>()

const contestStore = useContestStore()
const isUpdating = ref(false)
const drawerRange = ref<DateRange | null>(null)

const editForm = ref({
  name: '',
  description: '',
  type: 'general',
  status: 'draft',
  is_rounds_dynamic: false,
  mode: 'standard',
  rounds_count: 1,
})

// Sincronizar formulario al abrir
watch(() => props.open, (isOpen) => {
  if (isOpen && props.contest) {
    editForm.value = {
      name: props.contest.name || '',
      description: props.contest.description || '',
      type: props.contest.type || 'general',
      status: props.contest.status || 'draft',
      is_rounds_dynamic: props.contest.is_rounds_dynamic || false,
      mode: (props.contest.settings as any)?.mode || 'standard',
      rounds_count: (props.contest.settings as any)?.rounds_count || 1,
    }
    
    if (props.contest.starts_at && props.contest.ends_at) {
      try {
        drawerRange.value = {
          start: parseDate(props.contest.starts_at.split('T')[0]) as any,
          end: parseDate(props.contest.ends_at.split('T')[0]) as any
        }
      } catch (e) {
        drawerRange.value = null
      }
    } else {
      drawerRange.value = null
    }
  }
})

const handleUpdate = async () => {
  // Validación básica
  if (!editForm.value.name.trim()) {
    toast.error('El nombre del concurso es obligatorio')
    return
  }

  isUpdating.value = true
  try {
    const payload: any = {
      name: editForm.value.name,
      description: editForm.value.description,
      type: editForm.value.type as any,
      status: editForm.value.status as any,
      is_rounds_dynamic: editForm.value.is_rounds_dynamic,
      settings: {
        ...(props.contest.settings as any || {}),
        mode: editForm.value.mode,
        rounds_count: editForm.value.rounds_count,
      }
    }
    
    if (drawerRange.value?.start) {
      payload.starts_at = drawerRange.value.start.toString()
    }
    if (drawerRange.value?.end) {
      payload.ends_at = drawerRange.value.end.toString()
    }

    const promise = contestStore.updateContest(payload)
    
    toast.promise(promise, {
      loading: 'Actualizando parámetros del concurso...',
      success: 'Configuración actualizada correctamente',
      error: 'Error al actualizar el concurso'
    })

    await promise
    emit('updated')
    emit('update:open', false)
  } catch (error) {
    console.error('Update failed:', error)
  } finally {
    isUpdating.value = false
  }
}

const handleOpenAutoFocus = (e: Event) => {
  e.preventDefault()
  setTimeout(() => {
    const input = document.getElementById('name')
    if (input) input.focus()
  }, 50)
}
</script>

<template>
  <Drawer :open="open" @update:open="emit('update:open', $event)">
    <DrawerContent @open-auto-focus="handleOpenAutoFocus">
      <div class="mx-auto w-full max-w-4xl">
        <DrawerHeader>
          <DrawerTitle>Configuración Global</DrawerTitle>
          <DrawerDescription>Modifica los parámetros básicos del concurso.</DrawerDescription>
        </DrawerHeader>
        
        <div class="p-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
            <!-- Columna Izquierda: Identificación y Parámetros -->
            <div class="space-y-6">
              <div class="grid grid-cols-1 gap-4">
                <!-- Modo y Rondas -->
                <div class="space-y-4">
                  <div class="grid gap-2">
                    <Label class="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-zinc-400">
                      <Target class="w-3.5 h-3.5" /> Modo del Concurso
                    </Label>
                    <Select v-model="editForm.mode" :modal="false">
                      <SelectTrigger class="h-10 border-2">
                        <SelectValue placeholder="Selecciona el modo">
                          {{ editForm.mode === 'standard' ? 'Estándar' : editForm.mode === 'tournament' ? 'Torneo' : '' }}
                        </SelectValue>
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="standard">
                          <div class="flex flex-col items-start gap-0.5 py-1">
                            <span class="font-bold">Estándar</span>
                            <span class="text-[10px] text-muted-foreground">Formato tradicional de concurso.</span>
                          </div>
                        </SelectItem>
                        <SelectItem value="tournament">
                          <div class="flex flex-col items-start gap-0.5 py-1">
                            <span class="font-bold">Torneo</span>
                            <span class="text-[10px] text-muted-foreground">Eliminatorias directas.</span>
                          </div>
                        </SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  <!-- Numero de Rondas (Ahora debajo de Modo) -->
                  <transition 
                    enter-active-class="transition duration-300 ease-out" 
                    enter-from-class="transform -translate-y-2 opacity-0" 
                    enter-to-class="transform translate-y-0 opacity-100"
                  >
                    <div v-if="editForm.mode === 'standard' && !editForm.is_rounds_dynamic" class="grid gap-2">
                      <Label for="roundsCount" class="flex items-center gap-2 text-[10px] font-bold uppercase tracking-wider text-zinc-500">
                        <Plus class="w-3 h-3" /> Número de Rondas
                      </Label>
                      <NumberField 
                        id="roundsCount" 
                        v-model="editForm.rounds_count" 
                        :min="1" 
                        :max="20"
                      >
                        <NumberFieldContent>
                          <NumberFieldDecrement />
                          <NumberFieldInput 
                             class="h-10 px-3 text-sm bg-muted/40 border-2 border-border font-bold text-center" 
                          />
                          <NumberFieldIncrement />
                        </NumberFieldContent>
                      </NumberField>
                    </div>
                  </transition>
                </div>

                <!-- Nombre y Descripción -->
                <div class="grid gap-4 pt-2">
                  <div class="grid gap-2">
                    <Label for="name" class="text-xs font-bold uppercase tracking-wider text-zinc-400">Nombre del Concurso</Label>
                    <Input id="name" v-model="editForm.name" class="h-10 border-2" placeholder="Ej. Mi Concurso de Baile" />
                  </div>
                  <div class="grid gap-2">
                    <Label for="description" class="text-xs font-bold uppercase tracking-wider text-zinc-400">Descripción</Label>
                    <Textarea id="description" v-model="editForm.description" rows="3" class="text-sm border-2 resize-none" placeholder="Cuenta de qué trata este concurso..." />
                  </div>
                </div>

                <!-- Estado y Tipo -->
                <div class="grid grid-cols-2 gap-4">
                  <div class="grid gap-2">
                    <Label for="status" class="text-xs font-bold uppercase tracking-wider text-zinc-400">Estado</Label>
                    <Select v-model="editForm.status" :modal="false">
                      <SelectTrigger id="status" class="h-10 border-2">
                        <SelectValue placeholder="Estado" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="draft">Borrador</SelectItem>
                        <SelectItem value="active">Activo</SelectItem>
                        <SelectItem value="finished">Finalizado</SelectItem>
                        <SelectItem value="cancelled">Cancelado</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div class="grid gap-2">
                    <Label for="type" class="text-xs font-bold uppercase tracking-wider text-zinc-400">Tipo</Label>
                    <Select v-model="editForm.type" :modal="false">
                      <SelectTrigger id="type" class="h-10 border-2">
                        <SelectValue placeholder="Tipo" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="music">Música</SelectItem>
                        <SelectItem value="dance">Baile</SelectItem>
                        <SelectItem value="general">General</SelectItem>
                        <SelectItem value="libre">Libre</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              </div>
            </div>

            <!-- Columna Derecha: Configuración Técnica y Fechas -->
            <div class="space-y-8">
              <!-- Estructura (Movida a la derecha) -->
              <transition 
                 enter-active-class="transition duration-300 ease-out" 
                 enter-from-class="transform translate-x-4 opacity-0" 
                 enter-to-class="transform translate-x-0 opacity-100"
              >
                <div v-if="editForm.mode === 'standard'" class="grid gap-3">
                   <Label class="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-muted-foreground">
                     <Layers class="w-3.5 h-3.5" /> Configuración de Estructura
                   </Label>
                   <div class="grid grid-cols-2 gap-1 p-1.5 bg-muted rounded-xl border-2 border-border shadow-inner">
                     <button 
                       type="button"
                       :class="[
                         'text-[10px] py-2.5 rounded-lg transition-all font-bold uppercase tracking-widest',
                         !editForm.is_rounds_dynamic ? 'bg-card border border-border shadow-lg' : 'text-muted-foreground hover:text-foreground'
                       ]"
                       @click="editForm.is_rounds_dynamic = false"
                     >
                       Fija
                     </button>
                     <button 
                       type="button"
                       :class="[
                         'text-[10px] py-2.5 rounded-lg transition-all font-bold uppercase tracking-widest',
                         editForm.is_rounds_dynamic ? 'bg-card border border-border shadow-lg' : 'text-muted-foreground hover:text-foreground'
                       ]"
                       @click="editForm.is_rounds_dynamic = true"
                     >
                       Dinámica
                     </button>
                   </div>
                   <p class="text-[10px] text-muted-foreground italic px-1">
                     {{ editForm.is_rounds_dynamic ? 'Las rondas se crean sobre la marcha según la participación.' : 'Define un número exacto de rondas antes de comenzar.' }}
                   </p>
                </div>
              </transition>

              <!-- Calendario -->
              <div class="grid gap-3">
                <Label class="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-zinc-400">
                  <CalendarRange class="w-3.5 h-3.5" /> Duración del Concurso
                </Label>
                <div class="border-2 rounded-2xl p-4 bg-muted/40 border-border flex justify-center shadow-sm w-fit mx-auto">
                  <RangeCalendar :model-value="(drawerRange as any)" @update:model-value="drawerRange = $event" class="shadow-none border-none" />
                </div>
              </div>
            </div>
          </div>
        </div>

        <DrawerFooter class="flex flex-row justify-end border-t gap-3 p-6 pt-4">
          <Button variant="outline" @click="emit('update:open', false)" class="text-[10px] font-bold uppercase tracking-widest px-6 bg-zinc-50 dark:bg-zinc-900 hover:bg-zinc-100 dark:hover:bg-zinc-800 border-2 rounded-md">Cerrar</Button>
          <Button class="bg-zinc-900 dark:bg-zinc-100 text-white dark:text-zinc-900 hover:bg-zinc-800 dark:hover:bg-zinc-200 gap-2 text-[10px] font-bold uppercase tracking-widest px-6 border-2 border-border rounded-md" :disabled="isUpdating" @click="handleUpdate">
            <Save class="w-4 h-4" />
            {{ isUpdating ? 'Guardando...' : 'Guardar Cambios' }}
          </Button>
        </DrawerFooter>
      </div>
    </DrawerContent>
  </Drawer>
</template>
