-- ============================================================================
-- Fix: create_configured_product_and_bom_preview debe persistir TODAS las
-- columnas de pricing en ConfiguredProducts inmediatamente (no solo el JSON)
-- Fecha: 2026-03-05
--
-- Problema raíz:
--   El flujo actual hace:
--     1. INSERT ConfiguredProduct → todos los totales en 0
--     2. build_bom_preview_snapshot() → guarda JSON en bom_preview_snapshot
--     3. NO llama calculate_configured_product_totals()
--   Resultado: columnas bom_total, roll_msrp_total, unit_msrp_total, etc. = 0
--   El ReviewStep lee del JSON (bom_preview_snapshot.totals) → $151.82 visible
--   pero los valores no están en columnas auditables de la BD.
--
-- Fix:
--   Después de build_bom_preview_snapshot(), llamar calculate_configured_product_totals()
--   para que lea el snapshot recién generado y persista todos los valores en columnas.
--
-- Columnas que deben tener valores tras la creación:
--   roll_msrp_total, bom_total, accessories_total, labor_amount, total_msrp
--   msrp_product_subtotal, labor_msrp, unit_msrp_total
--   roll_total_cost_landed, bom_total_cost_landed, accessories_total_cost_landed
--   unit_product_cost_landed, unit_labor_cost
--   total_cost_landed_without_labor, total_cost_with_labor
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_configured_product_and_bom_preview(
  p_org_id          uuid,
  p_product_type_id uuid,
  p_config_snapshot jsonb,
  p_quote_id        uuid DEFAULT NULL,
  p_quote_line_id   uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_configured_product_id uuid;
  v_bom_template_id       uuid;
  v_preview_snapshot      jsonb;
  v_totals_after          jsonb;
  v_hardware_color        text;
  v_fabric_item_id        uuid;
  v_width_mm              numeric(12,4);
  v_height_mm             numeric(12,4);
  v_quantity              numeric(12,4);
  v_roll_sku              text;
  v_roll_collection_name  text;
  v_roll_variant_name     text;
  v_roll_width            numeric(12,4);
  v_labor_pct             numeric(12,4);
BEGIN
  -- Bloquear claves OneOff
  PERFORM public.reject_oneoff_keys(p_config_snapshot);

  -- Labor % desde CostSettings
  SELECT COALESCE(cs.labor_pct, 0)
  INTO v_labor_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_org_id
  LIMIT 1;

  IF v_labor_pct IS NULL THEN v_labor_pct := 0; END IF;

  -- Resolver BOM template
  v_bom_template_id := (p_config_snapshot->>'bom_template_id')::uuid;

  IF v_bom_template_id IS NULL THEN
    BEGIN
      SELECT public.select_best_bom_template_v2_strict(
        p_org_id,
        p_product_type_id,
        p_config_snapshot
      ) INTO v_bom_template_id;
    EXCEPTION WHEN OTHERS THEN
      v_bom_template_id := NULL;
    END;
  END IF;

  IF v_bom_template_id IS NULL THEN
    RAISE EXCEPTION 'No matching BOMTemplate found for product_type_id=% with config=%',
      p_product_type_id, p_config_snapshot::text;
  END IF;

  -- Hardware color
  v_hardware_color := COALESCE(
    p_config_snapshot->>'hardware_color',
    p_config_snapshot->>'hardwareColor'
  );

  -- Fabric / roll item
  v_fabric_item_id := (p_config_snapshot->>'variantId')::uuid;
  IF v_fabric_item_id IS NULL THEN
    v_fabric_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid;
  END IF;

  -- Dimensiones (soporte multi-panel: measurements.width_total_mm)
  v_width_mm := COALESCE(
    (p_config_snapshot->'measurements'->>'width_total_mm')::numeric(12,4),
    (p_config_snapshot->>'width_mm')::numeric(12,4)
  );
  v_height_mm  := (p_config_snapshot->>'height_mm')::numeric(12,4);
  v_quantity   := COALESCE((p_config_snapshot->>'quantity')::numeric(12,4), 1);

  IF v_fabric_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.collection_name, ci.variant_name, ci.roll_width
    INTO v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width
    FROM public."CatalogItems" ci
    WHERE ci.id = v_fabric_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;
  END IF;

  -- ── PASO 1: Insertar ConfiguredProduct ────────────────────────────────────
  INSERT INTO public."ConfiguredProducts" (
    organization_id,
    quote_id,
    bom_template_id,
    product_type_id,
    width_mm,
    height_mm,
    quantity,
    hardware_color,
    roll_catalog_item_id,
    roll_sku,
    roll_collection_name,
    roll_variant_name,
    roll_width,
    config_snapshot,
    labor_pct,
    -- Totales iniciales en 0; se rellenan en pasos 2-3
    roll_msrp_total, bom_total, accessories_total, total_msrp
  )
  VALUES (
    p_org_id,
    p_quote_id,
    v_bom_template_id,
    p_product_type_id,
    v_width_mm,
    v_height_mm,
    v_quantity,
    v_hardware_color,
    v_fabric_item_id,
    v_roll_sku,
    v_roll_collection_name,
    v_roll_variant_name,
    v_roll_width,
    p_config_snapshot,
    v_labor_pct,
    0, 0, 0, 0
  )
  RETURNING id INTO v_configured_product_id;

  -- ── PASO 2: Construir BOM snapshot (detalle de líneas del BOM) ─────────────
  v_preview_snapshot := public.build_bom_preview_snapshot(
    p_org_id,
    v_configured_product_id,
    v_bom_template_id
  );

  UPDATE public."ConfiguredProducts"
  SET bom_preview_snapshot = v_preview_snapshot,
      updated_at           = now()
  WHERE id = v_configured_product_id
    AND organization_id = p_org_id;

  -- ── PASO 3: CRÍTICO — Calcular y persistir TODOS los totales en columnas ───
  --   Lee el bom_preview_snapshot recién guardado y persiste:
  --   roll_msrp_total, bom_total, accessories_total, labor_amount, total_msrp,
  --   msrp_product_subtotal, labor_msrp, unit_msrp_total,
  --   roll_total_cost_landed, bom_total_cost_landed, accessories_total_cost_landed,
  --   unit_product_cost_landed, unit_labor_cost,
  --   total_cost_landed_without_labor, total_cost_with_labor
  PERFORM public.calculate_configured_product_totals(v_configured_product_id);

  -- ── PASO 4: Leer los totales ya persistidos para devolverlos al frontend ───
  SELECT
    jsonb_build_object(
      'roll_msrp_total',                cp.roll_msrp_total,
      'bom_total',                      cp.bom_total,
      'accessories_total',              cp.accessories_total,
      'labor_amount',                   cp.labor_amount,
      'total_msrp',                     cp.total_msrp,
      'msrp_product_subtotal',          cp.msrp_product_subtotal,
      'labor_msrp',                     cp.labor_msrp,
      'unit_msrp_total',                cp.unit_msrp_total,
      'roll_total_cost_landed',         cp.roll_total_cost_landed,
      'bom_total_cost_landed',          cp.bom_total_cost_landed,
      'accessories_total_cost_landed',  cp.accessories_total_cost_landed,
      'unit_product_cost_landed',       cp.unit_product_cost_landed,
      'unit_labor_cost',                cp.unit_labor_cost,
      'total_cost_landed_without_labor',cp.total_cost_landed_without_labor,
      'total_cost_with_labor',          cp.total_cost_with_labor
    )
  INTO v_totals_after
  FROM public."ConfiguredProducts" cp
  WHERE cp.id = v_configured_product_id;

  -- Releer snapshot actualizado (calculate_configured_product_totals actualiza bom_preview_snapshot.totals)
  SELECT bom_preview_snapshot
  INTO v_preview_snapshot
  FROM public."ConfiguredProducts"
  WHERE id = v_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id', v_configured_product_id,
    'bom_instance_id',       NULL,
    'bom_template_id',       v_bom_template_id,
    'totals',                v_totals_after,       -- ← desde columnas reales
    'bom_preview_snapshot',  v_preview_snapshot    -- ← JSON completo con líneas de BOM
  );
END;
$$;

COMMENT ON FUNCTION public.create_configured_product_and_bom_preview(uuid, uuid, jsonb, uuid, uuid) IS
'Crea ConfiguredProduct en 3 pasos:
1. INSERT con datos básicos (totales en 0).
2. build_bom_preview_snapshot() → persiste JSON con desglose de líneas BOM.
3. calculate_configured_product_totals() → lee el snapshot y persiste TODOS los totales
   en columnas auditables (roll_msrp_total, bom_total, unit_msrp_total, costos, etc.).
El resultado devuelve totales leídos de columnas reales, no de cálculos en el frontend.';

GRANT EXECUTE ON FUNCTION public.create_configured_product_and_bom_preview(uuid, uuid, jsonb, uuid, uuid)
  TO authenticated, service_role, anon;

-- ============================================================================
-- BACKFILL: recalcular todos los ConfiguredProducts que tengan bom_preview_snapshot
-- pero columnas de totales en 0 (creados antes de este fix)
-- ============================================================================
DO $$
DECLARE
  v_id uuid;
  v_count int := 0;
BEGIN
  FOR v_id IN
    SELECT id
    FROM public."ConfiguredProducts"
    WHERE deleted = false
      AND bom_preview_snapshot IS NOT NULL
      AND bom_preview_snapshot <> '{}'::jsonb
      AND bom_preview_snapshot->>'version' = '1'
      AND (
        COALESCE(unit_msrp_total, 0) = 0
        OR COALESCE(bom_total, 0) = 0
        OR COALESCE(roll_msrp_total, 0) = 0
      )
  LOOP
    PERFORM public.calculate_configured_product_totals(v_id);
    v_count := v_count + 1;
  END LOOP;

  RAISE NOTICE 'Backfill complete: % ConfiguredProducts recalculados.', v_count;
END $$;
