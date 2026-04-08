import { h } from 'vue'
import type { ColumnDef } from '@tanstack/vue-table'
import type { Participant } from '~~/types'
import { Checkbox } from '@/components/ui/checkbox'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import { ArrowUpDown, ArrowUp, ArrowDown, Trash2 } from 'lucide-vue-next'

export const createColumns = (onDelete: (id: string) => void): ColumnDef<Participant>[] => [
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
    header: ({ column }) => {
      const sorted = column.getIsSorted()
      return h(Button, {
        variant: 'ghost',
        class: 'px-0 font-bold text-xs uppercase tracking-wider text-zinc-500 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 hover:bg-transparent gap-1.5',
        onClick: () => column.toggleSorting(column.getIsSorted() === 'asc'),
      }, () => [
        'Participante',
        sorted === 'asc'
          ? h(ArrowUp, { class: 'w-3 h-3' })
          : sorted === 'desc'
            ? h(ArrowDown, { class: 'w-3 h-3' })
            : h(ArrowUpDown, { class: 'w-3 h-3 opacity-40' }),
      ])
    },
    cell: ({ row }) => {
      const name = row.getValue('name') as string
      const email = row.original.email
      return h('div', { class: 'flex items-center gap-3 py-1' }, [
        h(Avatar, { class: 'h-8 w-8 rounded-lg border-2 border-zinc-100 dark:border-zinc-800' },
          () => h(AvatarFallback, { class: 'text-[10px] font-bold bg-zinc-100 dark:bg-zinc-900' }, () => name.substring(0, 2).toUpperCase())
        ),
        h('div', { class: 'flex flex-col' }, [
          h('span', { class: 'text-sm font-bold text-zinc-900 dark:text-zinc-100 leading-tight' }, name),
          h('span', { class: 'text-[10px] text-zinc-400 font-medium truncate max-w-[160px]' }, email || 'Sin email'),
        ]),
      ])
    },
    enableSorting: true,
  },
  {
    accessorKey: 'dni',
    header: 'ID / DNI',
    cell: ({ row }) => {
      const dni = row.getValue('dni') as string | null
      return h('span', { class: 'font-mono text-[10px] font-bold px-2 py-0.5 rounded bg-zinc-100 dark:bg-zinc-900 text-zinc-500' }, dni || 'PENDIENTE')
    },
    enableSorting: false,
  },
  {
    id: 'actions',
    header: '',
    cell: ({ row }) => h('div', { class: 'flex justify-end' },
      h(Button, {
        variant: 'ghost',
        size: 'icon',
        class: 'h-7 w-7 text-zinc-300 dark:text-zinc-600 hover:text-red-500 transition-colors',
        onClick: (e: MouseEvent) => { e.stopPropagation(); onDelete(row.original.id) },
      }, () => h(Trash2, { class: 'w-3.5 h-3.5' }))
    ),
    enableSorting: false,
  },
]
