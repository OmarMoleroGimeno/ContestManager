-- 0022_billing_reason_purchase_tickets.sql
-- Allow 'purchase_tickets' as a valid reason in billing_transactions for à-la-carte
-- ticket top-ups (see 0021_credit_tickets.sql).
ALTER TABLE public.billing_transactions DROP CONSTRAINT billing_transactions_reason_check;
ALTER TABLE public.billing_transactions ADD CONSTRAINT billing_transactions_reason_check
  CHECK (reason = ANY (ARRAY[
    'purchase_bundle',
    'purchase_tickets',
    'signup_bonus',
    'enrollment',
    'csv_import',
    'manual_add',
    'contest_activation',
    'admin_adjust'
  ]));
