import { h } from 'vue'
import type { ColumnDef } from '@tanstack/vue-table'
import { Checkbox } from '@/components/ui/checkbox'

export interface PromotionParticipant {
  participant_id: string
  name: string
  average: number
}

export const columns: ColumnDef<PromotionParticipant>[] = [
  {
    id: 'select',
    header: ({ table }) => h(Checkbox, {
      'modelValue': table.getIsAllRowsSelected() || (table.getIsSomeRowsSelected() && 'indeterminate'),
      'onUpdate:modelValue': (value: any) => table.toggleAllRowsSelected(!!value),
      'ariaLabel': 'Select all',
      'onClick': (e: MouseEvent) => e.stopPropagation(),
    }),
    cell: ({ row }) => h(Checkbox, {
      'modelValue': row.getIsSelected(),
      'onUpdate:modelValue': (value: any) => row.toggleSelected(!!value),
      'ariaLabel': 'Select row',
      'onClick': (e: MouseEvent) => e.stopPropagation(),
    }),
    enableSorting: false,
    enableHiding: false,
  },
  {
    accessorKey: 'name',
    header: 'Aspirante',
    cell: ({ row }) => h('div', { class: 'font-bold text-sm text-zinc-900 dark:text-zinc-100' }, row.getValue('name')),
  },
  {
    accessorKey: 'average',
    header: () => h('div', { class: 'text-right uppercase text-[10px] font-black tracking-widest text-zinc-400' }, 'Promedio'),
    cell: ({ row }) => h('div', { class: 'text-right font-black text-base text-zinc-400 dark:text-zinc-600' }, (row.getValue('average') as number).toFixed(2)),
  },
]
