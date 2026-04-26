<script setup lang="ts">
import { ref, computed } from 'vue'

const props = defineProps<{
  name: string
  avatarUrl?: string | null
  size?: string
  textSize?: string
}>()

const lightboxOpen = ref(false)

const initials = computed(() =>
  props.name
    .split(' ')
    .filter(Boolean)
    .map(n => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2)
)

const sizeClass = computed(() => props.size ?? 'w-8 h-8')
const textSizeClass = computed(() => props.textSize ?? 'text-[10px]')
</script>

<template>
  <div
    class="relative group shrink-0 rounded-lg border-2 border-zinc-100 dark:border-zinc-800 overflow-hidden bg-zinc-200 dark:bg-zinc-700"
    :class="[sizeClass, avatarUrl ? 'cursor-zoom-in' : '']"
    @click.stop="avatarUrl && (lightboxOpen = true)"
  >
    <img
      v-if="avatarUrl"
      :src="avatarUrl"
      :alt="name"
      class="h-full w-full object-cover"
    />
    <div
      v-else
      class="h-full w-full flex items-center justify-center font-bold text-zinc-700 dark:text-zinc-300"
      :class="textSizeClass"
    >
      {{ initials }}
    </div>
    <div
      v-if="avatarUrl"
      class="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none"
    >
      <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5"
          d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
      </svg>
    </div>

    <!-- Lightbox -->
    <Teleport to="body">
      <Transition name="ab-fade">
        <div
          v-if="lightboxOpen"
          class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm"
          @click="lightboxOpen = false"
        >
          <img
            :src="avatarUrl ?? ''"
            :alt="name"
            class="rounded-2xl max-w-[320px] max-h-[320px] object-cover"
            @click.stop
          />
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<style scoped>
.ab-fade-enter-active, .ab-fade-leave-active { transition: opacity 0.15s ease; }
.ab-fade-enter-from, .ab-fade-leave-to { opacity: 0; }
</style>
