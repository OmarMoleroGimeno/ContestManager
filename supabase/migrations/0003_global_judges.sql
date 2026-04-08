-- 0003_global_judges.sql
-- New structure for Global Judge Profiles and Organization Memberships

-- 1. Create Global Judges Table
CREATE TABLE IF NOT EXISTS public.judges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    specialty TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Create Judge Pool Memberships Table (Multi-tenant link)
CREATE TABLE IF NOT EXISTS public.judge_pool_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    judge_id UUID NOT NULL REFERENCES public.judges(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(organization_id, judge_id)
);

-- 3. Enable RLS
ALTER TABLE public.judges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.judge_pool_members ENABLE ROW LEVEL SECURITY;

-- 4. Triggers for updated_at
CREATE TRIGGER handle_judges_updated_at
BEFORE UPDATE ON judges
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

CREATE TRIGGER handle_judge_pool_members_updated_at
BEFORE UPDATE ON judge_pool_members
FOR EACH ROW EXECUTE PROCEDURE handle_updated_at();

-- 5. RLS Policies
-- Judges: Viewable by anyone in the same organization pool
CREATE POLICY "Judges are viewable by organization members" ON judges FOR SELECT TO authenticated
USING (
    id IN (
        SELECT judge_id FROM judge_pool_members jpm
        JOIN organizations o ON o.id = jpm.organization_id
        WHERE o.owner_id = auth.uid() OR EXISTS (
            SELECT 1 FROM contests c 
            WHERE c.organization_id = o.id AND is_contest_member(c.id)
        )
    )
);

-- Judge Pool Members: Viewable by organization owner and contest members
CREATE POLICY "Judge memberships viewable by owner and members" ON judge_pool_members FOR SELECT TO authenticated
USING (
    organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
    ) OR organization_id IN (
        SELECT organization_id FROM contests WHERE is_contest_member(id)
    )
);

-- Edit Policies (Owner only)
CREATE POLICY "Judges are editable by organization owner" ON judges FOR ALL TO authenticated
USING (
    id IN (
        SELECT judge_id FROM judge_pool_members jpm
        JOIN organizations o ON o.id = jpm.organization_id
        WHERE o.owner_id = auth.uid()
    )
);

CREATE POLICY "Judge memberships are editable by organization owner" ON judge_pool_members FOR ALL TO authenticated
USING (
    organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid())
);
