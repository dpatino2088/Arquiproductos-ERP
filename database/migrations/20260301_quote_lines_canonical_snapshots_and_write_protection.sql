-- ============================================================================
-- Migración: QuoteLines — columnas canónicas, backfill, constraints, write-path único
-- Fecha: 2026-03-01
--
-- Objetivo: estabilizar CP vs QuoteLines (contrato canónico).
-- - Añadir unit_msrp_total_snapshot y unit_cost_total_snapshot (canónicos).
-- - Backfill desde snapshots existentes (roll/bom) o msrp/total_cost/quantity.
-- - CHECKs de coherencia (quantity > 0, msrp = unit*quantity, total_cost = unit*quantity).
-- - Trigger que bloquea escritura directa a pricing/snapshots salvo desde RPCs.
-- - NO se eliminan columnas legacy (deprecación en fases posteriores).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Añadir columnas canónicas a QuoteLines (si no existen)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'unit_msrp_total_snapshot'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN unit_msrp_total_snapshot numeric(12,4) DEFAULT NULL;
    COMMENT ON COLUMN public."QuoteLines".unit_msrp_total_snapshot IS 'Snapshot canónico del MSRP unitario (roll+bom+accessories+labor) al commit/sync. msrp = unit_msrp_total_snapshot * quantity.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'unit_cost_total_snapshot'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN unit_cost_total_snapshot numeric(12,4) DEFAULT NULL;
    COMMENT ON COLUMN public."QuoteLines".unit_cost_total_snapshot IS 'Snapshot canónico del costo unitario al commit/sync. total_cost = unit_cost_total_snapshot * quantity.';
  END IF;
  -- Asegurar que msrp y total_cost existan (algunos esquemas legacy pueden no tenerlas)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'msrp'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN msrp numeric(12,4) DEFAULT NULL;
    COMMENT ON COLUMN public."QuoteLines".msrp IS 'Total MSRP de la línea (unit_msrp_total_snapshot * quantity).';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'total_cost'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN total_cost numeric(12,4) DEFAULT NULL;
    COMMENT ON COLUMN public."QuoteLines".total_cost IS 'Costo total de la línea (unit_cost_total_snapshot * quantity).';
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 2) Backfill: unit_msrp_total_snapshot y unit_cost_total_snapshot
-- ----------------------------------------------------------------------------
UPDATE public."QuoteLines"
SET
  unit_msrp_total_snapshot = CASE
    WHEN COALESCE(quantity, 0) <= 0 THEN NULL
    WHEN msrp IS NOT NULL THEN ROUND(msrp / quantity, 4)
    ELSE ROUND(COALESCE(roll_msrp_snapshot, 0) + COALESCE(bom_msrp_snapshot, 0), 4)
  END,
  unit_cost_total_snapshot = CASE
    WHEN COALESCE(quantity, 0) <= 0 THEN NULL
    WHEN total_cost IS NOT NULL THEN ROUND(total_cost / quantity, 4)
    ELSE ROUND(COALESCE(roll_cost_snapshot, 0) + COALESCE(bom_cost_snapshot, 0), 4)
  END
WHERE (unit_msrp_total_snapshot IS NULL OR unit_cost_total_snapshot IS NULL)
  AND quantity IS NOT NULL AND quantity > 0;

-- Alinear msrp/total_cost con los snapshots donde falte (evitar violar CHECK después)
UPDATE public."QuoteLines"
SET msrp = ROUND(COALESCE(unit_msrp_total_snapshot, 0) * COALESCE(quantity, 1), 2),
    total_cost = ROUND(COALESCE(unit_cost_total_snapshot, 0) * COALESCE(quantity, 1), 2)
WHERE quantity > 0
  AND (msrp IS NULL OR total_cost IS NULL
       OR ABS(msrp - ROUND(COALESCE(unit_msrp_total_snapshot, 0) * quantity, 2)) > 0.01
       OR ABS(total_cost - ROUND(COALESCE(unit_cost_total_snapshot, 0) * quantity, 2)) > 0.01);

-- ----------------------------------------------------------------------------
-- 3) CHECK constraints (NOT VALID para no bloquear tabla; luego VALIDATE)
-- ----------------------------------------------------------------------------
-- quantity > 0: solo añadir si no hay filas con quantity <= 0 (si falla, corregir datos y re-ejecutar)
ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_quantity_positive;
ALTER TABLE public."QuoteLines"
  ADD CONSTRAINT chk_quotelines_quantity_positive
  CHECK (quantity IS NOT NULL AND quantity > 0);

ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_msrp_coherent;

-- Tolerancia 0.01 para evitar falsos negativos por numeric(12,4)*quantity vs msrp(12,2)
ALTER TABLE public."QuoteLines"
  ADD CONSTRAINT chk_quotelines_msrp_coherent
  CHECK (
    unit_msrp_total_snapshot IS NULL AND msrp IS NULL
    OR (quantity > 0 AND unit_msrp_total_snapshot IS NOT NULL AND msrp IS NOT NULL
        AND abs(msrp - (unit_msrp_total_snapshot * quantity)) <= 0.01)
  ) NOT VALID;

ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_total_cost_coherent;

ALTER TABLE public."QuoteLines"
  ADD CONSTRAINT chk_quotelines_total_cost_coherent
  CHECK (
    unit_cost_total_snapshot IS NULL AND total_cost IS NULL
    OR (quantity > 0 AND unit_cost_total_snapshot IS NOT NULL AND total_cost IS NOT NULL
        AND abs(total_cost - (unit_cost_total_snapshot * quantity)) <= 0.01)
  ) NOT VALID;

ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_unit_snapshots_non_neg;

ALTER TABLE public."QuoteLines"
  ADD CONSTRAINT chk_quotelines_unit_snapshots_non_neg
  CHECK (
    (unit_msrp_total_snapshot IS NULL OR unit_msrp_total_snapshot >= 0)
    AND (unit_cost_total_snapshot IS NULL OR unit_cost_total_snapshot >= 0)
  ) NOT VALID;

ALTER TABLE public."QuoteLines" VALIDATE CONSTRAINT chk_quotelines_msrp_coherent;
ALTER TABLE public."QuoteLines" VALIDATE CONSTRAINT chk_quotelines_total_cost_coherent;
ALTER TABLE public."QuoteLines" VALIDATE CONSTRAINT chk_quotelines_unit_snapshots_non_neg;

-- ----------------------------------------------------------------------------
-- 4) Trigger: bloquear UPDATE directo al "pricing column set"
--    Solo permitir si current_setting('app.write_source', true) = 'rpc'
--    Set exacto: msrp, total_cost, unit_msrp_total_snapshot, unit_cost_total_snapshot,
--    roll_msrp_snapshot, bom_msrp_snapshot, roll_cost_snapshot, bom_cost_snapshot,
--    pricing_version, last_priced_at
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_quote_lines_allow_pricing_write_only_via_rpc()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_setting('app.write_source', true) = 'rpc' THEN
    RETURN NEW;
  END IF;

  IF OLD.roll_msrp_snapshot IS DISTINCT FROM NEW.roll_msrp_snapshot
     OR OLD.bom_msrp_snapshot IS DISTINCT FROM NEW.bom_msrp_snapshot
     OR OLD.roll_cost_snapshot IS DISTINCT FROM NEW.roll_cost_snapshot
     OR OLD.bom_cost_snapshot IS DISTINCT FROM NEW.bom_cost_snapshot
     OR OLD.msrp IS DISTINCT FROM NEW.msrp
     OR OLD.total_cost IS DISTINCT FROM NEW.total_cost
     OR OLD.unit_msrp_total_snapshot IS DISTINCT FROM NEW.unit_msrp_total_snapshot
     OR OLD.unit_cost_total_snapshot IS DISTINCT FROM NEW.unit_cost_total_snapshot
     OR OLD.pricing_version IS DISTINCT FROM NEW.pricing_version
     OR OLD.last_priced_at IS DISTINCT FROM NEW.last_priced_at
  THEN
    RAISE EXCEPTION 'QuoteLines: pricing/snapshot columns can only be updated via commit_configured_product_to_quote_line or sync_quote_line_pricing_from_configured_product (set app.write_source=rpc)';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_quote_lines_pricing_write_via_rpc_only ON public."QuoteLines";
CREATE TRIGGER trg_quote_lines_pricing_write_via_rpc_only
  BEFORE UPDATE ON public."QuoteLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_quote_lines_allow_pricing_write_only_via_rpc();

-- ----------------------------------------------------------------------------
-- 5) RPCs: commit y sync escriben canónicas y marcan write_source
--    sync respeta pricing_locked (no-op si locked)
-- ----------------------------------------------------------------------------
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
  v_cp RECORD;
  v_roll_item RECORD;
  v_quote_line_id uuid;
  v_bom_instance_id uuid;
  v_width_m numeric(12,4);
  v_height_m numeric(12,4);
  v_line_quantity numeric(12,4);
  v_operating_type text;
  v_unit_msrp numeric(12,4);
  v_unit_cost numeric(12,4);
  v_product_type_code text;
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

  v_line_quantity := GREATEST(COALESCE(v_cp.quantity, 1), 1);
  v_width_m := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m := COALESCE(v_cp.height_mm / 1000.0, 0);
  v_operating_type := COALESCE(v_cp.config_snapshot->>'operating_type', v_cp.config_snapshot->>'drive_type', v_cp.config_snapshot->>'operation_type');

  v_unit_msrp := COALESCE(v_cp.total_msrp, 0);
  v_unit_cost := COALESCE(v_cp.unit_product_cost_landed, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  IF v_unit_cost = 0 THEN
    v_unit_cost := COALESCE(v_cp.roll_total_cost_landed, 0) + COALESCE(v_cp.bom_total_cost_landed, 0) + COALESCE(v_cp.accessories_total_cost_landed, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  END IF;

  SELECT pt.code INTO v_product_type_code
  FROM public."ProductTypes" pt
  WHERE pt.id = v_cp.product_type_id
  LIMIT 1;
  -- product_type_id se guarda directamente desde ConfiguredProducts (v_cp.product_type_id)

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
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer, collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity,
    hardware_color, drive_type, position, area, fabric_drop,
    roll_msrp_snapshot, bom_msrp_snapshot, roll_cost_snapshot, bom_cost_snapshot,
    unit_msrp_total_snapshot, unit_cost_total_snapshot,
    msrp, total_cost,
    pricing_locked, last_priced_at, pricing_version,
    product_type, product_type_id
  )
  VALUES (
    p_org_id, p_quote_id, (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1),
    v_cp.id, v_cp.bom_template_id,
    v_cp.roll_catalog_item_id, COALESCE(v_cp.roll_sku, v_roll_item.sku), v_roll_item.name, v_roll_item.category_id, v_roll_item.manufacturer_id, v_roll_item.manufacturer_name,
    COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name), COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name),
    v_cp.roll_catalog_item_id IS NOT NULL, CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END, COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    v_width_m, v_height_m, v_line_quantity,
    v_cp.hardware_color, v_operating_type, p_position, p_area, COALESCE(p_fabric_drop, v_cp.config_snapshot->>'fabricDrop', v_cp.config_snapshot->>'drop_type'),
    COALESCE(v_cp.roll_msrp_total, 0), COALESCE(v_cp.bom_total, 0),
    COALESCE(v_cp.roll_total_cost_landed, 0), COALESCE(v_cp.bom_total_cost_landed, 0),
    v_unit_msrp, v_unit_cost,
    ROUND(v_unit_msrp * v_line_quantity, 2), ROUND(v_unit_cost * v_line_quantity, 2),
    true, now(), 1,
    v_product_type_code, v_cp.product_type_id
  )
  RETURNING id INTO v_quote_line_id;

  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_quote_line_pricing_from_configured_product(p_quote_line_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql RECORD;
  v_cp RECORD;
  v_qty numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_unit_cost numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required';
  END IF;

  SELECT id, organization_id, configured_product_id, quantity, pricing_locked
  INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;
  IF v_ql.configured_product_id IS NULL THEN
    RETURN;
  END IF;
  IF COALESCE(v_ql.pricing_locked, false) = true THEN
    RETURN;
  END IF;

  PERFORM public.calculate_configured_product_totals(v_ql.configured_product_id);

  SELECT *
  INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = v_ql.configured_product_id
    AND organization_id = v_ql.organization_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found for QuoteLine %', v_ql.configured_product_id, p_quote_line_id;
  END IF;

  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);
  v_unit_msrp := COALESCE(v_cp.total_msrp, 0);
  v_unit_cost := COALESCE(v_cp.unit_product_cost_landed, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  IF v_unit_cost = 0 THEN
    v_unit_cost := COALESCE(v_cp.roll_total_cost_landed, 0) + COALESCE(v_cp.bom_total_cost_landed, 0) + COALESCE(v_cp.accessories_total_cost_landed, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  END IF;

  PERFORM set_config('app.write_source', 'rpc', true);

  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot = COALESCE(v_cp.roll_msrp_total, 0),
    bom_msrp_snapshot = COALESCE(v_cp.bom_total, 0),
    roll_cost_snapshot = COALESCE(v_cp.roll_total_cost_landed, 0),
    bom_cost_snapshot = COALESCE(v_cp.bom_total_cost_landed, 0),
    unit_msrp_total_snapshot = v_unit_msrp,
    unit_cost_total_snapshot = v_unit_cost,
    msrp = ROUND(v_unit_msrp * v_qty, 2),
    total_cost = ROUND(v_unit_cost * v_qty, 2),
    last_priced_at = now(),
    pricing_version = COALESCE(pricing_version, 0) + 1,
    pricing_locked = true
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.commit_configured_product_to_quote_line(uuid, uuid, uuid, uuid, text, text, text, text, text) IS
'Creates QuoteLine from ConfiguredProduct. Writes only canonical columns (snapshots + unit_msrp_total_snapshot + unit_cost_total_snapshot + msrp + total_cost). Single write-path.';
COMMENT ON FUNCTION public.sync_quote_line_pricing_from_configured_product(uuid) IS
'Refreshes QuoteLine from ConfiguredProduct. No-op if pricing_locked. Writes only canonical columns. Single write-path.';
