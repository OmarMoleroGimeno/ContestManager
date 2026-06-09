<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { toast } from 'vue-sonner'
import { Eye, EyeOff, Loader2, Zap } from 'lucide-vue-next'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue
} from '@/components/ui/select'

const passwordStrength = computed(() => {
  if (!password.value) return { percent: 0, color: '', text: '' }
  
  let score = 0
  if (password.value.length >= 8) score++
  if (/[A-Z]/.test(password.value)) score++
  if (/[a-z]/.test(password.value)) score++
  if (/\d/.test(password.value)) score++
  if (/[@$!%*?&]/.test(password.value)) score++
  
  if (score <= 2) return { percent: 25, color: 'bg-red-500', text: 'Débil' }
  if (score <= 3) return { percent: 50, color: 'bg-yellow-500', text: 'Media' }
  if (score <= 4) return { percent: 75, color: 'bg-blue-500', text: 'Buena' }
  return { percent: 100, color: 'bg-green-500', text: 'Fuerte' }
})

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

const mode = ref<'login' | 'register'>(
  (route.query.mode as string) === 'register' ? 'register' : 'login'
)
const email = ref('')
const password = ref('')
const confirmPassword = ref('')
const showPassword = ref(false)
const showConfirmPassword = ref(false)
const loading = ref(false)
const oauthLoading = ref<'google' | 'github' | null>(null)
const passwordError = ref('')
const acceptedTerms = ref(false)
const marketingConsent = ref(false)

const DEMO_USERS = [
  { label: 'Organización Demo', sublabel: 'Dueño · Conservatorio Demo', email: 'org@contestsaas.demo', password: 'Demo1234!' },
  { label: 'Ana García', sublabel: 'Participante · Piano Juvenil', email: 'participante@contestsaas.demo', password: 'Demo1234!' },
  { label: 'Carlos Jurado', sublabel: 'Jurado · Piano Juvenil', email: 'jurado@contestsaas.demo', password: 'Demo1234!' },
]

// Clear password error when user starts typing
watch([password, confirmPassword], () => {
  if (passwordError.value) passwordError.value = ''
})

function selectDemoUser(val: string) {
  const found = DEMO_USERS.find(u => u.email === val)
  if (!found) return
  mode.value = 'login'
  email.value = found.email
  password.value = found.password
}

async function handleLogin() {
  loading.value = true
  const { error } = await authStore.signIn(email.value.trim(), password.value)
  loading.value = false

  if (error) {
    toast.error(error.message.includes('Invalid login') ? 'Correo o contraseña incorrectos.' : error.message)
    return
  }
  const target = returnTo.value
    ? `/auth/callback?returnTo=${encodeURIComponent(returnTo.value)}`
    : '/auth/callback'
  await navigateTo(target)
}

async function handleRegister() {
  passwordError.value = ''
  
  // Validate terms acceptance
  if (!acceptedTerms.value) {
    passwordError.value = 'Debes aceptar los términos y política de privacidad.'
    toast.error(passwordError.value)
    return
  }
  
  // Validate password length (minimum 8 characters)
  if (password.value.length < 8) {
    passwordError.value = 'La contraseña debe tener al menos 8 caracteres.'
    toast.error(passwordError.value)
    return
  }
  
  // Validate password complexity
  const hasUppercase = /[A-Z]/.test(password.value)
  const hasLowercase = /[a-z]/.test(password.value)
  const hasNumber = /\d/.test(password.value)
  const hasSymbol = /[@$!%*?&]/.test(password.value)
  
  if (!hasUppercase || !hasLowercase || !hasNumber || !hasSymbol) {
    passwordError.value = 'La contraseña debe incluir mayúscula, minúscula, número y símbolo (@$!%*?&).'
    toast.error(passwordError.value)
    return
  }
  
  // Validate passwords match
  if (password.value !== confirmPassword.value) {
    passwordError.value = 'Las contraseñas no coinciden.'
    toast.error(passwordError.value)
    return
  }
  
  loading.value = true
  const { error, data } = await authStore.signUp(email.value.trim(), password.value, marketingConsent.value)
  loading.value = false

  if (error) {
    passwordError.value = error.message
    toast.error(
      error.message.includes('already registered')
        ? 'Este correo ya tiene una cuenta. Inicia sesión.'
        : error.message
    )
    return
  }
  if (data.session) {
    const target = returnTo.value
      ? `/auth/callback?returnTo=${encodeURIComponent(returnTo.value)}`
      : '/auth/callback'
    await navigateTo(target)
  } else {
    toast.success('¡Cuenta creada! Revisa tu correo para confirmarla.')
  }
}

function submit() {
  if (mode.value === 'login') handleLogin()
  else handleRegister()
}

async function handleOAuth(provider: 'google' | 'github') {
  oauthLoading.value = provider
  const { error } = await authStore.signInWithOAuth(provider, returnTo.value)
  if (error) {
    oauthLoading.value = null
    toast.error(error.message || 'No se pudo iniciar sesión')
  }
  // On success the browser is redirected to the OAuth provider — no further action.
}
</script>

<template>
  <div class="space-y-6">
    <!-- Logo + heading -->
    <div class="flex flex-col items-center gap-3">
      <img
        src="https://thaftosvbwcoudzfwiou.supabase.co/storage/v1/object/public/contest-assets/logo.png"
        alt="Logo"
        class="w-24 h-24 object-contain"
      />
      <h1 class="text-2xl font-bold tracking-tight text-zinc-100">
        {{ mode === 'login' ? 'Log in to ContestSaaS' : 'Crea tu cuenta' }}
      </h1>
      <p class="text-sm text-zinc-400">
        <template v-if="mode === 'login'">
          ¿No tienes cuenta?
          <button type="button" class="font-semibold text-zinc-100 hover:underline underline-offset-4" @click="mode = 'register'">Regístrate</button>.
        </template>
        <template v-else>
          ¿Ya tienes cuenta?
          <button type="button" class="font-semibold text-zinc-100 hover:underline underline-offset-4" @click="mode = 'login'">Inicia sesión</button>.
        </template>
      </p>
    </div>

    <!-- OAuth buttons -->
    <div class="grid grid-cols-2 gap-3">
      <button
        type="button"
        :disabled="oauthLoading !== null"
        class="group inline-flex items-center justify-center gap-2 h-11 rounded-lg bg-zinc-900/60 border border-white/10 hover:bg-zinc-800/80 hover:border-white/20 text-sm text-zinc-100 transition-colors backdrop-blur disabled:opacity-50"
        @click="handleOAuth('google')"
      >
        <Loader2 v-if="oauthLoading === 'google'" class="w-4 h-4 animate-spin" />
        <svg v-else viewBox="0 0 24 24" class="w-4 h-4">
          <path fill="#fff" d="M21.35 11.1H12v3.83h5.34c-.23 1.4-1.66 4.1-5.34 4.1-3.21 0-5.83-2.66-5.83-5.94S8.79 7.16 12 7.16c1.83 0 3.05.78 3.75 1.45l2.55-2.46C16.7 4.65 14.55 3.7 12 3.7 6.93 3.7 2.83 7.8 2.83 12.87S6.93 22.05 12 22.05c6.93 0 9.55-4.86 9.55-7.4 0-.5-.05-.88-.2-1.55z"/>
        </svg>
        Log in with Google
      </button>
      <button
        type="button"
        :disabled="oauthLoading !== null"
        class="group inline-flex items-center justify-center gap-2 h-11 rounded-lg bg-zinc-900/60 border border-white/10 hover:bg-zinc-800/80 hover:border-white/20 text-sm text-zinc-100 transition-colors backdrop-blur disabled:opacity-50"
        @click="handleOAuth('github')"
      >
        <Loader2 v-if="oauthLoading === 'github'" class="w-4 h-4 animate-spin" />
        <svg v-else viewBox="0 0 24 24" class="w-4 h-4 fill-current">
          <path d="M12 .5C5.73.5.75 5.48.75 11.75c0 4.96 3.22 9.16 7.69 10.65.56.1.77-.24.77-.54v-1.9c-3.13.68-3.79-1.51-3.79-1.51-.51-1.3-1.25-1.65-1.25-1.65-1.02-.7.08-.69.08-.69 1.13.08 1.72 1.16 1.72 1.16 1 1.72 2.62 1.22 3.26.93.1-.72.39-1.22.71-1.5-2.5-.29-5.13-1.25-5.13-5.55 0-1.23.44-2.23 1.16-3.02-.12-.29-.5-1.43.11-2.99 0 0 .94-.3 3.09 1.15a10.7 10.7 0 0 1 5.63 0c2.15-1.45 3.09-1.15 3.09-1.15.61 1.56.23 2.7.11 2.99.72.79 1.16 1.79 1.16 3.02 0 4.31-2.63 5.26-5.14 5.54.4.34.76 1.02.76 2.06v3.05c0 .3.2.65.78.54 4.46-1.49 7.68-5.69 7.68-10.65C23.25 5.48 18.27.5 12 .5z"/>
        </svg>
        Log in with GitHub
      </button>
    </div>

    <!-- Divider -->
    <div class="flex items-center gap-3">
      <div class="flex-1 h-px bg-white/10" />
      <span class="text-xs text-zinc-500">or</span>
      <div class="flex-1 h-px bg-white/10" />
    </div>

    <!-- Email + Password -->
    <form @submit.prevent="submit" class="space-y-4">
      <div class="space-y-1.5">
        <label for="email" class="text-sm text-zinc-300">Email</label>
        <input
          id="email"
          v-model="email"
          type="email"
          required
          autocomplete="email"
          placeholder="alan.turing@example.com"
          class="w-full h-11 px-3 rounded-lg bg-zinc-900/60 border border-white/10 text-sm text-zinc-100 placeholder:text-zinc-500 focus:outline-none focus:ring-2 focus:ring-white/20 focus:border-white/20 transition"
        />
      </div>

      <div class="space-y-1.5">
        <div class="flex items-center justify-between">
          <label for="password" class="text-sm text-zinc-300">Password</label>
          <button v-if="mode === 'login'" type="button" class="text-xs text-zinc-400 hover:text-zinc-100 transition-colors">
            Forgot your password?
          </button>
        </div>
        <div class="relative">
          <input
            id="password"
            v-model="password"
            :type="showPassword ? 'text' : 'password'"
            required
            :autocomplete="mode === 'login' ? 'current-password' : 'new-password'"
            placeholder="••••••••••••"
            class="w-full h-11 pl-3 pr-10 rounded-lg bg-zinc-900/60 border border-white/10 text-sm text-zinc-100 placeholder:text-zinc-500 focus:outline-none focus:ring-2 focus:ring-white/20 focus:border-white/20 transition"
            :class="passwordError && mode === 'register' ? 'border-red-500 focus:ring-red-500/20' : ''"
          />
          <button
            type="button"
            class="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-500 hover:text-zinc-200 transition-colors"
            @click="showPassword = !showPassword"
          >
            <Eye v-if="!showPassword" class="w-4 h-4" />
            <EyeOff v-else class="w-4 h-4" />
          </button>
        </div>
        <div v-if="mode === 'register' && password" class="space-y-2">
          <div class="h-1 bg-zinc-700 rounded-full overflow-hidden">
            <div :class="passwordStrength.color" :style="{ width: passwordStrength.percent + '%' }" class="h-full transition-all duration-300" />
          </div>
          <p class="text-xs" :class="passwordStrength.color">{{ passwordStrength.text }}</p>
          <ul class="text-xs text-zinc-500 space-y-1">
            <li :class="password.length >= 8 ? 'text-green-500' : ''">✓ 8+ caracteres</li>
            <li :class="/[A-Z]/.test(password) ? 'text-green-500' : ''">✓ Mayúscula</li>
            <li :class="/[a-z]/.test(password) ? 'text-green-500' : ''">✓ Minúscula</li>
            <li :class="/\d/.test(password) ? 'text-green-500' : ''">✓ Número</li>
            <li :class="/[@$!%*?&]/.test(password) ? 'text-green-500' : ''">✓ Símbolo</li>
          </ul>
        </div>
      </div>

      <div v-if="mode === 'register'" class="space-y-1.5">
        <label for="confirmPassword" class="text-sm text-zinc-300">Confirm Password</label>
        <div class="relative">
          <input
            id="confirmPassword"
            v-model="confirmPassword"
            :type="showConfirmPassword ? 'text' : 'password'"
            required
            autocomplete="new-password"
            placeholder="••••••••••••"
            class="w-full h-11 pl-3 pr-10 rounded-lg bg-zinc-900/60 border border-white/10 text-sm text-zinc-100 placeholder:text-zinc-500 focus:outline-none focus:ring-2 focus:ring-white/20 focus:border-white/20 transition"
            :class="passwordError ? 'border-red-500 focus:ring-red-500/20' : ''"
          />
          <button
            type="button"
            class="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-500 hover:text-zinc-200 transition-colors"
            @click="showConfirmPassword = !showConfirmPassword"
          >
            <Eye v-if="!showConfirmPassword" class="w-4 h-4" />
            <EyeOff v-else class="w-4 h-4" />
          </button>
        </div>
        <p v-if="passwordError" class="text-xs text-red-400">{{ passwordError }}</p>
      </div>

      <button
        type="submit"
        :disabled="loading || !email || !password || (mode === 'register' && !confirmPassword)"
        class="w-full h-11 rounded-lg bg-zinc-100 text-zinc-900 font-semibold text-sm hover:bg-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed inline-flex items-center justify-center gap-2"
      >
        <Loader2 v-if="loading" class="w-4 h-4 animate-spin" />
        {{ loading
          ? (mode === 'login' ? 'Ingresando…' : 'Creando cuenta…')
          : (mode === 'login' ? 'Log In' : 'Crear cuenta') }}
      </button>

      <div v-if="mode === 'register'" class="space-y-3">
        <label class="flex items-start gap-2 text-xs text-zinc-400 cursor-pointer">
          <input type="checkbox" v-model="acceptedTerms" required class="mt-0.5 accent-zinc-100" />
          <span>Acepto los <a href="/terms" class="underline hover:text-zinc-300">Términos de Servicio</a> y la <a href="/privacy" class="underline hover:text-zinc-300">Política de Privacidad</a></span>
        </label>
        
        <label class="flex items-start gap-2 text-xs text-zinc-400 cursor-pointer">
          <input type="checkbox" v-model="marketingConsent" class="mt-0.5 accent-zinc-100" />
          <span>Acepto recibir correos sobre actualizaciones y novedades (opcional)</span>
        </label>
      </div>
      <p v-else class="text-xs text-zinc-500 text-center">
        By signing in, you agree to our
        <a href="/terms" class="underline hover:text-zinc-300">Terms</a> and
        <a href="/privacy" class="underline hover:text-zinc-300">Privacy Policy</a>.
      </p>
    </form>

    <!-- Demo quick-login -->
    <div class="rounded-xl border border-dashed border-white/10 bg-white/[0.02] p-3 space-y-2">
      <div class="flex items-center gap-1.5 text-xs text-zinc-400 font-medium">
        <Zap class="w-3.5 h-3.5 text-amber-400" />
        Acceso rápido — usuarios de demo
      </div>
      <Select @update:model-value="selectDemoUser">
        <SelectTrigger class="h-9 bg-zinc-900/60 border-white/10 text-sm text-zinc-100">
          <SelectValue placeholder="Selecciona un usuario…" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem v-for="u in DEMO_USERS" :key="u.email" :value="u.email">
            <div class="flex flex-col">
              <span class="font-medium">{{ u.label }}</span>
              <span class="text-xs text-muted-foreground">{{ u.sublabel }}</span>
            </div>
          </SelectItem>
        </SelectContent>
      </Select>
    </div>
  </div>
</template>
