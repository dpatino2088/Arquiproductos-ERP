-- ====================================================
-- MIGRATION: Agregar labor_amount a ConfiguredProducts y ajustar cálculo
-- Date: 2026-01-25
-- Description: 
--  1. Agrega columna labor_amount si no existe
--  2. Ajusta calculate_configured_product_totals para incluir labor en roll_plus_bom_total
-- ====================================================

BEGIN;

-- ====================================================
-- 1. Agregar columna labor_amount si no existe
-- ====================================================
ALTER TABLE public."ConfiguredProducts"
  ADD COLUMN IF NOT EXISTS labor_amount numeric(12,4) DEFAULT 0;

-- ====================================================
-- 2. Ajustar calculate_configured_product_totals para incluir labor
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
    v_subtotal_msrp numeric(12,4) := 0;
    v_roll_plus_bom_total numeric(12,4) := 0;
    -- Cost totals
    v_roll_total_cost numeric(12,4) := 0;
    v_bom_total_cost numeric(12,4) := 0;
    -- Labor
    v_labor_pct numeric(7,4) := 0;
    v_labor_amount numeric(12,4) := 0;
    -- Otros
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
    SELECT id INTO v_bom_instance_id
    FROM public."BOMInstances"
    WHERE configured_product_id = p_configured_product_id
        AND deleted = false
    ORDER BY created_at DESC
    LIMIT 1;

    -- 3. Calcular Roll MSRP Total y Roll Total Cost
    IF v_cp.roll_catalog_item_id IS NOT NULL THEN
        -- Obtener MSRP sale_out y total_cost del roll
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

        -- Si aún no se encontró, registrar warning y usar 0
        IF v_roll_msrp IS NULL THEN
            RAISE WARNING 'CatalogItemsMSRP no encontrado para roll catalog_item_id % (organization_id: %). Usando 0.', 
                v_cp.roll_catalog_item_id, v_cp.organization_id;
            v_roll_msrp := 0;
            v_roll_total_cost_per_unit := 0;
        ELSE
            v_roll_msrp := COALESCE(v_roll_msrp, 0);
            v_roll_total_cost_per_unit := COALESCE(v_roll_total_cost_per_unit, 0);
        END IF;
        
        -- Usar roll_width guardado en ConfiguredProduct (snapshot)
        v_width_m := COALESCE(v_cp.roll_width, 0);

        IF v_roll_msrp > 0 AND v_width_m > 0 AND v_cp.height_mm IS NOT NULL THEN
            v_height_m := v_cp.height_mm / 1000.0; -- Convertir mm a metros
            v_quantity := COALESCE(v_cp.quantity, 1);
            
            -- Calcular MSRP total
            v_roll_msrp_total := v_roll_msrp * v_width_m * v_height_m * v_quantity;
            
            -- Calcular costo total real
            v_roll_total_cost := v_roll_total_cost_per_unit * v_width_m * v_height_m * v_quantity;
        END IF;
    END IF;

    -- 4. Calcular BOM Total (MSRP y Costo)
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
            
            -- Sumar MSRP
            v_bom_total := v_bom_total + (v_part_msrp * v_bom_line.qty);
            
            -- Sumar costo real
            v_bom_total_cost := v_bom_total_cost + (v_part_total_cost * v_bom_line.qty);
        END LOOP;
    END IF;

    -- 5. Calcular subtotal MSRP (sin labor)
    v_subtotal_msrp := COALESCE(v_roll_msrp_total, 0) + COALESCE(v_bom_total, 0);

    -- 6. Obtener labor_pct desde CostSettings (por organization_id)
    -- ✅ Prioridad: CostSettings > metadata > ConfiguredProducts.labor_pct > 0
    SELECT labor_pct INTO v_labor_pct
    FROM public."CostSettings"
    WHERE organization_id = v_cp.organization_id
        AND is_active = true
    LIMIT 1;

    -- Si no se encontró en CostSettings, intentar desde metadata o columna
    IF v_labor_pct IS NULL THEN
        v_labor_pct := COALESCE(
            (v_cp.metadata->>'labor_pct')::numeric,
            v_cp.labor_pct,
            0
        );
    END IF;

    -- Asegurar que labor_pct esté en formato decimal (ej: 0.15 para 15%)
    -- CostSettings.labor_pct ya está en formato decimal (0.15 = 15%)
    -- Si viene de metadata o columna y está > 1, convertir a decimal
    IF v_labor_pct > 1 THEN
        v_labor_pct := v_labor_pct / 100.0;
    END IF;
    
    -- Normalizar: si es NULL o negativo, usar 0
    v_labor_pct := COALESCE(v_labor_pct, 0);
    IF v_labor_pct < 0 THEN
        v_labor_pct := 0;
    END IF;

    -- 7. Calcular labor_amount y roll_plus_bom_total (con labor)
    v_labor_amount := v_subtotal_msrp * v_labor_pct;
    -- ✅ FÓRMULA: roll_plus_bom_total = subtotal_msrp * (1 + labor_pct)
    v_roll_plus_bom_total := v_subtotal_msrp * (1 + v_labor_pct);

    -- 8. Obtener accessories_total (si existe en metadata)
    v_accessories_total := COALESCE(
        (v_cp.metadata->>'accessories_total')::numeric,
        v_cp.accessories_total,
        0
    );

    -- 9. Calcular Total MSRP final (incluye accessories)
    v_total_msrp := v_roll_plus_bom_total + v_accessories_total;

    -- 10. Actualizar ConfiguredProduct con todos los totals
    UPDATE public."ConfiguredProducts"
    SET 
        -- MSRP totals
        roll_msrp_total = v_roll_msrp_total,
        bom_total = v_bom_total,
        roll_plus_bom_total = v_roll_plus_bom_total, -- ✅ Ya incluye labor
        -- Cost totals
        roll_total_cost = v_roll_total_cost,
        bom_total_cost = v_bom_total_cost,
        -- Labor
        labor_pct = v_labor_pct,
        labor_amount = v_labor_amount, -- ✅ Nuevo
        -- Otros
        accessories_total = v_accessories_total,
        total_msrp = v_total_msrp,
        updated_at = now()
    WHERE id = p_configured_product_id;

    -- 11. Retornar totals como JSONB
    RETURN jsonb_build_object(
        'roll_msrp_total', v_roll_msrp_total,
        'bom_total', v_bom_total,
        'subtotal_msrp', v_subtotal_msrp, -- ✅ Nuevo: sin labor
        'labor_pct', v_labor_pct,
        'labor_amount', v_labor_amount, -- ✅ Nuevo
        'roll_plus_bom_total', v_roll_plus_bom_total, -- ✅ Con labor
        'roll_total_cost', v_roll_total_cost,
        'bom_total_cost', v_bom_total_cost,
        'accessories_total', v_accessories_total,
        'total_msrp', v_total_msrp
    );
END;
$$;

COMMENT ON FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") IS 
'Calcula y actualiza totals de ConfiguredProduct:
- MSRP: roll_msrp_total, bom_total, subtotal_msrp (sin labor), roll_plus_bom_total (con labor)
- Labor: labor_pct (desde CostSettings), labor_amount, aplicado a roll_plus_bom_total
- Costos: roll_total_cost, bom_total_cost
✅ FÓRMULA: roll_plus_bom_total = (roll_msrp_total + bom_total) * (1 + labor_pct)
✅ Usa BOMInstances y BOMInstanceLines (mayúsculas).';

COMMIT;
