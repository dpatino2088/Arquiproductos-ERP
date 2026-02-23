-- ============================================================================
-- Fabric Pricing Basis — Organization-level global setting (FUTURE-ONLY)
-- Fecha: 2026-03-15
--
-- IMPORTANTE: No recalcula ConfiguredProducts existentes. Solo aplica al generar
-- un nuevo snapshot (nuevo CP o flujos normales de guardado/rebuild). No backfill.
--
-- PROPÓSITO: Permitir que la organización decida cómo mostrar tela en quotes:
--   auto  → usa roll_pricing_mode del CatalogItem (comportamiento anterior)
--   linear → fuerza metros lineales (m), convirtiendo unit_price si es necesario
--   sqm    → fuerza metros cuadrados (m²), convirtiendo unit_price si es necesario
--
-- SOLO afecta la capa DISPLAY (bom_preview_snapshot.items).
-- NO cambia costos, totals de calculate_configured_product_totals, ni landed cost.
--
-- INVARIANTE CLAVE: qty * unit_price = line_total SIEMPRE igual (solo se reexpresan)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PARTE A: Columna en CostSettings
-- ----------------------------------------------------------------------------
ALTER TABLE public."CostSettings"
  ADD COLUMN IF NOT EXISTS fabric_pricing_basis text NOT NULL DEFAULT 'auto';

ALTER TABLE public."CostSettings"
  DROP CONSTRAINT IF EXISTS costsettings_fabric_pricing_basis_chk;

ALTER TABLE public."CostSettings"
  ADD CONSTRAINT costsettings_fabric_pricing_basis_chk
  CHECK (fabric_pricing_basis IN ('auto', 'linear', 'sqm'));

COMMENT ON COLUMN public."CostSettings".fabric_pricing_basis IS
  'Display/quote basis for fabric rolls: auto (from roll_pricing_mode), linear (m), sqm (m²). Only affects bom_preview_snapshot display; does not change costs.';


-- ----------------------------------------------------------------------------
-- PARTE B: build_bom_preview_snapshot actualizado con pricing basis + conversión
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.build_bom_preview_snapshot(
  p_org_id uuid,
  p_configured_product_id uuid,
  p_bom_template_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_config jsonb;
  v_items jsonb := '[]'::jsonb;
  v_totals jsonb;
  v_comp RECORD;
  v_child RECORD;
  v_item_info RECORD;
  v_msrp_info RECORD;
  v_roll_msrp_unit numeric := 0;
  v_roll_dealer_unit numeric := 0;
  v_roll_labor_unit numeric := 0;
  v_qty numeric;
  v_unit_price numeric;
  v_line_total numeric;
  v_width_mm numeric;
  v_height_mm numeric;
  v_width_m numeric;
  v_height_m numeric;
  v_area_m2 numeric;
  v_roll_item jsonb;
  v_parent_items jsonb := '[]'::jsonb;
  v_children jsonb;
  v_item_id text;
  v_selected boolean;
  v_roll_msrp_total numeric;
  v_bom_sum numeric;
  v_labor_amount numeric;
  v_accessories_total numeric;
  v_total_msrp numeric;
  v_child_unit_price numeric;
  v_child_line_total numeric;
  v_roll_total_cost numeric;
  v_roll_factor numeric := 0;
  v_roll_qty numeric := 0;
  v_roll_width_effective numeric;
  v_width_total_m numeric;
  v_roll_pricing_mode text;
  v_roll_measure_basis text;
  v_roll_uom text := 'm²';
  -- Fabric Pricing Basis
  v_global_basis text := 'auto';      -- setting org: auto | linear | sqm
  v_msrp_source_uom text := 'm';      -- UOM en que está expresado el msrp (normalized to 'm' or 'm2')
  v_basis_effective text;             -- basis final aplicado (para auditoría en meta)
  v_meta_warning text;                -- warning cuando se degrada por falta de roll_width_m
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  v_config := COALESCE(v_cp.config_snapshot, '{}'::jsonb);

  v_width_mm := COALESCE(
    (v_config->'measurements'->>'width_total_mm')::numeric,
    v_cp.width_mm,
    0
  );
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_width_m := v_width_mm / 1000.0;
  v_height_m := v_height_mm / 1000.0;
  v_area_m2 := v_width_m * v_height_m;
  v_width_total_m := v_width_m;

  -- Leer setting global (fabric_pricing_basis) de la org
  SELECT COALESCE(cs.fabric_pricing_basis, 'auto')
  INTO v_global_basis
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_org_id
  LIMIT 1;

  IF v_global_basis IS NULL THEN
    v_global_basis := 'auto';
  END IF;

  -- ROLL: qty + unit_price + UOM según pricing basis + conversión
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT r.msrp, r.dealer_price, r.labor_msrp
    INTO v_roll_msrp_unit, v_roll_dealer_unit, v_roll_labor_unit
    FROM public.get_roll_pricing(p_org_id, v_cp.roll_catalog_item_id) r;

    -- Solo roll_width_m (evitar ci.roll_width legacy no normalizado)
    SELECT ci.sku, ci.name, ci.unit_of_measure,
           ci.roll_pricing_mode, ci.measure_basis,
           ci.roll_width_m AS roll_width_catalog
    INTO v_item_info
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;

    v_roll_width_effective := COALESCE(v_cp.roll_width, (v_item_info.roll_width_catalog)::numeric, 0);

    -- UOM fuente del msrp (de CatalogItemsMSRP.pricing_uom), normalizar a 'm' o 'm2'
    SELECT COALESCE(cim.pricing_uom, 'm')
    INTO v_msrp_source_uom
    FROM public."CatalogItemsMSRP" cim
    WHERE cim.catalog_item_id = v_cp.roll_catalog_item_id
      AND cim.organization_id = p_org_id
    ORDER BY cim.updated_at DESC NULLS LAST
    LIMIT 1;
    IF v_msrp_source_uom IS NULL THEN v_msrp_source_uom := 'm'; END IF;
    IF lower(replace(v_msrp_source_uom, '²', '2')) IN ('m2','sqm','sq_m','sqm2') THEN
      v_msrp_source_uom := 'm2';
    ELSE
      v_msrp_source_uom := 'm';
    END IF;

    v_meta_warning := NULL;

    -- ══════════════════════════════════════════════════════════════
    -- Basis efectivo = global setting, con excepciones:
    --   per_unit siempre gana (no tiene sentido convertirlo)
    --   sin roll_width_m no se puede convertir → degrade a source basis + meta.warning
    -- ══════════════════════════════════════════════════════════════
    IF COALESCE(v_item_info.roll_pricing_mode, '') = 'per_unit' THEN
      v_basis_effective := 'unit';

    ELSIF v_global_basis = 'linear'
      AND v_msrp_source_uom = 'm2'
      AND (v_roll_width_effective IS NULL OR v_roll_width_effective <= 0)
    THEN
      -- Queremos linear, fuente es $/m², no hay roll_width → degrade a sqm (source)
      v_basis_effective := 'sqm';
      v_meta_warning := 'Conversion to linear required roll_width_m; using source basis (m²).';

    ELSIF v_global_basis = 'sqm'
      AND v_msrp_source_uom = 'm'
      AND (v_roll_width_effective IS NULL OR v_roll_width_effective <= 0)
    THEN
      -- Queremos sqm, fuente es $/m, no hay roll_width → degrade a linear (source)
      v_basis_effective := 'linear';
      v_meta_warning := 'Conversion to sqm required roll_width_m; using source basis (m).';

    ELSIF v_global_basis = 'linear' THEN
      v_basis_effective := 'linear';

    ELSIF v_global_basis = 'sqm' THEN
      v_basis_effective := 'sqm';

    ELSE
      -- auto: usar roll_pricing_mode del item
      IF COALESCE(v_item_info.roll_pricing_mode, '') = 'per_linear_meter'
         OR COALESCE(v_item_info.measure_basis, '') = 'linear' THEN
        v_basis_effective := 'linear';
      ELSE
        v_basis_effective := 'sqm';
      END IF;
    END IF;

    -- ══════════════════════════════════════════════════════════════
    -- Calcular qty, uom, unit_price según basis efectivo
    -- Invariante: qty * unit_price = mismo total económico siempre
    -- ══════════════════════════════════════════════════════════════
    IF v_basis_effective = 'unit' THEN
      v_roll_factor := 1;
      v_roll_uom    := 'ea';
      v_unit_price  := COALESCE(v_roll_msrp_unit, 0);

    ELSIF v_basis_effective = 'linear' THEN
      -- Mostrar en metros lineales
      v_roll_factor := v_height_m;
      v_roll_uom    := 'm';
      -- Convertir unit_price si el msrp viene en $/m²
      IF COALESCE(v_msrp_source_uom,'') IN ('m2','m²')
         AND v_roll_width_effective > 0 THEN
        -- $/m² → $/m: multiplicar por roll_width
        v_unit_price := COALESCE(v_roll_msrp_unit, 0) * v_roll_width_effective;
      ELSE
        v_unit_price := COALESCE(v_roll_msrp_unit, 0);  -- ya está en $/m
      END IF;

    ELSE
      -- Mostrar en metros cuadrados (sqm o auto con per_square_meter/default)
      -- Área del producto = width × height (NO roll_width × height). Ej: 1.2×1.2 = 1.44 m²
      v_roll_factor := v_width_total_m * v_height_m;
      v_roll_uom := 'm²';
      -- Convertir unit_price si el msrp viene en $/m
      IF COALESCE(v_msrp_source_uom,'') = 'm'
         AND v_roll_width_effective > 0 THEN
        -- $/m → $/m²: dividir por roll_width
        v_unit_price := COALESCE(v_roll_msrp_unit, 0) / v_roll_width_effective;
      ELSE
        v_unit_price := COALESCE(v_roll_msrp_unit, 0);  -- ya está en $/m²
      END IF;
    END IF;

    v_roll_qty  := GREATEST(v_roll_factor, 0) * COALESCE(v_cp.quantity, 1);
    v_qty       := v_roll_qty;
    v_line_total := ROUND(v_qty * v_unit_price, 2);

    SELECT cim.total_cost INTO v_roll_total_cost
    FROM public."CatalogItemsMSRP" cim
    WHERE cim.catalog_item_id = v_cp.roll_catalog_item_id
      AND cim.organization_id = p_org_id
    ORDER BY cim.updated_at DESC NULLS LAST
    LIMIT 1;

    v_roll_item := jsonb_build_object(
      'id', COALESCE(v_cp.roll_catalog_item_id::text, 'roll:' || COALESCE(v_cp.roll_sku, 'unknown')),
      'kind', 'roll',
      'role', 'fabric',
      'level', 0,
      'selected', true,
      'catalog_item_id', v_cp.roll_catalog_item_id,
      'sku', v_cp.roll_sku,
      'name', COALESCE(v_cp.roll_variant_name, v_item_info.name, v_cp.roll_sku),
      'qty', ROUND(v_qty, 3),
      'uom', v_roll_uom,
      'unit_price', ROUND(v_unit_price, 4),
      'line_total', v_line_total,
      'children', '[]'::jsonb,
      'meta', jsonb_build_object(
        'collection_name', v_cp.roll_collection_name,
        'variant_name', v_cp.roll_variant_name,
        'roll_width', v_cp.roll_width,
        'roll_width_m', v_roll_width_effective,
        'roll_factor', v_roll_factor,
        'pricing_basis', v_basis_effective,
        'global_setting', v_global_basis,
        'msrp_source_uom', v_msrp_source_uom,
        'warning', v_meta_warning
      )
    );
    v_items := v_items || v_roll_item;
  ELSE
    v_roll_total_cost := 0;
  END IF;

  -- BOM: desde BOMComponents
  IF p_bom_template_id IS NOT NULL THEN
    FOR v_comp IN
      SELECT bc.id, bc.component_role, bc.component_item_id, bc.qty_type, bc.qty_value,
             bc.qty_delta_mm, bc.uom, bc.parent_component_id, bc.sort_order
      FROM public."BOMComponents" bc
      WHERE bc.bom_template_id = p_bom_template_id
        AND bc.organization_id = p_org_id
        AND bc.deleted = false
        AND bc.archived = false
        AND bc.parent_component_id IS NULL
      ORDER BY bc.sort_order ASC
    LOOP
      v_selected := false;
      DECLARE
        v_role_lower text := lower(COALESCE(v_comp.component_role, ''));
        v_selected_id uuid;
        v_config jsonb := COALESCE(v_cp.config_snapshot, '{}'::jsonb);
      BEGIN
        CASE v_role_lower
          WHEN 'bottom_bar'     THEN v_selected_id := public.try_parse_uuid(v_config->>'bottom_bar_item_id');
          WHEN 'headbox'        THEN v_selected_id := public.try_parse_uuid(v_config->>'headbox_item_id');
          WHEN 'side_channel'   THEN v_selected_id := public.try_parse_uuid(v_config->>'side_channel_item_id');
          WHEN 'bottom_channel' THEN v_selected_id := public.try_parse_uuid(v_config->>'bottom_channel_item_id');
          WHEN 'motor'          THEN v_selected_id := public.try_parse_uuid(v_config->>'motor_item_id');
          WHEN 'drive'          THEN v_selected_id := public.try_parse_uuid(v_config->>'drive_item_id');
          WHEN 'tube'           THEN v_selected_id := public.try_parse_uuid(v_config->>'tube_item_id');
          ELSE v_selected_id := NULL;
        END CASE;
        IF v_selected_id IS NOT NULL THEN
          v_comp.component_item_id := v_selected_id;
          v_selected := true;
        END IF;
      END;

      IF v_comp.component_item_id IS NULL THEN CONTINUE; END IF;

      SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
      FROM public."CatalogItems" ci
      WHERE ci.id = v_comp.component_item_id AND ci.organization_id = p_org_id
      LIMIT 1;

      SELECT cim.msrp, cim.total_cost INTO v_msrp_info
      FROM public."CatalogItemsMSRP" cim
      WHERE cim.catalog_item_id = v_comp.component_item_id AND cim.organization_id = p_org_id
      ORDER BY cim.updated_at DESC NULLS LAST
      LIMIT 1;

      v_qty := COALESCE(v_comp.qty_value, 1);
      CASE COALESCE(v_comp.qty_type, 'fixed')
        WHEN 'per_width', 'width' THEN v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_height', 'height' THEN v_qty := GREATEST(0, (v_height_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_m2', 'area' THEN v_qty := GREATEST(0, v_area_m2);
        ELSE v_qty := COALESCE(v_comp.qty_value, 1);
      END CASE;

      v_unit_price := COALESCE(v_msrp_info.msrp, 0);
      v_line_total := ROUND(v_qty * v_unit_price, 2);

      v_children := '[]'::jsonb;
      FOR v_child IN
        SELECT bc.id, bc.component_role, bc.component_item_id, bc.qty_type, bc.qty_value, bc.qty_delta_mm, bc.uom
        FROM public."BOMComponents" bc
        WHERE bc.parent_component_id = v_comp.id
          AND bc.organization_id = p_org_id
          AND bc.deleted = false
          AND bc.archived = false
        ORDER BY bc.sort_order ASC
      LOOP
        IF v_child.component_item_id IS NULL THEN CONTINUE; END IF;

        SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
        FROM public."CatalogItems" ci
        WHERE ci.id = v_child.component_item_id AND ci.organization_id = p_org_id
        LIMIT 1;

        SELECT cim.msrp, cim.total_cost INTO v_msrp_info
        FROM public."CatalogItemsMSRP" cim
        WHERE cim.catalog_item_id = v_child.component_item_id AND cim.organization_id = p_org_id
        ORDER BY cim.updated_at DESC NULLS LAST
        LIMIT 1;

        DECLARE
          v_child_qty numeric;
        BEGIN
          v_child_qty := COALESCE(v_child.qty_value, 1);
          CASE COALESCE(v_child.qty_type, 'fixed')
            WHEN 'per_width', 'width' THEN v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
            WHEN 'per_height', 'height' THEN v_child_qty := GREATEST(0, (v_height_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
            WHEN 'per_m2', 'area' THEN v_child_qty := GREATEST(0, v_area_m2);
            ELSE v_child_qty := COALESCE(v_child.qty_value, 1);
          END CASE;
          v_child_unit_price := COALESCE(v_msrp_info.msrp, 0);
          v_child_line_total := ROUND(v_child_qty * v_child_unit_price, 2);
          v_children := v_children || jsonb_build_object(
            'id', v_child.id::text, 'kind', 'child', 'role', COALESCE(v_child.component_role, 'child'),
            'level', 1, 'selected', false, 'catalog_item_id', v_child.component_item_id,
            'sku', v_item_info.sku, 'name', v_item_info.name,
            'qty', ROUND(v_child_qty, 3),
            'uom', COALESCE(v_child.uom, v_item_info.unit_of_measure, 'ea'),
            'unit_price', v_child_unit_price, 'line_total', v_child_line_total,
            'children', '[]'::jsonb, 'meta', '{}'::jsonb
          );
        END;
      END LOOP;

      v_items := v_items || jsonb_build_object(
        'id', v_comp.id::text, 'kind', 'parent', 'role', COALESCE(v_comp.component_role, 'component'),
        'level', 0, 'selected', v_selected, 'catalog_item_id', v_comp.component_item_id,
        'sku', v_item_info.sku, 'name', v_item_info.name,
        'qty', ROUND(v_qty, 3),
        'uom', COALESCE(v_comp.uom, v_item_info.unit_of_measure, 'ea'),
        'unit_price', v_unit_price, 'line_total', v_line_total,
        'children', v_children, 'meta', '{}'::jsonb
      );
    END LOOP;
  END IF;

  SELECT * INTO v_cp FROM public."ConfiguredProducts" WHERE id = p_configured_product_id AND organization_id = p_org_id;

  SELECT COALESCE(SUM((item->>'line_total')::numeric), 0) INTO v_roll_msrp_total
  FROM jsonb_array_elements(v_items) AS item WHERE item->>'kind' = 'roll';
  IF v_roll_msrp_total = 0 THEN v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0); END IF;

  SELECT COALESCE(SUM(
    (item->>'line_total')::numeric +
    COALESCE((SELECT SUM((c->>'line_total')::numeric) FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c), 0)
  ), 0) INTO v_bom_sum
  FROM jsonb_array_elements(v_items) AS item WHERE item->>'kind' = 'parent';
  IF v_bom_sum = 0 THEN v_bom_sum := COALESCE(v_cp.bom_total, 0); END IF;

  v_labor_amount := COALESCE(v_cp.labor_amount, 0);
  v_accessories_total := COALESCE(v_cp.accessories_total, 0);
  IF v_labor_amount = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_amount := (v_roll_msrp_total + v_bom_sum) * (v_cp.labor_pct / 100.0);
  END IF;
  v_total_msrp := v_roll_msrp_total + v_bom_sum + v_labor_amount + v_accessories_total;

  v_totals := jsonb_build_object(
    'roll_qty', v_roll_qty,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_sum,
    'accessories_total', v_accessories_total,
    'labor_pct', COALESCE(v_cp.labor_pct, 0),
    'labor_amount', v_labor_amount,
    'total_msrp', v_total_msrp,
    'roll_total_cost', COALESCE(v_roll_total_cost, v_cp.roll_total_cost, 0),
    'bom_total_cost', COALESCE(v_cp.bom_total_cost, 0)
  );

  RETURN jsonb_build_object(
    'version', '1',
    'product_type_id', v_cp.product_type_id,
    'bom_template_id', p_bom_template_id,
    'price_basis', 'msrp',
    'currency', 'USD',
    'totals', v_totals,
    'items', v_items
  );
END;
$$;

COMMENT ON FUNCTION public.build_bom_preview_snapshot(uuid, uuid, uuid) IS
'BOM preview JSONB. Roll qty/uom/unit_price según CostSettings.fabric_pricing_basis (auto|linear|sqm) con conversión correcta de unit_price. Future-only: applies when snapshot is generated; no backfill. Invariante: qty*unit_price=line_total. meta: pricing_basis, global_setting, msrp_source_uom, warning (if degrade).';


-- ----------------------------------------------------------------------------
-- PARTE C: Queries de verificación
-- (copiar y ejecutar manualmente tras la migración y regenerar snapshot)
-- ----------------------------------------------------------------------------
/*
-- 1) Verificar la nueva columna
SELECT organization_id, fabric_pricing_basis
FROM public."CostSettings"
LIMIT 5;

-- 2) Cambiar setting de prueba a 'linear'
UPDATE public."CostSettings"
SET fabric_pricing_basis = 'linear'
WHERE organization_id = '<tu_org_id>'::uuid;

-- 3) Regenerar snapshot
SELECT public.calculate_configured_product_totals('cfccd659-8a9b-45f5-abb1-5c07b77e8766'::uuid);

-- 4) Ver resultado del roll en el snapshot
SELECT
  item->>'sku'                  AS sku,
  (item->>'qty')::numeric       AS qty,
  item->>'uom'                  AS uom,
  (item->>'unit_price')::numeric AS unit_price,
  (item->>'line_total')::numeric AS line_total,
  item->'meta'->>'roll_width_m'   AS roll_width_m,
  item->'meta'->>'pricing_basis'  AS pricing_basis,
  item->'meta'->>'msrp_source_uom' AS msrp_source_uom
FROM public."ConfiguredProducts" cp
CROSS JOIN LATERAL jsonb_array_elements(cp.bom_preview_snapshot->'items') item
WHERE cp.id = 'cfccd659-8a9b-45f5-abb1-5c07b77e8766'::uuid
  AND item->>'kind' = 'roll';

-- ESPERADO con basis='linear', pricing_uom='m', roll_width_m=2, height_m=1.2:
--   qty=1.2 | uom='m' | unit_price=88.8163 | line_total=106.58
-- ESPERADO con basis='sqm', pricing_uom='m', roll_width_m=2, height_m=1.2:
--   qty=2.4 | uom='m²' | unit_price=44.4082 | line_total=106.58

-- 5) Confirmar invariante (total igual en ambos casos)
-- qty * unit_price = line_total (mismo valor económico, solo reexpresado)
*/

DO $$
BEGIN
  RAISE NOTICE '✅ Migration 20260315: fabric_pricing_basis en CostSettings + build_bom_preview_snapshot con conversión unit_price y auditoría en meta.';
END $$;
