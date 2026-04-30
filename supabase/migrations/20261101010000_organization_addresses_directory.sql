-- Address directory per organization (for PO ship-to and other reusable destinations)

CREATE TABLE IF NOT EXISTS public."OrganizationAddresses" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
  name text NOT NULL,
  street_address_line_1 text NOT NULL,
  street_address_line_2 text NULL,
  city text NULL,
  state text NULL,
  zip_code text NULL,
  country text NULL,
  notes text NULL,
  is_active boolean NOT NULL DEFAULT true,
  is_default_po_ship_to boolean NOT NULL DEFAULT false,
  deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_org_addresses_org_deleted
  ON public."OrganizationAddresses" (organization_id, deleted);

CREATE INDEX IF NOT EXISTS idx_org_addresses_org_active
  ON public."OrganizationAddresses" (organization_id, is_active)
  WHERE deleted = false;

CREATE UNIQUE INDEX IF NOT EXISTS ux_org_addresses_default_po
  ON public."OrganizationAddresses" (organization_id)
  WHERE is_default_po_ship_to = true
    AND deleted = false
    AND is_active = true;

CREATE OR REPLACE FUNCTION public.organization_addresses_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_organization_addresses_set_updated_at ON public."OrganizationAddresses";
CREATE TRIGGER trg_organization_addresses_set_updated_at
BEFORE UPDATE ON public."OrganizationAddresses"
FOR EACH ROW
EXECUTE FUNCTION public.organization_addresses_set_updated_at();

CREATE OR REPLACE FUNCTION public.organization_addresses_ensure_single_default()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.is_default_po_ship_to = true AND NEW.deleted = false AND NEW.is_active = true THEN
    UPDATE public."OrganizationAddresses"
    SET is_default_po_ship_to = false
    WHERE organization_id = NEW.organization_id
      AND id <> NEW.id
      AND deleted = false
      AND is_active = true;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_organization_addresses_single_default ON public."OrganizationAddresses";
CREATE TRIGGER trg_organization_addresses_single_default
BEFORE INSERT OR UPDATE OF is_default_po_ship_to, deleted, is_active ON public."OrganizationAddresses"
FOR EACH ROW
EXECUTE FUNCTION public.organization_addresses_ensure_single_default();

ALTER TABLE public."OrganizationAddresses" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS organization_addresses_select ON public."OrganizationAddresses";
CREATE POLICY organization_addresses_select
ON public."OrganizationAddresses"
FOR SELECT
USING (is_org_user_member(organization_id));

DROP POLICY IF EXISTS organization_addresses_insert ON public."OrganizationAddresses";
CREATE POLICY organization_addresses_insert
ON public."OrganizationAddresses"
FOR INSERT
WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS organization_addresses_update ON public."OrganizationAddresses";
CREATE POLICY organization_addresses_update
ON public."OrganizationAddresses"
FOR UPDATE
USING (is_org_user_member(organization_id))
WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS organization_addresses_delete ON public."OrganizationAddresses";
CREATE POLICY organization_addresses_delete
ON public."OrganizationAddresses"
FOR DELETE
USING (is_org_user_member(organization_id));

COMMENT ON TABLE public."OrganizationAddresses" IS
  'Reusable organization-level address directory (e.g., Panama, Miami) for purchasing and logistics workflows.';

NOTIFY pgrst, 'reload schema';
