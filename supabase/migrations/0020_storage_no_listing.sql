-- 0020_storage_no_listing.sql
-- Drop broad SELECT policies on public storage buckets.
-- Public buckets serve object URLs directly via the CDN; a SELECT policy on
-- storage.objects only grants list-objects rights, exposing file inventories.
DROP POLICY IF EXISTS "Public read avatars" ON storage.objects;
DROP POLICY IF EXISTS "contest_assets_public_read" ON storage.objects;
