<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Building2, User, ArrowRight, Loader2, Check } from 'lucide-vue-next'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

definePageMeta({
  layout: 'auth'
})

const authStore = useAuthStore()
const route = useRoute()
const returnTo = computed(() => {
  const raw = (route.query.returnTo as string) || ''
  return raw && raw.startsWith('/') && !raw.startsWith('//') ? raw : ''
})
const step = ref<'type' | 'details'>('type')
const accountType = ref<'org_owner' | 'user'>('user')
const fullName = ref('')
const orgName = ref('')
const loading = ref(false)

function selectType(type: 'org_owner' | 'user') {
  accountType.value = type
  step.value = 'details'
}

function generateSlug(name: string): string {
  return name
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
}

async function handleSubmit() {
  if (!fullName.value.trim()) {
    toast.error('Ingresa tu nombre completo.')
    return
  }
  if (accountType.value === 'org_owner' && !orgName.value.trim()) {
    toast.error('Ingresa el nombre de tu organización.')
    return
  }

  loading.value = true

  const { error: profileError } = await authStore.updateProfile({
    full_name: fullName.value.trim(),
    account_type: accountType.value
  })

  if (profileError) {
    toast.error('No se pudo guardar tu perfil. Intenta de nuevo.')
    loading.value = false
    return
  }

  if (accountType.value === 'org_owner') {
    const slug = generateSlug(orgName.value.trim())
    const { error: orgError } = await authStore.createOrganization(orgName.value.trim(), slug)
    if (orgError) {
      toast.error(
        orgError.message.includes('unique')
          ? 'Ya existe una organización con ese nombre. Elige otro.'
          : 'No se pudo crear la organización. Intenta de nuevo.'
      )
      loading.value = false
      return
    }
  }

  loading.value = false
  toast.success('¡Perfil configurado!')
  await navigateTo(returnTo.value || '/dashboard')
}
</script>

<template>
  <div class="space-y-4">
    <!-- Step 1: Choose account type -->
    <template v-if="step === 'type'">
      <div class="text-center mb-6">
        <h2 class="text-2xl font-bold tracking-tight">Bienvenido a ContestSaaS</h2>
        <p class="text-muted-foreground text-sm mt-1">¿Cómo vas a usar la plataforma?</p>
      </div>

      <div class="grid gap-3">
        <button
          type="button"
          class="group relative flex items-start gap-4 rounded-xl border border-border bg-card p-5 text-left transition-all hover:border-zinc-400 hover:shadow-md dark:hover:border-zinc-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          @click="selectType('org_owner')"
        >
          <div class="mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-900">
            <Building2 class="w-5 h-5" />
          </div>
          <div class="flex-1">
            <p class="font-semibold text-sm">Soy una organización</p>
            <p class="text-xs text-muted-foreground mt-0.5">
              Creo y gestiono concursos, categorías y participantes.
            </p>
          </div>
          <ArrowRight class="w-4 h-4 text-muted-foreground mt-3 opacity-0 transition-opacity group-hover:opacity-100" />
        </button>

        <button
          type="button"
          class="group relative flex items-start gap-4 rounded-xl border border-border bg-card p-5 text-left transition-all hover:border-zinc-400 hover:shadow-md dark:hover:border-zinc-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          @click="selectType('user')"
        >
          <div class="mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-zinc-100 text-zinc-900 dark:bg-zinc-800 dark:text-zinc-100">
            <User class="w-5 h-5" />
          </div>
          <div class="flex-1">
            <p class="font-semibold text-sm">Soy participante o jurado</p>
            <p class="text-xs text-muted-foreground mt-0.5">
              Participo en concursos o evalúo como jurado.
            </p>
          </div>
          <ArrowRight class="w-4 h-4 text-muted-foreground mt-3 opacity-0 transition-opacity group-hover:opacity-100" />
        </button>
      </div>
    </template>

    <!-- Step 2: Fill in details -->
    <template v-else>
      <Card class="shadow-lg">
        <CardHeader>
          <div class="flex items-center gap-3">
            <div
              class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg"
              :class="accountType === 'org_owner'
                ? 'bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-900'
                : 'bg-zinc-100 text-zinc-900 dark:bg-zinc-800 dark:text-zinc-100'"
            >
              <Building2 v-if="accountType === 'org_owner'" class="w-5 h-5" />
              <User v-else class="w-5 h-5" />
            </div>
            <div>
              <CardTitle class="text-base">
                {{ accountType === 'org_owner' ? 'Configura tu organización' : 'Tu perfil' }}
              </CardTitle>
              <CardDescription class="text-xs">
                {{ accountType === 'org_owner'
                  ? 'Estos datos se mostrarán en tus concursos públicos.'
                  : 'Así te verán los organizadores.' }}
              </CardDescription>
            </div>
          </div>
        </CardHeader>

        <CardContent>
          <form @submit.prevent="handleSubmit" class="space-y-4">
            <div class="space-y-2">
              <Label for="full-name">Tu nombre completo</Label>
              <Input
                id="full-name"
                v-model="fullName"
                type="text"
                placeholder="Ana García"
                required
                autocomplete="name"
                class="h-10"
              />
            </div>

            <div v-if="accountType === 'org_owner'" class="space-y-2">
              <Label for="org-name">Nombre de la organización</Label>
              <Input
                id="org-name"
                v-model="orgName"
                type="text"
                placeholder="Conservatorio Municipal"
                required
                class="h-10"
              />
              <p class="text-xs text-muted-foreground">
                Slug: <code class="font-mono">{{ generateSlug(orgName || 'mi-organizacion') }}</code>
              </p>
            </div>

            <div class="flex gap-2 pt-1">
              <Button
                type="button"
                variant="outline"
                class="flex-1"
                :disabled="loading"
                @click="step = 'type'"
              >
                Volver
              </Button>
              <Button type="submit" class="flex-1" :disabled="loading">
                <Loader2 v-if="loading" class="w-4 h-4 mr-2 animate-spin" />
                <Check v-else class="w-4 h-4 mr-2" />
                {{ loading ? 'Guardando…' : 'Comenzar' }}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </template>
  </div>
</template>
