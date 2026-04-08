<script setup lang="ts">
import { ref, computed } from 'vue'
import {
  Stepper,
  StepperIndicator,
  StepperItem,
  StepperSeparator,
  StepperTitle,
  StepperDescription,
  StepperTrigger
} from '@/components/ui/stepper'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Check, Info, Settings, Flag, Calendar as CalendarIcon } from 'lucide-vue-next'
import { RangeCalendar } from '@/components/ui/range-calendar'
import { DateFormatter, getLocalTimeZone } from '@internationalized/date'
import type { DateRange } from 'reka-ui'
import { cn } from '@/utils'
import { toast } from 'vue-sonner'
import { useContestStore } from '@/stores/contest'
import { 
  Select, SelectContent, SelectGroup, SelectItem, 
  SelectLabel, SelectTrigger, SelectValue 
} from '@/components/ui/select'
import { 
  Trophy, Layers, Target, HelpCircle 
} from 'lucide-vue-next'

definePageMeta({ middleware: 'auth' })

const contestStore = useContestStore()

function handlePromiseClick() {
  toast.promise<{ name: string }>(
    () =>
      new Promise(resolve =>
        setTimeout(() => resolve({ name: 'Event' }), 2000),
      ),
    {
      loading: 'Loading...',
      success: (data: { name: string }) => `${data.name} has been created`,
      error: 'Error',
    },
  )
}

const steps = [
  {
    step: 1,
    title: 'Información Básica',
    description: 'Nombre y detalle del concurso',
    icon: Info,
  },
  {
    step: 2,
    title: 'Detalles y Reglas',
    description: 'Premios y normas a seguir',
    icon: Settings,
  },
  {
    step: 3,
    title: 'Revisión Final',
    description: 'Verifica y publica tu concurso',
    icon: Flag,
  },
]

import type { ContestFormPayload } from '~~/types'

const currentStep = ref(1)

const formData = ref<ContestFormPayload>({
  name: '',
  short_description: '',
  prizes: '',
  rules: '',
  is_rounds_dynamic: true,
  mode: 'standard',
})

const dateRange = ref({
  start: undefined,
  end: undefined,
}) as Ref<DateRange>

const df = new DateFormatter('es-ES', {
  dateStyle: 'medium',
})

const isStep1Valid = computed(() => formData.value.name.trim() !== '' && dateRange.value.start != null && dateRange.value.end != null)
const isStep2Valid = computed(() => (formData.value.prizes || '').trim() !== '' && (formData.value.rules || '').trim() !== '')

const canGoNext = computed(() => {
  if (currentStep.value === 1) return isStep1Valid.value
  if (currentStep.value === 2) return isStep2Valid.value
  return true
})

const canNavigateTo = (targetStep: number) => {
  if (targetStep <= currentStep.value) return true
  if (targetStep === 2) return isStep1Valid.value
  if (targetStep === 3) return isStep1Valid.value && isStep2Valid.value
  return false
}

function handleStepClick(stepNumber: number) {
  if (canNavigateTo(stepNumber)) {
    currentStep.value = stepNumber
  }
}

function nextStep() {
  if (canGoNext.value && currentStep.value < 3) {
    currentStep.value++
  }
}

function prevStep() {
  if (currentStep.value > 1) currentStep.value--
}

async function createContest() {
  const payload = {
    ...formData.value,
    starts_at: dateRange.value.start?.toString(),
    ends_at: dateRange.value.end?.toString(),
  }

  const promise = contestStore.createContest(payload)

  toast.promise(promise, {
    loading: 'Creando concurso en el backend...',
    success: '¡Concurso creado con éxito!',
    error: 'Hubo un error crítico al crear el concurso'
  })

  try {
    const data = await promise
    if (data && data.slug) {
      navigateTo(`/contests/${data.slug}`)
    } else {
      navigateTo('/contests')
    }
  } catch (error) {
    console.error('Failed to create contest:', error)
  }
}
</script>

<template>
  <div class="w-full max-w-5xl mx-auto flex flex-col gap-8 py-8 px-4">
    
    <div class="w-full shrink-0 pt-6">
      <div class="mb-6 flex flex-col items-start gap-4">
        <div class="text-center sm:text-left">
          <h1 class="text-3xl font-extrabold text-foreground tracking-tight">Crear Nuevo Concurso</h1>
          <p class="text-muted-foreground mt-1 text-sm">Sigue los pasos para configurar tu concurso en pocos minutos.</p>
        </div>
      </div>

      <Stepper v-model="currentStep" class="flex w-full items-start gap-2">
        <StepperItem
          v-for="step in steps"
          :key="step.step"
          class="relative flex w-full flex-col items-center justify-center cursor-pointer"
          :step="step.step"
          v-slot="{ state }"
          @click="handleStepClick(step.step)"
        >
          <StepperSeparator
            v-if="step.step !== 3"
            class="absolute left-[calc(50%+20px)] right-[calc(-50%+10px)] top-5 block h-[2px] shrink-0 rounded-full bg-border transition-colors group-data-[state=completed]:bg-primary"
          />

          <StepperTrigger as-child>
            <Button
              :variant="(state || '') === 'completed' || (state || '') === 'active' ? 'default' : 'outline'"
              size="icon"
              class="z-10 rounded-full shrink-0 transition-all duration-200"
              :class="[(state || '') === 'active' ? 'ring-2 ring-ring ring-offset-2 ring-offset-background' : '']"
              :disabled="!canNavigateTo(step.step) && step.step > currentStep"
            >
              <Check v-if="(state || '') === 'completed'" class="w-5 h-5 shrink-0" />
              <component :is="step.icon" v-else class="w-5 h-5 shrink-0" />
            </Button>
          </StepperTrigger>
          <div class="mt-3 flex flex-col items-center text-center">
            <StepperTitle
              :class="[(state || '') === 'active' ? 'text-primary' : 'text-muted-foreground', 'font-semibold transition-colors']"
            >
              {{ step.title }}
            </StepperTitle>
            <StepperDescription
              :class="[(state || '') === 'active' ? 'text-primary' : 'text-muted-foreground', 'text-xs transition-colors hidden sm:block']"
            >
              {{ step.description }}
            </StepperDescription>
          </div>
        </StepperItem>
      </Stepper>
    </div>

    <!-- Bottom Form Area -->
    <div class="bg-card border border-border rounded-2xl shadow-sm flex flex-col relative mb-6">
      <form @submit.prevent="currentStep === 3 ? createContest() : nextStep()" class="flex flex-col justify-between">
        
        <div class="p-8 sm:p-10 relative">
          <!-- Step 1 -->
          <div v-if="currentStep === 1" class="h-full flex flex-col animate-in fade-in slide-in-from-right-4 duration-500">
            <div class="mb-8 space-y-2">
              <h2 class="text-2xl font-bold">Información Básica</h2>
              <p class="text-base text-muted-foreground">Define los detalles principales de tu competición.</p>
            </div>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-10 items-start">
              <!-- Left Col: Strategic Configuration -->
              <div class="space-y-6">
                <div class="space-y-3">
                  <Label for="name" class="text-base font-bold">Nombre del Concurso</Label>
                  <Input id="name" v-model="formData.name" placeholder="Ej. Batalla de Bandas 2026" class="h-12 text-base" />
                </div>
                <div class="space-y-3">
                  <Label for="description" class="text-base font-bold">Descripción Corta</Label>
                  <Textarea id="description" v-model="formData.short_description" placeholder="Introduce una breve descripción sobre el concurso..." class="min-h-[140px] text-base" />
                </div>
              </div>
              
              <!-- Right Col: Logistics -->
              <div class="space-y-6 flex flex-col w-full md:border-l md:border-border md:pl-10">
                <div class="space-y-4">
                  <Label class="text-base font-bold flex items-center gap-2">
                    <CalendarIcon class="w-5 h-5 text-zinc-400" /> Fechas del Concurso
                  </Label>
                  <p class="text-xs text-muted-foreground">Selecciona el rango de días en los que se llevará a cabo el evento.</p>
                  <div class="p-6 bg-white dark:bg-zinc-900/50 rounded-xl shadow-[0_0_1px_rgba(0,0,0,0.1),0_2px_4px_rgba(0,0,0,0.05)] inline-flex justify-center w-full overflow-hidden border border-zinc-100 dark:border-zinc-800">
                    <RangeCalendar
                      v-model="dateRange"
                      :number-of-months="1"
                      class="mx-auto"
                      @update:start-value="(startDate) => dateRange.start = startDate"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Step 2 -->
          <div v-if="currentStep === 2" class="space-y-8 flex flex-col animate-in fade-in slide-in-from-right-4 duration-500">
            <div class="space-y-3">
              <h2 class="text-2xl font-bold">Detalles y Reglas</h2>
              <p class="text-base text-muted-foreground">Establece qué pueden ganar y las condiciones de participación.</p>
            </div>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-10 items-start">
              <!-- Left Col: Strategic -->
              <div class="space-y-8">
                <div class="space-y-6">
                  <div class="space-y-4">
                    <Label class="text-base flex items-center gap-2 font-bold">
                       <Target class="w-5 h-5 text-zinc-400" /> Modo de Competición
                    </Label>
                    <Select v-model="formData.mode">
                      <SelectTrigger class="h-12 text-base">
                        <SelectValue placeholder="Selecciona el modo">
                          {{ formData.mode === 'standard' ? 'Estándar' : formData.mode === 'tournament' ? 'Torneo' : '' }}
                        </SelectValue>
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="standard">
                          <div class="flex flex-col items-start gap-0.5 py-1">
                            <span class="font-bold">Estándar</span>
                            <span class="text-xs text-muted-foreground">Formato tradicional de concurso por categorías.</span>
                          </div>
                        </SelectItem>
                        <SelectItem value="tournament">
                          <div class="flex flex-col items-start gap-0.5 py-1">
                            <span class="font-bold text-blue-600">Torneo (Brackets)</span>
                            <span class="text-xs text-muted-foreground">Eliminatorias directas con emparejamientos automáticos.</span>
                          </div>
                        </SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  <div v-if="formData.mode === 'standard'" class="space-y-4 animate-in fade-in slide-in-from-top-2 duration-300">
                    <Label class="text-base flex items-center gap-2 font-bold">
                       <Layers class="w-5 h-5 text-zinc-400" /> Estructura de Rondas
                    </Label>
                    <div class="grid grid-cols-2 gap-3">
                       <div 
                         @click="formData.is_rounds_dynamic = false"
                         :class="[
                           'p-4 border-2 rounded-xl cursor-pointer transition-all flex flex-col gap-2',
                           !formData.is_rounds_dynamic ? 'border-zinc-900 bg-zinc-50 dark:bg-zinc-900 shadow-md' : 'border-zinc-100 hover:border-zinc-200 bg-white dark:bg-zinc-950'
                         ]"
                       >
                         <span class="text-sm font-bold">Estipuladas</span>
                       </div>
                       <div 
                         @click="formData.is_rounds_dynamic = true"
                         :class="[
                           'p-4 border-2 rounded-xl cursor-pointer transition-all flex flex-col gap-2',
                           formData.is_rounds_dynamic ? 'border-zinc-900 bg-zinc-50 dark:bg-zinc-900 shadow-md' : 'border-zinc-100 hover:border-zinc-200 bg-white dark:bg-zinc-950'
                         ]"
                       >
                         <span class="text-sm font-bold">Dinámicas</span>
                       </div>
                    </div>
                  </div>
                </div>

                <div class="space-y-3 pt-6 border-t border-dashed">
                  <Label for="prizes" class="text-base font-bold">Premios</Label>
                  <Input id="prizes" v-model="formData.prizes" placeholder="Ej. $1,000 MXN para el primer lugar" class="h-12 text-base" />
                </div>
              </div>

              <!-- Right Col: Rules -->
              <div class="space-y-6 md:border-l md:border-border md:pl-10">
                <div class="space-y-3">
                  <Label for="rules" class="text-base font-bold">Reglas Generales</Label>
                  <Textarea id="rules" v-model="formData.rules" placeholder="Ej. Presentar tema original grabado en estudio..." rows="10" class="min-h-[200px] text-base" />
                </div>
              </div>
            </div>
          </div>

          <!-- Step 3 -->
          <div v-if="currentStep === 3" class="space-y-8 flex flex-col animate-in fade-in slide-in-from-right-4 duration-500">
            <div class="space-y-3">
              <h2 class="text-2xl font-bold">Revisión Final</h2>
              <p class="text-base text-muted-foreground">Asegúrate de que todo está correcto antes de publicar el concurso.</p>
            </div>
            <div class="bg-muted p-8 rounded-xl space-y-6 text-base mt-2 border border-border">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                <div>
                  <span class="font-semibold text-muted-foreground block mb-2">Nombre:</span>
                  <p class="font-medium text-foreground text-xl">{{ formData.name || 'No definido' }}</p>
                </div>
                <div>
                  <span class="font-semibold text-muted-foreground block mb-2">Fechas:</span>
                  <p class="text-foreground">
                    <template v-if="dateRange.start && dateRange.end">
                      Del {{ df.format(dateRange.start.toDate(getLocalTimeZone())) }} al {{ df.format(dateRange.end.toDate(getLocalTimeZone())) }}
                    </template>
                    <template v-else>
                      Fechas no definidas
                    </template>
                  </p>
                </div>
              </div>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-8 pt-4 border-t border-border">
                <div>
                  <span class="font-semibold text-muted-foreground block mb-2">Premios:</span>
                  <p class="text-foreground">{{ formData.prizes || 'Sin premios' }}</p>
                </div>
                <div>
                   <span class="font-semibold text-muted-foreground block mb-2">Estructura del Concurso:</span>
                   <div class="flex gap-2">
                     <Badge variant="outline" class="font-bold uppercase tracking-tight">{{ formData.mode === 'tournament' ? 'Torneo / Brackets' : 'Estándar' }}</Badge>
                     <Badge variant="secondary" class="font-bold uppercase tracking-tight text-white bg-zinc-900">
                       {{ formData.is_rounds_dynamic ? 'Dinámico (On-the-fly)' : 'Estipulado (Fijo)' }}
                     </Badge>
                   </div>
                </div>
              </div>
              <div class="pt-4 border-t border-border">
                <span class="font-semibold text-muted-foreground block mb-2">Descripción:</span>
                <p class="text-foreground">{{ formData.short_description || 'Sin descripción' }}</p>
              </div>
              <div class="pt-4 border-t border-border">
                <span class="font-semibold text-muted-foreground block mb-2">Reglas:</span>
                <p class="text-foreground whitespace-pre-wrap">{{ formData.rules || 'Sin reglas' }}</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Controls (Sticky Bottom) -->
        <div class="px-8 sm:px-10 py-6 border-t border-border bg-card flex justify-between items-center z-10 w-full relative rounded-b-2xl">
          <Button type="button" variant="outline" size="lg" @click="prevStep" :disabled="currentStep === 1">
            Atrás
          </Button>
          <Button type="submit" size="lg" v-if="currentStep < 3" :disabled="!canGoNext">
            Siguiente
          </Button>
          <Button type="submit" size="lg" v-else class="bg-zinc-900 hover:bg-zinc-800 text-white border-0 shadow-md shadow-zinc-900/20">
            Crear Concurso
          </Button>
        </div>
      </form>
    </div>
  </div>
</template>