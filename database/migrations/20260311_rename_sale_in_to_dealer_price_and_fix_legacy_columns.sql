-- ============================================================================
-- Migración integral: sale_in → dealer_price en QuoteLines
-- Fecha: 2026-03-11
--
-- Renames:
--   unit_sale_in_price_snapshot → unit_dealer_price_snapshot
--   sale_in_total              → dealer_price_total
--   sale_in_discount_pct       → dealer_discount_pct
--
-- Actualiza:
--   - Constraint chk_quotelines_sale_in_coherent → chk_quotelines_dealer_price_coherent
--   - Trigger trg_quote_lines_allow_pricing_write_only_via_rpc
--   - sync_quote_line_pricing_from_configured_product
--   - commit_configured_product_to_quote_line
-- ============================================================================


-- ═══════════════════════════════════════════════════════════════════════════
-- PARTE 1: Renombrar columnas en QuoteLines
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines'
      AND column_name = 'unit_sale_in_price_snapshot'
  ) THEN
    ALTER TABLE public."QuoteLines"
      RENAME COLUMN unit_sale_in_price_snapshot TO unit_dealer_price_snapshot;
    RAISE NOTICE '✅ unit_sale_in_price_snapshot → unit_dealer_price_snapshot';
  ELSE
    RAISE NOTICE 'ℹ️ unit_dealer_price_snapshot ya existe (o sale_in ya renombrado)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines'
      AND column_name = 'sale_in_total'
  ) THEN
    ALTER TABLE public."QuoteLines"
      RENAME COLUMN sale_in_total TO dealer_price_total;
    RAISE NOTICE '✅ sale_in_total → dealer_price_total';
  ELSE
    RAISE NOTICE 'ℹ️ dealer_price_total ya existe';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines'
      AND column_name = 'sale_in_discount_pct'
  ) THEN
    ALTER TABLE public."QuoteLines"
      RENAME COLUMN sale_in_discount_pct TO dealer_discount_pct;
    RAISE NOTICE '✅ sale_in_discount_pct → dealer_discount_pct';
  ELSE
    RAISE NOTICE 'ℹ️ dealer_discount_pct ya existe';
  END IF;
END $$;


-- ═══════════════════════════════════════════════════════════════════════════
-- PARTE 1b: Columnas de auditoría (Tier = canónico)
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public."QuoteLines"
  ADD COLUMN IF NOT EXISTS dealer_tier_id_snapshot uuid,
  ADD COLUMN IF NOT EXISTS dealer_tier_code_snapshot text,
  ADD COLUMN IF NOT EXISTS catalog_dealer_unit_snapshot numeric(12,4),
  ADD COLUMN IF NOT EXISTS dealer_price_source text;

COMMENT ON COLUMN public."QuoteLines".dealer_tier_id_snapshot IS
'Snapshot: dealer tier id usado para calcular Dealer Price.';

COMMENT ON COLUMN public."QuoteLines".dealer_tier_code_snapshot IS
'Snapshot: dealer tier code usado (PLATINUM/GOLD/etc).';

COMMENT ON COLUMN public."QuoteLines".catalog_dealer_unit_snapshot IS
'AUDIT: CatalogItemsMSRP.dealer_price del roll (si existe). NO se usa para calcular Dealer Price.';

COMMENT ON COLUMN public."QuoteLines".dealer_price_source IS
'AUDIT: fuente Dealer Price. Canónico: tier.';


-- ═══════════════════════════════════════════════════════════════════════════
-- PARTE 2: Recrear constraint con nuevos nombres
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_sale_in_coherent;

ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_dealer_price_coherent;

ALTER TABLE public."QuoteLines"
  ADD CONSTRAINT chk_quotelines_dealer_price_coherent
  CHECK (
    unit_dealer_price_snapshot IS NULL
    OR dealer_price_total IS NULL
    OR quantity IS NULL
    OR quantity <= 0
    OR abs(dealer_price_total - (unit_dealer_price_snapshot * quantity)) <= 0.02
  ) NOT VALID;

ALTER TABLE public."QuoteLines"
  VALIDATE CONSTRAINT chk_quotelines_dealer_price_coherent;


-- ═══════════════════════════════════════════════════════════════════════════
-- PARTE 3: Trigger — proteger las nuevas columnas
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.trg_quote_lines_allow_pricing_write_only_via_rpc()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_setting('app.write_source', true) = 'rpc' THEN
    RETURN NEW;
  END IF;

  IF OLD.roll_msrp_snapshot            IS DISTINCT FROM NEW.roll_msrp_snapshot
     OR OLD.bom_msrp_snapshot          IS DISTINCT FROM NEW.bom_msrp_snapshot
     OR OLD.roll_cost_snapshot         IS DISTINCT FROM NEW.roll_cost_snapshot
     OR OLD.bom_cost_snapshot          IS DISTINCT FROM NEW.bom_cost_snapshot
     OR OLD.msrp                       IS DISTINCT FROM NEW.msrp
     OR OLD.total_cost                 IS DISTINCT FROM NEW.total_cost
     OR OLD.unit_msrp_total_snapshot   IS DISTINCT FROM NEW.unit_msrp_total_snapshot
     OR OLD.unit_cost_total_snapshot   IS DISTINCT FROM NEW.unit_cost_total_snapshot
     OR OLD.unit_dealer_price_snapshot IS DISTINCT FROM NEW.unit_dealer_price_snapshot
     OR OLD.dealer_price_total         IS DISTINCT FROM NEW.dealer_price_total
     OR OLD.dealer_discount_pct        IS DISTINCT FROM NEW.dealer_discount_pct
     OR OLD.dealer_tier_id_snapshot    IS DISTINCT FROM NEW.dealer_tier_id_snapshot
     OR OLD.dealer_tier_code_snapshot  IS DISTINCT FROM NEW.dealer_tier_code_snapshot
     OR OLD.catalog_dealer_unit_snapshot IS DISTINCT FROM NEW.catalog_dealer_unit_snapshot
     OR OLD.dealer_price_source        IS DISTINCT FROM NEW.dealer_price_source
     OR OLD.pricing_version            IS DISTINCT FROM NEW.pricing_version
     OR OLD.last_priced_at             IS DISTINCT FROM NEW.last_priced_at
  THEN
    RAISE EXCEPTION
      'QuoteLines: pricing/snapshot columns can only be written via '
      'commit_configured_product_to_quote_line or sync_quote_line_pricing_from_configured_product '
      '(set app.write_source=rpc). Protected: msrp, total_cost, unit_msrp_total_snapshot, '
      'unit_cost_total_snapshot, unit_dealer_price_snapshot, dealer_price_total, dealer_discount_pct, '
      'dealer_tier_id/code_snapshot, catalog_dealer_unit_snapshot, dealer_price_source, '
      'roll/bom snapshots, pricing_version, last_priced_at.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_quote_lines_pricing_write_via_rpc_only ON public."QuoteLines";
CREATE TRIGGER trg_quote_lines_pricing_write_via_rpc_only
  BEFORE UPDATE ON public."QuoteLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_quote_lines_allow_pricing_write_only_via_rpc();


-- ═══════════════════════════════════════════════════════════════════════════
-- PARTE 4: sync_quote_line_pricing_from_configured_product (dealer_price)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.sync_quote_line_pricing_from_configured_product(p_quote_line_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql           RECORD;
  v_cp           RECORD;
  v_totals       jsonb;
  v_qty          numeric(12,4);
  v_unit_msrp    numeric(12,4);
  v_unit_cost    numeric(12,4);
  v_dealer_tier_id uuid;
  v_dealer_tier_code text;
  v_discount_pct numeric(5,2);
  v_unit_dealer_price numeric(12,4);
  v_catalog_dealer_unit numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required';
  END IF;

  SELECT ql.id, ql.organization_id, ql.configured_product_id,
         ql.quantity, ql.pricing_locked, ql.quote_id
  INTO v_ql
  FROM public."QuoteLines" ql
  WHERE ql.id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;
  IF v_ql.configured_product_id IS NULL THEN RETURN; END IF;
  IF COALESCE(v_ql.pricing_locked, false) = true THEN RETURN; END IF;

  PERFORM public.calculate_configured_product_totals(v_ql.configured_product_id);

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = v_ql.configured_product_id
    AND organization_id = v_ql.organization_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found for QuoteLine %', v_ql.configured_product_id, p_quote_line_id;
  END IF;

  v_totals := COALESCE(v_cp.bom_preview_snapshot->'totals', '{}'::jsonb);
  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);

  v_unit_msrp := COALESCE(v_cp.total_msrp, (v_totals->>'total_msrp')::numeric, 0);
  v_unit_cost := COALESCE(v_cp.unit_product_cost_landed, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  IF v_unit_cost = 0 THEN
    v_unit_cost := COALESCE(
      (v_totals->>'total_cost_with_labor')::numeric,
      COALESCE(v_cp.roll_total_cost_landed, 0)
        + COALESCE(v_cp.bom_total_cost_landed, 0)
        + COALESCE(v_cp.accessories_total_cost_landed, 0)
        + COALESCE(v_cp.unit_labor_cost, 0),
      0
    );
  END IF;

  -- Tier del dealer desde el Quote (canónico: SIEMPRE por tier)
  SELECT d.dealer_tier_id, dt.code, COALESCE(dt.discount_pct, 35)
  INTO v_dealer_tier_id, v_dealer_tier_code, v_discount_pct
  FROM public."Quotes" q
  JOIN public."Dealers" d ON d.id = q.dealer_id
  LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
  WHERE q.id = v_ql.quote_id
  LIMIT 1;

  IF v_discount_pct IS NULL THEN
    v_discount_pct := 35;
  END IF;

  -- Canónico: SIEMPRE por tier
  v_unit_dealer_price := ROUND(v_unit_msrp * (1 - v_discount_pct / 100.0), 4);

  -- AUDIT: dealer_price del catálogo (solo referencia, no se usa para calcular)
  SELECT cim.dealer_price
  INTO v_catalog_dealer_unit
  FROM public."CatalogItemsMSRP" cim
  WHERE cim.organization_id = v_ql.organization_id
    AND cim.catalog_item_id = v_cp.roll_catalog_item_id
  ORDER BY cim.updated_at DESC NULLS LAST
  LIMIT 1;

  PERFORM set_config('app.write_source', 'rpc', true);

  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot         = COALESCE(v_cp.roll_msrp_total, (v_totals->>'roll_msrp_total')::numeric, 0),
    bom_msrp_snapshot          = COALESCE(v_cp.bom_total, (v_totals->>'bom_total')::numeric, 0),
    roll_cost_snapshot         = COALESCE(v_cp.roll_total_cost_landed, (v_totals->>'roll_total_cost_landed')::numeric, 0),
    bom_cost_snapshot          = COALESCE(v_cp.bom_total_cost_landed, (v_totals->>'bom_total_cost_landed')::numeric, 0),
    unit_msrp_total_snapshot   = v_unit_msrp,
    unit_cost_total_snapshot   = v_unit_cost,
    msrp                       = ROUND(v_unit_msrp * v_qty, 2),
    total_cost                 = ROUND(v_unit_cost * v_qty, 2),
    unit_dealer_price_snapshot = v_unit_dealer_price,
    dealer_price_total         = ROUND(v_unit_dealer_price * v_qty, 2),
    dealer_discount_pct        = v_discount_pct,
    dealer_tier_id_snapshot    = v_dealer_tier_id,
    dealer_tier_code_snapshot  = v_dealer_tier_code,
    catalog_dealer_unit_snapshot = v_catalog_dealer_unit,
    dealer_price_source        = 'tier',
    last_priced_at             = now(),
    pricing_version            = COALESCE(pricing_version, 0) + 1,
    pricing_locked             = true
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.sync_quote_line_pricing_from_configured_product(uuid) IS
'Refreshes QuoteLine pricing from ConfiguredProduct. No-op if pricing_locked. Dealer Price: SIEMPRE por tier (dealer_discount_pct nunca NULL). Guarda auditoría: dealer_tier_id/code, catalog_dealer_unit, dealer_price_source=tier.';


-- ═══════════════════════════════════════════════════════════════════════════
-- PARTE 5: commit_configured_product_to_quote_line (dealer_price)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.commit_configured_product_to_quote_line(
  p_org_id uuid,
  p_quote_id uuid,
  p_configured_product_id uuid,
  p_dealer_id uuid DEFAULT NULL,
  p_position text DEFAULT NULL,
  p_area text DEFAULT NULL,
  p_fabric_drop text DEFAULT NULL,
  p_installation_type text DEFAULT NULL,
  p_installation_location text DEFAULT NULL
)
RETURNS TABLE(quote_line_id uuid, bom_instance_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cp              RECORD;
  v_roll_item       RECORD;
  v_quote_line_id   uuid;
  v_bom_instance_id uuid;
  v_width_m         numeric(12,4);
  v_height_m        numeric(12,4);
  v_line_quantity   numeric(12,4);
  v_operating_type  text;
  v_unit_msrp       numeric(12,4);
  v_unit_cost       numeric(12,4);
  v_product_type_code text;
  v_effective_dealer_id uuid;
  v_dealer_tier_id  uuid;
  v_dealer_tier_code text;
  v_discount_pct    numeric(5,2);
  v_unit_dealer_price numeric(12,4);
  v_catalog_dealer_unit numeric(12,4);
BEGIN
  IF p_org_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_org_id is required'; END IF;
  IF p_quote_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_quote_id is required'; END IF;
  IF p_configured_product_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_configured_product_id is required'; END IF;

  PERFORM public.calculate_configured_product_totals(p_configured_product_id);

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found or does not belong to org %', p_configured_product_id, p_org_id;
  END IF;

  v_line_quantity  := GREATEST(COALESCE(v_cp.quantity, 1), 1);
  v_width_m        := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m       := COALESCE(v_cp.height_mm / 1000.0, 0);
  v_operating_type := COALESCE(
    v_cp.config_snapshot->>'operating_type',
    v_cp.config_snapshot->>'drive_type',
    v_cp.config_snapshot->>'operation_type'
  );

  v_unit_msrp := COALESCE(v_cp.total_msrp, 0);
  v_unit_cost := COALESCE(v_cp.unit_product_cost_landed, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  IF v_unit_cost = 0 THEN
    v_unit_cost :=
      COALESCE(v_cp.roll_total_cost_landed, 0)
      + COALESCE(v_cp.bom_total_cost_landed, 0)
      + COALESCE(v_cp.accessories_total_cost_landed, 0)
      + COALESCE(v_cp.unit_labor_cost, 0);
  END IF;

  v_effective_dealer_id := COALESCE(
    p_dealer_id,
    (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)
  );

  SELECT d.dealer_tier_id, dt.code, COALESCE(dt.discount_pct, 35)
  INTO v_dealer_tier_id, v_dealer_tier_code, v_discount_pct
  FROM public."Dealers" d
  LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
  WHERE d.id = v_effective_dealer_id
  LIMIT 1;

  IF v_discount_pct IS NULL THEN
    v_discount_pct := 35;
  END IF;

  v_unit_dealer_price := ROUND(v_unit_msrp * (1 - v_discount_pct / 100.0), 4);

  -- AUDIT: dealer_price del catálogo (solo referencia)
  SELECT cim.dealer_price
  INTO v_catalog_dealer_unit
  FROM public."CatalogItemsMSRP" cim
  WHERE cim.organization_id = p_org_id
    AND cim.catalog_item_id = v_cp.roll_catalog_item_id
  ORDER BY cim.updated_at DESC NULLS LAST
  LIMIT 1;

  SELECT pt.code INTO v_product_type_code
  FROM public."ProductTypes" pt
  WHERE pt.id = v_cp.product_type_id
  LIMIT 1;

  SELECT ci.sku, ci.name, ci.category_id, ci.manufacturer_id, m.name AS manufacturer_name,
         ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_m
  INTO v_roll_item
  FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id
    AND ci.is_active = true
  LIMIT 1;

  PERFORM set_config('app.write_source', 'rpc', true);

  INSERT INTO public."QuoteLines" (
    organization_id, quote_id, dealer_id,
    configured_product_id, bom_template_id,
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer,
    collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity,
    hardware_color, drive_type, position, area, fabric_drop,
    roll_msrp_snapshot, bom_msrp_snapshot,
    roll_cost_snapshot, bom_cost_snapshot,
    unit_msrp_total_snapshot, unit_cost_total_snapshot,
    msrp, total_cost,
    unit_dealer_price_snapshot, dealer_price_total, dealer_discount_pct,
    dealer_tier_id_snapshot, dealer_tier_code_snapshot,
    catalog_dealer_unit_snapshot, dealer_price_source,
    pricing_locked, last_priced_at, pricing_version,
    product_type, product_type_id
  )
  VALUES (
    p_org_id, p_quote_id, v_effective_dealer_id,
    v_cp.id, v_cp.bom_template_id,
    v_cp.roll_catalog_item_id,
    COALESCE(v_cp.roll_sku, v_roll_item.sku), v_roll_item.name,
    v_roll_item.category_id, v_roll_item.manufacturer_id, v_roll_item.manufacturer_name,
    COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name),
    COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name),
    v_cp.roll_catalog_item_id IS NOT NULL,
    CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END,
    COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    v_width_m, v_height_m, v_line_quantity,
    v_cp.hardware_color, v_operating_type, p_position, p_area,
    COALESCE(p_fabric_drop, v_cp.config_snapshot->>'fabricDrop', v_cp.config_snapshot->>'drop_type'),
    COALESCE(v_cp.roll_msrp_total, 0), COALESCE(v_cp.bom_total, 0),
    COALESCE(v_cp.roll_total_cost_landed, 0), COALESCE(v_cp.bom_total_cost_landed, 0),
    v_unit_msrp, v_unit_cost,
    ROUND(v_unit_msrp * v_line_quantity, 2),
    ROUND(v_unit_cost * v_line_quantity, 2),
    v_unit_dealer_price,
    ROUND(v_unit_dealer_price * v_line_quantity, 2),
    v_discount_pct,
    v_dealer_tier_id, v_dealer_tier_code,
    v_catalog_dealer_unit, 'tier',
    true, now(), 1,
    v_product_type_code, v_cp.product_type_id
  )
  RETURNING id INTO v_quote_line_id;

  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;

COMMENT ON FUNCTION public.commit_configured_product_to_quote_line(uuid, uuid, uuid, uuid, text, text, text, text, text) IS
'Creates QuoteLine from ConfiguredProduct. Snapshots: MSRP (unit_msrp_total_snapshot, msrp), Cost (unit_cost_total_snapshot, total_cost), Dealer Price (unit_dealer_price_snapshot, dealer_price_total, dealer_discount_pct). Single write-path.';


-- ═══════════════════════════════════════════════════════════════════════════
-- PARTE 6: Column comments
-- ═══════════════════════════════════════════════════════════════════════════

COMMENT ON COLUMN public."QuoteLines".unit_dealer_price_snapshot IS
'Dealer price unitario = MSRP × (1 - tier_discount_pct/100). Snapshot al momento del commit/sync.';

COMMENT ON COLUMN public."QuoteLines".dealer_price_total IS
'Dealer price total = unit_dealer_price_snapshot × quantity.';

COMMENT ON COLUMN public."QuoteLines".dealer_discount_pct IS
'% descuento del tier del dealer aplicado (ej. Bronze=35%). Canónico: siempre por tier, nunca NULL.';


-- ═══════════════════════════════════════════════════════════════════════════
-- PRICING COLUMN SET (referencia)
-- ═══════════════════════════════════════════════════════════════════════════
-- QuoteLines pricing columns (all written via RPC only):
--   roll_msrp_snapshot         ← CP.roll_msrp_total
--   bom_msrp_snapshot          ← CP.bom_total
--   roll_cost_snapshot         ← CP.roll_total_cost_landed
--   bom_cost_snapshot          ← CP.bom_total_cost_landed
--   unit_msrp_total_snapshot   ← CP.total_msrp (unit)
--   unit_cost_total_snapshot   ← CP.unit_product_cost_landed + unit_labor_cost
--   msrp                       ← unit_msrp × quantity (MSRP total)
--   total_cost                 ← unit_cost × quantity
--   unit_dealer_price_snapshot ← MSRP × (1 - tier discount %). SIEMPRE por tier.
--   dealer_price_total         ← unit_dealer_price × quantity
--   dealer_discount_pct        ← tier discount % (nunca NULL)
--   dealer_tier_id_snapshot    ← auditoría: tier usado
--   dealer_tier_code_snapshot  ← auditoría: código tier (PLATINUM/GOLD/etc)
--   catalog_dealer_unit_snapshot ← AUDIT: CatalogItemsMSRP.dealer_price (referencia, no usado)
--   dealer_price_source        ← 'tier' (canónico)
--   pricing_locked             ← true after commit/sync
--   pricing_version            ← incremental
--   last_priced_at             ← timestamp
--
--
-- ============================================================================
-- VERIFICACIÓN (sustituir TU_QUOTE_ID)
-- ============================================================================
-- SELECT
--   ql.id,
--   ql.quantity,
--   ql.unit_msrp_total_snapshot,
--   ql.dealer_discount_pct,
--   ql.dealer_tier_code_snapshot,
--   ql.unit_dealer_price_snapshot,
--   ql.dealer_price_total,
--   round(ql.unit_msrp_total_snapshot * (1 - (ql.dealer_discount_pct/100.0)), 4) as expected_unit_dealer,
--   round(ql.unit_msrp_total_snapshot * (1 - (ql.dealer_discount_pct/100.0)) * ql.quantity, 2) as expected_total_dealer,
--   (abs(ql.unit_dealer_price_snapshot - round(ql.unit_msrp_total_snapshot * (1 - (ql.dealer_discount_pct/100.0)), 4)) <= 0.02) as ok_unit,
--   (abs(ql.dealer_price_total - round(ql.unit_msrp_total_snapshot * (1 - (ql.dealer_discount_pct/100.0)) * ql.quantity, 2)) <= 0.02) as ok_total,
--   ql.catalog_dealer_unit_snapshot,
--   ql.dealer_price_source
-- FROM public."QuoteLines" ql
-- WHERE ql.quote_id = 'TU_QUOTE_ID'::uuid
-- ORDER BY ql.created_at DESC;
