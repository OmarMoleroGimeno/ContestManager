<script setup lang="ts">
import { Loader2 } from 'lucide-vue-next'

definePageMeta({
  layout: 'auth',
  middleware: []
})

const authStore = useAuthStore()

onMounted(async () => {
  // Give Supabase a moment to process the URL hash / token
  await new Promise((r) => setTimeout(r, 300))

  // Re-fetch session (handles magic link token in URL hash)
  await authStore.init()

  if (!authStore.isAuthenticated) {
    await navigateTo('/auth/login')
    return
  }

  // Route based on onboarding completeness
  if (authStore.needsOnboarding) {
    await navigateTo('/onboarding')
    return
  }

  if (authStore.needsOrgSetup) {
    await navigateTo('/onboarding')
    return
  }

  await navigateTo('/dashboard')
})
</script>

<template>
  <div class="flex flex-col items-center gap-4 py-8 text-muted-foreground">
    <Loader2 class="w-8 h-8 animate-spin" />
    <p class="text-sm">Verificando sesión…</p>
  </div>
</template>
