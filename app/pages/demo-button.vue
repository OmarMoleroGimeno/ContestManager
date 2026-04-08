<script setup lang="ts">
import MotionButton from '@/components/ui/MotionButton.vue'
</script>

<template>
  <div class="flex flex-col items-center justify-center min-h-screen bg-zinc-50 dark:bg-zinc-950 p-8 space-y-12">
    <div class="text-center space-y-4">
      <h1 class="text-4xl font-black tracking-tighter uppercase text-zinc-900 dark:text-zinc-100">Motion Button Demo</h1>
      <p class="text-zinc-500 dark:text-zinc-400 font-medium uppercase tracking-widest text-[10px]">Componente interactivo con expansión circular</p>
    </div>

    <div class="p-12 rounded-[3rem] border-2 border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900/50 shadow-2xl flex items-center justify-center">
      <MotionButton label="Get Started" />
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
      <MotionButton label="Explorar Categorías" class="bg-blue-50 dark:bg-blue-900/10" />
      <MotionButton label="Contactar Soporte" class="bg-emerald-50 dark:bg-emerald-900/10" />
    </div>
  </div>
</template>
