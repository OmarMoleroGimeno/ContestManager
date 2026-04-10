import { storeToRefs } from 'pinia'
import { useAuthStore } from '../stores/auth'

export const useAuth = () => {
  const store = useAuthStore()
  const {
    user,
    session,
    profile,
    organization,
    loading,
    isAuthenticated,
    isOrgOwner,
    needsOnboarding,
    needsOrgSetup,
    displayName,
    initials
  } = storeToRefs(store)

  return {
    user,
    session,
    profile,
    organization,
    loading,
    isAuthenticated,
    isOrgOwner,
    needsOnboarding,
    needsOrgSetup,
    displayName,
    initials,
    init: store.init,
    signIn: store.signIn,
    signUp: store.signUp,
    signOut: store.signOut,
    updateProfile: store.updateProfile,
    createOrganization: store.createOrganization
  }
}
