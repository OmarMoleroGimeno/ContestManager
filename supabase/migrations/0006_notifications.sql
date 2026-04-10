-- ─── Notifications table ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,           -- 'contest_joined', 'judge_assigned', etc.
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  payload     JSONB DEFAULT '{}',      -- extra context (contest_id, category_id…)
  read        BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_read_idx    ON public.notifications(user_id, read);

-- ─── RLS ────────────────────────────────────────────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- Service role can insert (used by triggers via SECURITY DEFINER)
CREATE POLICY "Service role can insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (true);

-- ─── Enable Realtime ─────────────────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- ─── Trigger: participant added to a contest category ────────────────────────
CREATE OR REPLACE FUNCTION public.notify_participant_added()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_contest_name  TEXT;
  v_contest_slug  TEXT;
  v_category_name TEXT;
BEGIN
  -- participants.user_id may be null for external participants; skip if null
  IF NEW.user_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT c.name, c.slug, cat.name
    INTO v_contest_name, v_contest_slug, v_category_name
    FROM categories cat
    JOIN contests c ON c.id = cat.contest_id
   WHERE cat.id = NEW.category_id;

  INSERT INTO public.notifications (user_id, type, title, body, payload)
  VALUES (
    NEW.user_id,
    'contest_joined',
    'Has sido inscrito en un concurso',
    'Te han inscrito en la categoría "' || COALESCE(v_category_name, '') || '" del concurso "' || COALESCE(v_contest_name, '') || '".',
    jsonb_build_object(
      'category_id', NEW.category_id,
      'contest_name', v_contest_name,
      'contest_slug', v_contest_slug,
      'category_name', v_category_name
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_participant_added ON public.participants;
CREATE TRIGGER trg_notify_participant_added
  AFTER INSERT ON public.participants
  FOR EACH ROW EXECUTE FUNCTION public.notify_participant_added();

-- ─── Trigger: judge assigned to a contest ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_judge_assigned()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_contest_name  TEXT;
  v_contest_slug  TEXT;
  v_judge_user_id UUID;
BEGIN
  -- Only fire for judge role
  IF NEW.role <> 'judge' THEN
    RETURN NEW;
  END IF;

  -- If user_id is set directly, use it; otherwise look up by email
  IF NEW.user_id IS NOT NULL THEN
    v_judge_user_id := NEW.user_id;
  ELSIF NEW.email IS NOT NULL THEN
    SELECT id INTO v_judge_user_id
      FROM auth.users
     WHERE email = NEW.email
     LIMIT 1;
  END IF;

  IF v_judge_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT name, slug INTO v_contest_name, v_contest_slug FROM contests WHERE id = NEW.contest_id;

  INSERT INTO public.notifications (user_id, type, title, body, payload)
  VALUES (
    v_judge_user_id,
    'judge_assigned',
    'Has sido asignado como jurado',
    'Has sido asignado como jurado en el concurso "' || COALESCE(v_contest_name, '') || '".',
    jsonb_build_object(
      'contest_id', NEW.contest_id,
      'contest_name', v_contest_name,
      'contest_slug', v_contest_slug
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_judge_assigned ON public.contest_members;
CREATE TRIGGER trg_notify_judge_assigned
  AFTER INSERT ON public.contest_members
  FOR EACH ROW EXECUTE FUNCTION public.notify_judge_assigned();
