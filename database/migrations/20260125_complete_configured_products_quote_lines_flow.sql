-- ====================================================
-- MIGRATION: Completar flujo ConfiguredProducts → QuoteLines
-- Date: 2026-01-25
-- Description: 
--  1. Agregar columnas de costos reales a ConfiguredProducts (roll_total_cost, bom_total_cost)
--  2. Actualizar calculate_configured_product_totals para calcular costos reales
--  3. Asegurar que QuoteLines use snapshots correctos
-- ====================================================

BEGIN;

-- ====================================================
-- 1. Agregar columnas de costos reales a ConfiguredProducts
-- ====================================================
ALTER TABLE public."ConfiguredProducts"
  ADD COLUMN IF NOT EXISTS roll_total_cost numeric(12,4) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bom_total_cost numeric(12,4) DEFAULT 0;

COMMENT ON COLUMN public."ConfiguredProducts".roll_total_cost IS 
'Costo real total del roll (usando CatalogItemsMSRP.total_cost). 
Calculado como: total_cost del roll × roll_width × height_m × quantity';

COMMENT ON COLUMN public."ConfiguredProducts".bom_total_cost IS 
'Costo real total del BOM (suma de CatalogItemsMSRP.total_cost de cada BOMInstanceLine).
Calculado como: SUM(total_cost × qty) para cada línea del BOM';

-- ====================================================
-- 2. Actualizar función calculate_configured_product_totals
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_cp RECORD;
    v_bom_instance_id uuid;
    -- MSRP totals
    v_roll_msrp_total numeric(12,4) := 0;
    v_bom_total numeric(12,4) := 0;
    v_roll_plus_bom_total numeric(12,4) := 0;
    -- Cost totals (nuevos)
    v_roll_total_cost numeric(12,4) := 0;
    v_bom_total_cost numeric(12,4) := 0;
    -- Otros
    v_labor_pct numeric(5,2) := 0;
    v_accessories_total numeric(12,4) := 0;
    v_total_msrp numeric(12,4) := 0;
    v_width_m numeric(12,4);
    v_height_m numeric(12,4);
    v_quantity numeric(12,4);
    v_roll_msrp numeric(12,4);
    v_roll_total_cost_per_unit numeric(12,4);
    v_bom_line RECORD;
    v_part_msrp numeric(12,4);
    v_part_total_cost numeric(12,4);
BEGIN
    -- 1. Obtener ConfiguredProduct
    SELECT * INTO v_cp
    FROM public."ConfiguredProducts"
    WHERE id = p_configured_product_id
        AND deleted = false;

    IF v_cp.id IS NULL THEN
        RAISE EXCEPTION 'ConfiguredProduct not found %', p_configured_product_id;
    END IF;

    -- 2. Obtener BOMInstance asociado
    -- ✅ Usar BOMInstances (mayúsculas)
    SELECT id INTO v_bom_instance_id
    FROM public."BOMInstances"
    WHERE configured_product_id = p_configured_product_id
        AND deleted = false
    ORDER BY created_at DESC
    LIMIT 1;

    -- 3. Calcular Roll MSRP Total y Roll Total Cost
    -- ✅ FÓRMULA MSRP: MSRP Sale out × Ancho del rollo total × Altura de la medida
    -- ✅ FÓRMULA COSTO: Total Cost × Ancho del rollo total × Altura de la medida
    IF v_cp.roll_catalog_item_id IS NOT NULL THEN
        -- Obtener MSRP sale_out y total_cost del roll
        -- ✅ Priorizar organization_id específico, luego fallback a NULL
        SELECT 
            msrp_sale_out,
            total_cost
        INTO v_roll_msrp, v_roll_total_cost_per_unit
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_cp.roll_catalog_item_id
            AND organization_id = v_cp.organization_id
        LIMIT 1;

        -- Si no se encontró, intentar sin organization_id (fallback)
        IF v_roll_msrp IS NULL THEN
            SELECT 
                msrp_sale_out,
                total_cost
            INTO v_roll_msrp, v_roll_total_cost_per_unit
            FROM public."CatalogItemsMSRP"
            WHERE catalog_item_id = v_cp.roll_catalog_item_id
                AND organization_id IS NULL
            LIMIT 1;
        END IF;

        -- Si aún no se encontró, registrar error controlado
        IF v_roll_msrp IS NULL THEN
            RAISE WARNING 'CatalogItemsMSRP no encontrado para roll catalog_item_id % (organization_id: %). Usando 0.', 
                v_cp.roll_catalog_item_id, v_cp.organization_id;
            v_roll_msrp := 0;
            v_roll_total_cost_per_unit := 0;
        ELSE
            v_roll_msrp := COALESCE(v_roll_msrp, 0);
            v_roll_total_cost_per_unit := COALESCE(v_roll_total_cost_per_unit, 0);
        END IF;
        
        -- ✅ Usar roll_width guardado en ConfiguredProduct (snapshot)
        v_width_m := COALESCE(v_cp.roll_width, 0); -- roll_width ya está en metros

        IF v_roll_msrp > 0 AND v_width_m > 0 AND v_cp.height_mm IS NOT NULL THEN
            v_height_m := v_cp.height_mm / 1000.0; -- Convertir mm a metros
            v_quantity := COALESCE(v_cp.quantity, 1);
            
            -- ✅ Calcular MSRP total
            v_roll_msrp_total := v_roll_msrp * v_width_m * v_height_m * v_quantity;
            
            -- ✅ Calcular costo total real
            v_roll_total_cost := v_roll_total_cost_per_unit * v_width_m * v_height_m * v_quantity;
        END IF;
    END IF;

    -- 4. Calcular BOM Total (MSRP y Costo)
    -- ✅ BOM Total MSRP = Suma de msrp_sale_out × qty de cada línea
    -- ✅ BOM Total Cost = Suma de total_cost × qty de cada línea
    IF v_bom_instance_id IS NOT NULL THEN
        FOR v_bom_line IN
            SELECT 
                bil.resolved_part_id,
                bil.qty
            FROM public."BOMInstanceLines" bil
            WHERE bil.bom_instance_id = v_bom_instance_id
                AND bil.deleted = false
                AND bil.resolved_part_id IS NOT NULL
        LOOP
            -- Obtener MSRP sale_out y total_cost de cada componente
            -- ✅ Manejar nulls: si no existe en CatalogItemsMSRP, usar 0 y registrar warning
            SELECT 
                msrp_sale_out,
                total_cost
            INTO v_part_msrp, v_part_total_cost
            FROM public."CatalogItemsMSRP"
            WHERE catalog_item_id = v_bom_line.resolved_part_id
                AND organization_id = v_cp.organization_id
            LIMIT 1;

            -- Si no se encontró, intentar sin organization_id (fallback)
            IF v_part_msrp IS NULL THEN
                SELECT 
                    msrp_sale_out,
                    total_cost
                INTO v_part_msrp, v_part_total_cost
                FROM public."CatalogItemsMSRP"
                WHERE catalog_item_id = v_bom_line.resolved_part_id
                    AND organization_id IS NULL
                LIMIT 1;
            END IF;

            -- Si aún no se encontró, registrar warning y usar 0
            IF v_part_msrp IS NULL THEN
                RAISE WARNING 'CatalogItemsMSRP no encontrado para catalog_item_id % (organization_id: %). Usando 0.', 
                    v_bom_line.resolved_part_id, v_cp.organization_id;
                v_part_msrp := 0;
                v_part_total_cost := 0;
            ELSE
                v_part_msrp := COALESCE(v_part_msrp, 0);
                v_part_total_cost := COALESCE(v_part_total_cost, 0);
            END IF;
            
            -- ✅ Sumar MSRP
            v_bom_total := v_bom_total + (v_part_msrp * v_bom_line.qty);
            
            -- ✅ Sumar costo real
            v_bom_total_cost := v_bom_total_cost + (v_part_total_cost * v_bom_line.qty);
        END LOOP;
    END IF;

    -- 5. Calcular Fabric + BOM Total
    v_roll_plus_bom_total := v_roll_msrp_total + v_bom_total;

    -- 6. Obtener labor_pct (de cost settings o metadata)
    v_labor_pct := COALESCE(
        (v_cp.metadata->>'labor_pct')::numeric,
        v_cp.labor_pct,
        0
    );

    -- 7. Obtener accessories_total (si existe en metadata)
    v_accessories_total := COALESCE(
        (v_cp.metadata->>'accessories_total')::numeric,
        v_cp.accessories_total,
        0
    );

    -- 8. Calcular Total MSRP final
    -- Formula: (Roll + BOM) * (1 + labor_pct) + Accessories
    v_total_msrp := (v_roll_plus_bom_total * (1 + (v_labor_pct / 100))) + v_accessories_total;

    -- 9. Actualizar ConfiguredProduct con todos los totals
    UPDATE public."ConfiguredProducts"
    SET 
        -- MSRP totals
        roll_msrp_total = v_roll_msrp_total,
        bom_total = v_bom_total,
        roll_plus_bom_total = v_roll_plus_bom_total,
        -- ✅ Cost totals (nuevos)
        roll_total_cost = v_roll_total_cost,
        bom_total_cost = v_bom_total_cost,
        -- Otros
        labor_pct = v_labor_pct,
        accessories_total = v_accessories_total,
        total_msrp = v_total_msrp,
        updated_at = now()
    WHERE id = p_configured_product_id;

    -- 10. Retornar totals como JSONB
    RETURN jsonb_build_object(
        'roll_msrp_total', v_roll_msrp_total,
        'bom_total', v_bom_total,
        'roll_plus_bom_total', v_roll_plus_bom_total,
        'roll_total_cost', v_roll_total_cost,
        'bom_total_cost', v_bom_total_cost,
        'labor_pct', v_labor_pct,
        'accessories_total', v_accessories_total,
        'total_msrp', v_total_msrp
    );
END;
$$;

COMMENT ON FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") IS 
'Calcula y actualiza totals de ConfiguredProduct:
- MSRP: roll_msrp_total, bom_total (usando msrp_sale_out), roll_plus_bom_total
- Costos: roll_total_cost, bom_total_cost (usando total_cost)
✅ CORREGIDO: Usa BOMInstances y BOMInstanceLines (mayúsculas).
✅ NUEVO: Calcula costos reales para margen.';

COMMIT;
