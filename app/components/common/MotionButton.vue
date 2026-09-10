<script setup lang="ts">
import { type HTMLAttributes } from 'vue'
import { ArrowRight } from 'lucide-vue-next'
import { cn } from '@/utils'

interface Props {
  label: string
  variant?: 'primary' | 'secondary'
  class?: HTMLAttributes['class']
  animate?: boolean
  delay?: number
  disabled?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'primary',
  animate: false,
  delay: 0,
  disabled: false
})
</script>

<template>
  <button
    :disabled="disabled"
    :class="cn(
      'bg-background group relative h-auto w-fit min-w-[200px] cursor-pointer rounded-full border-none p-1 outline-none flex items-center transition-opacity disabled:opacity-50 disabled:cursor-not-allowed',
      props.class
    )"
  >
    <span
      class="circle bg-zinc-900 dark:bg-zinc-100 m-0 block h-12 w-12 overflow-hidden rounded-full duration-500 group-hover:w-full"
      aria-hidden="true"
    ></span>
    
    <div class="icon absolute top-1/2 left-4 -translate-y-1/2 duration-500 group-hover:left-[calc(100%-2.5rem)]">
      <ArrowRight class="text-white dark:text-zinc-900 size-6" />
    </div>

    <span class="button-text text-zinc-900 dark:text-zinc-100 group-hover:text-white dark:group-hover:text-zinc-900 font-bold absolute top-1/2 left-1/2 ml-4 -translate-x-1/2 -translate-y-1/2 text-center text-lg tracking-tight whitespace-nowrap duration-500 pointer-events-none">
      {{ label }}
    </span>
  </button>
</template>

<style scoped>
.circle {
  transition: all 0.5s cubic-bezier(0.23, 1, 0.32, 1);
}

.icon {
  transition: all 0.5s cubic-bezier(0.23, 1, 0.32, 1);
}

.button-text {
  transition: all 0.5s cubic-bezier(0.23, 1, 0.32, 1);
}
</style>
