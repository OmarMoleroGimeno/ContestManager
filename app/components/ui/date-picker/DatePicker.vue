<script setup lang="ts">
import { computed } from 'vue'
import {
  DateFormatter,
  type DateValue,
  getLocalTimeZone,
} from '@internationalized/date'

import { Calendar as CalendarIcon } from 'lucide-vue-next'
import { Calendar } from '@/components/ui/calendar'
import { Button } from '@/components/ui/button'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { cn } from '@/utils'

const props = defineProps<{
  modelValue?: DateValue
  placeholder?: string
  class?: string
}>()

const emits = defineEmits<{
  (e: 'update:modelValue', value: DateValue | undefined): void
}>()

const df = new DateFormatter('es-ES', {
  dateStyle: 'long',
})

const value = computed({
  get: () => props.modelValue,
  set: (val) => emits('update:modelValue', val),
})
</script>

<template>
  <Popover>
    <PopoverTrigger as-child>
      <Button
        variant="outline"
        :class="cn(
          'w-full justify-start text-left font-normal',
          !value && 'text-muted-foreground',
          props.class,
        )"
      >
        <CalendarIcon class="mr-2 h-4 w-4" />
        {{ value ? df.format(value.toDate(getLocalTimeZone())) : (props.placeholder ?? "Selecciona una fecha") }}
      </Button>
    </PopoverTrigger>
    <PopoverContent class="w-auto p-0">
      <Calendar v-model="value" initial-focus />
    </PopoverContent>
  </Popover>
</template>
