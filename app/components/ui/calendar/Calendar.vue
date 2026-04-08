<script lang="ts" setup>
import { computed, type Ref } from 'vue'
import { useVModel } from '@vueuse/core'
import { 
  CalendarRoot, 
  type CalendarRootEmits, 
  type CalendarRootProps,
  useForwardPropsEmits 
} from "reka-ui"
import { 
  DateFormatter, 
  getLocalTimeZone, 
  today,
  type DateValue,
} from "@internationalized/date"
import { cn } from '@/utils'
import { 
  Select, 
  SelectContent, 
  SelectItem, 
  SelectTrigger, 
  SelectValue 
} from '@/components/ui/select'
import { 
  CalendarCell, 
  CalendarCellTrigger, 
  CalendarGrid, 
  CalendarGridBody, 
  CalendarGridHead, 
  CalendarGridRow, 
  CalendarHeadCell, 
  CalendarHeader, 
  CalendarHeading, 
  CalendarNextButton, 
  CalendarPrevButton 
} from "."

const props = withDefaults(defineProps<CalendarRootProps & { class?: string }>(), {
  placeholder: undefined,
})

const emits = defineEmits<CalendarRootEmits>()

const placeholder = useVModel(props, 'placeholder', emits, {
  passive: true,
  defaultValue: today(getLocalTimeZone()),
}) as Ref<DateValue>

const delegatedProps = computed(() => {
  const { class: _, placeholder: __, ...delegated } = props
  return delegated
})

const forwarded = useForwardPropsEmits(delegatedProps, emits)

const formatter = new DateFormatter('es-ES', { month: 'long' })

const months = Array.from({ length: 12 }, (_, i) => ({
  value: i + 1,
  label: formatter.format(new Date(2024, i, 1))
}))

const currentYear = today(getLocalTimeZone()).year
const years = Array.from({ length: currentYear - 1900 + 1 }, (_, i) => currentYear - i)

function handleMonthChange(v: string) {
  placeholder.value = placeholder.value.set({ month: Number(v) })
}

function handleYearChange(v: string) {
  placeholder.value = placeholder.value.set({ year: Number(v) })
}
</script>

<template>
  <CalendarRoot
    v-slot="{ grid, weekDays }"
    v-model:placeholder="placeholder"
    :class="cn('p-3', props.class)"
    v-bind="forwarded"
  >
    <CalendarHeader>
      <CalendarPrevButton />
      <CalendarHeading class="flex items-center gap-2">
        <Select :model-value="String(placeholder.month)" @update:model-value="(v) => handleMonthChange(v as string)">
          <SelectTrigger class="h-7 border-none bg-transparent p-1 focus:ring-0">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem v-for="month in months" :key="month.value" :value="String(month.value)">
              {{ month.label }}
            </SelectItem>
          </SelectContent>
        </Select>

        <Select :model-value="String(placeholder.year)" @update:model-value="(v) => handleYearChange(v as string)">
          <SelectTrigger class="h-7 border-none bg-transparent p-1 focus:ring-0">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem v-for="year in years" :key="year" :value="String(year)">
              {{ year }}
            </SelectItem>
          </SelectContent>
        </Select>
      </CalendarHeading>
      <CalendarNextButton />
    </CalendarHeader>

    <div class="flex flex-col gap-y-4 mt-4 sm:flex-row sm:gap-x-4 sm:gap-y-0">
      <CalendarGrid v-for="month in grid" :key="month.value.toString()">
        <CalendarGridHead>
          <CalendarGridRow>
            <CalendarHeadCell
              v-for="day in weekDays" :key="day"
            >
              {{ day }}
            </CalendarHeadCell>
          </CalendarGridRow>
        </CalendarGridHead>
        <CalendarGridBody>
          <CalendarGridRow v-for="(weekDates, index) in month.rows" :key="`weekDate-${index}`" class="mt-2 w-full">
            <CalendarCell
              v-for="weekDate in weekDates"
              :key="weekDate.toString()"
              :date="weekDate"
            >
              <CalendarCellTrigger
                :day="weekDate"
                :month="month.value"
              />
            </CalendarCell>
          </CalendarGridRow>
        </CalendarGridBody>
      </CalendarGrid>
    </div>
  </CalendarRoot>
</template>
