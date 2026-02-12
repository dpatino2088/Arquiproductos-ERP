-- Create storage bucket "dealer-logo" for dealer logos (separate from catalog-images).
-- Note: The full DB dump (e.g. backups/2026-02_07_V12_full.sql) does NOT include the storage
-- schema; buckets are not in the dump. This script must be run in the Supabase project to
-- ensure the dealer-logo bucket exists. Run in Supabase SQL Editor (Dashboard → SQL Editor).
-- If your project uses a different storage.buckets schema, adjust column names (e.g. file_size_limit vs fileSizeLimit).

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types,
  created_at,
  updated_at
)
VALUES (
  gen_random_uuid(),
  'dealer-logo',
  true,
  5242880,  -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
  now(),
  now()
)
ON CONFLICT (name) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types,
  updated_at = now();
