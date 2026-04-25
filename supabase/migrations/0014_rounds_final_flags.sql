-- 0014_rounds_final_flags.sql
-- Snapshot existing in-DB additions: is_final, is_ranking, is_published on rounds.
-- These flags power the "finalize contest + publish ranking pseudo-round" flow.

ALTER TABLE IF EXISTS public.rounds
  ADD COLUMN IF NOT EXISTS is_final     BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_ranking   BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT false;

-- Partial unique indexes: at most one final round + one ranking pseudo-round per category
CREATE UNIQUE INDEX IF NOT EXISTS rounds_one_final_per_category
  ON public.rounds (category_id)
  WHERE is_final = true;

CREATE UNIQUE INDEX IF NOT EXISTS rounds_one_ranking_per_category
  ON public.rounds (category_id)
  WHERE is_ranking = true;
