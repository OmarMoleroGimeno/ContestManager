-- 0026_refund_ticket.sql
-- Adds a refund path for tickets consumed via enrollment/csv_import/manual_add.
-- Used when a participant is removed before the contest is activated.

ALTER TABLE public.billing_transactions DROP CONSTRAINT billing_transactions_reason_check;
ALTER TABLE public.billing_transactions ADD CONSTRAINT billing_transactions_reason_check
  CHECK (reason = ANY (ARRAY[
    'purchase_bundle','purchase_tickets','signup_bonus','enrollment','csv_import',
    'manual_add','contest_activation','admin_adjust','refund_ticket'
  ]));

CREATE OR REPLACE FUNCTION public.refund_ticket(
  p_org_id         UUID,
  p_participant_id UUID,
  p_contest_id     UUID
) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_consumed    INT;
  v_already     INT;
  v_new_balance INT;
BEGIN
  SELECT COUNT(*) INTO v_consumed FROM public.billing_transactions
   WHERE participant_id = p_participant_id
     AND entity = 'ticket' AND delta = -1
     AND reason IN ('enrollment','csv_import','manual_add');
  IF v_consumed = 0 THEN RETURN NULL; END IF;

  SELECT COUNT(*) INTO v_already FROM public.billing_transactions
   WHERE participant_id = p_participant_id
     AND entity = 'ticket' AND delta = 1 AND reason = 'refund_ticket';
  IF v_already > 0 THEN RETURN NULL; END IF;

  UPDATE public.organizations
     SET ticket_balance = ticket_balance + 1
   WHERE id = p_org_id
   RETURNING ticket_balance INTO v_new_balance;
  IF NOT FOUND THEN RAISE EXCEPTION 'org_not_found'; END IF;

  INSERT INTO public.billing_transactions
    (organization_id, entity, delta, reason, participant_id, contest_id, balance_after)
  VALUES (p_org_id, 'ticket', 1, 'refund_ticket', p_participant_id, p_contest_id, v_new_balance);

  RETURN v_new_balance;
END;
$$;
