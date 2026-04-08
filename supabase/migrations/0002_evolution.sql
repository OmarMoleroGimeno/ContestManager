-- 0002_evolution.sql
-- Evolution of the SaaS platform based on the legacy schema

-- 1. Categories expansion
ALTER TABLE IF EXISTS categories 
ADD COLUMN IF NOT EXISTS min_age INTEGER,
ADD COLUMN IF NOT EXISTS max_age INTEGER,
ADD COLUMN IF NOT EXISTS tier TEXT,
ADD COLUMN IF NOT EXISTS artistic_type TEXT,
ADD COLUMN IF NOT EXISTS speciality TEXT;

-- 2. Participants expansion
ALTER TABLE IF EXISTS participants 
ADD COLUMN IF NOT EXISTS first_name TEXT,
ADD COLUMN IF NOT EXISTS last_name TEXT,
ADD COLUMN IF NOT EXISTS dni TEXT,
ADD COLUMN IF NOT EXISTS birthdate DATE,
ADD COLUMN IF NOT EXISTS country TEXT;

-- 3. Round Participants expansion (Scheduling)
ALTER TABLE IF EXISTS round_participants 
ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS location TEXT;

-- 4. Rounds expansion (Chaining)
ALTER TABLE IF EXISTS rounds 
ADD COLUMN IF NOT EXISTS next_round_id UUID REFERENCES rounds(id) ON DELETE SET NULL;

-- 5. Prizes Table
CREATE TABLE IF NOT EXISTS prizes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    winner_id UUID REFERENCES participants(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Rehearsals (Essays) Table
CREATE TABLE IF NOT EXISTS rehearsals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id UUID NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
    participant_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
    accompanist_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- idPianist
    scheduled_at TIMESTAMPTZ NOT NULL,
    location TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Update Triggers
CREATE TRIGGER handle_prizes_updated_at
BEFORE UPDATE ON prizes
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

CREATE TRIGGER handle_rehearsals_updated_at
BEFORE UPDATE ON rehearsals
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

-- RLS for new tables
ALTER TABLE prizes ENABLE ROW LEVEL SECURITY;
ALTER TABLE rehearsals ENABLE ROW LEVEL SECURITY;

-- Prizes Policies
CREATE POLICY "Prizes are viewable by contest members" ON prizes FOR SELECT TO authenticated
USING (category_id IN (
    SELECT c.id FROM categories c
    WHERE is_contest_member(c.contest_id)
));

CREATE POLICY "Prizes are editable by organizer" ON prizes FOR ALL TO authenticated
USING (category_id IN (
    SELECT c.id FROM categories c
    WHERE is_contest_organizer(c.contest_id)
)) WITH CHECK (category_id IN (
    SELECT c.id FROM categories c
    WHERE is_contest_organizer(c.contest_id)
));

-- Rehearsals Policies
CREATE POLICY "Rehearsals are viewable by contest members" ON rehearsals FOR SELECT TO authenticated
USING (round_id IN (
    SELECT r.id FROM rounds r
    JOIN categories c ON c.id = r.category_id
    WHERE is_contest_member(c.contest_id)
));

CREATE POLICY "Rehearsals are editable by organizer" ON rehearsals FOR ALL TO authenticated
USING (round_id IN (
    SELECT r.id FROM rounds r
    JOIN categories c ON c.id = r.category_id
    WHERE is_contest_organizer(c.contest_id)
)) WITH CHECK (round_id IN (
    SELECT r.id FROM rounds r
    JOIN categories c ON c.id = r.category_id
    WHERE is_contest_organizer(c.contest_id)
));
