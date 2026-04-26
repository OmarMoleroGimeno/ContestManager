import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useContestsStore } from '@/stores/contests'
import { useCategoriesStore } from '@/stores/categories'
import { useRoundsStore } from '@/stores/rounds'
import { useBreadcrumbMeta } from '@/composables/useBreadcrumbMeta'
import { storeToRefs } from 'pinia'

export interface BreadcrumbItem {
  label: string
  href?: string
}

function slugToLabel(slug: string): string {
  return slug
    .split('-')
    .map(w => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ')
}

function truncate(str: string, max = 28): string {
  return str.length > max ? str.slice(0, max - 1) + '…' : str
}

export function useBreadcrumbs() {
  const route = useRoute()
  const contestsStore = useContestsStore()
  const categoriesStore = useCategoriesStore()
  const roundsStore = useRoundsStore()
  const { meta } = useBreadcrumbMeta()

  const { items: contests } = storeToRefs(contestsStore)
  const { items: categories } = storeToRefs(categoriesStore)
  const { items: rounds } = storeToRefs(roundsStore)

  const breadcrumbs = computed((): BreadcrumbItem[] => {
    const path = route.path
    const params = route.params as Record<string, string>

    // ── /dashboard ─────────────────────────────────────────────────────────
    if (path === '/dashboard') {
      return [{ label: 'Dashboard' }]
    }

    // ── /judge-pool ────────────────────────────────────────────────────────
    if (path === '/judge-pool') {
      return [{ label: 'Jurados' }]
    }

    // ── /contests ──────────────────────────────────────────────────────────
    if (path === '/contests') {
      return [{ label: 'Concursos' }]
    }

    if (path === '/contests/new') {
      return [
        { label: 'Concursos', href: '/contests' },
        { label: 'Nuevo Concurso' },
      ]
    }

    // ── /contests/[slug] ───────────────────────────────────────────────────
    if (params.slug && path.startsWith('/contests/')) {
      const contest = contests.value.find(c => c.slug === params.slug)
      const rawContest = meta.value.contest ?? contest?.name ?? slugToLabel(params.slug)
      const contestLabel = truncate(rawContest)
      const contestHref = `/contests/${params.slug}`

      // /contests/[slug]/categories/[id]/rounds/[roundId]
      if (params.roundId) {
        const category = categories.value.find(c => c.id === params.id)
        const round = rounds.value.find(r => r.id === params.roundId)
        const catLabel = truncate(meta.value.category ?? category?.name ?? '…')
        const roundLabel = truncate(meta.value.round ?? round?.name ?? '…')
        return [
          { label: 'Concursos', href: '/contests' },
          { label: contestLabel, href: contestHref },
          { label: catLabel, href: `/contests/${params.slug}/categories/${params.id}` },
          { label: roundLabel },
        ]
      }

      // /contests/[slug]/categories/[id]
      if (params.id) {
        const category = categories.value.find(c => c.id === params.id)
        const catLabel = truncate(meta.value.category ?? category?.name ?? '…')
        return [
          { label: 'Concursos', href: '/contests' },
          { label: contestLabel, href: contestHref },
          { label: catLabel },
        ]
      }

      // /contests/[slug]
      return [
        { label: 'Concursos', href: '/contests' },
        { label: contestLabel },
      ]
    }

    // ── /my-contests ───────────────────────────────────────────────────────
    if (path === '/my-contests') {
      return [{ label: 'Mis Concursos' }]
    }

    if (params.slug && path.startsWith('/my-contests/')) {
      const contest = contests.value.find(c => c.slug === params.slug)
      const rawContest = meta.value.contest ?? contest?.name ?? slugToLabel(params.slug)
      const contestLabel = truncate(rawContest)
      const contestHref = `/my-contests/${params.slug}`

      // /my-contests/[slug]/categories/[id]/rounds/[roundId]
      if (params.roundId) {
        const category = categories.value.find(c => c.id === params.id)
        const round = rounds.value.find(r => r.id === params.roundId)
        const catLabel = truncate(meta.value.category ?? category?.name ?? '…')
        const roundLabel = truncate(meta.value.round ?? round?.name ?? '…')
        return [
          { label: 'Mis Concursos', href: '/my-contests' },
          { label: contestLabel, href: contestHref },
          { label: catLabel, href: `/my-contests/${params.slug}/categories/${params.id}` },
          { label: roundLabel },
        ]
      }

      // /my-contests/[slug]/categories/[id]
      if (params.id) {
        const category = categories.value.find(c => c.id === params.id)
        const catLabel = truncate(meta.value.category ?? category?.name ?? '…')
        return [
          { label: 'Mis Concursos', href: '/my-contests' },
          { label: contestLabel, href: contestHref },
          { label: catLabel },
        ]
      }

      return [
        { label: 'Mis Concursos', href: '/my-contests' },
        { label: contestLabel },
      ]
    }

    // ── /onboarding ────────────────────────────────────────────────────────
    if (path.startsWith('/onboarding')) {
      return [{ label: 'Configuración inicial' }]
    }

    return []
  })

  return { breadcrumbs }
}
