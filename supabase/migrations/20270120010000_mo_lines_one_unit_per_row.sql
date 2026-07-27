-- MO Lines: 1 sold manufacture unit = 1 MOL row (qty=1) + 1 BOMInstance.
-- Catalog/supply_only lines stay 1 MOL with sol.quantity.
-- Replaces mol_mo_sol_unique and removes bil.qty × sol.quantity scaling.

-- ============================================================================
-- 1) Schema
-- ============================================================================
ALTER TABLE public."ManufacturingOrderLines"
  ADD COLUMN IF NOT EXISTS unit_index integer NOT NULL DEFAULT 1;

ALTER TABLE public."BOMInstances"
  ADD COLUMN IF NOT EXISTS manufacturing_order_line_id uuid
    REFERENCES public."ManufacturingOrderLines"(id) ON DELETE SET NULL;

ALTER TABLE public."WorkOrderTasks"
  ADD COLUMN IF NOT EXISTS manufacturing_order_line_id uuid
    REFERENCES public."ManufacturingOrderLines"(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_bomi_mol_id
  ON public."BOMInstances" (manufacturing_order_line_id)
  WHERE manufacturing_order_line_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_wot_mol_id
  ON public."WorkOrderTasks" (manufacturing_order_line_id)
  WHERE manufacturing_order_line_id IS NOT NULL;

DROP INDEX IF EXISTS public.mol_mo_sol_unique;

CREATE UNIQUE INDEX mol_mo_sol_unit_unique
  ON public."ManufacturingOrderLines" (manufacturing_order_id, sales_order_line_id, unit_index)
  WHERE deleted = false AND sales_order_line_id IS NOT NULL;

-- Link existing BI → sole MOL for that (mo, sol)
UPDATE public."BOMInstances" bi
SET manufacturing_order_line_id = mol.id,
    updated_at = now()
FROM public."ManufacturingOrderLines" mol
WHERE bi.manufacturing_order_line_id IS NULL
  AND bi.deleted = false
  AND mol.deleted = false
  AND mol.manufacturing_order_id = bi.manufacturing_order_id
  AND mol.sales_order_line_id = bi.sales_order_line_id
  AND NOT EXISTS (
    SELECT 1 FROM public."ManufacturingOrderLines" m2
    WHERE m2.manufacturing_order_id = mol.manufacturing_order_id
      AND m2.sales_order_line_id = mol.sales_order_line_id
      AND m2.deleted = false
      AND m2.id <> mol.id
  );

-- Link existing WO tasks → sole MOL for that (mo, sol)
UPDATE public."WorkOrderTasks" wot
SET manufacturing_order_line_id = mol.id
FROM public."ManufacturingOrderLines" mol
WHERE wot.manufacturing_order_line_id IS NULL
  AND COALESCE(wot.deleted, false) = false
  AND wot.sales_order_line_id IS NOT NULL
  AND mol.deleted = false
  AND mol.manufacturing_order_id = wot.manufacturing_order_id
  AND mol.sales_order_line_id = wot.sales_order_line_id
  AND NOT EXISTS (
    SELECT 1 FROM public."ManufacturingOrderLines" m2
    WHERE m2.manufacturing_order_id = mol.manufacturing_order_id
      AND m2.sales_order_line_id = mol.sales_order_line_id
      AND m2.deleted = false
      AND m2.id <> mol.id
  );
