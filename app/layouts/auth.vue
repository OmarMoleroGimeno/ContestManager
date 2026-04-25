<script setup lang="ts">
import { Toaster } from '@/components/ui/sonner'
import Grainient from '@/components/ui/Grainient.vue'
</script>

<template>
  <div class="auth-shell relative min-h-screen overflow-hidden bg-black text-zinc-100 antialiased">
    <!-- Grainient WebGL backdrop -->
    <ClientOnly>
      <div class="pointer-events-none absolute inset-0">
        <Grainient
          color1="#1a1a2e"
          color2="#000000"
          color3="#9b9ec1"
          :time-speed="0.25"
          :color-balance="0"
          :warp-strength="1"
          :warp-frequency="5"
          :warp-speed="2"
          :warp-amplitude="50"
          :blend-angle="0"
          :blend-softness="0.05"
          :rotation-amount="500"
          :noise-scale="2"
          :grain-amount="0.1"
          :grain-scale="2"
          :grain-animated="false"
          :contrast="1.5"
          :gamma="1"
          :saturation="1"
          :center-x="0"
          :center-y="0"
          :zoom="0.9"
        />
      </div>
    </ClientOnly>

    <main class="relative min-h-screen flex items-center justify-center px-4 py-16">
      <div class="w-full max-w-md">
        <slot />
      </div>
    </main>

    <Toaster position="top-center" theme="dark" />
  </div>
</template>
