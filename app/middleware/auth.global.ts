import { useAuthStore } from '~/stores/auth'

const PUBLIC_PATHS = ['/auth/login', '/auth/callback']
const ONBOARDING_PATH = '/onboarding'

// Only org owners can access these
const ORG_ONLY_PATHS = ['/contests', '/judge-pool']

export default defineNuxtRouteMiddleware(async (to) => {
  if (import.meta.server) return

  const authStore = useAuthStore()

  const isPublic = PUBLIC_PATHS.some((p) => to.path.startsWith(p))
  const isOnboarding = to.path.startsWith(ONBOARDING_PATH)
  const isOrgOnly = ORG_ONLY_PATHS.some((p) => to.path.startsWith(p))

  // ── Not authenticated ──────────────────────────────────────────────────
  if (!authStore.isAuthenticated) {
    if (!isPublic) return navigateTo('/auth/login')
    return
  }

  // ── Authenticated ──────────────────────────────────────────────────────

  // Redirect away from auth pages
  if (isPublic) return navigateTo('/dashboard')

  // Onboarding checks
  if (authStore.needsOnboarding && !isOnboarding) return navigateTo(ONBOARDING_PATH)
  if (authStore.needsOrgSetup && !isOnboarding) return navigateTo(ONBOARDING_PATH)

  // Block non-org users from org-only pages
  if (isOrgOnly && !authStore.isOrgOwner) return navigateTo('/my-contests')
})
