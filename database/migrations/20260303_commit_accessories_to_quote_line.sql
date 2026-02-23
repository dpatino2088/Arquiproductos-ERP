-- ============================================================================
-- Migración: commit_accessories_to_quote_line
-- Fecha: 2026-03-03
--
-- Objetivo: crear un RPC canónico para guardar una línea de solo-accesorios
-- en QuoteLines, siguiendo las mismas reglas que commit_configured_product_to_quote_line:
--
--   1. Los accesorios tienen precio en CatalogItemsMSRP (msrp, dealer_price, total_cost).
--   2. El MSRP de la línea = suma(accesorio.msrp × qty) → unit_msrp_total_snapshot = msrp/1.
--   3. El costo = suma(accesorio.total_cost × qty) → unit_cost_total_snapshot = cost/1.
--   4. Sale-In = MSRP × (1 - tier_discount) → unit_sale_in_price_snapshot, sale_in_total.
--   5. Se escribe vía set_config('app.write_source','rpc') para pasar el trigger.
--   6. No hay width/height/fabric/BOM: es solo-accesorios.
--   7. Area y Position vienen como parámetros opcionales.
--
-- Flujo correcto:
--   Accessories step → commit_accessories_to_quote_line() → QuoteLine con snapshots canónicos
-- ============================================================================

-- ============================================================================
-- RPC: commit_accessories_to_quote_line
-- Crea UNA QuoteLine POR accesorio (no agrupa todo en una sola línea).
-- Cada línea tiene: nombre del accesorio, qty, MSRP real (CatalogItemsMSRP),
-- costo, y precio al dealer con snapshot del tier.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.commit_accessories_to_quote_line(
  p_org_id      uuid,
  p_quote_id    uuid,
  -- Array JSONB: [{catalog_item_id, qty, name (opcional)}]
  p_accessories jsonb,
  p_area        text DEFAULT NULL,
  p_position    text DEFAULT NULL
)
RETURNS TABLE(quote_line_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dealer_id         uuid;
  v_dealer_tier_id    uuid;
  v_discount_pct      numeric(5,2);
  v_item              RECORD;
  v_msrp_row          RECORD;
  v_item_name         text;
  v_item_sku          text;
  v_unit_msrp         numeric(12,4);
  v_unit_cost         numeric(12,4);
  v_unit_sale_in      numeric(12,4);
  v_line_msrp         numeric(12,4);
  v_line_cost         numeric(12,4);
  v_line_sale_in      numeric(12,4);
  v_item_qty          numeric(12,4);
  v_new_line_id       uuid;
BEGIN
  IF p_org_id IS NULL THEN
    RAISE EXCEPTION 'commit_accessories_to_quote_line: p_org_id is required';
  END IF;
  IF p_quote_id IS NULL THEN
    RAISE EXCEPTION 'commit_accessories_to_quote_line: p_quote_id is required';
  END IF;
  IF p_accessories IS NULL OR jsonb_array_length(p_accessories) = 0 THEN
    RAISE EXCEPTION 'commit_accessories_to_quote_line: p_accessories must be a non-empty array';
  END IF;

  -- 1. Dealer del Quote
  SELECT dealer_id INTO v_dealer_id
  FROM public."Quotes"
  WHERE id = p_quote_id
  LIMIT 1;

  -- 2. Tier → discount_pct (Bronze 35% por defecto)
  SELECT d.dealer_tier_id INTO v_dealer_tier_id
  FROM public."Dealers" d
  WHERE d.id = v_dealer_id
  LIMIT 1;

  SELECT COALESCE(dt.discount_pct, 35)
  INTO v_discount_pct
  FROM public."DealerTiers" dt
  WHERE dt.id = v_dealer_tier_id
  LIMIT 1;

  IF v_discount_pct IS NULL THEN v_discount_pct := 35; END IF;

  -- 3. Por cada accesorio → una QuoteLine individual
  PERFORM set_config('app.write_source', 'rpc', true);

  FOR v_item IN
    SELECT
      (elem->>'catalog_item_id')::uuid                AS catalog_item_id,
      GREATEST(1, COALESCE((elem->>'qty')::int, 1))  AS qty,
      COALESCE(elem->>'name', '')                     AS name_override
    FROM jsonb_array_elements(p_accessories) AS elem
  LOOP
    v_item_qty := v_item.qty;

    -- Leer nombre y SKU del catálogo
    SELECT
      COALESCE(ci.item_name, ci.name, 'Accessory'),
      COALESCE(ci.sku, '')
    INTO v_item_name, v_item_sku
    FROM public."CatalogItems" ci
    WHERE ci.id = v_item.catalog_item_id
    LIMIT 1;

    IF v_item.name_override <> '' THEN
      v_item_name := v_item.name_override;
    END IF;

    -- Leer MSRP y costo unitario desde CatalogItemsMSRP
    SELECT cm.msrp, cm.total_cost
    INTO v_msrp_row
    FROM public."CatalogItemsMSRP" cm
    WHERE cm.catalog_item_id = v_item.catalog_item_id
      AND cm.organization_id = p_org_id
    LIMIT 1;

    IF v_msrp_row IS NULL THEN
      -- Fallback si no existe en CatalogItemsMSRP
      SELECT COALESCE(ci.cost_exw * 1.5, 0), COALESCE(ci.cost_exw, 0)
      INTO v_unit_msrp, v_unit_cost
      FROM public."CatalogItems" ci
      WHERE ci.id = v_item.catalog_item_id
      LIMIT 1;
      IF v_unit_msrp IS NULL THEN v_unit_msrp := 0; END IF;
      IF v_unit_cost IS NULL THEN v_unit_cost := 0; END IF;
    ELSE
      v_unit_msrp := COALESCE(v_msrp_row.msrp, 0);
      v_unit_cost := COALESCE(v_msrp_row.total_cost, 0);
    END IF;

    -- Totales de línea = precio unitario × cantidad
    v_line_msrp    := ROUND(v_unit_msrp * v_item_qty, 2);
    v_line_cost    := ROUND(v_unit_cost * v_item_qty, 2);
    v_unit_sale_in := ROUND(v_unit_msrp * (1 - v_discount_pct / 100.0), 4);
    v_line_sale_in := ROUND(v_unit_sale_in * v_item_qty, 2);

    -- Insertar QuoteLine individual
    INSERT INTO public."QuoteLines" (
      organization_id,
      quote_id,
      dealer_id,
      product_type,
      configured_product_id,
      name,
      sku,
      quantity,
      area,
      position,
      -- Snapshots canónicos
      unit_msrp_total_snapshot,
      unit_cost_total_snapshot,
      msrp,
      total_cost,
      -- Sale-In snapshots
      unit_sale_in_price_snapshot,
      sale_in_total,
      sale_in_discount_pct,
      -- Auditoría
      pricing_locked,
      last_priced_at,
      pricing_version
    )
    VALUES (
      p_org_id,
      p_quote_id,
      v_dealer_id,
      'accessories',
      NULL,
      v_item_name,
      v_item_sku,
      v_item_qty,
      p_area,
      p_position,
      -- unit = precio por unidad; line = precio × qty
      v_unit_msrp,
      v_unit_cost,
      v_line_msrp,
      v_line_cost,
      v_unit_sale_in,
      v_line_sale_in,
      v_discount_pct,
      false,
      now(),
      1
    )
    RETURNING id INTO v_new_line_id;

    RETURN NEXT v_new_line_id;  -- devuelve una fila por accesorio
  END LOOP;
END;
$$;

COMMENT ON FUNCTION public.commit_accessories_to_quote_line(uuid, uuid, jsonb, text, text) IS
'Crea UNA QuoteLine por cada accesorio en p_accessories.
Lee MSRP y costo de CatalogItemsMSRP. Aplica descuento del tier del dealer.
Snapshots: unit_msrp_total_snapshot, unit_cost_total_snapshot, unit_sale_in_price_snapshot.
p_accessories: [{catalog_item_id: uuid, qty: int, name: text (opcional)}]';

GRANT EXECUTE ON FUNCTION public.commit_accessories_to_quote_line(uuid, uuid, jsonb, text, text)
  TO authenticated, service_role, anon;
