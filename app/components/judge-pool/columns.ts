import { h } from 'vue'
import type { ColumnDef } from '@tanstack/vue-table'
import type { JudgePoolMember } from '~~/types'
import { Checkbox } from '@/components/ui/checkbox'
import { Badge } from '@/components/ui/badge'
import AvatarCell from '@/components/ui/avatar/AvatarCell.vue'

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
    cell: ({ row }) => h(AvatarCell, {
      name: row.getValue('full_name') as string,
      email: row.original.email,
      avatarUrl: row.original.avatar_url ?? null,
    }),
  },
  {
    accessorKey: 'specialty',
    header: 'Especialidad',
    cell: ({ row }) => {
      const specialty = row.getValue('specialty') as string
      return specialty
        ? h(Badge, { variant: 'outline', class: 'text-[9px] uppercase font-bold py-0' }, () => specialty)
        : h('span', { class: 'text-zinc-400 text-xs italic' }, 'No especificada')
    },
  },
]
