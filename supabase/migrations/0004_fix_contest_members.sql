-- 0004_fix_contest_members.sql
-- Allow judges to be added without a user_id yet
-- and support external names/emails in contest_members

-- 1. Add email and full_name columns
ALTER TABLE public.contest_members 
ADD COLUMN IF NOT EXISTS email TEXT,
ADD COLUMN IF NOT EXISTS full_name TEXT;

-- 2. Make user_id optional
ALTER TABLE public.contest_members 
ALTER COLUMN user_id DROP NOT NULL;

-- 3. Update RLS policies (if any depend on user_id)
-- The existing is_contest_member function might need check.
-- Let's check is_contest_member definition.
