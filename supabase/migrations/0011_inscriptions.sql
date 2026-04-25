-- 0011_inscriptions.sql
-- Public inscription flow: token-based registration links, age/capacity checks

-- ─────────────────────────────────────────────
-- 1. contests: registration token + open flag
-- ─────────────────────────────────────────────
ALTER TABLE public.contests
  ADD COLUMN IF NOT EXISTS registration_token TEXT,
  ADD COLUMN IF NOT EXISTS registration_open BOOLEAN NOT NULL DEFAULT true;

-- Backfill tokens for existing rows
UPDATE public.contests
   SET registration_token = encode(gen_random_bytes(12), 'hex')
 WHERE registration_token IS NULL;

ALTER TABLE public.contests
  ALTER COLUMN registration_token SET DEFAULT encode(gen_random_bytes(12), 'hex'),
  ALTER COLUMN registration_token SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS contests_registration_token_key
  ON public.contests (registration_token);

-- ─────────────────────────────────────────────
-- 2. categories: optional capacity
-- ─────────────────────────────────────────────
ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS max_participants INT;

-- ─────────────────────────────────────────────
-- 3. participants: email / phone
-- ─────────────────────────────────────────────
ALTER TABLE public.participants
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT;

-- Prevent a user enrolling twice in the same category
CREATE UNIQUE INDEX IF NOT EXISTS participants_unique_user_category
  ON public.participants (category_id, user_id)
  WHERE user_id IS NOT NULL;

-- ─────────────────────────────────────────────
-- 4. Public read: contest + categories by token
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_contest_by_token(p_token TEXT)
RETURNS TABLE (
  id UUID,
  slug TEXT,
  name TEXT,
  description TEXT,
  cover_image_url TEXT,
  type TEXT,
  status TEXT,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  registration_open BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.id, c.slug, c.name, c.description, c.cover_image_url,
         c.type::text, c.status::text,
         c.starts_at, c.ends_at, c.registration_open
    FROM public.contests c
   WHERE c.registration_token = p_token
   LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_categories_for_token(p_token TEXT)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  status TEXT,
  min_age INT,
  max_age INT,
  max_participants INT,
  current_count BIGINT
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT cat.id, cat.name, cat.description, cat.status::text,
         cat.min_age, cat.max_age, cat.max_participants,
         (SELECT COUNT(*)
            FROM public.participants p
           WHERE p.category_id = cat.id
             AND p.status <> 'eliminated')::bigint AS current_count
    FROM public.categories cat
    JOIN public.contests c ON c.id = cat.contest_id
   WHERE c.registration_token = p_token
   ORDER BY cat.name ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_contest_by_token(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_categories_for_token(TEXT) TO anon, authenticated;

-- ─────────────────────────────────────────────
-- 5. Enroll RPC (authenticated users only)
--    Validates: auth, open window, age range, capacity
--    Triggers existing notify_participant_added → in-app notification
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
  v_reg_open       BOOLEAN;
  v_reg_starts     TIMESTAMPTZ;
  v_cat            RECORD;
  v_age            INT;
  v_count          BIGINT;
  v_participant_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000';
  END IF;

  SELECT id, registration_open, starts_at
    INTO v_contest_id, v_reg_open, v_reg_starts
    FROM public.contests
   WHERE registration_token = p_token
   LIMIT 1;

  IF v_contest_id IS NULL THEN
    RAISE EXCEPTION 'contest_not_found';
  END IF;
  IF NOT v_reg_open THEN
    RAISE EXCEPTION 'registration_closed';
  END IF;

  SELECT * INTO v_cat
    FROM public.categories
   WHERE id = p_category_id AND contest_id = v_contest_id;
  IF v_cat IS NULL THEN
    RAISE EXCEPTION 'category_not_found';
  END IF;

  -- Age at contest start (falls back to now() if no start date)
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

  -- Capacity
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

  RETURN v_participant_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.enroll_participant(
  TEXT, UUID, TEXT, TEXT, DATE, TEXT, TEXT, TEXT, TEXT
) TO authenticated;
