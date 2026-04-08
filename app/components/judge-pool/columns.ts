import { h } from 'vue'
import type { ColumnDef } from '@tanstack/vue-table'
import type { JudgePoolMember } from '~~/types'
import { Checkbox } from '@/components/ui/checkbox'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'

export const columns: ColumnDef<JudgePoolMember>[] = [
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
    accessorKey: 'full_name',
    header: 'Jurado',
    cell: ({ row }) => {
      const name = row.getValue('full_name') as string
      const email = row.original.email
      return h('div', { class: 'flex items-center gap-3 py-1' }, [
        h(Avatar, { class: 'h-8 w-8 rounded-lg border-2 border-zinc-100 dark:border-zinc-800' }, 
          () => h(AvatarFallback, { class: 'text-[10px] font-bold bg-zinc-100 dark:bg-zinc-900' }, () => name.substring(0, 2).toUpperCase())
        ),
        h('div', { class: 'flex flex-col' }, [
          h('span', { class: 'text-sm font-bold text-zinc-900 dark:text-zinc-100 leading-tight' }, name),
          h('span', { class: 'text-[10px] text-zinc-400 font-medium truncate max-w-[150px]' }, email || 'Sin email')
        ])
      ])
    },
  },
  {
    accessorKey: 'specialty',
    header: 'Especialidad',
    cell: ({ row }) => {
      const specialty = row.getValue('specialty') as string
      return specialty ? h(Badge, { variant: 'outline', class: 'text-[9px] uppercase font-bold py-0' }, () => specialty) : '-'
    },
  },
]
