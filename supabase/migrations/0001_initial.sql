-- Trigger function for updated_at
CREATE OR REPLACE FUNCTION handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Enums
CREATE TYPE contest_type AS ENUM ('music', 'general', 'dance', 'libre');
CREATE TYPE contest_status AS ENUM ('draft', 'active', 'finished', 'cancelled');
CREATE TYPE contest_role AS ENUM ('organizer', 'judge', 'viewer');
CREATE TYPE category_status AS ENUM ('pending', 'active', 'closed');
CREATE TYPE round_status AS ENUM ('pending', 'active', 'closed');
CREATE TYPE scoring_type AS ENUM ('numeric', 'rank', 'vote');
CREATE TYPE participant_status AS ENUM ('active', 'eliminated');

-- Organizations
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    logo_url TEXT,
    settings JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER handle_organizations_updated_at
BEFORE UPDATE ON organizations
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

-- Contests
CREATE TABLE contests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    type contest_type NOT NULL DEFAULT 'music',
    status contest_status NOT NULL DEFAULT 'draft',
    is_rounds_dynamic BOOLEAN NOT NULL DEFAULT false,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    settings JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER handle_contests_updated_at
BEFORE UPDATE ON contests
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

-- Contest Members
CREATE TABLE contest_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contest_id UUID NOT NULL REFERENCES contests(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role contest_role NOT NULL DEFAULT 'viewer',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(contest_id, user_id)
);

CREATE TRIGGER handle_contest_members_updated_at
BEFORE UPDATE ON contest_members
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

-- Categories
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contest_id UUID NOT NULL REFERENCES contests(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    "order" INTEGER NOT NULL DEFAULT 0,
    status category_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER handle_categories_updated_at
BEFORE UPDATE ON categories
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

-- Rounds
CREATE TABLE rounds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    "order" INTEGER NOT NULL DEFAULT 0,
    status round_status NOT NULL DEFAULT 'pending',
    scoring_type scoring_type NOT NULL DEFAULT 'numeric',
    max_score NUMERIC,
    started_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER handle_rounds_updated_at
BEFORE UPDATE ON rounds
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

-- Participants
CREATE TABLE participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contest_id UUID NOT NULL REFERENCES contests(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    metadata JSONB,
    status participant_status NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER handle_participants_updated_at
BEFORE UPDATE ON participants
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

-- Round Participants
CREATE TABLE round_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id UUID NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
    participant_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
    "order" INTEGER,
    is_qualified BOOLEAN,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(round_id, participant_id)
);

CREATE TRIGGER handle_round_participants_updated_at
BEFORE UPDATE ON round_participants
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

-- Score Criteria
CREATE TABLE score_criteria (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id UUID NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    weight NUMERIC NOT NULL DEFAULT 1.0,
    max_value NUMERIC NOT NULL DEFAULT 10.0,
    "order" INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER handle_score_criteria_updated_at
BEFORE UPDATE ON score_criteria
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

-- Scores
CREATE TABLE scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id UUID NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
    participant_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
    judge_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    value NUMERIC NOT NULL,
    criteria_scores JSONB,
    notes TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(round_id, participant_id, judge_id)
);

CREATE TRIGGER handle_scores_updated_at
BEFORE UPDATE ON scores
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

-- =========================================================
-- RLS POLICIES
-- =========================================================

ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE contests ENABLE ROW LEVEL SECURITY;
ALTER TABLE contest_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE round_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE score_criteria ENABLE ROW LEVEL SECURITY;
ALTER TABLE scores ENABLE ROW LEVEL SECURITY;

-- Helper Function for RLS
CREATE OR REPLACE FUNCTION public.is_contest_organizer(c_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM contest_members
    WHERE contest_id = c_id
    AND user_id = auth.uid()
    AND role = 'organizer'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_contest_member(c_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM contest_members
    WHERE contest_id = c_id
    AND user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Organizations: Only members can read. Owner can write.
-- Wait, we don't have org_members, only contest_members. We'll allow owner to read/write,
-- and anyone who is in a contest for this org to read.
CREATE POLICY "Organizations are viewable by owner and contest members" ON organizations FOR SELECT TO authenticated
USING (
    owner_id = auth.uid() OR
    id IN (SELECT organization_id FROM contests WHERE is_contest_member(id))
);

CREATE POLICY "Organizations are editable by owner" ON organizations FOR ALL TO authenticated
USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

-- Contests: Public read if not draft. Write for organizer.
CREATE POLICY "Contests are viewable by public if not draft" ON contests FOR SELECT
USING (status != 'draft');

CREATE POLICY "Contests are viewable by members" ON contests FOR SELECT TO authenticated
USING (is_contest_member(id));

CREATE POLICY "Contests are editable by organizer" ON contests FOR ALL TO authenticated
USING (is_contest_organizer(id)) WITH CHECK (is_contest_organizer(id));

-- Contest Members
CREATE POLICY "Contest members viewable by members" ON contest_members FOR SELECT TO authenticated
USING (is_contest_member(contest_id));

CREATE POLICY "Contest members editable by organizer" ON contest_members FOR ALL TO authenticated
USING (is_contest_organizer(contest_id)) WITH CHECK (is_contest_organizer(contest_id));

-- Categories
CREATE POLICY "Categories viewable by members" ON categories FOR SELECT TO authenticated
USING (is_contest_member(contest_id));

CREATE POLICY "Categories editable by organizer" ON categories FOR ALL TO authenticated
USING (is_contest_organizer(contest_id)) WITH CHECK (is_contest_organizer(contest_id));

-- Rounds
CREATE POLICY "Rounds viewable by members" ON rounds FOR SELECT TO authenticated
USING (id IN (
    SELECT r.id FROM rounds r
    JOIN categories c ON c.id = r.category_id
    WHERE is_contest_member(c.contest_id)
));

CREATE POLICY "Rounds editable by organizer" ON rounds FOR ALL TO authenticated
USING (id IN (
    SELECT r.id FROM rounds r
    JOIN categories c ON c.id = r.category_id
    WHERE is_contest_organizer(c.contest_id)
)) WITH CHECK (id IN (
    SELECT r.id FROM rounds r
    JOIN categories c ON c.id = r.category_id
    WHERE is_contest_organizer(c.contest_id)
));

-- Participants
CREATE POLICY "Participants viewable by members or themselves" ON participants FOR SELECT TO authenticated
USING (
    is_contest_member(contest_id) OR
    user_id = auth.uid()
);

CREATE POLICY "Participants editable by organizer" ON participants FOR ALL TO authenticated
USING (is_contest_organizer(contest_id)) WITH CHECK (is_contest_organizer(contest_id));

-- Round Participants
CREATE POLICY "Round Participants viewable by members" ON round_participants FOR SELECT TO authenticated
USING (id IN (
    SELECT rp.id FROM round_participants rp
    JOIN rounds r ON r.id = rp.round_id
    JOIN categories c ON c.id = r.category_id
    WHERE is_contest_member(c.contest_id)
));

CREATE POLICY "Round Participants editable by organizer" ON round_participants FOR ALL TO authenticated
USING (id IN (
    SELECT rp.id FROM round_participants rp
    JOIN rounds r ON r.id = rp.round_id
    JOIN categories c ON c.id = r.category_id
    WHERE is_contest_organizer(c.contest_id)
)) WITH CHECK (id IN (
    SELECT rp.id FROM round_participants rp
    JOIN rounds r ON r.id = rp.round_id
    JOIN categories c ON c.id = r.category_id
    WHERE is_contest_organizer(c.contest_id)
));

-- Score Criteria
CREATE POLICY "Score Criteria viewable by members" ON score_criteria FOR SELECT TO authenticated
USING (id IN (
    SELECT sc.id FROM score_criteria sc
    JOIN rounds r ON r.id = sc.round_id
    JOIN categories c ON c.id = r.category_id
    WHERE is_contest_member(c.contest_id)
));

CREATE POLICY "Score Criteria editable by organizer" ON score_criteria FOR ALL TO authenticated
USING (id IN (
    SELECT sc.id FROM score_criteria sc
    JOIN rounds r ON r.id = sc.round_id
    JOIN categories c ON c.id = r.category_id
    WHERE is_contest_organizer(c.contest_id)
)) WITH CHECK (id IN (
    SELECT sc.id FROM score_criteria sc
    JOIN rounds r ON r.id = sc.round_id
    JOIN categories c ON c.id = r.category_id
    WHERE is_contest_organizer(c.contest_id)
));

-- Scores: Judge reads/writes own. Organizer reads all.
CREATE POLICY "Scores viewable by judge or organizer" ON scores FOR SELECT TO authenticated
USING (
    judge_id = auth.uid() OR
    id IN (
        SELECT s.id FROM scores s
        JOIN rounds r ON r.id = s.round_id
        JOIN categories c ON c.id = r.category_id
        WHERE is_contest_organizer(c.contest_id)
    )
);

CREATE POLICY "Scores insertable by judge" ON scores FOR INSERT TO authenticated
WITH CHECK (judge_id = auth.uid());

CREATE POLICY "Scores updatable by judge" ON scores FOR UPDATE TO authenticated
USING (judge_id = auth.uid()) WITH CHECK (judge_id = auth.uid());

CREATE POLICY "Scores deletable by judge" ON scores FOR DELETE TO authenticated
USING (judge_id = auth.uid());
