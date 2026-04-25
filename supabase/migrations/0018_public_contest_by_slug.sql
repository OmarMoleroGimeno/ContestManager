-- Public read by slug (no token needed) for landing pages /c/[slug]
CREATE OR REPLACE FUNCTION public.get_public_contest_by_slug(p_slug TEXT)
RETURNS TABLE (
  id UUID, slug TEXT, name TEXT, description TEXT, cover_image_url TEXT,
  type TEXT, status TEXT, starts_at TIMESTAMPTZ, ends_at TIMESTAMPTZ,
  registration_open BOOLEAN, registration_token TEXT,
  entry_fee_cents INTEGER, org_name TEXT, org_slug TEXT,
  org_charges_enabled BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.id, c.slug, c.name, c.description, c.cover_image_url,
         c.type::text, c.status::text,
         c.starts_at, c.ends_at, c.registration_open, c.registration_token,
         COALESCE(c.entry_fee_cents, 0),
         o.name, o.slug,
         COALESCE(o.stripe_charges_enabled, false)
    FROM public.contests c
    JOIN public.organizations o ON o.id = c.organization_id
   WHERE c.slug = p_slug
     AND c.status IN ('active','finished')
   LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_public_categories_by_slug(p_slug TEXT)
RETURNS TABLE (
  id UUID, name TEXT, description TEXT, status TEXT,
  min_age INT, max_age INT, max_participants INT, current_count BIGINT
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT cat.id, cat.name, cat.description, cat.status::text,
         cat.min_age, cat.max_age, cat.max_participants,
         (SELECT COUNT(*) FROM public.participants p
           WHERE p.category_id = cat.id AND p.status <> 'eliminated')::bigint
    FROM public.categories cat
    JOIN public.contests c ON c.id = cat.contest_id
   WHERE c.slug = p_slug
     AND c.status IN ('active','finished')
   ORDER BY cat.name ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_contest_by_slug(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_categories_by_slug(TEXT) TO anon, authenticated;
