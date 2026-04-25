-- Extend scores: admin can set on behalf of judge
ALTER TABLE scores
  ADD COLUMN IF NOT EXISTS set_by_admin BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS admin_user_id UUID REFERENCES auth.users(id);

-- Extend round_participants: admin final score override
ALTER TABLE round_participants
  ADD COLUMN IF NOT EXISTS final_score_override NUMERIC,
  ADD COLUMN IF NOT EXISTS final_score_override_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS final_score_override_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS final_score_override_notes TEXT;

-- Audit log table
CREATE TABLE IF NOT EXISTS score_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id UUID NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
  participant_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
  judge_id UUID REFERENCES auth.users(id),
  changed_by UUID NOT NULL REFERENCES auth.users(id),
  changed_by_name TEXT,
  action TEXT NOT NULL,
  old_value NUMERIC,
  new_value NUMERIC,
  notes TEXT,
  is_admin_action BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS score_audit_logs_round_idx ON score_audit_logs(round_id);
CREATE INDEX IF NOT EXISTS score_audit_logs_participant_idx ON score_audit_logs(participant_id, round_id);

ALTER TABLE score_audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Audit logs viewable by organizer" ON score_audit_logs FOR SELECT TO authenticated
USING (
  round_id IN (
    SELECT r.id FROM rounds r
    JOIN categories c ON c.id = r.category_id
    WHERE EXISTS (
      SELECT 1 FROM contest_members cm
      WHERE cm.contest_id = c.contest_id
        AND cm.user_id = auth.uid()
        AND cm.role = 'organizer'
    )
  )
);
