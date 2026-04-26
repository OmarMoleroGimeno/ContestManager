-- ─── Notify organization owner on participant enroll/unenroll ───────────────

-- INSERT: notify org owner of new enrollment
CREATE OR REPLACE FUNCTION public.notify_org_participant_added()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_owner_id      UUID;
  v_contest_name  TEXT;
  v_contest_slug  TEXT;
  v_category_name TEXT;
  v_participant   TEXT;
BEGIN
  SELECT o.owner_id, c.name, c.slug, cat.name
    INTO v_owner_id, v_contest_name, v_contest_slug, v_category_name
    FROM categories cat
    JOIN contests c       ON c.id = cat.contest_id
    JOIN organizations o  ON o.id = c.organization_id
   WHERE cat.id = NEW.category_id;

  IF v_owner_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_participant := TRIM(COALESCE(NEW.first_name, '') || ' ' || COALESCE(NEW.last_name, ''));
  IF v_participant = '' THEN
    v_participant := COALESCE(NEW.name, 'Participante');
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, payload)
  VALUES (
    v_owner_id,
    'org_participant_enrolled',
    'Nueva inscripción',
    v_participant || ' se ha inscrito en "' || COALESCE(v_category_name, '') || '" (' || COALESCE(v_contest_name, '') || ').',
    jsonb_build_object(
      'participant_id',  NEW.id,
      'participant_name', v_participant,
      'contest_id',      NEW.contest_id,
      'contest_name',    v_contest_name,
      'contest_slug',    v_contest_slug,
      'category_id',     NEW.category_id,
      'category_name',   v_category_name
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_org_participant_added ON public.participants;
CREATE TRIGGER trg_notify_org_participant_added
  AFTER INSERT ON public.participants
  FOR EACH ROW EXECUTE FUNCTION public.notify_org_participant_added();

-- DELETE: notify org owner of unenrollment
CREATE OR REPLACE FUNCTION public.notify_org_participant_removed()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_owner_id      UUID;
  v_contest_name  TEXT;
  v_contest_slug  TEXT;
  v_category_name TEXT;
  v_participant   TEXT;
BEGIN
  SELECT o.owner_id, c.name, c.slug, cat.name
    INTO v_owner_id, v_contest_name, v_contest_slug, v_category_name
    FROM categories cat
    JOIN contests c       ON c.id = cat.contest_id
    JOIN organizations o  ON o.id = c.organization_id
   WHERE cat.id = OLD.category_id;

  IF v_owner_id IS NULL THEN
    RETURN OLD;
  END IF;

  v_participant := TRIM(COALESCE(OLD.first_name, '') || ' ' || COALESCE(OLD.last_name, ''));
  IF v_participant = '' THEN
    v_participant := COALESCE(OLD.name, 'Participante');
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, payload)
  VALUES (
    v_owner_id,
    'org_participant_unenrolled',
    'Baja de inscripción',
    v_participant || ' ya no está inscrito en "' || COALESCE(v_category_name, '') || '" (' || COALESCE(v_contest_name, '') || ').',
    jsonb_build_object(
      'participant_id',   OLD.id,
      'participant_name', v_participant,
      'contest_id',       OLD.contest_id,
      'contest_name',     v_contest_name,
      'contest_slug',     v_contest_slug,
      'category_id',      OLD.category_id,
      'category_name',    v_category_name
    )
  );

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_org_participant_removed ON public.participants;
CREATE TRIGGER trg_notify_org_participant_removed
  AFTER DELETE ON public.participants
  FOR EACH ROW EXECUTE FUNCTION public.notify_org_participant_removed();
