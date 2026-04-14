-- Bucket for Manufacturing Order attachments (PDF, images, etc.).
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
  'mo-attachments',
  'mo-attachments',
  true,
  10485760,
  ARRAY[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ],
  now(),
  now()
)
ON CONFLICT (name) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types,
  updated_at = now();

DROP POLICY IF EXISTS "mo_attachments_storage_select" ON storage.objects;
CREATE POLICY "mo_attachments_storage_select"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id IN (SELECT id FROM storage.buckets WHERE name = 'mo-attachments'));

DROP POLICY IF EXISTS "mo_attachments_storage_insert" ON storage.objects;
CREATE POLICY "mo_attachments_storage_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN (SELECT id FROM storage.buckets WHERE name = 'mo-attachments'));

DROP POLICY IF EXISTS "mo_attachments_storage_delete" ON storage.objects;
CREATE POLICY "mo_attachments_storage_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id IN (SELECT id FROM storage.buckets WHERE name = 'mo-attachments'));;
