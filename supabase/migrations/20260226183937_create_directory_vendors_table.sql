
CREATE TABLE IF NOT EXISTS public."DirectoryVendors" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
  name text NOT NULL,
  vendor_name text,
  ein text,
  website text,
  email text,
  work_phone text,
  fax text,
  street_address_line_1 text,
  street_address_line_2 text,
  city text,
  state text,
  zip_code text,
  country text,
  billing_street_address_line_1 text,
  billing_street_address_line_2 text,
  billing_city text,
  billing_state text,
  billing_zip_code text,
  billing_country text,
  notes text,
  primary_contact_id uuid,
  deleted boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  updated_by uuid
);

CREATE INDEX IF NOT EXISTS idx_directory_vendors_org ON public."DirectoryVendors"(organization_id);
CREATE INDEX IF NOT EXISTS idx_directory_vendors_name ON public."DirectoryVendors"(name);
CREATE INDEX IF NOT EXISTS idx_directory_vendors_not_deleted ON public."DirectoryVendors"(deleted) WHERE deleted = false;

ALTER TABLE public."DirectoryVendors" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "vendors_select" ON public."DirectoryVendors"
  FOR SELECT USING (is_org_user_member(organization_id));

CREATE POLICY "vendors_insert" ON public."DirectoryVendors"
  FOR INSERT WITH CHECK (is_org_user_member(organization_id));

CREATE POLICY "vendors_update" ON public."DirectoryVendors"
  FOR UPDATE USING (is_org_user_member(organization_id));

CREATE POLICY "vendors_delete" ON public."DirectoryVendors"
  FOR DELETE USING (is_org_user_member(organization_id));
;
