
-- ManufacturingOrderLines
CREATE TABLE IF NOT EXISTS public."ManufacturingOrderLines" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  manufacturing_order_id uuid NOT NULL REFERENCES public."ManufacturingOrders"(id) ON DELETE CASCADE,
  sales_order_line_id uuid REFERENCES public."SaleOrderLines"(id) ON DELETE SET NULL,
  organization_id uuid,
  configured_product_id uuid REFERENCES public."ConfiguredProducts"(id) ON DELETE SET NULL,
  quantity numeric(12,4) NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_production','completed','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_mol_mo_id ON public."ManufacturingOrderLines"(manufacturing_order_id);
CREATE INDEX IF NOT EXISTS idx_mol_sol_id ON public."ManufacturingOrderLines"(sales_order_line_id);

-- BOMInstances
CREATE TABLE IF NOT EXISTS public."BOMInstances" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid,
  manufacturing_order_id uuid NOT NULL REFERENCES public."ManufacturingOrders"(id) ON DELETE CASCADE,
  sales_order_line_id uuid REFERENCES public."SaleOrderLines"(id) ON DELETE SET NULL,
  quote_line_id uuid,
  bom_template_id uuid REFERENCES public."BOMTemplates"(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_bomi_mo_id ON public."BOMInstances"(manufacturing_order_id);

-- BOMInstanceLines
CREATE TABLE IF NOT EXISTS public."BOMInstanceLines" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bom_instance_id uuid NOT NULL REFERENCES public."BOMInstances"(id) ON DELETE CASCADE,
  organization_id uuid,
  catalog_item_id uuid,
  resolved_part_id uuid,
  part_role text,
  qty numeric(12,4) NOT NULL DEFAULT 1,
  uom text NOT NULL DEFAULT 'ea',
  cut_length_mm numeric,
  cut_width_mm numeric,
  cut_height_mm numeric,
  unit_cost_exw numeric(12,4) DEFAULT 0,
  total_cost_exw numeric(12,4) DEFAULT 0,
  unit_msrp numeric(12,4) DEFAULT 0,
  total_msrp numeric(12,4) DEFAULT 0,
  calc_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_bomil_bi_id ON public."BOMInstanceLines"(bom_instance_id);

-- CutJobs
CREATE TABLE IF NOT EXISTS public."CutJobs" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid,
  manufacturing_order_id uuid NOT NULL REFERENCES public."ManufacturingOrders"(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','planned','in_progress','completed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_cj_mo_id ON public."CutJobs"(manufacturing_order_id);

-- CutJobLines
CREATE TABLE IF NOT EXISTS public."CutJobLines" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cut_job_id uuid NOT NULL REFERENCES public."CutJobs"(id) ON DELETE CASCADE,
  bom_instance_line_id uuid REFERENCES public."BOMInstanceLines"(id) ON DELETE SET NULL,
  resolved_sku text,
  part_role text,
  qty numeric(12,4) NOT NULL DEFAULT 1,
  cut_length_mm numeric,
  cut_width_mm numeric,
  cut_height_mm numeric,
  uom text NOT NULL DEFAULT 'ea',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_cjl_cj_id ON public."CutJobLines"(cut_job_id);
;
