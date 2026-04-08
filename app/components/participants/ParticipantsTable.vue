<script setup lang="ts">
import { createColumns } from './columns'
import DataTable from '@/components/ui/data-table/DataTable.vue'
import type { Participant } from '~~/types'

const props = defineProps<{
  data: Participant[]
  flush?: boolean
}>()

const emit = defineEmits<{
  (e: 'update:selection', value: string[]): void
  (e: 'delete', id: string): void
}>()

const tableRef = ref()

const columns = createColumns((id: string) => emit('delete', id))

// Sync selection back to parent
watch(() => tableRef.value?.table?.getFilteredSelectedRowModel().rows, (rows) => {
  if (rows) {
    emit('update:selection', rows.map((row: any) => row.original.id))
  }
}, { deep: true })
</script>

<template>
  <DataTable
    ref="tableRef"
    :columns="columns"
    :data="data"
    :flush="flush"
    :default-page-size="5"
    search-column="name"
    search-placeholder="Buscar participante por nombre..."
  />
</template>
