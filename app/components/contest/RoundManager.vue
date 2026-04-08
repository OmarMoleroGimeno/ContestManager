<template>
  <div>
    <h2 class="text-2xl font-bold mb-4">Rondas</h2>
    <div v-if="currentContest?.is_rounds_dynamic" class="mb-4">
      <button @click="createDynamicRound" class="bg-zinc-900 hover:bg-zinc-800 text-white px-4 py-2 rounded transition-colors font-medium">Generar Siguiente Ronda</button>
    </div>
    <ul>
      <li v-for="r in rounds" :key="r.id" class="p-2 border-b">
        {{ r.name }} - Estado: <span class="font-semibold">{{ r.status }}</span>
      </li>
    </ul>
  </div>
</template>
<script setup>
const { currentContest, rounds } = useContest()
const createDynamicRound = async () => {
  // Lógica para endpoint dinámica
}
</script>