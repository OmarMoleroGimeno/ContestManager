-- 0023_participants_unique_per_category.sql
-- Prevent duplicate enrollments inside the same category. A participant is the
-- "same person" by user_id, DNI (case-insensitive) or email (case-insensitive).
-- Soft-deleted ('eliminated') rows are ignored by the unique constraint so they
-- can be re-enrolled later.

-- Soft-eliminate existing duplicates (keep oldest row per (category_id, key))
WITH dupes AS (
  SELECT id, ROW_NUMBER() OVER (
    PARTITION BY category_id, lower(dni) ORDER BY created_at ASC
  ) AS rn
  FROM public.participants
  WHERE dni IS NOT NULL AND dni <> '' AND status <> 'eliminated'
)
UPDATE public.participants p SET status = 'eliminated'
  FROM dupes d WHERE p.id = d.id AND d.rn > 1;

WITH dupes AS (
  SELECT id, ROW_NUMBER() OVER (
    PARTITION BY category_id, lower(email) ORDER BY created_at ASC
  ) AS rn
  FROM public.participants
  WHERE email IS NOT NULL AND email <> '' AND status <> 'eliminated'
)
UPDATE public.participants p SET status = 'eliminated'
  FROM dupes d WHERE p.id = d.id AND d.rn > 1;

WITH dupes AS (
  SELECT id, ROW_NUMBER() OVER (
    PARTITION BY category_id, user_id ORDER BY created_at ASC
  ) AS rn
  FROM public.participants
  WHERE user_id IS NOT NULL AND status <> 'eliminated'
)
UPDATE public.participants p SET status = 'eliminated'
  FROM dupes d WHERE p.id = d.id AND d.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS participants_unique_category_user
  ON public.participants (category_id, user_id)
  WHERE user_id IS NOT NULL AND status <> 'eliminated';

CREATE UNIQUE INDEX IF NOT EXISTS participants_unique_category_dni
  ON public.participants (category_id, lower(dni))
  WHERE dni IS NOT NULL AND dni <> '' AND status <> 'eliminated';

CREATE UNIQUE INDEX IF NOT EXISTS participants_unique_category_email
  ON public.participants (category_id, lower(email))
  WHERE email IS NOT NULL AND email <> '' AND status <> 'eliminated';
