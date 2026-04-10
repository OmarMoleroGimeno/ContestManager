import { ref, computed, onUnmounted } from 'vue'
import type { RealtimeChannel } from '@supabase/supabase-js'

export interface AppNotification {
  id: string
  type: string
  title: string
  body: string
  payload: Record<string, unknown>
  read: boolean
  created_at: string
}

export function useNotifications() {
  const notifications = ref<AppNotification[]>([])
  const loading = ref(false)
  let channel: RealtimeChannel | null = null

  const unreadCount = computed(() => notifications.value.filter((n) => !n.read).length)

  function getSupabase() {
    return useNuxtApp().$supabase as ReturnType<typeof import('@supabase/supabase-js').createClient>
  }

  async function fetchNotifications() {
    const authStore = useAuthStore()
    if (!authStore.user) return

    loading.value = true
    const supabase = getSupabase()
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', authStore.user.id)
      .order('created_at', { ascending: false })
      .limit(20)

    if (!error && data) {
      notifications.value = data as AppNotification[]
    }
    loading.value = false
  }

  async function markAsRead(id: string) {
    const n = notifications.value.find((n) => n.id === id)
    if (!n || n.read) return
    n.read = true
    const supabase = getSupabase()
    await supabase.from('notifications').update({ read: true }).eq('id', id)
  }

  async function markAllAsRead() {
    const unread = notifications.value.filter((n) => !n.read)
    if (!unread.length) return
    unread.forEach((n) => (n.read = true))
    const supabase = getSupabase()
    await supabase
      .from('notifications')
      .update({ read: true })
      .in('id', unread.map((n) => n.id))
  }

  function subscribeRealtime(userId: string) {
    const supabase = getSupabase()
    channel = supabase
      .channel(`notifications:${userId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${userId}`,
        },
        (payload) => {
          notifications.value.unshift(payload.new as AppNotification)
        }
      )
      .subscribe()
  }

  function unsubscribe() {
    if (channel) {
      const supabase = getSupabase()
      supabase.removeChannel(channel)
      channel = null
    }
  }

  async function init() {
    const authStore = useAuthStore()
    if (!authStore.user) return
    await fetchNotifications()
    subscribeRealtime(authStore.user.id)
  }

  onUnmounted(unsubscribe)

  return {
    notifications,
    unreadCount,
    loading,
    init,
    markAsRead,
    markAllAsRead,
    unsubscribe,
  }
}
