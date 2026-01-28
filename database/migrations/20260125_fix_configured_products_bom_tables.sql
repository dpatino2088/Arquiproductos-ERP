-- ====================================================
-- MIGRATION: Corregir referencias a tablas BOM en calculate_configured_product_totals
-- Date: 2026-01-25
-- Description: Corrige la función para usar BOMInstances y BOMInstanceLines (mayúsculas)
-- ====================================================

BEGIN;

-- ====================================================
-- Corregir función calculate_configured_product_totals
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_cp RECORD;
    v_bom_instance_id uuid;
    v_roll_msrp_total numeric(12,4) := 0;
    v_bom_total numeric(12,4) := 0;
    v_roll_plus_bom_total numeric(12,4) := 0;
    v_labor_pct numeric(5,2) := 0;
    v_accessories_total numeric(12,4) := 0;
    v_total_msrp numeric(12,4) := 0;
    v_width_m numeric(12,4);
    v_height_m numeric(12,4);
    v_quantity numeric(12,4);
    v_roll_msrp numeric(12,4);
    v_bom_line RECORD;
    v_part_msrp numeric(12,4);
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
    -- ✅ CORRECCIÓN: Usar BOMInstances (mayúsculas) en lugar de BomInstances
    SELECT id INTO v_bom_instance_id
    FROM public."BOMInstances"
    WHERE configured_product_id = p_configured_product_id
        AND deleted = false
    ORDER BY created_at DESC
    LIMIT 1;

    -- 3. Calcular Roll MSRP Total
    -- ✅ FÓRMULA: MSRP Sale out × Ancho del rollo total × Altura de la medida de measurements
    -- Donde:
    -- - MSRP Sale out = msrp_sale_out del roll (desde CatalogItemsMSRP)
    -- - Ancho del rollo total = roll_width del roll (desde CatalogItems.roll_width)
    -- - Altura de la medida = height_mm del producto (medida de measurements)
    IF v_cp.roll_catalog_item_id IS NOT NULL THEN
        -- Obtener MSRP sale_out del roll
        SELECT msrp_sale_out INTO v_roll_msrp
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_cp.roll_catalog_item_id
            AND (organization_id = v_cp.organization_id OR organization_id IS NULL)
        ORDER BY organization_id DESC NULLS LAST
        LIMIT 1;

        v_roll_msrp := COALESCE(v_roll_msrp, 0);
        
        -- ✅ Usar roll_width guardado en ConfiguredProduct (snapshot)
        v_width_m := COALESCE(v_cp.roll_width, 0); -- roll_width ya está en metros (guardado como snapshot)

        IF v_roll_msrp > 0 AND v_width_m > 0 AND v_cp.height_mm IS NOT NULL THEN
            v_height_m := v_cp.height_mm / 1000.0; -- Convertir mm a metros
            v_quantity := COALESCE(v_cp.quantity, 1);
            -- ✅ Fórmula: MSRP Sale out × Ancho del rollo total × Altura de la medida
            v_roll_msrp_total := v_roll_msrp * v_width_m * v_height_m * v_quantity;
        END IF;
    END IF;

    -- 4. Calcular BOM Total (sumar todas las líneas de BOMInstanceLines)
    -- ✅ CORRECCIÓN: Usar BOMInstanceLines (mayúsculas) en lugar de BomInstanceLines
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
            -- Obtener MSRP sale_out de cada componente
            SELECT msrp_sale_out INTO v_part_msrp
            FROM public."CatalogItemsMSRP"
            WHERE catalog_item_id = v_bom_line.resolved_part_id
                AND (organization_id = v_cp.organization_id OR organization_id IS NULL)
            ORDER BY organization_id DESC NULLS LAST
            LIMIT 1;

            v_part_msrp := COALESCE(v_part_msrp, 0);
            v_bom_total := v_bom_total + (v_part_msrp * v_bom_line.qty);
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

    -- 9. Actualizar ConfiguredProduct con totals
    UPDATE public."ConfiguredProducts"
    SET 
        roll_msrp_total = v_roll_msrp_total,
        bom_total = v_bom_total,
        roll_plus_bom_total = v_roll_plus_bom_total,
        labor_pct = v_labor_pct,
        accessories_total = v_accessories_total,
        total_msrp = v_total_msrp,
        updated_at = now()
    WHERE id = p_configured_product_id;

    -- 10. Retornar resultado
    RETURN jsonb_build_object(
        'roll_msrp_total', v_roll_msrp_total,
        'bom_total', v_bom_total,
        'roll_plus_bom_total', v_roll_plus_bom_total,
        'labor_pct', v_labor_pct,
        'accessories_total', v_accessories_total,
        'total_msrp', v_total_msrp
    );
END;
$$;

COMMENT ON FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") IS 
'Calcula y actualiza totals de ConfiguredProduct: roll_msrp_total, bom_total (sumando MSRP sale_out de todas las BOMInstanceLines), roll_plus_bom_total, y total_msrp final con labor y accessories.
✅ CORREGIDO: Usa BOMInstances y BOMInstanceLines (mayúsculas) en lugar de tablas antiguas.';

COMMIT;
