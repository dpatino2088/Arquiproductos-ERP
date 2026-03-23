-- ====================================================
-- FIX COMPLETO Y FINAL - BOM CONFIGURATOR
-- ====================================================
-- Ejecuta ESTE ÚNICO SQL y todo debe funcionar
-- Org: 3acbb54c-c71f-4cb2-9fe3-d3ac513babe2
-- ====================================================

BEGIN;

-- ============================================================================
-- 1. CREAR TABLA SaleOrderLines (si no existe)
-- ============================================================================

CREATE TABLE IF NOT EXISTS "public"."SaleOrderLines" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "organization_id" uuid NOT NULL,
    "sales_order_id" uuid NOT NULL,
    "quote_line_id" uuid,
    "catalog_item_id" uuid,
    "quantity" numeric(12,4) DEFAULT 1 NOT NULL,
    "width_m" numeric(12,4),
    "height_m" numeric(12,4),
    "sqm" numeric(12,4),
    "unit_price" numeric(12,4),
    "line_total" numeric(12,4),
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "SaleOrderLines_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "saleorderlines_so_fk" FOREIGN KEY ("sales_order_id") 
        REFERENCES "public"."SalesOrders"("id") ON DELETE CASCADE
);

GRANT SELECT ON TABLE "public"."SaleOrderLines" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."SaleOrderLines" TO "authenticated";
GRANT ALL ON TABLE "public"."SaleOrderLines" TO "service_role";

-- ============================================================================
-- 2. AGREGAR COLUMNAS FALTANTES A QuoteLines
-- ============================================================================

DO $$
DECLARE
  v_col_exists boolean;
BEGIN
  -- product_type
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'product_type') INTO v_col_exists;
  IF NOT v_col_exists THEN ALTER TABLE public."QuoteLines" ADD COLUMN product_type text; END IF;

  -- area
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'area') INTO v_col_exists;
  IF NOT v_col_exists THEN ALTER TABLE public."QuoteLines" ADD COLUMN area text; END IF;

  -- position
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'position') INTO v_col_exists;
  IF NOT v_col_exists THEN ALTER TABLE public."QuoteLines" ADD COLUMN position text; END IF;

  -- hardware_color
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'hardware_color') INTO v_col_exists;
  IF NOT v_col_exists THEN ALTER TABLE public."QuoteLines" ADD COLUMN hardware_color text; END IF;

  -- cassette
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'cassette') INTO v_col_exists;
  IF NOT v_col_exists THEN ALTER TABLE public."QuoteLines" ADD COLUMN cassette boolean DEFAULT false; END IF;

  -- side_channel
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'side_channel') INTO v_col_exists;
  IF NOT v_col_exists THEN ALTER TABLE public."QuoteLines" ADD COLUMN side_channel boolean DEFAULT false; END IF;

  -- drive_type
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'drive_type') INTO v_col_exists;
  IF NOT v_col_exists THEN ALTER TABLE public."QuoteLines" ADD COLUMN drive_type text; END IF;

  -- bom_template_id
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'bom_template_id') INTO v_col_exists;
  IF NOT v_col_exists THEN 
    ALTER TABLE public."QuoteLines" ADD COLUMN bom_template_id uuid;
    ALTER TABLE public."QuoteLines" ADD CONSTRAINT fk_quote_lines_bom_template FOREIGN KEY (bom_template_id) REFERENCES public."BOMTemplates"(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================================================
-- 3. ACTUALIZAR CONSTRAINT DE QuoteLineComponents
-- ============================================================================

ALTER TABLE public."QuoteLineComponents"
DROP CONSTRAINT IF EXISTS "quotelinecomponents_component_role_check";

ALTER TABLE public."QuoteLineComponents"
ADD CONSTRAINT "quotelinecomponents_component_role_check" CHECK (
  component_role IS NULL OR component_role = ANY (ARRAY[
    -- PADRES (BOM)
    'tube', 'track', 'bottom_bar', 'bottom_channel', 'hem_weight', 'side_channel',
    'top_rail', 'headbox', 'bracket', 'idler', 'drive', 'motor', 'adapter',
    'chain', 'chain_stop', 'chain_tensioner', 'wand', 'end_cap', 'filler',
    'tape', 'consumable', 'fastener', 'accessory', 'carrier', 'belt', 'belt_connector',
    -- OPCIONES (Config)
    'fabric', 'hardware_color', 'drive_type', 'system_size', 'cassette',
    'bottom_rail_type', 'tube_type', 'side_channels', 'bearing', 'hook', 'brush'
  ])
);

-- ============================================================================
-- 4. AGREGAR is_required A BOMComponents (si no existe)
-- ============================================================================

DO $$
DECLARE
  v_col_exists boolean;
BEGIN
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'BOMComponents' AND column_name = 'is_required') INTO v_col_exists;
  IF NOT v_col_exists THEN 
    ALTER TABLE public."BOMComponents" ADD COLUMN is_required boolean DEFAULT false NOT NULL;
  END IF;
END $$;

-- ============================================================================
-- 5. CREAR ÍNDICES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_quote_lines_product_type ON public."QuoteLines"(product_type) WHERE product_type IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_quote_lines_bom_template_id ON public."QuoteLines"(bom_template_id) WHERE bom_template_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_saleorderlines_so ON public."SaleOrderLines"(sales_order_id);

COMMIT;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 
  '✅ QuoteLines columns' as status,
  string_agg(column_name, ', ' ORDER BY column_name) as columns
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'QuoteLines'
  AND column_name IN ('product_type', 'area', 'position', 'hardware_color', 'cassette', 'side_channel', 'drive_type', 'bom_template_id')

UNION ALL

SELECT 
  '✅ SaleOrderLines exists' as status,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'SaleOrderLines')
    THEN 'YES' ELSE 'NO' END as columns;
