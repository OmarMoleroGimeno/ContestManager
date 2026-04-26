/**
 * Diseño "Dark Premium": Utilidades de Estilo para Badges y Estados
 * Basado en: bg-[color]-950/40 text-[color]-400 border-[color]-500/30 (Modo Oscuro)
 * Basado en: bg-[color]-50 text-[color]-700 border-[color]-200 (Modo Claro)
 */

export const getStatusClasses = (status: string) => {
  const styles: Record<string, string> = {
    draft: 'bg-zinc-50 text-zinc-700 border-zinc-200 dark:bg-zinc-950/50 dark:text-zinc-400 dark:border-zinc-500/30',
    active: 'bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950/40 dark:text-emerald-400 dark:border-emerald-500/30',
    finished: 'bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950/40 dark:text-blue-400 dark:border-blue-500/30',
    cancelled: 'bg-red-50 text-red-700 border-red-200 dark:bg-red-950/40 dark:text-red-400 dark:border-red-500/30',
    pending: 'bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950/40 dark:text-amber-400 dark:border-amber-500/30',
    closed: 'bg-zinc-100 text-zinc-500 border-zinc-200 dark:bg-zinc-900/50 dark:text-zinc-500 dark:border-zinc-800'
  }
  return styles[status] || styles.draft
}

export const getTypeClasses = (type: string) => {
  const styles: Record<string, string> = {
    music: 'bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950/40 dark:text-amber-400 dark:border-amber-500/30',
    dance: 'bg-pink-50 text-pink-700 border-pink-200 dark:bg-pink-950/40 dark:text-pink-400 dark:border-pink-500/30',
    general: 'bg-indigo-50 text-indigo-700 border-indigo-200 dark:bg-indigo-950/40 dark:text-indigo-400 dark:border-indigo-500/30',
    libre: 'bg-cyan-50 text-cyan-700 border-cyan-200 dark:bg-cyan-950/40 dark:text-cyan-400 dark:border-cyan-500/30'
  }
  return styles[type] || 'bg-zinc-50 text-zinc-700 border-zinc-200 dark:bg-zinc-900/50 dark:text-zinc-400 dark:border-zinc-500/30'
}

export const getModeClasses = (mode: string) => {
  return mode === 'tournament' 
    ? 'bg-violet-50 text-violet-700 border-violet-200 dark:bg-violet-950/40 dark:text-violet-400 dark:border-violet-500/30' 
    : 'bg-sky-50 text-sky-700 border-sky-200 dark:bg-sky-950/40 dark:text-sky-400 dark:border-sky-500/30'
}

// Banner variants: readable on dark overlay. Light=solid white, Dark=translucent glass
export const getStatusBannerClasses = (status: string) => {
  const styles: Record<string, string> = {
    draft: 'bg-white/90 text-zinc-700 border-zinc-200 dark:bg-white/10 dark:text-zinc-200 dark:border-white/20',
    active: 'bg-white/90 text-emerald-700 border-emerald-200 dark:bg-emerald-400/10 dark:text-emerald-300 dark:border-emerald-300/30',
    finished: 'bg-white/90 text-blue-700 border-blue-200 dark:bg-blue-400/10 dark:text-blue-300 dark:border-blue-300/30',
    cancelled: 'bg-white/90 text-red-700 border-red-200 dark:bg-red-400/10 dark:text-red-300 dark:border-red-300/30',
    pending: 'bg-white/90 text-amber-700 border-amber-200 dark:bg-amber-400/10 dark:text-amber-300 dark:border-amber-300/30',
    closed: 'bg-white/90 text-zinc-500 border-zinc-200 dark:bg-white/10 dark:text-zinc-300 dark:border-white/20'
  }
  return styles[status] || styles.draft
}

export const getTypeBannerClasses = (type: string) => {
  const styles: Record<string, string> = {
    music: 'bg-white/90 text-amber-700 border-amber-200 dark:bg-amber-400/10 dark:text-amber-300 dark:border-amber-300/30',
    dance: 'bg-white/90 text-pink-700 border-pink-200 dark:bg-pink-400/10 dark:text-pink-300 dark:border-pink-300/30',
    general: 'bg-white/90 text-indigo-700 border-indigo-200 dark:bg-indigo-400/10 dark:text-indigo-300 dark:border-indigo-300/30',
    libre: 'bg-white/90 text-cyan-700 border-cyan-200 dark:bg-cyan-400/10 dark:text-cyan-300 dark:border-cyan-300/30'
  }
  return styles[type] || 'bg-white/90 text-zinc-700 border-zinc-200 dark:bg-white/10 dark:text-zinc-200 dark:border-white/20'
}

export const getModeBannerClasses = (mode: string) => {
  return mode === 'tournament'
    ? 'bg-white/90 text-violet-700 border-violet-200 dark:bg-violet-400/10 dark:text-violet-300 dark:border-violet-300/30'
    : 'bg-white/90 text-sky-700 border-sky-200 dark:bg-sky-400/10 dark:text-sky-300 dark:border-sky-300/30'
}

export const getTierClasses = (isDynamic: boolean) => {
  return isDynamic
    ? 'bg-orange-50 text-orange-700 border-orange-200 dark:bg-orange-950/40 dark:text-orange-400 dark:border-orange-500/30'
    : 'bg-zinc-50 text-zinc-700 border-zinc-200 dark:bg-zinc-950/50 dark:text-zinc-400 dark:border-zinc-500/30'
}
