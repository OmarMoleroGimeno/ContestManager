<template>
  <div class="p-4 border rounded-lg bg-gray-50">
    <h3 class="font-bold mb-4">Evaluar Participante</h3>
    <form @submit.prevent="submitScore" class="space-y-4">
      <div v-for="criteria in scoreCriteria" :key="criteria.id">
        <label class="block text-sm font-medium text-gray-700">{{ criteria.name }} (Max: {{ criteria.max_value }})</label>
        <input v-model.number="criteriaScores[criteria.id]" type="number" step="0.1" :max="criteria.max_value" required class="mt-1 w-full px-3 py-2 border rounded-md" />
      </div>
      <label class="block text-sm font-medium text-gray-700">Notas Adicionales</label>
      <textarea v-model="notes" class="mt-1 w-full px-3 py-2 border rounded-md"></textarea>
      
      <button type="submit" class="w-full bg-zinc-900 hover:bg-zinc-800 text-white py-2 rounded transition-colors font-medium">Enviar Puntuación</button>
    </form>
  </div>
</template>
<script setup>
import { ref } from 'vue'
const criteriaScores = ref({})
const notes = ref('')
const scoreCriteria = ref([]) // Se cargaría del backend para la ronda actual

const submitScore = async () => {
  // Enviar a POST /api/scores
}
</script>