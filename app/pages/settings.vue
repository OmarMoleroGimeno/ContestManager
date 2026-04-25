<script setup lang="ts">
import { ref, computed } from 'vue'
import { User, Building2, Lock, Save, Camera, AlertTriangle } from 'lucide-vue-next'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Separator } from '@/components/ui/separator'
import { Badge } from '@/components/ui/badge'
import { toast } from 'vue-sonner'
import { storeToRefs } from 'pinia'

const authStore = useAuthStore()
const { profile, organization, user, isOrgOwner, initials, displayName } = storeToRefs(authStore)

// ── Avatar upload ─────────────────────────────────────────────────────────────
const avatarInput = ref<HTMLInputElement | null>(null)
const uploadingAvatar = ref(false)
const avatarPreview = ref<string | null>(profile.value?.avatar_url ?? null)
watch(profile, (p) => { if (p?.avatar_url) avatarPreview.value = p.avatar_url })

async function handleAvatarChange(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (!file || !user.value) return

  // Local preview
  avatarPreview.value = URL.createObjectURL(file)
  uploadingAvatar.value = true

  try {
    const nuxtApp = useNuxtApp()
    const supabase = nuxtApp.$supabase as any
    const ext = file.name.split('.').pop()
    const path = `${user.value.id}/avatar.${ext}`

    const { error: upErr } = await supabase.storage
      .from('avatars')
      .upload(path, file, { upsert: true, contentType: file.type })
    if (upErr) throw upErr

    const { data: urlData } = supabase.storage.from('avatars').getPublicUrl(path)
    const publicUrl = `${urlData.publicUrl}?t=${Date.now()}`

    const { error: profileErr } = await authStore.updateProfile({ avatar_url: publicUrl })
    if (profileErr) throw profileErr

    profileForm.value.avatar_url = publicUrl
    avatarPreview.value = publicUrl
    toast.success('Avatar actualizado')
  } catch (e: any) {
    toast.error(e?.message ?? 'Error al subir imagen')
    avatarPreview.value = profile.value?.avatar_url ?? null
  } finally {
    uploadingAvatar.value = false
    if (avatarInput.value) avatarInput.value.value = ''
  }
}

// ── Avatar preview lightbox ───────────────────────────────────────────────────
const lightboxOpen = ref(false)

// ── Profile form ──────────────────────────────────────────────────────────────
const profileForm = ref({
  full_name: profile.value?.full_name ?? '',
  avatar_url: profile.value?.avatar_url ?? '',
})
watch(profile, (p) => {
  if (p) {
    profileForm.value.full_name = p.full_name ?? ''
    profileForm.value.avatar_url = p.avatar_url ?? ''
  }
})
const savingProfile = ref(false)
async function saveProfile() {
  savingProfile.value = true
  try {
    const { error } = await authStore.updateProfile({
      full_name: profileForm.value.full_name,
    })
    if (error) throw error
    toast.success('Perfil actualizado')
  } catch (e: any) {
    toast.error(e?.message ?? 'Error al guardar')
  } finally {
    savingProfile.value = false
  }
}

// ── Org form ──────────────────────────────────────────────────────────────────
const orgForm = ref({
  name: organization.value?.name ?? '',
  slug: organization.value?.slug ?? '',
})
watch(organization, (o) => {
  if (o) {
    orgForm.value.name = o.name
    orgForm.value.slug = o.slug
  }
})
const savingOrg = ref(false)
async function saveOrg() {
  if (!organization.value) return
  savingOrg.value = true
  try {
    const nuxtApp = useNuxtApp()
    const supabase = nuxtApp.$supabase as any
    const { error } = await supabase
      .from('organizations')
      .update({ name: orgForm.value.name, slug: orgForm.value.slug })
      .eq('id', organization.value.id)
    if (error) throw error
    await authStore.fetchOrganization()
    toast.success('Organización actualizada')
  } catch (e: any) {
    toast.error(e?.message ?? 'Error al guardar')
  } finally {
    savingOrg.value = false
  }
}

// ── Password form ─────────────────────────────────────────────────────────────
const pwForm = ref({ current: '', newPw: '', confirm: '' })
const savingPw = ref(false)
const pwError = computed(() => {
  if (pwForm.value.newPw && pwForm.value.newPw.length < 8) return 'Mínimo 8 caracteres'
  if (pwForm.value.confirm && pwForm.value.newPw !== pwForm.value.confirm) return 'Las contraseñas no coinciden'
  return null
})
async function savePassword() {
  if (pwError.value || !pwForm.value.newPw) return
  savingPw.value = true
  try {
    const nuxtApp = useNuxtApp()
    const supabase = nuxtApp.$supabase as any
    const { error } = await supabase.auth.updateUser({ password: pwForm.value.newPw })
    if (error) throw error
    pwForm.value = { current: '', newPw: '', confirm: '' }
    toast.success('Contraseña actualizada')
  } catch (e: any) {
    toast.error(e?.message ?? 'Error al cambiar contraseña')
  } finally {
    savingPw.value = false
  }
}

// ── Tab ───────────────────────────────────────────────────────────────────────
const tab = ref<'profile' | 'org' | 'security'>('profile')
</script>

<template>
  <div class="max-w-3xl mx-auto space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500 pb-16">

    <!-- Header -->
    <div>
      <h2 class="text-2xl font-bold tracking-tight">Configuración de cuenta</h2>
      <p class="text-sm text-muted-foreground mt-1">Gestiona tu perfil, organización y seguridad</p>
    </div>

    <!-- Tabs -->
    <div class="flex gap-1 p-1 bg-muted rounded-xl w-fit border border-border/50">
      <button
        v-for="t in (isOrgOwner ? ['profile', 'org', 'security'] : ['profile', 'security'])"
        :key="t"
        @click="tab = t as any"
        :class="[
          'px-4 py-1.5 rounded-lg text-xs font-bold uppercase tracking-widest transition-all',
          tab === t
            ? 'bg-background shadow-sm text-foreground'
            : 'text-muted-foreground hover:text-foreground'
        ]"
      >
        {{ t === 'profile' ? 'Perfil' : t === 'org' ? 'Organización' : 'Seguridad' }}
      </button>
    </div>

    <!-- ── PROFILE TAB ────────────────────────────────────────────────────────── -->
    <template v-if="tab === 'profile'">
      <Card class="border-border shadow-sm">
        <CardHeader class="pb-4">
          <div class="flex items-center gap-3">
            <div class="p-2 bg-zinc-100 dark:bg-zinc-800 rounded-lg">
              <User class="w-4 h-4 text-zinc-600 dark:text-zinc-400" />
            </div>
            <div>
              <CardTitle class="text-base">Información personal</CardTitle>
              <CardDescription class="text-xs">Nombre y foto de perfil</CardDescription>
            </div>
          </div>
        </CardHeader>
        <Separator />
        <CardContent class="pt-6 space-y-6">

          <!-- Avatar -->
          <div class="flex items-center gap-5">
            <div
              class="relative group cursor-pointer"
              @click="avatarPreview ? lightboxOpen = true : avatarInput?.click()"
            >
              <Avatar class="h-16 w-16 rounded-xl border-2 border-border shadow-sm">
                <AvatarImage :src="avatarPreview ?? ''" />
                <AvatarFallback class="rounded-xl text-lg font-bold bg-zinc-100 dark:bg-zinc-800">
                  {{ initials }}
                </AvatarFallback>
              </Avatar>
              <div class="absolute inset-0 rounded-xl bg-black/50 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                <Camera v-if="!uploadingAvatar" class="w-5 h-5 text-white" />
                <span v-else class="text-white text-lg animate-spin">⟳</span>
              </div>
            </div>
            <div>
              <p class="text-sm font-bold text-zinc-800 dark:text-zinc-200">Foto de perfil</p>
              <p class="text-xs text-muted-foreground mt-0.5">JPG, PNG, WebP · Máx 2MB</p>
              <Button
                variant="outline"
                size="sm"
                class="mt-2 h-7 px-3 text-[10px] font-bold uppercase tracking-widest gap-1.5"
                :disabled="uploadingAvatar"
                @click="avatarInput?.click()"
              >
                <Camera class="w-3 h-3" />
                {{ uploadingAvatar ? 'Subiendo...' : 'Cambiar foto' }}
              </Button>
            </div>
            <input
              ref="avatarInput"
              type="file"
              accept="image/jpeg,image/png,image/webp,image/gif"
              class="hidden"
              @change="handleAvatarChange"
            />
          </div>

          <!-- Lightbox -->
          <Teleport to="body">
            <Transition name="fade">
              <div
                v-if="lightboxOpen"
                class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm"
                @click="lightboxOpen = false"
              >
                <img
                  :src="avatarPreview ?? ''"
                  :alt="displayName"
                  class="rounded-2xl max-w-[320px] max-h-[320px] object-cover shadow-2xl"
                  @click.stop
                />
              </div>
            </Transition>
          </Teleport>

          <!-- Name -->
          <div class="space-y-1.5">
            <Label class="text-xs font-bold uppercase tracking-widest text-zinc-500">Nombre completo</Label>
            <Input v-model="profileForm.full_name" placeholder="Tu nombre" class="h-9 text-sm" />
          </div>

          <!-- Email (readonly) -->
          <div class="space-y-1.5">
            <Label class="text-xs font-bold uppercase tracking-widest text-zinc-500">Email</Label>
            <Input :value="user?.email" disabled class="h-9 text-sm bg-muted text-muted-foreground" />
            <p class="text-[10px] text-muted-foreground">El email no se puede cambiar desde aquí</p>
          </div>

          <!-- Account type badge -->
          <div class="flex items-center gap-3 p-3 rounded-xl bg-muted/50 border border-border/50">
            <div>
              <p class="text-xs font-bold text-zinc-500 uppercase tracking-widest mb-1">Tipo de cuenta</p>
              <Badge
                :class="isOrgOwner
                  ? 'bg-violet-100 text-violet-700 border-violet-300 dark:bg-violet-950/40 dark:text-violet-300 dark:border-violet-700'
                  : 'bg-sky-100 text-sky-700 border-sky-300 dark:bg-sky-950/40 dark:text-sky-300 dark:border-sky-700'"
                variant="outline"
                class="font-bold text-[10px] uppercase tracking-widest"
              >
                {{ isOrgOwner ? 'Organización' : 'Usuario' }}
              </Badge>
            </div>
          </div>

          <div class="flex justify-end pt-2">
            <Button
              @click="saveProfile"
              :disabled="savingProfile"
              class="h-9 px-6 font-bold text-[10px] uppercase tracking-widest gap-2"
            >
              <Save v-if="!savingProfile" class="w-3.5 h-3.5" />
              <span class="animate-spin" v-else>⟳</span>
              {{ savingProfile ? 'Guardando...' : 'Guardar cambios' }}
            </Button>
          </div>
        </CardContent>
      </Card>
    </template>

    <!-- ── ORG TAB ─────────────────────────────────────────────────────────────── -->
    <template v-if="tab === 'org' && isOrgOwner">
      <Card class="border-border shadow-sm">
        <CardHeader class="pb-4">
          <div class="flex items-center gap-3">
            <div class="p-2 bg-zinc-100 dark:bg-zinc-800 rounded-lg">
              <Building2 class="w-4 h-4 text-zinc-600 dark:text-zinc-400" />
            </div>
            <div>
              <CardTitle class="text-base">Organización</CardTitle>
              <CardDescription class="text-xs">Datos de tu organización</CardDescription>
            </div>
          </div>
        </CardHeader>
        <Separator />
        <CardContent class="pt-6 space-y-5">

          <div class="space-y-1.5">
            <Label class="text-xs font-bold uppercase tracking-widest text-zinc-500">Nombre de la organización</Label>
            <Input v-model="orgForm.name" placeholder="Mi Conservatorio" class="h-9 text-sm" />
          </div>

          <div class="space-y-1.5">
            <Label class="text-xs font-bold uppercase tracking-widest text-zinc-500">Slug (URL)</Label>
            <div class="flex items-center">
              <span class="h-9 px-3 flex items-center text-xs text-muted-foreground bg-muted border border-r-0 border-border rounded-l-md">
                contestsaas.com/
              </span>
              <Input
                v-model="orgForm.slug"
                placeholder="mi-conservatorio"
                class="h-9 text-sm rounded-l-none"
              />
            </div>
            <p class="text-[10px] text-muted-foreground">Solo letras minúsculas, números y guiones</p>
          </div>

          <!-- Org ID (readonly) -->
          <div class="space-y-1.5">
            <Label class="text-xs font-bold uppercase tracking-widest text-zinc-500">ID de organización</Label>
            <Input :value="organization?.id" disabled class="h-9 text-sm bg-muted text-muted-foreground font-mono text-xs" />
          </div>

          <div class="flex justify-end pt-2">
            <Button
              @click="saveOrg"
              :disabled="savingOrg"
              class="h-9 px-6 font-bold text-[10px] uppercase tracking-widest gap-2"
            >
              <Save v-if="!savingOrg" class="w-3.5 h-3.5" />
              <span v-else class="animate-spin">⟳</span>
              {{ savingOrg ? 'Guardando...' : 'Guardar cambios' }}
            </Button>
          </div>
        </CardContent>
      </Card>
    </template>

    <!-- ── SECURITY TAB ──────────────────────────────────────────────────────── -->
    <template v-if="tab === 'security'">
      <Card class="border-border shadow-sm">
        <CardHeader class="pb-4">
          <div class="flex items-center gap-3">
            <div class="p-2 bg-zinc-100 dark:bg-zinc-800 rounded-lg">
              <Lock class="w-4 h-4 text-zinc-600 dark:text-zinc-400" />
            </div>
            <div>
              <CardTitle class="text-base">Contraseña</CardTitle>
              <CardDescription class="text-xs">Cambia tu contraseña de acceso</CardDescription>
            </div>
          </div>
        </CardHeader>
        <Separator />
        <CardContent class="pt-6 space-y-5">

          <div class="space-y-1.5">
            <Label class="text-xs font-bold uppercase tracking-widest text-zinc-500">Nueva contraseña</Label>
            <Input
              v-model="pwForm.newPw"
              type="password"
              placeholder="Mínimo 8 caracteres"
              class="h-9 text-sm"
            />
          </div>

          <div class="space-y-1.5">
            <Label class="text-xs font-bold uppercase tracking-widest text-zinc-500">Confirmar contraseña</Label>
            <Input
              v-model="pwForm.confirm"
              type="password"
              placeholder="Repite la contraseña"
              class="h-9 text-sm"
              :class="pwError && pwForm.confirm ? 'border-red-400 focus-visible:ring-red-400' : ''"
            />
            <p v-if="pwError && pwForm.confirm" class="text-[11px] text-red-500 font-medium">{{ pwError }}</p>
          </div>

          <div class="flex justify-end pt-2">
            <Button
              @click="savePassword"
              :disabled="savingPw || !!pwError || !pwForm.newPw"
              class="h-9 px-6 font-bold text-[10px] uppercase tracking-widest gap-2"
            >
              <Save v-if="!savingPw" class="w-3.5 h-3.5" />
              <span v-else class="animate-spin">⟳</span>
              {{ savingPw ? 'Guardando...' : 'Cambiar contraseña' }}
            </Button>
          </div>
        </CardContent>
      </Card>

      <!-- Danger zone -->
      <Card class="border-red-200 dark:border-red-900/50 shadow-sm">
        <CardHeader class="pb-4">
          <div class="flex items-center gap-3">
            <div class="p-2 bg-red-50 dark:bg-red-950/30 rounded-lg">
              <AlertTriangle class="w-4 h-4 text-red-500" />
            </div>
            <div>
              <CardTitle class="text-base text-red-600 dark:text-red-400">Zona de peligro</CardTitle>
              <CardDescription class="text-xs">Acciones irreversibles</CardDescription>
            </div>
          </div>
        </CardHeader>
        <Separator class="bg-red-100 dark:bg-red-900/30" />
        <CardContent class="pt-6">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-bold text-zinc-800 dark:text-zinc-200">Eliminar cuenta</p>
              <p class="text-xs text-muted-foreground mt-0.5">Borra permanentemente tu cuenta y todos los datos asociados</p>
            </div>
            <Button
              variant="outline"
              class="border-red-300 text-red-600 hover:bg-red-50 dark:border-red-800 dark:text-red-400 dark:hover:bg-red-950/30 font-bold text-[10px] uppercase tracking-widest h-9 px-4"
              disabled
            >
              Eliminar cuenta
            </Button>
          </div>
        </CardContent>
      </Card>
    </template>

  </div>
</template>

<style scoped>
.fade-enter-active, .fade-leave-active { transition: opacity 0.15s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
