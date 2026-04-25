<script setup lang="ts">
defineProps<{ href?: string }>()
</script>

<template>
  <NuxtLink
    v-if="href"
    :to="href"
    class="transition-colors hover:text-foreground"
  >
    <slot />
  </NuxtLink>
  <span v-else class="transition-colors hover:text-foreground cursor-pointer">
    <slot />
  </span>
</template>
