-- =====================================================
-- Adaptio Inventory Availability — Fase 1: Datos base
-- =====================================================
-- Reglas: Availability es informativo. Lead time cliente = Manufacturing.
-- QuoteLine NO guarda stock, ETA ni availability.
--
-- 1. Warehouses (por organización)
-- 2. Purchase Orders: warehouse_id, expected_date, status (OPEN/PARTIAL/CLOSED)
-- 3. Purchase order lines: ordered_qty, received_qty
-- 4. InventoryItemProfile (material + warehouse): import lead time, risk, special order
-- =====================================================

SET search_path = public;

-- Enum for PO status
DO $$ BEGIN
  CREATE TYPE public.purchase_order_status AS ENUM ('OPEN', 'PARTIAL', 'CLOSED');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Warehouses: one per org (or per dealer later); default warehouse for PO
CREATE TABLE IF NOT EXISTS "public"."Warehouses" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "organization_id" uuid NOT NULL,
  "name" text NOT NULL,
  "code" text,
  "is_default" boolean DEFAULT false NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "warehouses_organization_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_warehouses_organization_id ON "public"."Warehouses" ("organization_id");
COMMENT ON TABLE "public"."Warehouses" IS 'Warehouses per organization. PO and inventory views are scoped by warehouse.';

-- Purchase Orders: warehouse_id obligatorio, ETA, status
CREATE TABLE IF NOT EXISTS "public"."PurchaseOrders" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "organization_id" uuid NOT NULL,
  "warehouse_id" uuid NOT NULL,
  "po_number" text,
  "expected_date" date,
  "status" public.purchase_order_status DEFAULT 'OPEN' NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "purchase_orders_organization_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE,
  CONSTRAINT "purchase_orders_warehouse_fk" FOREIGN KEY ("warehouse_id") REFERENCES "public"."Warehouses"("id") ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_organization_id ON "public"."PurchaseOrders" ("organization_id");
CREATE INDEX IF NOT EXISTS idx_purchase_orders_warehouse_id ON "public"."PurchaseOrders" ("warehouse_id");
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON "public"."PurchaseOrders" ("status");
CREATE INDEX IF NOT EXISTS idx_purchase_orders_expected_date ON "public"."PurchaseOrders" ("expected_date");
COMMENT ON TABLE "public"."PurchaseOrders" IS 'Purchase orders. warehouse_id required. expected_date = ETA. status is supportive; inventory_on_order view uses (ordered_qty - received_qty) > 0 as source of truth.';
COMMENT ON COLUMN "public"."PurchaseOrders"."expected_date" IS 'ETA: expected delivery date for transit calculation. Null allowed; MIN(expected_date) in views only considers non-null.';
COMMENT ON COLUMN "public"."PurchaseOrders"."status" IS 'OPEN = not received; PARTIAL = some received; CLOSED = fully received. El cálculo (ordered_qty > received_qty) manda; status no sustituye la lógica.';

-- Purchase order lines: catalog_item, ordered_qty, received_qty
CREATE TABLE IF NOT EXISTS "public"."PurchaseOrderLines" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "purchase_order_id" uuid NOT NULL,
  "catalog_item_id" uuid NOT NULL,
  "ordered_qty" numeric(12,4) NOT NULL DEFAULT 0,
  "received_qty" numeric(12,4) NOT NULL DEFAULT 0,
  "unit" text DEFAULT 'ea',
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "po_lines_po_fk" FOREIGN KEY ("purchase_order_id") REFERENCES "public"."PurchaseOrders"("id") ON DELETE CASCADE,
  CONSTRAINT "po_lines_catalog_item_fk" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE RESTRICT,
  CONSTRAINT "po_lines_ordered_qty_non_neg" CHECK (ordered_qty >= 0),
  CONSTRAINT "po_lines_received_qty_non_neg" CHECK (received_qty >= 0),
  CONSTRAINT "po_lines_received_lte_ordered" CHECK (received_qty <= ordered_qty)
);

CREATE INDEX IF NOT EXISTS idx_po_lines_po_id ON "public"."PurchaseOrderLines" ("purchase_order_id");
CREATE INDEX IF NOT EXISTS idx_po_lines_catalog_item_id ON "public"."PurchaseOrderLines" ("catalog_item_id");
COMMENT ON TABLE "public"."PurchaseOrderLines" IS 'PO lines. received_qty updated by receipts. inventory_on_order uses (ordered_qty - received_qty) for OPEN/PARTIAL POs.';

-- Inventory item profiles: material + warehouse — fallback import, risk, special order
CREATE TABLE IF NOT EXISTS "public"."InventoryItemProfiles" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "catalog_item_id" uuid NOT NULL,
  "warehouse_id" uuid NOT NULL,
  "import_lead_time_min_days" integer,
  "import_lead_time_max_days" integer,
  "risk_level" text,
  "is_special_order" boolean DEFAULT false NOT NULL,
  "preferred_supplier_id" uuid,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("catalog_item_id", "warehouse_id"),
  CONSTRAINT "inv_profiles_catalog_item_fk" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE,
  CONSTRAINT "inv_profiles_warehouse_fk" FOREIGN KEY ("warehouse_id") REFERENCES "public"."Warehouses"("id") ON DELETE CASCADE,
  CONSTRAINT "inv_profiles_risk_level_chk" CHECK (risk_level IS NULL OR risk_level IN ('low', 'medium', 'high', 'critical'))
);

CREATE INDEX IF NOT EXISTS idx_inv_profiles_catalog_item ON "public"."InventoryItemProfiles" ("catalog_item_id");
CREATE INDEX IF NOT EXISTS idx_inv_profiles_warehouse ON "public"."InventoryItemProfiles" ("warehouse_id");
COMMENT ON TABLE "public"."InventoryItemProfiles" IS 'Per material + warehouse: import lead time, risk, special order. Used by inventory_availability view (informative only).';
COMMENT ON COLUMN "public"."InventoryItemProfiles"."risk_level" IS 'low | medium | high | critical. Informative for availability badge.';

-- Inventory balance (stock real): one row per org/warehouse/catalog_item. Source for inventory_on_hand view.
-- Updated by receipts, adjustments, etc. (to be wired by future migrations).
CREATE TABLE IF NOT EXISTS "public"."InventoryBalances" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "organization_id" uuid NOT NULL,
  "warehouse_id" uuid NOT NULL,
  "catalog_item_id" uuid NOT NULL,
  "quantity" numeric(12,4) NOT NULL DEFAULT 0,
  "updated_at" timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("organization_id", "warehouse_id", "catalog_item_id"),
  CONSTRAINT "inv_balances_org_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE,
  CONSTRAINT "inv_balances_warehouse_fk" FOREIGN KEY ("warehouse_id") REFERENCES "public"."Warehouses"("id") ON DELETE CASCADE,
  CONSTRAINT "inv_balances_catalog_item_fk" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE,
  CONSTRAINT "inv_balances_quantity_non_neg" CHECK (quantity >= 0)
);

CREATE INDEX IF NOT EXISTS idx_inv_balances_org_wh ON "public"."InventoryBalances" ("organization_id", "warehouse_id");
CREATE INDEX IF NOT EXISTS idx_inv_balances_catalog_item ON "public"."InventoryBalances" ("catalog_item_id");
COMMENT ON TABLE "public"."InventoryBalances" IS 'Current stock per org/warehouse/catalog_item. Source of truth for inventory_on_hand view.';

-- RLS: organization-scoped; use is_org_user_member(organization_id)
ALTER TABLE "public"."Warehouses" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."PurchaseOrders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."PurchaseOrderLines" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."InventoryItemProfiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."InventoryBalances" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "warehouses_select_org"
  ON "public"."Warehouses" FOR SELECT TO authenticated
  USING (public.is_org_user_member(organization_id));
CREATE POLICY "warehouses_insert_org"
  ON "public"."Warehouses" FOR INSERT TO authenticated
  WITH CHECK (public.is_org_user_member(organization_id));
CREATE POLICY "warehouses_update_org"
  ON "public"."Warehouses" FOR UPDATE TO authenticated
  USING (public.is_org_user_member(organization_id));

CREATE POLICY "purchase_orders_select_org"
  ON "public"."PurchaseOrders" FOR SELECT TO authenticated
  USING (public.is_org_user_member(organization_id));
CREATE POLICY "purchase_orders_insert_org"
  ON "public"."PurchaseOrders" FOR INSERT TO authenticated
  WITH CHECK (public.is_org_user_member(organization_id));
CREATE POLICY "purchase_orders_update_org"
  ON "public"."PurchaseOrders" FOR UPDATE TO authenticated
  USING (public.is_org_user_member(organization_id));

CREATE POLICY "po_lines_select_via_po"
  ON "public"."PurchaseOrderLines" FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM "public"."PurchaseOrders" po
      WHERE po.id = purchase_order_id AND public.is_org_user_member(po.organization_id)
    )
  );
CREATE POLICY "po_lines_insert_via_po"
  ON "public"."PurchaseOrderLines" FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "public"."PurchaseOrders" po
      WHERE po.id = purchase_order_id AND public.is_org_user_member(po.organization_id)
    )
  );
CREATE POLICY "po_lines_update_via_po"
  ON "public"."PurchaseOrderLines" FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM "public"."PurchaseOrders" po
      WHERE po.id = purchase_order_id AND public.is_org_user_member(po.organization_id)
    )
  );

CREATE POLICY "inv_profiles_select_org"
  ON "public"."InventoryItemProfiles" FOR SELECT TO authenticated
  USING (
    public.is_org_user_member((
      SELECT w.organization_id FROM "public"."Warehouses" w WHERE w.id = warehouse_id
    ))
  );
CREATE POLICY "inv_profiles_insert_org"
  ON "public"."InventoryItemProfiles" FOR INSERT TO authenticated
  WITH CHECK (
    public.is_org_user_member((
      SELECT w.organization_id FROM "public"."Warehouses" w WHERE w.id = warehouse_id
    ))
  );
CREATE POLICY "inv_profiles_update_org"
  ON "public"."InventoryItemProfiles" FOR UPDATE TO authenticated
  USING (
    public.is_org_user_member((
      SELECT w.organization_id FROM "public"."Warehouses" w WHERE w.id = warehouse_id
    ))
  );

CREATE POLICY "inv_balances_select_org"
  ON "public"."InventoryBalances" FOR SELECT TO authenticated
  USING (public.is_org_user_member(organization_id));
CREATE POLICY "inv_balances_insert_org"
  ON "public"."InventoryBalances" FOR INSERT TO authenticated
  WITH CHECK (public.is_org_user_member(organization_id));
CREATE POLICY "inv_balances_update_org"
  ON "public"."InventoryBalances" FOR UPDATE TO authenticated
  USING (public.is_org_user_member(organization_id));
