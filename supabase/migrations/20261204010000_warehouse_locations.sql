-- Warehouse Locations (Bins) — minimal model for small/medium factory
-- Single table with structured fields: zone / rack / level / bin
-- + auto-derived location_code (e.g. "A-R3-L2-B1").
-- + CatalogItems.primary_location_id so each SKU can point to its main bin.
-- RLS mirrors Warehouses (inventory.warehouse.* permissions + portal_in_org bridge).

BEGIN;

-- 1) Table
CREATE TABLE IF NOT EXISTS public."WarehouseLocations" (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
  warehouse_id    uuid NOT NULL REFERENCES public."Warehouses"(id) ON DELETE CASCADE,
  zone            text NULL,
  rack            text NULL,
  level           text NULL,
  bin             text NULL,
  location_code   text NOT NULL,
  is_pickable     boolean NOT NULL DEFAULT true,
  is_active       boolean NOT NULL DEFAULT true,
  notes           text NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT warehouse_locations_code_uniq
    UNIQUE (organization_id, warehouse_id, location_code)
);

CREATE INDEX IF NOT EXISTS idx_warehouse_locations_org_wh
  ON public."WarehouseLocations"(organization_id, warehouse_id)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_warehouse_locations_code
  ON public."WarehouseLocations"(organization_id, warehouse_id, location_code);

COMMENT ON TABLE public."WarehouseLocations" IS
  'Storage bins inside a warehouse. Single table with structured zone/rack/level/bin '
  'and auto-derived location_code. Designed for small-to-medium factory (no expiry/lots).';

-- 2) Auto-derive location_code from parts when not provided
CREATE OR REPLACE FUNCTION public.warehouse_locations_derive_code()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_parts text[] := ARRAY[]::text[];
  v_zone text := NULLIF(BTRIM(COALESCE(NEW.zone, '')), '');
  v_rack text := NULLIF(BTRIM(COALESCE(NEW.rack, '')), '');
  v_level text := NULLIF(BTRIM(COALESCE(NEW.level, '')), '');
  v_bin text := NULLIF(BTRIM(COALESCE(NEW.bin, '')), '');
  v_provided text := NULLIF(BTRIM(COALESCE(NEW.location_code, '')), '');
BEGIN
  IF v_provided IS NOT NULL THEN
    NEW.location_code := v_provided;
  ELSE
    IF v_zone  IS NOT NULL THEN v_parts := array_append(v_parts, v_zone);  END IF;
    IF v_rack  IS NOT NULL THEN v_parts := array_append(v_parts, v_rack);  END IF;
    IF v_level IS NOT NULL THEN v_parts := array_append(v_parts, v_level); END IF;
    IF v_bin   IS NOT NULL THEN v_parts := array_append(v_parts, v_bin);   END IF;
    IF array_length(v_parts, 1) IS NULL THEN
      RAISE EXCEPTION 'WarehouseLocations: zone/rack/level/bin or location_code required';
    END IF;
    NEW.location_code := array_to_string(v_parts, '-');
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_warehouse_locations_derive ON public."WarehouseLocations";
CREATE TRIGGER trg_warehouse_locations_derive
BEFORE INSERT OR UPDATE ON public."WarehouseLocations"
FOR EACH ROW
EXECUTE FUNCTION public.warehouse_locations_derive_code();

-- 3) CatalogItems.primary_location_id
ALTER TABLE public."CatalogItems"
  ADD COLUMN IF NOT EXISTS primary_location_id uuid NULL
    REFERENCES public."WarehouseLocations"(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_catalog_items_primary_location
  ON public."CatalogItems"(primary_location_id)
  WHERE primary_location_id IS NOT NULL;

COMMENT ON COLUMN public."CatalogItems".primary_location_id IS
  'Default storage bin for this SKU (used by Receipts putaway suggestion and Picklists).';

-- 4) Soft-delete safety: prevent setting is_active=false if SKUs still point to it.
CREATE OR REPLACE FUNCTION public.warehouse_locations_protect_inactive()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_count integer;
BEGIN
  IF NEW.is_active = false AND OLD.is_active = true THEN
    SELECT COUNT(*) INTO v_count
    FROM public."CatalogItems" ci
    WHERE ci.primary_location_id = NEW.id;
    IF v_count > 0 THEN
      RAISE EXCEPTION 'Cannot deactivate location: % SKU(s) still use it as primary location.', v_count;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_warehouse_locations_protect_inactive ON public."WarehouseLocations";
CREATE TRIGGER trg_warehouse_locations_protect_inactive
BEFORE UPDATE OF is_active ON public."WarehouseLocations"
FOR EACH ROW
EXECUTE FUNCTION public.warehouse_locations_protect_inactive();

-- 5) RLS — same policy shape used for Warehouses
ALTER TABLE public."WarehouseLocations" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS warehouse_locations_select_org ON public."WarehouseLocations";
CREATE POLICY warehouse_locations_select_org ON public."WarehouseLocations"
  FOR SELECT
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_read_inventory_org(organization_id));

DROP POLICY IF EXISTS warehouse_locations_insert_org ON public."WarehouseLocations";
CREATE POLICY warehouse_locations_insert_org ON public."WarehouseLocations"
  FOR INSERT
  TO authenticated
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_create_inventory_org(organization_id));

DROP POLICY IF EXISTS warehouse_locations_update_org ON public."WarehouseLocations";
CREATE POLICY warehouse_locations_update_org ON public."WarehouseLocations"
  FOR UPDATE
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_update_inventory_org(organization_id))
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_update_inventory_org(organization_id));

COMMIT;
