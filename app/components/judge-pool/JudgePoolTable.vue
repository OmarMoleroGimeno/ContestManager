<script setup lang="ts">
import { columns } from './columns'
import DataTable from '@/components/ui/data-table/DataTable.vue'
import type { JudgePoolMember } from '~~/types'

const props = defineProps<{
  data: JudgePoolMember[]
  flush?: boolean
}>()

const emit = defineEmits<{
  (e: 'update:selection', value: string[]): void
}>()

const tableRef = ref()

// Sync selection back to parent
watch(() => tableRef.value?.table?.getFilteredSelectedRowModel().rows, (rows) => {
  if (rows) {
    const selectedIds = rows.map((row: any) => row.original.id)
    emit('update:selection', selectedIds)
  }
}, { deep: true })
</script>

<template>
  <DataTable
    ref="tableRef"
    :columns="columns"
    :data="data"
    :default-page-size="4"
    :flush="flush"
  />
</template>
