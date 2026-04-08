<script setup lang="ts">
import { Toaster } from '@/components/ui/sonner'
import { Button } from '@/components/ui/button'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Input } from '@/components/ui/input'
import {
  SidebarProvider,
  Sidebar,
  SidebarContent,
  SidebarHeader,
  SidebarFooter,
  SidebarGroup,
  SidebarMenu,
  SidebarMenuItem,
  SidebarMenuButton,
  SidebarTrigger,
  SidebarInset
} from '@/components/ui/sidebar'
import { useRoute } from 'vue-router'

// Usando iconos genéricos temporalmente o Lucide
import { LayoutDashboard, Trophy, Settings, LogOut, Sun, Moon, Users } from 'lucide-vue-next'

const route = useRoute()
const colorMode = useColorMode()

function toggleColorMode() {
  colorMode.preference = colorMode.value === 'dark' ? 'light' : 'dark'
}
</script>

<template>
  <SidebarProvider>
    <Sidebar collapsible="icon">
      <SidebarHeader>
        <div class="px-2 py-4 flex items-center gap-3">
          <div class="w-10 h-10 rounded-lg bg-black flex items-center justify-center font-bold text-white shadow-lg shadow-zinc-900/20 text-lg">
            C
          </div>
          <h1 class="text-2xl font-extrabold tracking-tight group-data-[collapsible=icon]:hidden">Contest<span class="text-zinc-500">SaaS</span></h1>
        </div>
      </SidebarHeader>

      <SidebarContent>
        <SidebarGroup>
          <SidebarMenu>
            <SidebarMenuItem>
              <SidebarMenuButton as-child :isActive="route.path === '/dashboard'" tooltip="Resumen">
                <NuxtLink to="/dashboard">
                  <LayoutDashboard />
                  <span>Resumen</span>
                </NuxtLink>
              </SidebarMenuButton>
            </SidebarMenuItem>
            
            <SidebarMenuItem>
              <SidebarMenuButton as-child :isActive="route.path === '/contests'" tooltip="Mis Concursos">
                <NuxtLink to="/contests">
                  <Trophy />
                  <span>Mis Concursos</span>
                </NuxtLink>
              </SidebarMenuButton>
            </SidebarMenuItem>

            <SidebarMenuItem>
              <SidebarMenuButton as-child :isActive="route.path === '/judge-pool'" tooltip="Jurados">
                <NuxtLink to="/judge-pool">
                  <Users />
                  <span>Jurados</span>
                </NuxtLink>
              </SidebarMenuButton>
            </SidebarMenuItem>

            <SidebarMenuItem>
              <SidebarMenuButton as-child tooltip="Configuración">
                <a href="#">
                  <Settings />
                  <span>Configuración</span>
                </a>
              </SidebarMenuButton>
            </SidebarMenuItem>
          </SidebarMenu>
        </SidebarGroup>
      </SidebarContent>

      <SidebarFooter>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton as-child tooltip="Cerrar Sesión">
              <button class="w-full flex items-center gap-2">
                <LogOut />
                <span>Cerrar Sesión</span>
              </button>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
    </Sidebar>

    <SidebarInset class="bg-background text-foreground font-sans transition-colors">
      <header class="flex h-16 shrink-0 items-center justify-between gap-2 border-b border-border bg-card px-4 transition-[width,height,background-color] ease-linear w-full">
        <div class="flex items-center gap-2">
          <SidebarTrigger class="-ml-1" />
        </div>
        
        <div class="flex items-center justify-end gap-4 flex-1">
          <div class="w-full max-w-sm hidden md:flex">
             <Input placeholder="Buscar competencias, participantes..." class="bg-muted/50 border-border focus-visible:ring-zinc-900 h-9" />
          </div>
          
          <ClientOnly>
            <Button variant="ghost" size="icon" @click="toggleColorMode" class="rounded-full w-9 h-9">
              <Sun v-if="colorMode.value === 'dark'" class="w-5 h-5" />
              <Moon v-else class="w-5 h-5" />
              <span class="sr-only">Toggle theme</span>
            </Button>
            <template #fallback>
              <div class="w-9 h-9" />
            </template>
          </ClientOnly>

          <Avatar class="w-9 h-9 border border-border shadow-sm">
            <AvatarImage src="https://i.pravatar.cc/150?img=11" alt="Usuario" />
            <AvatarFallback>OM</AvatarFallback>
          </Avatar>
        </div>
      </header>
      
      <div class="flex-1 overflow-auto p-8 relative">
        <slot />
      </div>
    </SidebarInset>
    <Toaster position="top-center" theme="system" />
  </SidebarProvider>
</template>
