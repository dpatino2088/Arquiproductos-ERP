-- ============================================================================
-- Migración: QuoteLines — Sale-In snapshot (precio de venta al dealer)
-- Fecha: 2026-03-02
--
-- Objetivo: persistir el precio de venta al dealer (Sale-In) en QuoteLines
-- como snapshot inmutable al momento del commit/sync.
--
-- Contexto:
--   CAPA           FUENTE                        COLUMNAS EN BD
--   ─────────────────────────────────────────────────────────────────────
--   Purchase cost  ConfiguredProducts →           unit_cost_total_snapshot
--                  CatalogItemsMSRP.total_cost     total_cost
--   MSRP (lista)   ConfiguredProducts.total_msrp  unit_msrp_total_snapshot
--                                                 msrp
--   Sale-In        unit_msrp × (1 - tier_pct)     unit_sale_in_price_snapshot  ← NUEVO
--   (Dealer price)  congelado al momento commit    sale_in_total                ← NUEVO
--                  con el tier del dealer          sale_in_discount_pct         ← NUEVO
--
-- Problema actual:
--   "Dealer price" en UI = msrp × (1 − tier_discount) calculado dinámicamente.
--   Si el tier cambia → el precio mostrado en cotizaciones históricas cambia.
--   No hay snapshot, no hay auditoría, los reportes son inestables.
--
-- Solución:
--   3 columnas nuevas en QuoteLines, rellenadas en commit/sync desde DealerTiers.
--   Invariante: sale_in_total = unit_sale_in_price_snapshot × quantity
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Añadir columnas (idempotente)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines'
      AND column_name = 'unit_sale_in_price_snapshot'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD COLUMN unit_sale_in_price_snapshot numeric(12,4) DEFAULT NULL;
    COMMENT ON COLUMN public."QuoteLines".unit_sale_in_price_snapshot IS
      'Precio unitario de venta al dealer (Sale-In). Snapshot al commit/sync: unit_msrp_total_snapshot × (1 - sale_in_discount_pct/100). Inmutable tras commit; no cambia si el tier del dealer cambia.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines'
      AND column_name = 'sale_in_total'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD COLUMN sale_in_total numeric(12,4) DEFAULT NULL;
    COMMENT ON COLUMN public."QuoteLines".sale_in_total IS
      'Total de línea al dealer (Sale-In): unit_sale_in_price_snapshot × quantity. Snapshot inmutable.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines'
      AND column_name = 'sale_in_discount_pct'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD COLUMN sale_in_discount_pct numeric(5,2) DEFAULT NULL;
    COMMENT ON COLUMN public."QuoteLines".sale_in_discount_pct IS
      '% de descuento sobre MSRP aplicado al dealer en el commit/sync (de DealerTiers.discount_pct). Snapshot: audita qué tier se usó. Fuente: ''tier'' (DealerTiers) o ''manual''.';
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 2) Backfill: rellenar desde msrp + discount_pct
--    Prioridad:
--      a) msrp × (1 - discount_pct) si discount_pct existe en la línea
--      b) msrp × (1 - 0.35) [Bronze por defecto] si no hay nada
--    Solo para filas donde unit_sale_in_price_snapshot es NULL
--    Nota: net_price fue eliminada en 20260204_quotelines_drop_unused_columns.sql;
--          si aún existe (BD sin esa migración), el bloque DO la usa como mejor fuente.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_has_net_price  boolean;
  v_has_discount_pct boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines'
      AND column_name = 'net_price'
  ) INTO v_has_net_price;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines'
      AND column_name = 'discount_pct'
  ) INTO v_has_discount_pct;

  IF v_has_net_price THEN
    -- BD con net_price aún presente (antes de drop migration)
    EXECUTE $sql$
      UPDATE public."QuoteLines"
      SET
        sale_in_discount_pct = CASE
          WHEN net_price IS NOT NULL AND msrp IS NOT NULL AND msrp > 0
            THEN ROUND((1 - net_price / NULLIF(msrp, 0)) * 100, 2)
          WHEN discount_pct IS NOT NULL
            THEN ROUND(discount_pct * 100, 2)
          ELSE 35.00
        END,
        unit_sale_in_price_snapshot = CASE
          WHEN COALESCE(quantity, 0) <= 0 THEN NULL
          WHEN net_price IS NOT NULL AND quantity > 0
            THEN ROUND(net_price / NULLIF(quantity, 0), 4)
          WHEN msrp IS NOT NULL AND quantity > 0
            THEN ROUND((msrp / NULLIF(quantity, 0)) * (1 - COALESCE(discount_pct, 0.35)), 4)
          ELSE NULL
        END,
        sale_in_total = CASE
          WHEN net_price IS NOT NULL THEN ROUND(net_price, 2)
          WHEN msrp IS NOT NULL     THEN ROUND(msrp * (1 - COALESCE(discount_pct, 0.35)), 2)
          ELSE NULL
        END
      WHERE unit_sale_in_price_snapshot IS NULL
        AND (msrp IS NOT NULL OR net_price IS NOT NULL)
        AND quantity IS NOT NULL AND quantity > 0
    $sql$;
  ELSIF v_has_discount_pct THEN
    -- BD sin net_price pero con discount_pct
    EXECUTE $sql$
      UPDATE public."QuoteLines"
      SET
        sale_in_discount_pct = CASE
          WHEN discount_pct IS NOT NULL THEN ROUND(discount_pct * 100, 2)
          ELSE 35.00
        END,
        unit_sale_in_price_snapshot = CASE
          WHEN COALESCE(quantity, 0) <= 0 THEN NULL
          WHEN msrp IS NOT NULL AND quantity > 0
            THEN ROUND((msrp / NULLIF(quantity, 0)) * (1 - COALESCE(discount_pct, 0.35)), 4)
          ELSE NULL
        END,
        sale_in_total = CASE
          WHEN msrp IS NOT NULL THEN ROUND(msrp * (1 - COALESCE(discount_pct, 0.35)), 2)
          ELSE NULL
        END
      WHERE unit_sale_in_price_snapshot IS NULL
        AND msrp IS NOT NULL
        AND quantity IS NOT NULL AND quantity > 0
    $sql$;
  ELSE
    -- BD sin net_price ni discount_pct (esquema limpio post-deprecación)
    -- Usar 35% (Bronze) como descuento por defecto
    UPDATE public."QuoteLines"
    SET
      sale_in_discount_pct        = 35.00,
      unit_sale_in_price_snapshot = CASE
        WHEN COALESCE(quantity, 0) <= 0 THEN NULL
        WHEN msrp IS NOT NULL AND quantity > 0
          THEN ROUND((msrp / NULLIF(quantity, 0)) * 0.65, 4)
        ELSE NULL
      END,
      sale_in_total = CASE
        WHEN msrp IS NOT NULL THEN ROUND(msrp * 0.65, 2)
        ELSE NULL
      END
    WHERE unit_sale_in_price_snapshot IS NULL
      AND msrp IS NOT NULL
      AND quantity IS NOT NULL AND quantity > 0;
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 3) CHECK constraint (tolerancia, NOT VALID → VALIDATE)
-- ----------------------------------------------------------------------------
ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_sale_in_coherent;

ALTER TABLE public."QuoteLines"
  ADD CONSTRAINT chk_quotelines_sale_in_coherent
  CHECK (
    (unit_sale_in_price_snapshot IS NULL AND sale_in_total IS NULL)
    OR (
      quantity > 0
      AND unit_sale_in_price_snapshot IS NOT NULL
      AND sale_in_total IS NOT NULL
      AND abs(sale_in_total - (unit_sale_in_price_snapshot * quantity)) <= 0.01
    )
  ) NOT VALID;

ALTER TABLE public."QuoteLines" VALIDATE CONSTRAINT chk_quotelines_sale_in_coherent;

-- ----------------------------------------------------------------------------
-- 4) Extender trigger para bloquear escritura directa a las nuevas columnas
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_quote_lines_allow_pricing_write_only_via_rpc()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_setting('app.write_source', true) = 'rpc' THEN
    RETURN NEW;
  END IF;

  -- Pricing column set completo (incluyendo sale-in columns)
  IF OLD.roll_msrp_snapshot            IS DISTINCT FROM NEW.roll_msrp_snapshot
     OR OLD.bom_msrp_snapshot          IS DISTINCT FROM NEW.bom_msrp_snapshot
     OR OLD.roll_cost_snapshot         IS DISTINCT FROM NEW.roll_cost_snapshot
     OR OLD.bom_cost_snapshot          IS DISTINCT FROM NEW.bom_cost_snapshot
     OR OLD.msrp                       IS DISTINCT FROM NEW.msrp
     OR OLD.total_cost                 IS DISTINCT FROM NEW.total_cost
     OR OLD.unit_msrp_total_snapshot   IS DISTINCT FROM NEW.unit_msrp_total_snapshot
     OR OLD.unit_cost_total_snapshot   IS DISTINCT FROM NEW.unit_cost_total_snapshot
     OR OLD.unit_sale_in_price_snapshot IS DISTINCT FROM NEW.unit_sale_in_price_snapshot
     OR OLD.sale_in_total              IS DISTINCT FROM NEW.sale_in_total
     OR OLD.sale_in_discount_pct       IS DISTINCT FROM NEW.sale_in_discount_pct
     OR OLD.pricing_version            IS DISTINCT FROM NEW.pricing_version
     OR OLD.last_priced_at             IS DISTINCT FROM NEW.last_priced_at
  THEN
    RAISE EXCEPTION
      'QuoteLines: pricing/snapshot columns (including sale_in) can only be written via '
      'commit_configured_product_to_quote_line or sync_quote_line_pricing_from_configured_product '
      '(set app.write_source=rpc). Columnas protegidas: msrp, total_cost, unit_msrp_total_snapshot, '
      'unit_cost_total_snapshot, unit_sale_in_price_snapshot, sale_in_total, sale_in_discount_pct, '
      'roll/bom snapshots, pricing_version, last_priced_at.';
  END IF;

  RETURN NEW;
END;
$$;

-- El trigger ya existe; recrearlo en la tabla asegura la función actualizada
DROP TRIGGER IF EXISTS trg_quote_lines_pricing_write_via_rpc_only ON public."QuoteLines";
CREATE TRIGGER trg_quote_lines_pricing_write_via_rpc_only
  BEFORE UPDATE ON public."QuoteLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_quote_lines_allow_pricing_write_only_via_rpc();

-- ----------------------------------------------------------------------------
-- 5) Actualizar commit_configured_product_to_quote_line
--    Lee el tier del dealer del Quote → DealerTiers → discount_pct
--    Calcula unit_sale_in_price_snapshot y sale_in_total
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
  -- Sale-In
  v_effective_dealer_id uuid;
  v_dealer_tier_id  uuid;
  v_discount_pct    numeric(5,2);
  v_unit_sale_in    numeric(12,4);
BEGIN
  IF p_org_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_org_id is required'; END IF;
  IF p_quote_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_quote_id is required'; END IF;
  IF p_configured_product_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_configured_product_id is required'; END IF;

  -- 1. Recalcular CP
  PERFORM public.calculate_configured_product_totals(p_configured_product_id);

  -- 2. Leer CP
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

  -- 3. Leer dealer_id efectivo (parámetro o el del Quote)
  v_effective_dealer_id := COALESCE(
    p_dealer_id,
    (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)
  );

  -- 4. Obtener tier del dealer → discount_pct (snapshot)
  --    Si no hay DealerTiers o dealer sin tier → 35% (Bronze por defecto)
  SELECT d.dealer_tier_id INTO v_dealer_tier_id
  FROM public."Dealers" d
  WHERE d.id = v_effective_dealer_id
  LIMIT 1;

  SELECT COALESCE(dt.discount_pct, 35)
  INTO v_discount_pct
  FROM public."DealerTiers" dt
  WHERE dt.id = v_dealer_tier_id
  LIMIT 1;

  IF v_discount_pct IS NULL THEN
    v_discount_pct := 35; -- Bronze por defecto
  END IF;

  -- 5. Calcular Sale-In snapshot
  v_unit_sale_in := ROUND(v_unit_msrp * (1 - v_discount_pct / 100.0), 4);

  -- 6. Leer item del roll/fabric
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

  -- 7. Insertar QuoteLine con todos los snapshots
  PERFORM set_config('app.write_source', 'rpc', true);

  INSERT INTO public."QuoteLines" (
    organization_id, quote_id, dealer_id,
    configured_product_id, bom_template_id,
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer,
    collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity,
    hardware_color, drive_type, position, area, fabric_drop,
    -- Snapshots MSRP y costo
    roll_msrp_snapshot, bom_msrp_snapshot,
    roll_cost_snapshot, bom_cost_snapshot,
    unit_msrp_total_snapshot, unit_cost_total_snapshot,
    msrp, total_cost,
    -- Snapshots Sale-In (Dealer price)
    unit_sale_in_price_snapshot, sale_in_total, sale_in_discount_pct,
    -- Auditoría
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
    -- MSRP snapshots
    COALESCE(v_cp.roll_msrp_total, 0), COALESCE(v_cp.bom_total, 0),
    COALESCE(v_cp.roll_total_cost_landed, 0), COALESCE(v_cp.bom_total_cost_landed, 0),
    v_unit_msrp, v_unit_cost,
    ROUND(v_unit_msrp * v_line_quantity, 2),
    ROUND(v_unit_cost * v_line_quantity, 2),
    -- Sale-In snapshots
    v_unit_sale_in,
    ROUND(v_unit_sale_in * v_line_quantity, 2),
    v_discount_pct,
    -- Auditoría
    true, now(), 1,
    v_product_type_code, v_cp.product_type_id
  )
  RETURNING id INTO v_quote_line_id;

  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- 6) Actualizar sync_quote_line_pricing_from_configured_product
--    Lee dealer/tier desde el Quote al momento del sync
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_quote_line_pricing_from_configured_product(p_quote_line_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql           RECORD;
  v_cp           RECORD;
  v_qty          numeric(12,4);
  v_unit_msrp    numeric(12,4);
  v_unit_cost    numeric(12,4);
  -- Sale-In
  v_dealer_tier_id uuid;
  v_discount_pct   numeric(5,2);
  v_unit_sale_in   numeric(12,4);
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

  v_qty       := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);
  v_unit_msrp := COALESCE(v_cp.total_msrp, 0);
  v_unit_cost := COALESCE(v_cp.unit_product_cost_landed, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  IF v_unit_cost = 0 THEN
    v_unit_cost :=
      COALESCE(v_cp.roll_total_cost_landed, 0)
      + COALESCE(v_cp.bom_total_cost_landed, 0)
      + COALESCE(v_cp.accessories_total_cost_landed, 0)
      + COALESCE(v_cp.unit_labor_cost, 0);
  END IF;

  -- Dealer tier desde el Quote → Dealer → DealerTiers
  SELECT d.dealer_tier_id INTO v_dealer_tier_id
  FROM public."Quotes" q
  JOIN public."Dealers" d ON d.id = q.dealer_id
  WHERE q.id = v_ql.quote_id
  LIMIT 1;

  SELECT COALESCE(dt.discount_pct, 35)
  INTO v_discount_pct
  FROM public."DealerTiers" dt
  WHERE dt.id = v_dealer_tier_id
  LIMIT 1;

  IF v_discount_pct IS NULL THEN
    v_discount_pct := 35;
  END IF;

  v_unit_sale_in := ROUND(v_unit_msrp * (1 - v_discount_pct / 100.0), 4);

  PERFORM set_config('app.write_source', 'rpc', true);

  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot         = COALESCE(v_cp.roll_msrp_total, 0),
    bom_msrp_snapshot          = COALESCE(v_cp.bom_total, 0),
    roll_cost_snapshot         = COALESCE(v_cp.roll_total_cost_landed, 0),
    bom_cost_snapshot          = COALESCE(v_cp.bom_total_cost_landed, 0),
    unit_msrp_total_snapshot   = v_unit_msrp,
    unit_cost_total_snapshot   = v_unit_cost,
    msrp                       = ROUND(v_unit_msrp * v_qty, 2),
    total_cost                 = ROUND(v_unit_cost * v_qty, 2),
    unit_sale_in_price_snapshot = v_unit_sale_in,
    sale_in_total               = ROUND(v_unit_sale_in * v_qty, 2),
    sale_in_discount_pct        = v_discount_pct,
    last_priced_at             = now(),
    pricing_version            = COALESCE(pricing_version, 0) + 1,
    pricing_locked             = true
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- 7) Comentarios finales
-- ----------------------------------------------------------------------------
COMMENT ON FUNCTION public.commit_configured_product_to_quote_line(uuid, uuid, uuid, uuid, text, text, text, text, text) IS
'Creates QuoteLine from ConfiguredProduct. Snapshots: MSRP (unit_msrp_total_snapshot, msrp), Cost (unit_cost_total_snapshot, total_cost), Sale-In/Dealer (unit_sale_in_price_snapshot, sale_in_total, sale_in_discount_pct). Single write-path.';

COMMENT ON FUNCTION public.sync_quote_line_pricing_from_configured_product(uuid) IS
'Refreshes QuoteLine pricing from ConfiguredProduct. No-op if pricing_locked. Updates MSRP, Cost and Sale-In snapshots. Reads dealer tier from Quote.dealer_id at sync time.';

-- ============================================================================
-- PRICING COLUMN SET ACTUALIZADO (para referencia del equipo)
-- ============================================================================
-- Totales de línea:        msrp, total_cost
-- Snapshots canónicos:     unit_msrp_total_snapshot, unit_cost_total_snapshot
-- Snapshots Sale-In:       unit_sale_in_price_snapshot, sale_in_total, sale_in_discount_pct  ← NUEVOS
-- Snapshots por rubro:     roll_msrp_snapshot, bom_msrp_snapshot, roll_cost_snapshot, bom_cost_snapshot
-- Auditoría:               pricing_version, last_priced_at
-- ============================================================================
