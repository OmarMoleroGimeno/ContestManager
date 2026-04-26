<script setup lang="ts">
import { computed } from 'vue'
import { parseDate, getLocalTimeZone, type DateValue } from '@internationalized/date'
import { Calendar as CalendarIcon } from 'lucide-vue-next'
import { Calendar } from '@/components/ui/calendar'
import { Button } from '@/components/ui/button'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { cn } from '@/utils'

const props = defineProps<{
  modelValue?: string // "YYYY-MM-DDTHH:mm" or ""
  placeholder?: string
  class?: string
}>()

const emits = defineEmits<{
  (e: 'update:modelValue', value: string): void
}>()

const df = new Intl.DateTimeFormat('es-ES', { day: 'numeric', month: 'short', year: 'numeric' })

const datePart = computed(() => {
  if (!props.modelValue) return undefined
  const d = props.modelValue.split('T')[0]
  if (!d || d.length < 10) return undefined
  try { return parseDate(d) } catch { return undefined }
})

const timePart = computed(() =>
  props.modelValue?.includes('T') ? props.modelValue.split('T')[1] ?? '' : ''
)

const displayLabel = computed(() => {
  if (!datePart.value) return props.placeholder ?? 'Selecciona fecha y hora'
  const dateStr = df.format(datePart.value.toDate(getLocalTimeZone()))
  const t = timePart.value || '00:00'
  return `${dateStr} · ${t}`
})

function updateDate(val: DateValue | undefined) {
  const t = timePart.value || '00:00'
  emits('update:modelValue', val ? `${val.toString()}T${t}` : '')
}

function updateTime(val: string) {
  const d = datePart.value?.toString()
  if (d) emits('update:modelValue', `${d}T${val}`)
}
</script>

<template>
  <Popover>
    <PopoverTrigger as-child>
      <Button
        variant="outline"
        :class="cn(
          'w-full justify-start text-left font-normal text-sm h-8 border-2 border-zinc-200 dark:border-zinc-700 rounded-lg px-2 gap-1.5',
          !datePart && 'text-muted-foreground',
          props.class,
        )"
      >
        <CalendarIcon class="h-3.5 w-3.5 shrink-0 opacity-60" />
        <span class="truncate text-xs">{{ displayLabel }}</span>
      </Button>
    </PopoverTrigger>
    <PopoverContent class="w-auto p-0" align="start">
      <Calendar :model-value="datePart" initial-focus @update:model-value="updateDate" />
      <div class="p-3 border-t border-zinc-100 dark:border-zinc-800 flex items-center gap-2">
        <span class="text-[10px] font-bold uppercase tracking-widest text-zinc-400 shrink-0">Hora</span>
        <input
          type="time"
          :value="timePart"
          class="flex-1 h-8 rounded-md border-2 border-zinc-200 dark:border-zinc-700 bg-transparent px-2 text-sm focus:outline-none focus:border-zinc-400 dark:focus:border-zinc-500"
          @change="updateTime(($event.target as HTMLInputElement).value)"
        />
      </div>
    </PopoverContent>
  </Popover>
</template>
