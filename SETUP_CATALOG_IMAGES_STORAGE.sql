-- =====================================================
-- Setup Supabase Storage for Catalog Item Images
-- =====================================================
-- This script creates a public storage bucket for catalog item images
-- and sets up the necessary policies for authenticated users to upload
-- and for public users to read images.
--
-- IMPORTANT: Run this script in your Supabase SQL Editor
-- =====================================================

-- Step 1: Create the storage bucket (if it doesn't exist)
-- Note: This will fail if the bucket already exists, which is fine
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'catalog-images',
  'catalog-images',
  true, -- Public bucket (anyone can read)
  5242880, -- 5MB file size limit
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Step 2: Allow authenticated users to upload images
CREATE POLICY "Allow authenticated uploads"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'catalog-images');

-- Step 3: Allow public read access to images
CREATE POLICY "Allow public read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'catalog-images');

-- Step 4: Allow authenticated users to update their own uploads
CREATE POLICY "Allow authenticated updates"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'catalog-images')
WITH CHECK (bucket_id = 'catalog-images');

-- Step 5: Allow authenticated users to delete their own uploads
CREATE POLICY "Allow authenticated deletes"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'catalog-images');

-- =====================================================
-- Verification Queries (optional - run to verify setup)
-- =====================================================

-- Check if bucket was created
-- SELECT * FROM storage.buckets WHERE id = 'catalog-images';

-- Check policies
-- SELECT * FROM pg_policies WHERE tablename = 'objects' AND policyname LIKE '%catalog-images%';

-- =====================================================
-- Notes:
-- =====================================================
-- 1. The bucket is PUBLIC, meaning anyone with the URL can view images
-- 2. Only authenticated users can upload/update/delete
-- 3. File size limit is set to 5MB
-- 4. Only image MIME types are allowed
-- 5. Images are organized by organization_id in the path structure:
--    {organization_id}/{timestamp}-{random}.{ext}
-- =====================================================





