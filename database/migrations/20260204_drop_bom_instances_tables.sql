-- ============================================================================
-- Migration: Drop BOMInstances and BOMInstanceLines tables
-- Date: 2026-02-04
-- Description:
--   Estas tablas ya no son necesarias porque:
--   1. ConfiguredProducts.bom_preview_snapshot contiene toda la info del BOM
--   2. Manufactura se trabajará desde ConfiguredProduct (nuevo módulo)
--   3. Las QuoteLines ya no crean BOMInstances
--
--   TABLAS A ELIMINAR:
--   - BOMInstances
--   - BOMInstanceLines
--
--   TABLAS QUE SE MANTIENEN (usadas para configuración):
--   - BOMTemplates
--   - BOMTemplateSlots
--   - BOMComponents
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. ELIMINAR FUNCIONES QUE DEPENDEN DE BOMInstances
-- ═══════════════════════════════════════════════════════════════════════════

-- Función que crea BOMInstance para ConfiguredProduct
DROP FUNCTION IF EXISTS public.create_bom_instance_for_configured_product(uuid, uuid, uuid, uuid) CASCADE;

-- Función que genera BOMInstance para QuoteLine (legacy)
DROP FUNCTION IF EXISTS public.generate_bom_instance_for_quote_line(uuid, uuid, uuid) CASCADE;

-- Función que calcula totales desde BOMInstanceLines
-- NOTA: Esta función se actualiza para NO depender de BOMInstanceLines
-- DROP FUNCTION IF EXISTS public.calculate_configured_product_totals(uuid) CASCADE;

-- Vista de BOMInstances
DROP VIEW IF EXISTS public.vw_bom_instances_safe CASCADE;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. ELIMINAR TRIGGERS RELACIONADOS
-- ═══════════════════════════════════════════════════════════════════════════

-- Trigger que genera BOMInstance al insertar QuoteLine
DROP TRIGGER IF EXISTS trg_quote_lines_generate_bom_instance ON public."QuoteLines";

-- Función del trigger (ya no es necesaria)
DROP FUNCTION IF EXISTS public.trg_quote_lines_generate_bom_instance_fn() CASCADE;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. ELIMINAR TABLAS
-- ═══════════════════════════════════════════════════════════════════════════

-- Primero BOMInstanceLines (tiene FK a BOMInstances)
DROP TABLE IF EXISTS public."BOMInstanceLines" CASCADE;

-- Luego BOMInstances
DROP TABLE IF EXISTS public."BOMInstances" CASCADE;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. LIMPIAR COLUMNAS QUE REFERENCIAN BOMInstances
-- ═══════════════════════════════════════════════════════════════════════════

-- Columna en ConfiguredProducts que referenciaba BOMInstance (si existe)
-- ALTER TABLE public."ConfiguredProducts" DROP COLUMN IF EXISTS bom_instance_id;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. ACTUALIZAR calculate_configured_product_totals
--    Para que NO dependa de BOMInstanceLines
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.calculate_configured_product_totals(p_configured_product_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_comp RECORD;
  v_msrp_info RECORD;
  
  v_roll_msrp_unit numeric := 0;
  v_roll_cost_unit numeric := 0;
  v_roll_factor numeric := 0;
  v_roll_msrp_total numeric := 0;
  v_roll_total_cost numeric := 0;
  
  v_roll_pricing_mode text;
  v_roll_measure_basis text;
  v_roll_width_m numeric := 0;
  v_height_m numeric := 0;
  v_width_m numeric := 0;
  v_area_m2 numeric := 0;
  v_qty numeric := 1;
  
  v_bom_msrp numeric := 0;
  v_bom_total_cost numeric := 0;
  v_part_msrp numeric;
  v_part_total_cost numeric;
  v_part_qty numeric;
  
  v_roll_plus_bom_total numeric := 0;
  v_labor_amount numeric := 0;
  v_accessories_total numeric := 0;
  v_total_msrp numeric := 0;
BEGIN
  -- Obtener ConfiguredProduct
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  -- Dimensiones
  v_qty := COALESCE(v_cp.quantity, 1);
  v_height_m := COALESCE(v_cp.height_mm, 0) / 1000.0;
  v_width_m := COALESCE(v_cp.width_mm, 0) / 1000.0;
  v_area_m2 := v_width_m * v_height_m;
  v_roll_width_m := COALESCE(v_cp.roll_width, 0);

  -- ═══════════════════════════════════════════════════════════════════════
  -- 1. ROLL TOTALS
  -- ═══════════════════════════════════════════════════════════════════════
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT msrp, total_cost
      INTO v_roll_msrp_unit, v_roll_cost_unit
    FROM public."CatalogItemsMSRP"
    WHERE catalog_item_id = v_cp.roll_catalog_item_id
      AND organization_id = v_cp.organization_id
    LIMIT 1;

    IF v_roll_msrp_unit IS NULL THEN
      SELECT msrp, total_cost
        INTO v_roll_msrp_unit, v_roll_cost_unit
      FROM public."CatalogItemsMSRP"
      WHERE catalog_item_id = v_cp.roll_catalog_item_id
      LIMIT 1;
    END IF;

    SELECT ci.roll_pricing_mode, ci.measure_basis
      INTO v_roll_pricing_mode, v_roll_measure_basis
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
    LIMIT 1;

    -- Calcular factor según pricing mode
    IF v_roll_pricing_mode = 'per_unit' THEN
      v_roll_factor := v_qty;
    ELSIF v_roll_pricing_mode = 'per_linear_meter' OR v_roll_measure_basis = 'linear' THEN
      v_roll_factor := v_height_m * v_qty;
    ELSE
      -- per_square_meter OR default: área
      v_roll_factor := (v_roll_width_m * v_height_m) * v_qty;
    END IF;

    v_roll_msrp_total := COALESCE(v_roll_msrp_unit, 0) * v_roll_factor;
    v_roll_total_cost := COALESCE(v_roll_cost_unit, 0) * v_roll_factor;
  END IF;

  -- ═══════════════════════════════════════════════════════════════════════
  -- 2. BOM TOTALS (desde BOMComponents, NO desde BOMInstanceLines)
  -- ═══════════════════════════════════════════════════════════════════════
  IF v_cp.bom_template_id IS NOT NULL THEN
    FOR v_comp IN
      SELECT 
        bc.id,
        bc.component_role,
        bc.component_item_id,
        bc.qty_type,
        bc.qty_fixed,
        bc.is_optional,
        bc.is_default_selected
      FROM public."BOMComponents" bc
      WHERE bc.bom_template_id = v_cp.bom_template_id
        AND bc.organization_id = v_cp.organization_id
        AND bc.deleted = false
        AND bc.parent_component_id IS NULL  -- Solo padres
    LOOP
      -- Verificar si está seleccionado
      -- Por defecto, usar is_default_selected o no es opcional
      IF v_comp.is_optional AND NOT COALESCE(v_comp.is_default_selected, false) THEN
        -- Verificar si está en config_snapshot
        IF NOT (v_cp.config_snapshot->'selectedComponents' ? v_comp.id::text) THEN
          CONTINUE;
        END IF;
      END IF;

      -- Calcular cantidad
      v_part_qty := CASE v_comp.qty_type
        WHEN 'per_width' THEN v_width_m * v_qty
        WHEN 'per_height' THEN v_height_m * v_qty
        WHEN 'per_m2' THEN v_area_m2 * v_qty
        ELSE COALESCE(v_comp.qty_fixed, 1) * v_qty
      END;

      -- Obtener MSRP y cost
      SELECT msrp, total_cost
        INTO v_part_msrp, v_part_total_cost
      FROM public."CatalogItemsMSRP"
      WHERE catalog_item_id = v_comp.component_item_id
        AND organization_id = v_cp.organization_id
      LIMIT 1;

      IF v_part_msrp IS NULL THEN
        SELECT msrp, total_cost
          INTO v_part_msrp, v_part_total_cost
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_comp.component_item_id
        LIMIT 1;
      END IF;

      v_bom_msrp := v_bom_msrp + (COALESCE(v_part_msrp, 0) * v_part_qty);
      v_bom_total_cost := v_bom_total_cost + (COALESCE(v_part_total_cost, 0) * v_part_qty);

      -- Sumar children también
      FOR v_comp IN
        SELECT 
          bc.component_item_id,
          bc.qty_type,
          bc.qty_fixed
        FROM public."BOMComponents" bc
        WHERE bc.parent_component_id = v_comp.id
          AND bc.deleted = false
      LOOP
        v_part_qty := CASE v_comp.qty_type
          WHEN 'per_width' THEN v_width_m * v_qty
          WHEN 'per_height' THEN v_height_m * v_qty
          WHEN 'per_m2' THEN v_area_m2 * v_qty
          ELSE COALESCE(v_comp.qty_fixed, 1) * v_qty
        END;

        SELECT msrp, total_cost
          INTO v_part_msrp, v_part_total_cost
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_comp.component_item_id
        LIMIT 1;

        v_bom_msrp := v_bom_msrp + (COALESCE(v_part_msrp, 0) * v_part_qty);
        v_bom_total_cost := v_bom_total_cost + (COALESCE(v_part_total_cost, 0) * v_part_qty);
      END LOOP;
    END LOOP;
  END IF;

  -- ═══════════════════════════════════════════════════════════════════════
  -- 3. CALCULAR TOTALES
  -- ═══════════════════════════════════════════════════════════════════════
  v_roll_plus_bom_total := v_roll_msrp_total + v_bom_msrp;
  v_accessories_total := COALESCE(v_cp.accessories_total, 0);
  v_labor_amount := v_roll_plus_bom_total * (COALESCE(v_cp.labor_pct, 0) / 100.0);
  v_total_msrp := v_roll_plus_bom_total + v_accessories_total + v_labor_amount;

  -- Persistir en ConfiguredProducts
  UPDATE public."ConfiguredProducts"
  SET
    roll_msrp_total = v_roll_msrp_total,
    roll_total_cost = v_roll_total_cost,
    bom_total = v_bom_msrp,
    bom_total_cost = v_bom_total_cost,
    roll_plus_bom_total = v_roll_plus_bom_total,
    labor_amount = v_labor_amount,
    total_msrp = v_total_msrp,
    updated_at = now()
  WHERE id = p_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id', p_configured_product_id,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_msrp,
    'roll_plus_bom_total', v_roll_plus_bom_total,
    'labor_amount', v_labor_amount,
    'accessories_total', v_accessories_total,
    'total_msrp', v_total_msrp,
    'roll_total_cost', v_roll_total_cost,
    'bom_total_cost', v_bom_total_cost,
    'total_cost', (v_roll_total_cost + v_bom_total_cost)
  );
END;
$$;

COMMENT ON FUNCTION public.calculate_configured_product_totals(uuid) IS 
'Calcula totales para ConfiguredProduct.
✅ ACTUALIZADO: Ya NO depende de BOMInstanceLines.
Calcula BOM directamente desde BOMComponents + CatalogItemsMSRP.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. VERIFICACIÓN
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  RAISE NOTICE '══════════════════════════════════════════════════════════════';
  RAISE NOTICE '✅ Migration 20260204_drop_bom_instances_tables completed';
  RAISE NOTICE '══════════════════════════════════════════════════════════════';
  RAISE NOTICE '  ELIMINADO:';
  RAISE NOTICE '    - BOMInstanceLines table';
  RAISE NOTICE '    - BOMInstances table';
  RAISE NOTICE '    - create_bom_instance_for_configured_product function';
  RAISE NOTICE '    - generate_bom_instance_for_quote_line function';
  RAISE NOTICE '    - trg_quote_lines_generate_bom_instance trigger';
  RAISE NOTICE '  ';
  RAISE NOTICE '  ACTUALIZADO:';
  RAISE NOTICE '    - calculate_configured_product_totals (ya no usa BOMInstanceLines)';
  RAISE NOTICE '  ';
  RAISE NOTICE '  MANTENIDO:';
  RAISE NOTICE '    - BOMTemplates';
  RAISE NOTICE '    - BOMTemplateSlots';
  RAISE NOTICE '    - BOMComponents';
  RAISE NOTICE '══════════════════════════════════════════════════════════════';
END $$;
