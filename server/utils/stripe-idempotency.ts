import type { SupabaseAdmin } from '~~/server/services/stripe-webhook'

const TABLE = 'processed_stripe_events'

export type ClaimResult = 'acquired' | 'already_processed'

/**
 * Atomically claim a Stripe event before its handler runs.
 *
 * The insert IS the lock: a duplicate surfaces as Postgres unique_violation
 * (23505) on the primary key. Callers must never process an event they did
 * not acquire.
 *
 * supabase-js resolves with `{ data, error }` instead of rejecting, so a
 * try/catch around these calls never fires and the error has to be inspected
 * explicitly. Getting this wrong disables idempotency silently — a missing
 * table reads as "never seen this event" and every Stripe retry re-credits.
 *
 * @throws when the ledger is unusable, so the request fails and Stripe retries.
 */
export async function claimStripeEvent(
  admin: SupabaseAdmin,
  eventId: string,
  eventType: string,
): Promise<ClaimResult> {
  const { error } = await admin.from(TABLE).insert({
    stripe_event_id: eventId,
    event_type: eventType,
  })

  if (!error) return 'acquired'
  if (error.code === '23505') return 'already_processed'

  throw new Error(`idempotency_lock_failed: ${error.message}`)
}

/**
 * Look up whether an event was already processed.
 *
 * @throws when the lookup fails, so an unreadable ledger is never mistaken for
 * an empty one.
 */
export async function wasStripeEventProcessed(
  admin: SupabaseAdmin,
  eventId: string,
): Promise<boolean> {
  const { data, error } = await admin
    .from(TABLE)
    .select('stripe_event_id')
    .eq('stripe_event_id', eventId)
    .maybeSingle()

  if (error) throw new Error(`idempotency_lookup_failed: ${error.message}`)
  return !!data
}

/**
 * Release a claim so Stripe retries the event.
 *
 * Best-effort: a failure is logged, never thrown, because the caller is
 * already unwinding a failed handler.
 */
export async function releaseStripeEvent(
  admin: SupabaseAdmin,
  eventId: string,
): Promise<void> {
  const { error } = await admin.from(TABLE).delete().eq('stripe_event_id', eventId)
  if (error) console.error('[stripe webhook] idempotency rollback failed:', error.message)
}
