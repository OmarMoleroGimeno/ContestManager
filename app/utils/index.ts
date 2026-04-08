import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'
import type { Updater } from '@tanstack/vue-table'
import type { Ref } from 'vue'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function valueUpdater<T extends Updater<any>>(updaterOrValue: T, ref: Ref) {
  if (typeof updaterOrValue === 'function')
    ref.value = updaterOrValue(ref.value)
  else
    ref.value = updaterOrValue
}
