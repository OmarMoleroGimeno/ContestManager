-- 0024_bulk_enroll_dedupe.sql
-- Add per-row duplicate check (DNI + email) to bulk_enroll_csv. Raises
-- 'already_enrolled_in_category' when a person is already active in the target
-- category. Pairs with the partial unique indexes from 0023.

CREATE OR REPLACE FUNCTION public.bulk_enroll_csv(p_contest_id uuid, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id      UUID := auth.uid();
  v_org_id       UUID;
  v_owner_id     UUID;
  v_reg_starts   TIMESTAMPTZ;
  v_row          JSONB;
  v_count        INT := 0;
  v_ticket_bal   INT;
  v_cat          RECORD;
  v_age          INT;
  v_current      BIGINT;
  v_participant_id UUID;
  v_inserted_ids UUID[] := ARRAY[]::UUID[];
  v_cat_ids      UUID[] := ARRAY[]::UUID[];
  v_cat_id       UUID;
  v_birthdate    DATE;
  v_dni          TEXT;
  v_email        TEXT;
  v_dup          INT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000'; END IF;

  SELECT organization_id, starts_at
    INTO v_org_id, v_reg_starts
    FROM public.contests WHERE id = p_contest_id;
  IF v_org_id IS NULL THEN RAISE EXCEPTION 'contest_not_found'; END IF;

  SELECT owner_id INTO v_owner_id FROM public.organizations WHERE id = v_org_id;
  IF v_owner_id <> v_user_id THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_count := jsonb_array_length(p_rows);
  IF v_count = 0 THEN RAISE EXCEPTION 'empty_rows'; END IF;

  SELECT ticket_balance INTO v_ticket_bal
    FROM public.organizations WHERE id = v_org_id FOR UPDATE;
  IF v_ticket_bal < v_count THEN
    RAISE EXCEPTION 'insufficient_tickets: need %, have %', v_count, v_ticket_bal;
  END IF;

  FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    v_cat_id := (v_row->>'category_id')::UUID;
    v_dni    := NULLIF(v_row->>'dni','');
    v_email  := NULLIF(v_row->>'email','');

    SELECT * INTO v_cat FROM public.categories
     WHERE id = v_cat_id AND contest_id = p_contest_id;
    IF v_cat IS NULL THEN RAISE EXCEPTION 'category_not_found: %', v_cat_id; END IF;

    IF v_dni IS NOT NULL THEN
      SELECT COUNT(*) INTO v_dup FROM public.participants
        WHERE category_id = v_cat_id AND lower(dni) = lower(v_dni) AND status <> 'eliminated';
      IF v_dup > 0 THEN
        RAISE EXCEPTION 'already_enrolled_in_category: dni % cat %', v_dni, v_cat.name;
      END IF;
    END IF;
    IF v_email IS NOT NULL THEN
      SELECT COUNT(*) INTO v_dup FROM public.participants
        WHERE category_id = v_cat_id AND lower(email) = lower(v_email) AND status <> 'eliminated';
      IF v_dup > 0 THEN
        RAISE EXCEPTION 'already_enrolled_in_category: email % cat %', v_email, v_cat.name;
      END IF;
    END IF;

    v_birthdate := (v_row->>'birthdate')::DATE;
    v_age := date_part('year', age(COALESCE(v_reg_starts, now()), v_birthdate::timestamptz))::int;
    IF v_cat.min_age IS NOT NULL AND v_age < v_cat.min_age THEN
      RAISE EXCEPTION 'age_below_min: row % cat %', v_row, v_cat.name;
    END IF;
    IF v_cat.max_age IS NOT NULL AND v_age > v_cat.max_age THEN
      RAISE EXCEPTION 'age_above_max: row % cat %', v_row, v_cat.name;
    END IF;

    IF v_cat.max_participants IS NOT NULL THEN
      SELECT COUNT(*)::bigint INTO v_current
        FROM public.participants
       WHERE category_id = v_cat_id AND status <> 'eliminated';
      v_current := v_current + (SELECT COUNT(*) FROM unnest(v_cat_ids) x WHERE x = v_cat_id);
      IF v_current >= v_cat.max_participants THEN
        RAISE EXCEPTION 'category_full: %', v_cat.name;
      END IF;
    END IF;

    INSERT INTO public.participants(
      contest_id, category_id, user_id, name,
      first_name, last_name, birthdate, dni, country, email, phone, status,
      payment_status
    ) VALUES (
      p_contest_id, v_cat_id, NULL,
      TRIM(COALESCE(v_row->>'first_name','') || ' ' || COALESCE(v_row->>'last_name','')),
      v_row->>'first_name', v_row->>'last_name', v_birthdate,
      v_dni, NULLIF(v_row->>'country',''),
      v_email, NULLIF(v_row->>'phone',''),
      'active', 'free'
    ) RETURNING id INTO v_participant_id;

    PERFORM public.consume_ticket(v_org_id, v_participant_id, p_contest_id, 'csv_import');
    v_inserted_ids := array_append(v_inserted_ids, v_participant_id);
    v_cat_ids      := array_append(v_cat_ids, v_cat_id);
  END LOOP;

  RETURN jsonb_build_object(
    'inserted', v_count,
    'participant_ids', to_jsonb(v_inserted_ids)
  );
END; $function$;
