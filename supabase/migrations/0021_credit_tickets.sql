-- 0021_credit_tickets.sql
-- À la carte ticket top-up (no pack). Called from Stripe webhook on
-- successful checkout sessions whose metadata.type = 'tickets'.

CREATE OR REPLACE FUNCTION public.credit_tickets(
  p_org_id            UUID,
  p_quantity          INT,
  p_price_cents       INT,
  p_stripe_session_id TEXT,
  p_stripe_event_id   TEXT
) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_balance INT;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'invalid_quantity';
  END IF;

  -- Idempotency
  IF EXISTS (SELECT 1 FROM public.billing_transactions WHERE stripe_event_id = p_stripe_event_id) THEN
    SELECT ticket_balance INTO v_new_balance FROM public.organizations WHERE id = p_org_id;
    RETURN v_new_balance;
  END IF;

  UPDATE public.organizations
     SET ticket_balance = ticket_balance + p_quantity
   WHERE id = p_org_id
   RETURNING ticket_balance INTO v_new_balance;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'org_not_found';
  END IF;

  INSERT INTO public.billing_transactions
    (organization_id, entity, delta, reason, plan, amount_cents, stripe_session_id, stripe_event_id, balance_after)
  VALUES
    (p_org_id, 'ticket', p_quantity, 'purchase_tickets', NULL, p_price_cents, p_stripe_session_id, p_stripe_event_id, v_new_balance);

  RETURN v_new_balance;
END;
$$;
