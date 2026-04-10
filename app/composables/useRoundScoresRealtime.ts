import { ref, watch, onUnmounted } from 'vue'
import type { RealtimeChannel } from '@supabase/supabase-js'

/**
 * Subscribes to real-time score changes for a given round.
 * Calls `onScoreChange` whenever a score is inserted or updated.
 */
export function useRoundScoresRealtime(
  roundId: Ref<string>,
  onScoreChange: (roundId: string) => void
) {
  let channel: RealtimeChannel | null = null

  function getSupabase() {
    return useNuxtApp().$supabase as ReturnType<typeof import('@supabase/supabase-js').createClient>
  }

  function subscribe(id: string) {
    if (!id) return
    const supabase = getSupabase()

    channel = supabase
      .channel(`scores:round:${id}`)
      .on(
        'postgres_changes',
        {
          event: '*', // INSERT + UPDATE
          schema: 'public',
          table: 'scores',
          filter: `round_id=eq.${id}`,
        },
        () => {
          onScoreChange(id)
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

  // Re-subscribe whenever the round changes
  watch(
    roundId,
    (newId, oldId) => {
      if (oldId) unsubscribe()
      if (newId) subscribe(newId)
    },
    { immediate: true }
  )

  onUnmounted(unsubscribe)

  return { unsubscribe }
}
