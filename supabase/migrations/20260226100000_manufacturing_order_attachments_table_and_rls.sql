-- Table: manufacturing_order_attachments
-- Attachments for Manufacturing Orders (file metadata; files in Storage).

CREATE TABLE IF NOT EXISTS public.manufacturing_order_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  manufacturing_order_id uuid NOT NULL REFERENCES public."ManufacturingOrders"(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id),
  file_name text NOT NULL,
  file_path text NOT NULL,
  file_size bigint,
  content_type text,
  uploaded_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mo_attachments_mo_id ON public.manufacturing_order_attachments(manufacturing_order_id);
CREATE INDEX IF NOT EXISTS idx_mo_attachments_org_id ON public.manufacturing_order_attachments(organization_id);

ALTER TABLE public.manufacturing_order_attachments ENABLE ROW LEVEL SECURITY;

-- RLS: users can read/insert/delete attachments for MOs in their organization (via AppUsers.auth_user_id)
CREATE POLICY "mo_attachments_select"
  ON public.manufacturing_order_attachments FOR SELECT
  USING (
    organization_id IN (
      SELECT o.id FROM public."Organizations" o
      INNER JOIN public."AppUsers" au ON au.organization_id = o.id
      WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
    )
  );

CREATE POLICY "mo_attachments_insert"
  ON public.manufacturing_order_attachments FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT o.id FROM public."Organizations" o
      INNER JOIN public."AppUsers" au ON au.organization_id = o.id
      WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
    )
  );

CREATE POLICY "mo_attachments_delete"
  ON public.manufacturing_order_attachments FOR DELETE
  USING (
    organization_id IN (
      SELECT o.id FROM public."Organizations" o
      INNER JOIN public."AppUsers" au ON au.organization_id = o.id
      WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
    )
  );

COMMENT ON TABLE public.manufacturing_order_attachments IS 'File attachments for Manufacturing Orders. Files stored in Storage bucket (path: {org_id}/mo/{mo_id}/{filename}).';
