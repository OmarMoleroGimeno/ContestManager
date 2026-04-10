<script setup lang="ts">
// The global auth middleware handles redirects based on auth state.
// This page just provides a loading fallback during the initial check.
definePageMeta({ middleware: [] })

const authStore = useAuthStore()

onMounted(async () => {
  if (authStore.isAuthenticated) {
    await navigateTo('/dashboard')
  } else {
    await navigateTo('/auth/login')
  }
})
</script>

<template>
  <div class="flex min-h-screen items-center justify-center bg-background">
    <div class="text-center text-sm text-muted-foreground">Cargando…</div>
  </div>
</template>
