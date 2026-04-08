import { storeToRefs } from 'pinia'
import { useAuthStore } from '../stores/auth'

export const useAuth = () => {
  const store = useAuthStore()
  const { user, session } = storeToRefs(store)
  return {
    user,
    session,
    init: store.init,
    signIn: store.signIn,
    signOut: store.signOut
  }
}
