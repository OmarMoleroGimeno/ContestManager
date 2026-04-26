-- 0016_participants_refund_fields.sql
-- Add refund tracking fields on participants.

ALTER TABLE public.participants
  ADD COLUMN IF NOT EXISTS amount_refunded_cents INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS stripe_refund_id TEXT;

CREATE INDEX IF NOT EXISTS participants_pi_idx
  ON public.participants(stripe_payment_intent_id);
