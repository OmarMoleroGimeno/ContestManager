<script setup lang="ts">
import { columns, type PromotionParticipant } from './columns'
import DataTable from '@/components/ui/data-table/DataTable.vue'

const props = defineProps<{
  data: PromotionParticipant[]
}>()

const emit = defineEmits<{
  (e: 'update:selection', value: string[]): void
}>()

const tableRef = ref()

// Sync selection back to parent
watch(() => tableRef.value?.table?.getFilteredSelectedRowModel().rows, (rows) => {
  if (rows) {
    const selectedIds = rows.map((row: any) => row.original.participant_id)
    emit('update:selection', selectedIds)
  }
}, { deep: true })
</script>

<template>
  <DataTable
    ref="tableRef"
    :columns="columns"
    :data="data"
    search-column="name"
    search-placeholder="Buscar participante por nombre..."
  />
</template>
