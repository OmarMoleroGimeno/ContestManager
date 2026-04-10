<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Mail, Lock, Eye, EyeOff, Loader2, Zap } from 'lucide-vue-next'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue
} from '@/components/ui/select'

definePageMeta({
  layout: 'auth',
  middleware: []
})

const authStore = useAuthStore()

const mode = ref<'login' | 'register'>('login')
const email = ref('')
const password = ref('')
const showPassword = ref(false)
const loading = ref(false)

// ─── Demo users ───────────────────────────────────────────────────────────────
const DEMO_USERS = [
  { label: 'Organización Demo', sublabel: 'Dueño · Conservatorio Demo', email: 'org@contestsaas.demo', password: 'Demo1234!' },
  { label: 'Ana García', sublabel: 'Participante · Piano Juvenil', email: 'participante@contestsaas.demo', password: 'Demo1234!' },
  { label: 'Carlos Jurado', sublabel: 'Jurado · Piano Juvenil', email: 'jurado@contestsaas.demo', password: 'Demo1234!' },
]

function selectDemoUser(val: string) {
  const found = DEMO_USERS.find(u => u.email === val)
  if (!found) return
  mode.value = 'login'
  email.value = found.email
  password.value = found.password
}

// ─── Auth actions ─────────────────────────────────────────────────────────────
async function handleLogin() {
  loading.value = true
  const { error } = await authStore.signIn(email.value.trim(), password.value)
  loading.value = false

  if (error) {
    toast.error(
      error.message.includes('Invalid login')
        ? 'Correo o contraseña incorrectos.'
        : error.message
    )
    return
  }

  await navigateTo('/auth/callback')
}

async function handleRegister() {
  if (password.value.length < 6) {
    toast.error('La contraseña debe tener al menos 6 caracteres.')
    return
  }

  loading.value = true
  const { error, data } = await authStore.signUp(email.value.trim(), password.value)
  loading.value = false

  if (error) {
    toast.error(
      error.message.includes('already registered')
        ? 'Este correo ya tiene una cuenta. Inicia sesión.'
        : error.message
    )
    return
  }

  if (data.session) {
    await navigateTo('/auth/callback')
  } else {
    toast.success('¡Cuenta creada! Revisa tu correo para confirmarla.')
  }
}

function submit() {
  if (mode.value === 'login') handleLogin()
  else handleRegister()
}
</script>

<template>
  <div class="space-y-3">
    <!-- Demo quick-login -->
    <div class="rounded-xl border border-dashed border-border bg-muted/40 p-3 space-y-2">
      <div class="flex items-center gap-1.5 text-xs text-muted-foreground font-medium">
        <Zap class="w-3.5 h-3.5 text-amber-500" />
        Acceso rápido — usuarios de demo
      </div>
      <Select @update:model-value="selectDemoUser">
        <SelectTrigger class="h-9 bg-background text-sm">
          <SelectValue placeholder="Selecciona un usuario…" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem
            v-for="u in DEMO_USERS"
            :key="u.email"
            :value="u.email"
          >
            <div class="flex flex-col">
              <span class="font-medium">{{ u.label }}</span>
              <span class="text-xs text-muted-foreground">{{ u.sublabel }}</span>
            </div>
          </SelectItem>
        </SelectContent>
      </Select>
    </div>

    <!-- Login / Register card -->
    <Card class="shadow-lg">
      <CardHeader class="text-center pb-4">
        <CardTitle class="text-xl">
          {{ mode === 'login' ? 'Iniciar sesión' : 'Crear cuenta' }}
        </CardTitle>
        <CardDescription>
          {{ mode === 'login'
            ? 'Accede a tu panel de ContestSaaS.'
            : 'Crea tu cuenta para empezar.' }}
        </CardDescription>
      </CardHeader>

      <CardContent>
        <form @submit.prevent="submit" class="space-y-4">
          <!-- Email -->
          <div class="space-y-2">
            <Label for="email">Correo electrónico</Label>
            <div class="relative">
              <Mail class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground pointer-events-none" />
              <Input
                id="email"
                v-model="email"
                type="email"
                placeholder="tu@correo.com"
                required
                autocomplete="email"
                class="h-10 pl-9"
              />
            </div>
          </div>

          <!-- Password -->
          <div class="space-y-2">
            <Label for="password">Contraseña</Label>
            <div class="relative">
              <Lock class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground pointer-events-none" />
              <Input
                id="password"
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                placeholder="••••••••"
                required
                :autocomplete="mode === 'login' ? 'current-password' : 'new-password'"
                class="h-10 pl-9 pr-10"
              />
              <button
                type="button"
                class="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                @click="showPassword = !showPassword"
              >
                <Eye v-if="!showPassword" class="w-4 h-4" />
                <EyeOff v-else class="w-4 h-4" />
              </button>
            </div>
            <p v-if="mode === 'register'" class="text-xs text-muted-foreground">
              Mínimo 6 caracteres.
            </p>
          </div>

          <!-- Submit -->
          <Button type="submit" class="w-full" :disabled="loading || !email || !password">
            <Loader2 v-if="loading" class="w-4 h-4 mr-2 animate-spin" />
            <span>{{ loading
              ? (mode === 'login' ? 'Ingresando…' : 'Creando cuenta…')
              : (mode === 'login' ? 'Iniciar sesión' : 'Crear cuenta') }}</span>
          </Button>
        </form>

        <!-- Mode toggle -->
        <p class="mt-4 text-center text-sm text-muted-foreground">
          {{ mode === 'login' ? '¿No tienes cuenta?' : '¿Ya tienes cuenta?' }}
          <button
            type="button"
            class="ml-1 font-medium text-foreground underline-offset-4 hover:underline"
            @click="mode = mode === 'login' ? 'register' : 'login'"
          >
            {{ mode === 'login' ? 'Regístrate' : 'Inicia sesión' }}
          </button>
        </p>
      </CardContent>
    </Card>
  </div>
</template>
