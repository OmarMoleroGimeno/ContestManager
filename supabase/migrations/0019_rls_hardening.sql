-- 0019_rls_hardening.sql
-- Tighten RLS + fix mutable search_path on SECURITY DEFINER helpers.

-- ─────────────────────────────────────────────────────────────
-- 1. notifications: restrict INSERT to service_role only.
--    Previous policy allowed any role (public) with WITH CHECK (true),
--    which let authenticated clients forge notifications for any user.
--    All inserts come from triggers (SECURITY DEFINER) or server code
--    using the service_role key, so service_role-only is safe.
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Service role can insert notifications" ON public.notifications;

CREATE POLICY "Service role can insert notifications"
  ON public.notifications
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Scope SELECT/UPDATE to authenticated role (still gated by user_id).
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- 2. Pin search_path on SECURITY DEFINER / trigger functions.
--    Prevents privilege-escalation via search_path rewriting.
-- ─────────────────────────────────────────────────────────────
ALTER FUNCTION public.is_contest_organizer(uuid)                SET search_path = public, pg_temp;
ALTER FUNCTION public.is_contest_member(uuid)                   SET search_path = public, pg_temp;
ALTER FUNCTION public.notify_participant_added()                SET search_path = public, pg_temp;
ALTER FUNCTION public.notify_judge_assigned()                   SET search_path = public, pg_temp;
ALTER FUNCTION public.notify_org_participant_added()            SET search_path = public, pg_temp;
ALTER FUNCTION public.notify_org_participant_removed()          SET search_path = public, pg_temp;
ALTER FUNCTION public.handle_updated_at()                       SET search_path = public, pg_temp;
ALTER FUNCTION public.set_updated_at()                          SET search_path = public, pg_temp;
ALTER FUNCTION public.get_judge_pool(uuid)                      SET search_path = public, pg_temp;
ALTER FUNCTION public.get_contest_members_with_avatar(uuid)     SET search_path = public, pg_temp;
ALTER FUNCTION public.get_plan_bundles()                        SET search_path = public, pg_temp;
