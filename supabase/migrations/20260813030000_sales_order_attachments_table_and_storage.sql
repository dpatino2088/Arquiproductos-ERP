CREATE TABLE IF NOT EXISTS public.sales_order_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sales_order_id uuid NOT NULL REFERENCES public."SalesOrders"(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id),
  file_name text NOT NULL,
  file_path text NOT NULL,
  file_size bigint,
  content_type text,
  uploaded_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_so_attachments_so_id ON public.sales_order_attachments(sales_order_id);
CREATE INDEX IF NOT EXISTS idx_so_attachments_org_id ON public.sales_order_attachments(organization_id);

ALTER TABLE public.sales_order_attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "so_attachments_select" ON public.sales_order_attachments FOR SELECT
  USING (organization_id IN (
    SELECT o.id FROM public."Organizations" o
    INNER JOIN public."AppUsers" au ON au.organization_id = o.id
    WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
  ));

CREATE POLICY "so_attachments_insert" ON public.sales_order_attachments FOR INSERT
  WITH CHECK (organization_id IN (
    SELECT o.id FROM public."Organizations" o
    INNER JOIN public."AppUsers" au ON au.organization_id = o.id
    WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
  ));

CREATE POLICY "so_attachments_delete" ON public.sales_order_attachments FOR DELETE
  USING (organization_id IN (
    SELECT o.id FROM public."Organizations" o
    INNER JOIN public."AppUsers" au ON au.organization_id = o.id
    WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
  ));

-- Storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types, created_at, updated_at)
VALUES (
  'so-attachments', 'so-attachments', true, 10485760,
  ARRAY['application/pdf','image/jpeg','image/png','image/gif','image/webp',
        'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
  now(), now()
)
ON CONFLICT (name) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types,
  updated_at = now();

DROP POLICY IF EXISTS "so_attachments_storage_select" ON storage.objects;
CREATE POLICY "so_attachments_storage_select" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'so-attachments');

DROP POLICY IF EXISTS "so_attachments_storage_insert" ON storage.objects;
CREATE POLICY "so_attachments_storage_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'so-attachments');

DROP POLICY IF EXISTS "so_attachments_storage_update" ON storage.objects;
CREATE POLICY "so_attachments_storage_update" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'so-attachments') WITH CHECK (bucket_id = 'so-attachments');

DROP POLICY IF EXISTS "so_attachments_storage_delete" ON storage.objects;
CREATE POLICY "so_attachments_storage_delete" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'so-attachments');
