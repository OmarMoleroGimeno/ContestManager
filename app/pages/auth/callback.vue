<script setup lang="ts">
import { Loader2 } from 'lucide-vue-next'

definePageMeta({
  layout: 'auth',
  middleware: []
})

const authStore = useAuthStore()
const route = useRoute()

const returnTo = computed(() => {
  const raw = (route.query.returnTo as string) || ''
  if (raw && raw.startsWith('/') && !raw.startsWith('//')) return raw
  return ''
})

onMounted(async () => {
  // Give Supabase a moment to process the URL hash / token
  await new Promise((r) => setTimeout(r, 300))

  // Re-fetch session (handles magic link token in URL hash)
  await authStore.init()

  if (!authStore.isAuthenticated) {
    const loginTarget = returnTo.value
      ? `/auth/login?returnTo=${encodeURIComponent(returnTo.value)}`
      : '/auth/login'
    await navigateTo(loginTarget)
    return
  }

  // Route based on onboarding completeness
  if (authStore.needsOnboarding || authStore.needsOrgSetup) {
    const obTarget = returnTo.value
      ? `/onboarding?returnTo=${encodeURIComponent(returnTo.value)}`
      : '/onboarding'
    await navigateTo(obTarget)
    return
  }

  if (returnTo.value) {
    await navigateTo(returnTo.value)
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
