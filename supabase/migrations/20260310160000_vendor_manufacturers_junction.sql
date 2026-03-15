-- VendorManufacturers junction table: one vendor can supply multiple manufacturers
CREATE TABLE IF NOT EXISTS public."VendorManufacturers" (
  vendor_id       uuid NOT NULL REFERENCES public."DirectoryVendors"(id) ON DELETE CASCADE,
  manufacturer_id uuid NOT NULL REFERENCES public."Manufacturers"(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL,
  is_primary      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (vendor_id, manufacturer_id)
);

CREATE INDEX IF NOT EXISTS idx_vendor_manufacturers_mfr
  ON public."VendorManufacturers" (manufacturer_id);

CREATE INDEX IF NOT EXISTS idx_vendor_manufacturers_org
  ON public."VendorManufacturers" (organization_id);

ALTER TABLE public."VendorManufacturers" ENABLE ROW LEVEL SECURITY;

CREATE POLICY vm_select ON public."VendorManufacturers" FOR SELECT
  USING (is_org_user_member(organization_id));
CREATE POLICY vm_insert ON public."VendorManufacturers" FOR INSERT
  WITH CHECK (is_org_user_member(organization_id));
CREATE POLICY vm_update ON public."VendorManufacturers" FOR UPDATE
  USING (is_org_user_member(organization_id));
CREATE POLICY vm_delete ON public."VendorManufacturers" FOR DELETE
  USING (is_org_user_member(organization_id));

COMMENT ON TABLE public."VendorManufacturers" IS
  'Junction table: one vendor can supply products from multiple manufacturers.';

-- Migrate existing data from DirectoryVendors.manufacturer_id
INSERT INTO public."VendorManufacturers" (vendor_id, manufacturer_id, organization_id, is_primary)
SELECT dv.id, dv.manufacturer_id, dv.organization_id, true
FROM public."DirectoryVendors" dv
WHERE dv.manufacturer_id IS NOT NULL
  AND dv.deleted = false
ON CONFLICT DO NOTHING;

NOTIFY pgrst, 'reload schema';
