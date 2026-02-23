-- ============================================================================
-- Fix urgente: commit_configured_product_to_quote_line no guardaba product_type_id
-- Fecha: 2026-03-04
--
-- Problema: el INSERT en QuoteLines escribía product_type (text/code) pero
-- omitía product_type_id (uuid), que es la FK a ProductTypes y es esencial
-- para BOM, manufacturing y resolución de plantillas.
--
-- Solución: añadir product_type_id al INSERT del RPC, leyendo v_cp.product_type_id
-- que ya estaba disponible (ConfiguredProducts.product_type_id).
--
-- También: backfill de product_type_id para líneas existentes que tengan
-- configured_product_id (las más recientes).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Backfill product_type_id en QuoteLines existentes que lo tengan NULL
--    y que tengan un configured_product_id válido
-- ----------------------------------------------------------------------------
UPDATE public."QuoteLines" ql
SET product_type_id = cp.product_type_id
FROM public."ConfiguredProducts" cp
WHERE ql.configured_product_id = cp.id
  AND ql.product_type_id IS NULL
  AND cp.product_type_id IS NOT NULL;

-- Para líneas sin configured_product_id pero con product_type (text code), intentar resolver
UPDATE public."QuoteLines" ql
SET product_type_id = pt.id
FROM public."ProductTypes" pt
WHERE ql.product_type_id IS NULL
  AND ql.configured_product_id IS NULL
  AND ql.product_type IS NOT NULL
  AND pt.code = ql.product_type
  AND pt.organization_id = ql.organization_id;

-- ----------------------------------------------------------------------------
-- 2) Reemplazar el RPC con la versión que incluye product_type_id
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.commit_configured_product_to_quote_line(
  p_org_id      uuid,
  p_quote_id    uuid,
  p_configured_product_id uuid,
  p_dealer_id   uuid DEFAULT NULL,
  p_position    text DEFAULT NULL,
  p_area        text DEFAULT NULL,
  p_fabric_drop text DEFAULT NULL,
  p_installation_type     text DEFAULT NULL,
  p_installation_location text DEFAULT NULL
)
RETURNS TABLE(quote_line_id uuid, bom_instance_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cp                RECORD;
  v_roll_item         RECORD;
  v_quote_line_id     uuid;
  v_bom_instance_id   uuid;
  v_width_m           numeric(12,4);
  v_height_m          numeric(12,4);
  v_line_quantity     numeric(12,4);
  v_operating_type    text;
  v_unit_msrp         numeric(12,4);
  v_unit_cost         numeric(12,4);
  v_product_type_code text;
  -- Dealer tier / Sale-In
  v_effective_dealer_id uuid;
  v_dealer_tier_id    uuid;
  v_discount_pct      numeric(5,2);
  v_unit_sale_in      numeric(12,4);
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

  -- 3. product_type code (para la columna text)
  SELECT pt.code INTO v_product_type_code
  FROM public."ProductTypes" pt
  WHERE pt.id = v_cp.product_type_id
  LIMIT 1;

  -- 4. Dealer + tier + discount para Sale-In snapshot
  v_effective_dealer_id := COALESCE(
    p_dealer_id,
    (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)
  );
  SELECT d.dealer_tier_id INTO v_dealer_tier_id
  FROM public."Dealers" d
  WHERE d.id = v_effective_dealer_id LIMIT 1;

  SELECT COALESCE(dt.discount_pct, 35)
  INTO v_discount_pct
  FROM public."DealerTiers" dt
  WHERE dt.id = v_dealer_tier_id LIMIT 1;

  IF v_discount_pct IS NULL THEN v_discount_pct := 35; END IF;

  v_unit_sale_in := ROUND(v_unit_msrp * (1 - v_discount_pct / 100.0), 4);

  -- 5. Leer item del roll/fabric
  SELECT ci.sku, ci.name, ci.category_id, ci.manufacturer_id, m.name AS manufacturer_name,
         ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_m
  INTO v_roll_item
  FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id
    AND ci.is_active = true
  LIMIT 1;

  -- 6. Insertar QuoteLine con product_type_id
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
    unit_sale_in_price_snapshot, sale_in_total, sale_in_discount_pct,
    pricing_locked, last_priced_at, pricing_version,
    product_type, product_type_id          -- ← CRÍTICO: ambas columnas
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
    COALESCE(v_cp.roll_msrp_total, 0),   COALESCE(v_cp.bom_total, 0),
    COALESCE(v_cp.roll_total_cost_landed, 0), COALESCE(v_cp.bom_total_cost_landed, 0),
    v_unit_msrp, v_unit_cost,
    ROUND(v_unit_msrp * v_line_quantity, 2),
    ROUND(v_unit_cost * v_line_quantity, 2),
    v_unit_sale_in,
    ROUND(v_unit_sale_in * v_line_quantity, 2),
    v_discount_pct,
    true, now(), 1,
    v_product_type_code, v_cp.product_type_id   -- ← product_type (text) + product_type_id (uuid)
  )
  RETURNING id INTO v_quote_line_id;

  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;

COMMENT ON FUNCTION public.commit_configured_product_to_quote_line(uuid, uuid, uuid, uuid, text, text, text, text, text) IS
'Creates QuoteLine from ConfiguredProduct. Writes product_type (text code) AND product_type_id (uuid FK). '
'Also writes Sale-In snapshots (unit_sale_in_price_snapshot, sale_in_total, sale_in_discount_pct). Single write-path.';

GRANT EXECUTE ON FUNCTION public.commit_configured_product_to_quote_line(uuid, uuid, uuid, uuid, text, text, text, text, text)
  TO authenticated, service_role, anon;
