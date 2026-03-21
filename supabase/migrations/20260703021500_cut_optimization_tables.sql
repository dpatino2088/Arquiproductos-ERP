-- Cut optimization tables: CutPlans, CutPlanLines, FabricConstructionSpecs
SET search_path = public;

ALTER TABLE "CatalogItems" ADD COLUMN IF NOT EXISTS stock_length_mm numeric(12,2);

CREATE TABLE IF NOT EXISTS "CutPlans" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES "Organizations"(id),
  plan_type text NOT NULL CHECK (plan_type IN ('1d_profile', '2d_fabric')),
  material_catalog_item_id uuid REFERENCES "CatalogItems"(id),
  material_sku text,
  material_name text,
  stock_length_mm numeric(12,2),
  stock_width_mm numeric(12,2),
  kerf_mm numeric(6,2) DEFAULT 3.0,
  total_stock_units int NOT NULL DEFAULT 1,
  efficiency_pct numeric(5,2),
  total_waste_mm numeric(12,2),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'confirmed', 'in_progress', 'completed')),
  notes text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false
);

ALTER TABLE "CutPlans" ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS cut_plans_org ON "CutPlans" FOR ALL USING (is_org_member(organization_id));

CREATE TABLE IF NOT EXISTS "CutPlanLines" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cut_plan_id uuid NOT NULL REFERENCES "CutPlans"(id) ON DELETE CASCADE,
  manufacturing_order_id uuid REFERENCES "ManufacturingOrders"(id),
  bom_instance_line_id uuid REFERENCES "BOMInstanceLines"(id),
  work_order_task_line_id uuid,
  stock_index int NOT NULL DEFAULT 0,
  position_mm numeric(12,2) DEFAULT 0,
  position_x_mm numeric(12,2),
  position_y_mm numeric(12,2),
  cut_length_mm numeric(12,2) NOT NULL,
  cut_width_mm numeric(12,2),
  piece_label text,
  mo_number text,
  sequence int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE "CutPlanLines" ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS cut_plan_lines_via_plan ON "CutPlanLines" FOR ALL USING (
  cut_plan_id IN (SELECT cp.id FROM "CutPlans" cp WHERE is_org_member(cp.organization_id))
);

CREATE TABLE IF NOT EXISTS "FabricConstructionSpecs" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES "Organizations"(id),
  product_type text NOT NULL,
  display_name text NOT NULL,
  top_allowance_mm numeric(8,2) DEFAULT 0,
  bottom_allowance_mm numeric(8,2) DEFAULT 0,
  side_allowance_mm numeric(8,2) DEFAULT 0,
  hem_bar_pocket_mm numeric(8,2) DEFAULT 0,
  safety_margin_mm numeric(8,2) DEFAULT 0,
  additional_materials jsonb DEFAULT '[]'::jsonb,
  notes text,
  sort_order int DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  UNIQUE(organization_id, product_type)
);

ALTER TABLE "FabricConstructionSpecs" ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS fabric_specs_org ON "FabricConstructionSpecs" FOR ALL USING (is_org_member(organization_id));
