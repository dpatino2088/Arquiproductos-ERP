-- Table: quote_attachments
CREATE TABLE IF NOT EXISTS public.quote_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_id uuid NOT NULL REFERENCES public."Quotes"(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id),
  file_name text NOT NULL,
  file_path text NOT NULL,
  file_size bigint,
  content_type text,
  uploaded_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_quote_attachments_quote_id ON public.quote_attachments(quote_id);
CREATE INDEX IF NOT EXISTS idx_quote_attachments_org_id ON public.quote_attachments(organization_id);

ALTER TABLE public.quote_attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "quote_attachments_select"
  ON public.quote_attachments FOR SELECT
  USING (
    organization_id IN (
      SELECT o.id FROM public."Organizations" o
      INNER JOIN public."AppUsers" au ON au.organization_id = o.id
      WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
    )
  );

CREATE POLICY "quote_attachments_insert"
  ON public.quote_attachments FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT o.id FROM public."Organizations" o
      INNER JOIN public."AppUsers" au ON au.organization_id = o.id
      WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
    )
  );

CREATE POLICY "quote_attachments_delete"
  ON public.quote_attachments FOR DELETE
  USING (
    organization_id IN (
      SELECT o.id FROM public."Organizations" o
      INNER JOIN public."AppUsers" au ON au.organization_id = o.id
      WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
    )
  );

-- Storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types, created_at, updated_at)
VALUES (
  'quote-attachments',
  'quote-attachments',
  true,
  10485760,
  ARRAY[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ],
  now(),
  now()
)
ON CONFLICT (name) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types,
  updated_at = now();

DROP POLICY IF EXISTS "quote_attachments_storage_select" ON storage.objects;
CREATE POLICY "quote_attachments_storage_select"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'quote-attachments');

DROP POLICY IF EXISTS "quote_attachments_storage_insert" ON storage.objects;
CREATE POLICY "quote_attachments_storage_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'quote-attachments');

DROP POLICY IF EXISTS "quote_attachments_storage_update" ON storage.objects;
CREATE POLICY "quote_attachments_storage_update"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'quote-attachments')
  WITH CHECK (bucket_id = 'quote-attachments');

DROP POLICY IF EXISTS "quote_attachments_storage_delete" ON storage.objects;
CREATE POLICY "quote_attachments_storage_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'quote-attachments');
