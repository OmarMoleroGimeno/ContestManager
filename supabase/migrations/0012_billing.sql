-- 0012_billing.sql
-- Bundle-based billing: tickets (participants) + activations (contests)
-- Bundles sold via Stripe; balances live on organizations, auditable via ledger.

-- ─────────────────────────────────────────────
-- 1. Balances on organizations
-- ─────────────────────────────────────────────
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS ticket_balance     INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS activation_balance INT NOT NULL DEFAULT 0;

-- ─────────────────────────────────────────────
-- 2. Billing ledger (tickets + activations unified)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.billing_transactions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id   UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  entity            TEXT NOT NULL CHECK (entity IN ('ticket', 'activation')),
  delta             INT  NOT NULL,   -- + credit, - debit
  reason            TEXT NOT NULL CHECK (reason IN (
                      'purchase_bundle',
                      'signup_bonus',
                      'enrollment',
                      'csv_import',
                      'manual_add',
                      'contest_activation',
                      'admin_adjust'
                    )),
  plan              TEXT CHECK (plan IN ('starter','pro','enterprise')),
  amount_cents      INT,
  stripe_session_id TEXT,
  stripe_event_id   TEXT UNIQUE,
  participant_id    UUID REFERENCES public.participants(id) ON DELETE SET NULL,
  contest_id        UUID REFERENCES public.contests(id)     ON DELETE SET NULL,
  balance_after     INT NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS billing_tx_org_idx ON public.billing_transactions (organization_id, created_at DESC);
CREATE INDEX IF NOT EXISTS billing_tx_contest_idx ON public.billing_transactions (contest_id) WHERE contest_id IS NOT NULL;

ALTER TABLE public.billing_transactions ENABLE ROW LEVEL SECURITY;

-- Org owners can read their own ledger
CREATE POLICY "org_owner_read_ledger" ON public.billing_transactions
  FOR SELECT USING (
    organization_id IN (SELECT id FROM public.organizations WHERE owner_id = auth.uid())
  );

-- ─────────────────────────────────────────────
-- 3. Plan catalog (server-side constant, but exposed for UI)
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_plan_bundles()
RETURNS TABLE (
  plan         TEXT,
  tickets      INT,
  activations  INT,
  price_cents  INT
) LANGUAGE sql IMMUTABLE AS $$
  SELECT 'starter'::TEXT,    50,  1,  19500
  UNION ALL SELECT 'pro',       200, 3,  46000
  UNION ALL SELECT 'enterprise',1000,10, 120000;
$$;

GRANT EXECUTE ON FUNCTION public.get_plan_bundles() TO anon, authenticated;

-- ─────────────────────────────────────────────
-- 4. Consume ticket (atomic) — called when enrolling a participant
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.consume_ticket(
  p_org_id         UUID,
  p_participant_id UUID,
  p_contest_id     UUID,
  p_reason         TEXT
) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_balance INT;
BEGIN
  IF p_reason NOT IN ('enrollment','csv_import','manual_add') THEN
    RAISE EXCEPTION 'invalid_reason';
  END IF;

  UPDATE public.organizations
     SET ticket_balance = ticket_balance - 1
   WHERE id = p_org_id AND ticket_balance > 0
   RETURNING ticket_balance INTO v_new_balance;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'insufficient_tickets';
  END IF;

  INSERT INTO public.billing_transactions
    (organization_id, entity, delta, reason, participant_id, contest_id, balance_after)
  VALUES
    (p_org_id, 'ticket', -1, p_reason, p_participant_id, p_contest_id, v_new_balance);

  RETURN v_new_balance;
END;
$$;

-- ─────────────────────────────────────────────
-- 5. Consume activation (atomic) — called when activating a contest
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.consume_activation(
  p_org_id     UUID,
  p_contest_id UUID
) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_balance INT;
BEGIN
  UPDATE public.organizations
     SET activation_balance = activation_balance - 1
   WHERE id = p_org_id AND activation_balance > 0
   RETURNING activation_balance INTO v_new_balance;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'insufficient_activations';
  END IF;

  INSERT INTO public.billing_transactions
    (organization_id, entity, delta, reason, contest_id, balance_after)
  VALUES
    (p_org_id, 'activation', -1, 'contest_activation', p_contest_id, v_new_balance);

  RETURN v_new_balance;
END;
$$;

-- ─────────────────────────────────────────────
-- 6. Credit bundle (called from Stripe webhook)
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.credit_bundle(
  p_org_id            UUID,
  p_plan              TEXT,
  p_stripe_session_id TEXT,
  p_stripe_event_id   TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_tickets       INT;
  v_activations   INT;
  v_price_cents   INT;
  v_new_tickets   INT;
  v_new_activs    INT;
BEGIN
  SELECT tickets, activations, price_cents
    INTO v_tickets, v_activations, v_price_cents
    FROM public.get_plan_bundles()
   WHERE plan = p_plan;

  IF v_tickets IS NULL THEN
    RAISE EXCEPTION 'unknown_plan: %', p_plan;
  END IF;

  -- Idempotency: if we've already processed this Stripe event, no-op
  IF EXISTS (SELECT 1 FROM public.billing_transactions WHERE stripe_event_id = p_stripe_event_id) THEN
    RETURN;
  END IF;

  -- Credit both balances
  UPDATE public.organizations
     SET ticket_balance     = ticket_balance     + v_tickets,
         activation_balance = activation_balance + v_activations
   WHERE id = p_org_id
   RETURNING ticket_balance, activation_balance INTO v_new_tickets, v_new_activs;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'org_not_found';
  END IF;

  INSERT INTO public.billing_transactions
    (organization_id, entity, delta, reason, plan, amount_cents, stripe_session_id, stripe_event_id, balance_after)
  VALUES
    (p_org_id, 'ticket',     v_tickets,     'purchase_bundle', p_plan, v_price_cents, p_stripe_session_id, p_stripe_event_id || ':t', v_new_tickets),
    (p_org_id, 'activation', v_activations, 'purchase_bundle', p_plan, NULL,          p_stripe_session_id, p_stripe_event_id,         v_new_activs);
END;
$$;

-- ─────────────────────────────────────────────
-- 7. Signup bonus: 1 free activation when an organization is created
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.grant_signup_bonus()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.organizations
     SET activation_balance = activation_balance + 1
   WHERE id = NEW.id;

  INSERT INTO public.billing_transactions
    (organization_id, entity, delta, reason, balance_after)
  VALUES
    (NEW.id, 'activation', 1, 'signup_bonus',
     (SELECT activation_balance FROM public.organizations WHERE id = NEW.id));
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS organizations_signup_bonus ON public.organizations;
CREATE TRIGGER organizations_signup_bonus
AFTER INSERT ON public.organizations
FOR EACH ROW EXECUTE FUNCTION public.grant_signup_bonus();

-- Backfill: give 1 activation to existing organizations that have 0 balance
UPDATE public.organizations
   SET activation_balance = activation_balance + 1
 WHERE activation_balance = 0;

INSERT INTO public.billing_transactions (organization_id, entity, delta, reason, balance_after)
SELECT id, 'activation', 1, 'signup_bonus', activation_balance
  FROM public.organizations
 WHERE activation_balance = 1
   AND NOT EXISTS (
     SELECT 1 FROM public.billing_transactions b
      WHERE b.organization_id = organizations.id AND b.reason = 'signup_bonus'
   );

-- ─────────────────────────────────────────────
-- 8. Update enroll_participant RPC to consume a ticket
--    (Overrides migration 0011's version)
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.enroll_participant(
  p_token        TEXT,
  p_category_id  UUID,
  p_first_name   TEXT,
  p_last_name    TEXT,
  p_birthdate    DATE,
  p_dni          TEXT,
  p_country      TEXT,
  p_email        TEXT,
  p_phone        TEXT
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_contest_id     UUID;
  v_org_id         UUID;
  v_reg_open       BOOLEAN;
  v_reg_starts     TIMESTAMPTZ;
  v_cat            RECORD;
  v_age            INT;
  v_count          BIGINT;
  v_org_tickets    INT;
  v_participant_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000';
  END IF;

  SELECT id, organization_id, registration_open, starts_at
    INTO v_contest_id, v_org_id, v_reg_open, v_reg_starts
    FROM public.contests
   WHERE registration_token = p_token
   LIMIT 1;

  IF v_contest_id IS NULL THEN
    RAISE EXCEPTION 'contest_not_found';
  END IF;
  IF NOT v_reg_open THEN
    RAISE EXCEPTION 'registration_closed';
  END IF;

  -- Org must have tickets available
  SELECT ticket_balance INTO v_org_tickets
    FROM public.organizations WHERE id = v_org_id;
  IF v_org_tickets IS NULL OR v_org_tickets <= 0 THEN
    RAISE EXCEPTION 'insufficient_tickets';
  END IF;

  SELECT * INTO v_cat
    FROM public.categories
   WHERE id = p_category_id AND contest_id = v_contest_id;
  IF v_cat IS NULL THEN
    RAISE EXCEPTION 'category_not_found';
  END IF;

  v_age := date_part(
    'year',
    age(COALESCE(v_reg_starts, now()), p_birthdate::timestamptz)
  )::int;
  IF v_cat.min_age IS NOT NULL AND v_age < v_cat.min_age THEN
    RAISE EXCEPTION 'age_below_min';
  END IF;
  IF v_cat.max_age IS NOT NULL AND v_age > v_cat.max_age THEN
    RAISE EXCEPTION 'age_above_max';
  END IF;

  IF v_cat.max_participants IS NOT NULL THEN
    SELECT COUNT(*)::bigint INTO v_count
      FROM public.participants
     WHERE category_id = p_category_id
       AND status <> 'eliminated';
    IF v_count >= v_cat.max_participants THEN
      RAISE EXCEPTION 'category_full';
    END IF;
  END IF;

  INSERT INTO public.participants(
    contest_id, category_id, user_id, name,
    first_name, last_name, birthdate, dni, country,
    email, phone, status
  ) VALUES (
    v_contest_id, p_category_id, v_user_id,
    TRIM(COALESCE(p_first_name,'') || ' ' || COALESCE(p_last_name,'')),
    p_first_name, p_last_name, p_birthdate, p_dni, p_country,
    p_email, p_phone, 'active'
  )
  RETURNING id INTO v_participant_id;

  -- Consume ticket (atomic; may raise insufficient_tickets in race)
  PERFORM public.consume_ticket(v_org_id, v_participant_id, v_contest_id, 'enrollment');

  RETURN v_participant_id;
END;
$$;

-- ─────────────────────────────────────────────
-- 9. Error mapping for new error codes added to UI via message-text
--    (no extra work needed; the handler in /api/public/inscriptions
--     already matches on substring of error.message)
-- ─────────────────────────────────────────────
