-- InventoryMovements + InventoryMovementLines
-- Source of truth for all stock-affecting movements (issue to production, receipt, transfer, adjustment, return).
-- InventoryBalances is updated on confirm.

SET search_path = public;

-- Enums
DO $$ BEGIN
  CREATE TYPE public.inventory_movement_type AS ENUM ('receipt', 'issue_to_production', 'transfer', 'adjustment', 'return');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.inventory_movement_status AS ENUM ('draft', 'confirmed');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- InventoryMovements header
CREATE TABLE IF NOT EXISTS public."InventoryMovements" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id),
  warehouse_id uuid NOT NULL REFERENCES public."Warehouses"(id),
  movement_type public.inventory_movement_type NOT NULL,
  reference_type text,
  reference_id uuid,
  movement_no text,
  movement_date date NOT NULL DEFAULT CURRENT_DATE,
  status public.inventory_movement_status NOT NULL DEFAULT 'draft',
  notes text,
  confirmed_at timestamptz,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted boolean DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_inv_movements_org ON public."InventoryMovements"(organization_id);
CREATE INDEX IF NOT EXISTS idx_inv_movements_warehouse ON public."InventoryMovements"(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_inv_movements_ref ON public."InventoryMovements"(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_inv_movements_type ON public."InventoryMovements"(movement_type);
CREATE INDEX IF NOT EXISTS idx_inv_movements_status ON public."InventoryMovements"(status);

COMMENT ON TABLE public."InventoryMovements" IS 'Header for inventory movements. Each movement has lines in InventoryMovementLines. InventoryBalances updated on confirm.';

-- InventoryMovementLines
CREATE TABLE IF NOT EXISTS public."InventoryMovementLines" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_movement_id uuid NOT NULL REFERENCES public."InventoryMovements"(id) ON DELETE CASCADE,
  catalog_item_id uuid NOT NULL REFERENCES public."CatalogItems"(id),
  quantity numeric(12,4) NOT NULL,
  unit text DEFAULT 'ea',
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_movement_lines_movement ON public."InventoryMovementLines"(inventory_movement_id);
CREATE INDEX IF NOT EXISTS idx_inv_movement_lines_item ON public."InventoryMovementLines"(catalog_item_id);

COMMENT ON TABLE public."InventoryMovementLines" IS 'Lines per inventory movement. quantity is signed: positive = stock in, negative = stock out.';

-- RLS
ALTER TABLE public."InventoryMovements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."InventoryMovementLines" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inv_movements_select" ON public."InventoryMovements" FOR SELECT
  USING (organization_id IN (
    SELECT o.id FROM public."Organizations" o
    INNER JOIN public."AppUsers" au ON au.organization_id = o.id
    WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
  ));

CREATE POLICY "inv_movements_insert" ON public."InventoryMovements" FOR INSERT
  WITH CHECK (organization_id IN (
    SELECT o.id FROM public."Organizations" o
    INNER JOIN public."AppUsers" au ON au.organization_id = o.id
    WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
  ));

CREATE POLICY "inv_movements_update" ON public."InventoryMovements" FOR UPDATE
  USING (organization_id IN (
    SELECT o.id FROM public."Organizations" o
    INNER JOIN public."AppUsers" au ON au.organization_id = o.id
    WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
  ));

CREATE POLICY "inv_movements_delete" ON public."InventoryMovements" FOR DELETE
  USING (organization_id IN (
    SELECT o.id FROM public."Organizations" o
    INNER JOIN public."AppUsers" au ON au.organization_id = o.id
    WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
  ));

-- Lines RLS: via parent movement
CREATE POLICY "inv_movement_lines_select" ON public."InventoryMovementLines" FOR SELECT
  USING (inventory_movement_id IN (
    SELECT id FROM public."InventoryMovements" WHERE organization_id IN (
      SELECT o.id FROM public."Organizations" o
      INNER JOIN public."AppUsers" au ON au.organization_id = o.id
      WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
    )
  ));

CREATE POLICY "inv_movement_lines_insert" ON public."InventoryMovementLines" FOR INSERT
  WITH CHECK (inventory_movement_id IN (
    SELECT id FROM public."InventoryMovements" WHERE organization_id IN (
      SELECT o.id FROM public."Organizations" o
      INNER JOIN public."AppUsers" au ON au.organization_id = o.id
      WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
    )
  ));

CREATE POLICY "inv_movement_lines_update" ON public."InventoryMovementLines" FOR UPDATE
  USING (inventory_movement_id IN (
    SELECT id FROM public."InventoryMovements" WHERE organization_id IN (
      SELECT o.id FROM public."Organizations" o
      INNER JOIN public."AppUsers" au ON au.organization_id = o.id
      WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
    )
  ));

CREATE POLICY "inv_movement_lines_delete" ON public."InventoryMovementLines" FOR DELETE
  USING (inventory_movement_id IN (
    SELECT id FROM public."InventoryMovements" WHERE organization_id IN (
      SELECT o.id FROM public."Organizations" o
      INNER JOIN public."AppUsers" au ON au.organization_id = o.id
      WHERE au.auth_user_id = auth.uid() AND (au.deleted IS NULL OR au.deleted = false)
    )
  ));;
