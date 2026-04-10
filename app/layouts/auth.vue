<script setup lang="ts">
import { Toaster } from '@/components/ui/sonner'
</script>

<template>
  <div class="min-h-screen bg-background flex flex-col items-center justify-center p-4">
    <div class="w-full max-w-md">
      <!-- Brand -->
      <div class="flex items-center justify-center gap-3 mb-8">
        <div class="w-10 h-10 rounded-lg bg-black flex items-center justify-center font-bold text-white shadow-lg text-lg">
          C
        </div>
        <h1 class="text-2xl font-extrabold tracking-tight">
          Contest<span class="text-zinc-500">SaaS</span>
        </h1>
      </div>

      <!-- Page content -->
      <slot />
    </div>

    <Toaster position="top-center" theme="system" />
  </div>
</template>
