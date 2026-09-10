-- 0045_stripe_webhook_idempotency.sql
-- Prevent duplicate processing of Stripe webhook events.

CREATE TABLE IF NOT EXISTS public.processed_stripe_events (
    stripe_event_id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Allow service_role to insert / read
ALTER TABLE public.processed_stripe_events ENABLE ROW LEVEL SECURITY;

-- Postgres has no CREATE POLICY ... IF NOT EXISTS, so drop first to stay
-- re-runnable. The previous version of this file used it and the whole
-- migration aborted on a syntax error, which is why the table was never
-- created in production.
DROP POLICY IF EXISTS "Service role can manage processed_stripe_events"
  ON public.processed_stripe_events;

CREATE POLICY "Service role can manage processed_stripe_events"
  ON public.processed_stripe_events
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
