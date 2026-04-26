<script setup lang="ts" generic="TData, TValue">
import type { 
  ColumnDef, 
  ColumnFiltersState,
  SortingState,
  VisibilityState,
} from '@tanstack/vue-table'
import {
  FlexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  useVueTable,
} from '@tanstack/vue-table'

import { ref, watch, computed } from 'vue'
import { valueUpdater, cn } from '@/utils'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'

import { Search } from 'lucide-vue-next'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'

const props = defineProps<{
  columns: ColumnDef<TData, TValue>[]
  data: TData[]
  searchPlaceholder?: string
  searchColumn?: string
  defaultPageSize?: number
  flush?: boolean
  disableRowSelect?: boolean
}>()

const emit = defineEmits<{
  'update:selection': [string[]]
  'row-click': [any]
}>()

const sorting = ref<SortingState>([])
const columnFilters = ref<ColumnFiltersState>([])
const columnVisibility = ref<VisibilityState>({})
const rowSelection = ref({})

const pagination = ref({
  pageIndex: 0,
  pageSize: props.defaultPageSize || 10,
})

const table = useVueTable({
  get data() { return props.data },
  get columns() { return props.columns },
  getCoreRowModel: getCoreRowModel(),
  getPaginationRowModel: getPaginationRowModel(),
  getSortedRowModel: getSortedRowModel(),
  getFilteredRowModel: getFilteredRowModel(),
  onSortingChange: updaterOrValue => valueUpdater(updaterOrValue, sorting),
  onColumnFiltersChange: updaterOrValue => valueUpdater(updaterOrValue, columnFilters),
  onColumnVisibilityChange: updaterOrValue => valueUpdater(updaterOrValue, columnVisibility),
  onRowSelectionChange: updaterOrValue => valueUpdater(updaterOrValue, rowSelection),
  onPaginationChange: updaterOrValue => valueUpdater(updaterOrValue, pagination),
  state: {
    get sorting() { return sorting.value },
    get columnFilters() { return columnFilters.value },
    get columnVisibility() { return columnVisibility.value },
    get rowSelection() { return rowSelection.value },
    get pagination() { return pagination.value },
  },
  initialState: {
    pagination: {
      pageSize: props.defaultPageSize || 10,
    },
  },
})

// Emit selection changes
watch(rowSelection, () => {
  const selectedIds = table.getFilteredSelectedRowModel().rows.map(row => {
    const original = row.original as any
    return original.id || original.participant_id || original.judge_id || original.member_id
  })
  emit('update:selection', selectedIds.filter(Boolean))
}, { deep: true })

// Reset selection when the underlying data changes (e.g. after bulk delete)
// so stale indices don't shift onto the wrong rows
watch(() => props.data.length, () => {
  rowSelection.value = {}
  emit('update:selection', [])
})

// Expose table for external selection access if needed
defineExpose({
  table
})
</script>

<template>
  <div class="w-full">
    <div v-if="searchColumn" :class="cn('flex items-center py-4 px-1', flush && 'px-4 pt-4 pb-3')">
      <div class="relative w-full max-w-sm group">
        <Search class="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-zinc-400 group-focus-within:text-zinc-900 dark:group-focus-within:text-zinc-100 transition-colors" />
        <Input
          class="pl-9 h-10 w-full bg-white dark:bg-zinc-900 border-2 border-zinc-100 dark:border-zinc-800 rounded-xl focus:ring-zinc-500 shadow-sm transition-all duration-200"
          :placeholder="searchPlaceholder || 'Filtrar...'"
          :model-value="table.getColumn(searchColumn)?.getFilterValue() as string"
          @update:model-value="table.getColumn(searchColumn)?.setFilterValue($event)"
        />
      </div>
    </div>
    <div :class="cn(
      'overflow-hidden bg-white dark:bg-zinc-950/50 transition-all duration-300',
      flush ? 'border-b border-zinc-100 dark:border-zinc-800' : 'rounded-2xl border-2 border-zinc-100 dark:border-zinc-800 shadow-sm'
    )">
      <Table>
        <TableHeader>
          <TableRow v-for="headerGroup in table.getHeaderGroups()" :key="headerGroup.id" class="bg-zinc-50/50 dark:bg-zinc-900/30 hover:bg-zinc-50/50 border-b-2 border-zinc-100 dark:border-zinc-800">
            <TableHead v-for="header in headerGroup.headers" :key="header.id" class="h-12 text-zinc-500 dark:text-zinc-400 font-bold text-xs uppercase tracking-wider">
              <FlexRender
                v-if="!header.isPlaceholder" :render="header.column.columnDef.header"
                :props="header.getContext()"
              />
            </TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <template v-if="table.getRowModel().rows?.length">
            <TableRow
              v-for="row in table.getRowModel().rows" :key="row.id"
              :data-state="row.getIsSelected() ? 'selected' : undefined"
              class="group hover:bg-zinc-50 dark:hover:bg-zinc-900/40 transition-colors border-b border-zinc-100 dark:border-zinc-800 cursor-pointer"
              @click="() => { if (disableRowSelect) { emit('row-click', row.original) } else { row.toggleSelected(); emit('row-click', row.original) } }"
            >
              <TableCell v-for="cell in row.getVisibleCells()" :key="cell.id" class="py-4">
                <FlexRender :render="cell.column.columnDef.cell" :props="cell.getContext()" />
              </TableCell>
            </TableRow>
          </template>
          <template v-else>
            <TableRow>
              <TableCell :colspan="columns.length" class="h-32 text-center text-zinc-400 font-medium">
                Sin resultados.
              </TableCell>
            </TableRow>
          </template>
        </TableBody>
      </Table>
    </div>
    
    <div :class="cn('flex items-center justify-between space-x-2 py-6 px-2', flush && 'py-4 px-4')">
      <div class="text-sm text-zinc-500 font-medium flex items-center gap-2">
        <template v-if="!disableRowSelect">
          <span class="inline-flex items-center justify-center w-6 h-6 rounded-full bg-zinc-100 dark:bg-zinc-800 text-zinc-900 dark:text-zinc-100 text-[10px] font-bold">
            {{ table.getFilteredSelectedRowModel().rows.length }}
          </span>
          <span class="text-xs">de {{ table.getFilteredRowModel().rows.length }} seleccionados</span>
        </template>
        <span v-else class="text-xs">{{ table.getFilteredRowModel().rows.length }} resultado(s)</span>
      </div>
      <div class="flex items-center gap-2">
        <Button
          variant="outline"
          size="sm"
          class="h-9 px-4 border-2 border-zinc-100 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-900 transition-all active:scale-95 disabled:opacity-30 rounded-xl font-bold"
          :disabled="!table.getCanPreviousPage()"
          @click="table.previousPage()"
        >
          Anterior
        </Button>
        <Button
          variant="outline"
          size="sm"
          class="h-9 px-4 border-2 border-zinc-100 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-900 transition-all active:scale-95 disabled:opacity-30 rounded-xl font-bold"
          :disabled="!table.getCanNextPage()"
          @click="table.nextPage()"
        >
          Siguiente
        </Button>
      </div>
    </div>
  </div>
</template>

<style scoped>
:deep([data-state=selected]) {
  background-color: rgb(244 244 245 / 0.5);
}
.dark :deep([data-state=selected]) {
  background-color: rgb(39 39 42 / 0.4);
}
</style>
