<script lang="ts" setup>
import type { RangeCalendarRootEmits, RangeCalendarRootProps } from "reka-ui"
import type { HTMLAttributes } from "vue"
import { reactiveOmit } from "@vueuse/core"
import { RangeCalendarRoot, useForwardPropsEmits } from "reka-ui"
import { cn } from '@/utils'
import { RangeCalendarCell, RangeCalendarCellTrigger, RangeCalendarGrid, RangeCalendarGridBody, RangeCalendarGridHead, RangeCalendarGridRow, RangeCalendarHeadCell, RangeCalendarHeader, RangeCalendarNextButton, RangeCalendarPrevButton } from "."
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useVModel } from '@vueuse/core'
import { getLocalTimeZone, today } from '@internationalized/date'

const props = defineProps<RangeCalendarRootProps & { class?: HTMLAttributes["class"] }>()

const emits = defineEmits<RangeCalendarRootEmits>()

const delegatedProps = reactiveOmit(props, "class", "placeholder")

const placeholder = useVModel(props, 'placeholder', emits, {
  passive: true,
  defaultValue: props.defaultPlaceholder ?? today(getLocalTimeZone()),
}) as any

const forwarded = useForwardPropsEmits(delegatedProps, emits)

const months = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
]
const years = Array.from({ length: 10 }, (_, i) => new Date().getFullYear() + i)
</script>

<template>
  <RangeCalendarRoot
    v-slot="{ grid, weekDays }"
    :class="cn('p-3', props.class)"
    v-bind="forwarded"
    v-model:placeholder="placeholder"
  >
    <RangeCalendarHeader>
      <RangeCalendarPrevButton />
      <div v-if="grid && grid.length > 0" class="flex items-center gap-2">
        <Select
          :model-value="grid[0]?.value.month.toString()"
          @update:model-value="(v) => {
            if (!v || !placeholder) return;
            placeholder = placeholder?.set?.({ month: Number(v) }) ?? placeholder
          }"
        >
          <SelectTrigger class="w-[110px] h-8 text-sm">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem v-for="(m, i) in months" :key="i" :value="(i + 1).toString()">
              {{ m }}
            </SelectItem>
          </SelectContent>
        </Select>

        <Select
          :model-value="grid[0]?.value.year.toString()"
          @update:model-value="(v) => {
            if (!v || !placeholder) return;
            placeholder = placeholder?.set?.({ year: Number(v) }) ?? placeholder
          }"
        >
          <SelectTrigger class="w-[85px] h-8 text-sm">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem v-for="y in years" :key="y" :value="y.toString()">
              {{ y }}
            </SelectItem>
          </SelectContent>
        </Select>
      </div>
      <RangeCalendarNextButton />
    </RangeCalendarHeader>

    <div class="flex flex-col gap-y-4 mt-4 sm:flex-row sm:gap-x-4 sm:gap-y-0">
      <RangeCalendarGrid v-for="month in grid" :key="month.value.toString()">
        <RangeCalendarGridHead>
          <RangeCalendarGridRow>
            <RangeCalendarHeadCell
              v-for="day in weekDays" :key="day"
            >
              {{ day }}
            </RangeCalendarHeadCell>
          </RangeCalendarGridRow>
        </RangeCalendarGridHead>
        <RangeCalendarGridBody>
          <RangeCalendarGridRow v-for="(weekDates, index) in month.rows" :key="`weekDate-${index}`" class="mt-2 w-full">
            <RangeCalendarCell
              v-for="weekDate in weekDates"
              :key="weekDate.toString()"
              :date="weekDate"
            >
              <RangeCalendarCellTrigger
                :day="weekDate"
                :month="month.value"
              />
            </RangeCalendarCell>
          </RangeCalendarGridRow>
        </RangeCalendarGridBody>
      </RangeCalendarGrid>
    </div>
  </RangeCalendarRoot>
</template>
