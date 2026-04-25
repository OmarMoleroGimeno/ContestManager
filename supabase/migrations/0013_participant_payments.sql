-- 0013_participant_payments.sql
-- Stripe Connect for organizations + per-contest entry fee charged to participants.

-- ─────────────────────────────────────────────
-- 1. Organizations: Stripe Connect account
-- ─────────────────────────────────────────────
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS stripe_account_id         TEXT,
  ADD COLUMN IF NOT EXISTS stripe_onboarding_done    BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS stripe_charges_enabled    BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS stripe_payouts_enabled    BOOLEAN NOT NULL DEFAULT FALSE;

CREATE UNIQUE INDEX IF NOT EXISTS organizations_stripe_account_uidx
  ON public.organizations (stripe_account_id)
  WHERE stripe_account_id IS NOT NULL;

-- ─────────────────────────────────────────────
-- 2. Contests: entry fee (in cents, org currency=EUR for MVP)
-- ─────────────────────────────────────────────
ALTER TABLE public.contests
  ADD COLUMN IF NOT EXISTS entry_fee_cents INT NOT NULL DEFAULT 0;

-- ─────────────────────────────────────────────
-- 3. Participants: payment status
-- ─────────────────────────────────────────────
ALTER TABLE public.participants
  ADD COLUMN IF NOT EXISTS payment_status             TEXT NOT NULL DEFAULT 'free'
    CHECK (payment_status IN ('free','pending','paid','refunded')),
  ADD COLUMN IF NOT EXISTS stripe_payment_intent_id   TEXT,
  ADD COLUMN IF NOT EXISTS stripe_checkout_session_id TEXT,
  ADD COLUMN IF NOT EXISTS amount_paid_cents          INT;

CREATE UNIQUE INDEX IF NOT EXISTS participants_checkout_session_uidx
  ON public.participants (stripe_checkout_session_id)
  WHERE stripe_checkout_session_id IS NOT NULL;

-- ─────────────────────────────────────────────
-- 4. RPC: enroll_participant_paid
--    Used by webhook after successful payment. Runs same validations
--    as enroll_participant but accepts pre-paid session metadata and
--    a bypass of auth.uid (we pass user_id explicitly).
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.enroll_participant_paid(
  p_user_id       UUID,
  p_token         TEXT,
  p_category_id   UUID,
  p_first_name    TEXT,
  p_last_name     TEXT,
  p_birthdate     DATE,
  p_dni           TEXT,
  p_country       TEXT,
  p_email         TEXT,
  p_phone         TEXT,
  p_session_id    TEXT,
  p_payment_intent TEXT,
  p_amount_cents  INT
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_contest_id     UUID;
  v_org_id         UUID;
  v_reg_open       BOOLEAN;
  v_reg_starts     TIMESTAMPTZ;
  v_cat            RECORD;
  v_age            INT;
  v_count          BIGINT;
  v_org_tickets    INT;
  v_existing       UUID;
  v_participant_id UUID;
BEGIN
  -- Idempotency: if this checkout session already created a participant, return it
  SELECT id INTO v_existing FROM public.participants
   WHERE stripe_checkout_session_id = p_session_id LIMIT 1;
  IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;

  SELECT id, organization_id, registration_open, starts_at
    INTO v_contest_id, v_org_id, v_reg_open, v_reg_starts
    FROM public.contests
   WHERE registration_token = p_token LIMIT 1;
  IF v_contest_id IS NULL THEN RAISE EXCEPTION 'contest_not_found'; END IF;
  IF NOT v_reg_open THEN RAISE EXCEPTION 'registration_closed'; END IF;

  SELECT ticket_balance INTO v_org_tickets
    FROM public.organizations WHERE id = v_org_id;
  IF v_org_tickets IS NULL OR v_org_tickets <= 0 THEN
    RAISE EXCEPTION 'insufficient_tickets';
  END IF;

  SELECT * INTO v_cat FROM public.categories
   WHERE id = p_category_id AND contest_id = v_contest_id;
  IF v_cat IS NULL THEN RAISE EXCEPTION 'category_not_found'; END IF;

  v_age := date_part('year', age(COALESCE(v_reg_starts, now()), p_birthdate::timestamptz))::int;
  IF v_cat.min_age IS NOT NULL AND v_age < v_cat.min_age THEN RAISE EXCEPTION 'age_below_min'; END IF;
  IF v_cat.max_age IS NOT NULL AND v_age > v_cat.max_age THEN RAISE EXCEPTION 'age_above_max'; END IF;

  IF v_cat.max_participants IS NOT NULL THEN
    SELECT COUNT(*)::bigint INTO v_count FROM public.participants
     WHERE category_id = p_category_id AND status <> 'eliminated';
    IF v_count >= v_cat.max_participants THEN RAISE EXCEPTION 'category_full'; END IF;
  END IF;

  INSERT INTO public.participants(
    contest_id, category_id, user_id, name,
    first_name, last_name, birthdate, dni, country, email, phone, status,
    payment_status, stripe_checkout_session_id, stripe_payment_intent_id, amount_paid_cents
  ) VALUES (
    v_contest_id, p_category_id, p_user_id,
    TRIM(COALESCE(p_first_name,'') || ' ' || COALESCE(p_last_name,'')),
    p_first_name, p_last_name, p_birthdate, p_dni, p_country,
    p_email, p_phone, 'active',
    'paid', p_session_id, p_payment_intent, p_amount_cents
  ) RETURNING id INTO v_participant_id;

  PERFORM public.consume_ticket(v_org_id, v_participant_id, v_contest_id, 'enrollment');
  RETURN v_participant_id;
END; $$;

-- Lock this function down — only service_role (webhook) calls it
REVOKE ALL ON FUNCTION public.enroll_participant_paid FROM anon, authenticated;
