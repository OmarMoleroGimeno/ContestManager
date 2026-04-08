<template>
  <div class="flex min-h-screen items-center justify-center bg-gray-50">
    <div class="text-center font-bold text-xl text-gray-500">
      Cargando aplicación...
    </div>
  </div>
</template>

<script setup>
import { navigateTo } from '#imports'

// Redirige automáticamente al dashboard al entrar
navigateTo('/dashboard')
</script>