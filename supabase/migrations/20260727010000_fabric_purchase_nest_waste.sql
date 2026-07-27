-- Purchase waste % (nest-based buying); pricing waste_pct unchanged
ALTER TABLE "FabricRules"
  ADD COLUMN IF NOT EXISTS purchase_waste_pct numeric NOT NULL DEFAULT 0.20
    CHECK (purchase_waste_pct >= 0 AND purchase_waste_pct <= 1);

COMMENT ON COLUMN "FabricRules".purchase_waste_pct IS
  'Waste applied to nest roll consumption for Material Demand / PO. Pricing uses waste_pct on linear FabricRule qty.';
COMMENT ON COLUMN "FabricRules".waste_pct IS
  'Waste applied to linear FabricRule qty for quoting/costing only.';

-- Persisted nest consumption + buy qty per MO fabric SKU
CREATE TABLE IF NOT EXISTS "ManufacturingOrderFabricPurchase" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES "Organizations"(id),
  manufacturing_order_id uuid NOT NULL REFERENCES "ManufacturingOrders"(id) ON DELETE CASCADE,
  catalog_item_id uuid NOT NULL REFERENCES "CatalogItems"(id),
  nest_used_m numeric NOT NULL DEFAULT 0,
  purchase_waste_pct numeric NOT NULL DEFAULT 0.20,
  purchase_qty numeric NOT NULL DEFAULT 0,
  uom text NOT NULL DEFAULT 'm',
  piece_count integer NOT NULL DEFAULT 0,
  roll_count integer NOT NULL DEFAULT 0,
  efficiency_pct numeric NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (manufacturing_order_id, catalog_item_id)
);

CREATE INDEX IF NOT EXISTS idx_mofp_org_mo
  ON "ManufacturingOrderFabricPurchase" (organization_id, manufacturing_order_id);

ALTER TABLE "ManufacturingOrderFabricPurchase" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mofp_select ON "ManufacturingOrderFabricPurchase";
CREATE POLICY mofp_select ON "ManufacturingOrderFabricPurchase"
  FOR SELECT USING (is_org_user_member(organization_id));

DROP POLICY IF EXISTS mofp_insert ON "ManufacturingOrderFabricPurchase";
CREATE POLICY mofp_insert ON "ManufacturingOrderFabricPurchase"
  FOR INSERT WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS mofp_update ON "ManufacturingOrderFabricPurchase";
CREATE POLICY mofp_update ON "ManufacturingOrderFabricPurchase"
  FOR UPDATE USING (is_org_user_member(organization_id))
  WITH CHECK (is_org_user_member(organization_id));

DROP POLICY IF EXISTS mofp_delete ON "ManufacturingOrderFabricPurchase";
CREATE POLICY mofp_delete ON "ManufacturingOrderFabricPurchase"
  FOR DELETE USING (is_org_owner_or_admin(organization_id));

-- Material demand: fabric SKUs with nest purchase use purchase_qty; else linear bil.qty
CREATE OR REPLACE VIEW manufacturing_order_material_demand AS
WITH base AS (
  SELECT
    bi.manufacturing_order_id,
    bi.organization_id,
    bil.resolved_part_id AS catalog_item_id,
    ci.sku,
    ci.name AS item_name,
    sum(bil.qty * COALESCE(sol.quantity, 1::numeric)) AS linear_qty,
    bil.uom,
    mo.manufacturing_order_no,
    mo.status AS mo_status,
    bool_or(lower(COALESCE(bil.part_role, '')) = 'fabric') AS has_fabric_role
  FROM "BOMInstanceLines" bil
  JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
  JOIN "ManufacturingOrders" mo ON mo.id = bi.manufacturing_order_id
  JOIN "ManufacturingOrderLines" mol
    ON mol.manufacturing_order_id = bi.manufacturing_order_id
   AND mol.sales_order_line_id = bi.sales_order_line_id
   AND mol.deleted = false
  JOIN "SaleOrderLines" sol ON sol.id = bi.sales_order_line_id
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
  WHERE bi.deleted = false
    AND bil.deleted = false
    AND bil.excluded = false
    AND mo.deleted = false
    AND mol.status = ANY (ARRAY[
      'reviewed'::text, 'confirmed'::text, 'procurement'::text,
      'material_available'::text, 'materials_ready'::text, 'in_production'::text
    ])
  GROUP BY
    bi.manufacturing_order_id, bi.organization_id, bil.resolved_part_id,
    ci.sku, ci.name, bil.uom, mo.manufacturing_order_no, mo.status
)
SELECT
  b.manufacturing_order_id,
  b.organization_id,
  b.catalog_item_id,
  b.sku,
  b.item_name,
  CASE
    WHEN b.has_fabric_role AND fp.purchase_qty IS NOT NULL AND fp.purchase_qty > 0
      THEN fp.purchase_qty
    ELSE b.linear_qty
  END AS required_qty,
  b.uom,
  b.manufacturing_order_no,
  b.mo_status
FROM base b
LEFT JOIN "ManufacturingOrderFabricPurchase" fp
  ON fp.manufacturing_order_id = b.manufacturing_order_id
 AND fp.catalog_item_id = b.catalog_item_id;
