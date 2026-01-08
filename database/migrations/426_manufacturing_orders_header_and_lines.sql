-- ============================================================
-- MIGRATION: ManufacturingOrders -> Header + MO Lines (robusto)
-- Objetivo:
-- 1) Crear ManufacturingOrderLines (tabla hija)
-- 2) Asegurar que ManufacturingOrders use sale_order_id (header)
-- 3) Backfill: crear MO Lines a partir de SalesOrderLines existentes
-- 4) Update: generate_bom_for_manufacturing_order_v2(mo_id) para usar MO Lines
-- 5) Trigger opcional: al crear MO, auto-popular sus líneas
-- ============================================================

SET search_path = public;

BEGIN;

-- ============================================================
-- STEP 1) Crear tabla hija: ManufacturingOrderLines
-- ============================================================
CREATE TABLE IF NOT EXISTS public."ManufacturingOrderLines" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    manufacturing_order_id uuid NOT NULL,
    sales_order_line_id uuid NOT NULL,
    
    -- opcional pero útil para multi-tenant / scoping
    organization_id uuid NULL,
    
    status text NOT NULL DEFAULT 'planned', -- planned | in_production | completed | cancelled
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

-- FK: MO header
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'molines_manufacturing_order_fk'
    ) THEN
        ALTER TABLE public."ManufacturingOrderLines"
            ADD CONSTRAINT molines_manufacturing_order_fk
            FOREIGN KEY (manufacturing_order_id)
            REFERENCES public."ManufacturingOrders"(id)
            ON DELETE CASCADE;
    END IF;
END $$;

-- FK: SalesOrderLines
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'molines_sales_order_line_fk'
    ) THEN
        ALTER TABLE public."ManufacturingOrderLines"
            ADD CONSTRAINT molines_sales_order_line_fk
            FOREIGN KEY (sales_order_line_id)
            REFERENCES public."SalesOrderLines"(id)
            ON DELETE RESTRICT;
    END IF;
END $$;

-- FK: Organizations (opcional, pero buena práctica)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'molines_organization_fk'
    ) THEN
        ALTER TABLE public."ManufacturingOrderLines"
            ADD CONSTRAINT molines_organization_fk
            FOREIGN KEY (organization_id)
            REFERENCES public."Organizations"(id)
            ON DELETE SET NULL;
    END IF;
END $$;

-- Evitar duplicados: misma línea no puede estar 2 veces en el mismo MO
CREATE UNIQUE INDEX IF NOT EXISTS molines_unique_per_mo
    ON public."ManufacturingOrderLines"(manufacturing_order_id, sales_order_line_id)
    WHERE deleted = false;

CREATE INDEX IF NOT EXISTS molines_mo_idx
    ON public."ManufacturingOrderLines"(manufacturing_order_id)
    WHERE deleted = false;

CREATE INDEX IF NOT EXISTS molines_sol_idx
    ON public."ManufacturingOrderLines"(sales_order_line_id)
    WHERE deleted = false;

CREATE INDEX IF NOT EXISTS molines_org_idx
    ON public."ManufacturingOrderLines"(organization_id)
    WHERE deleted = false;

-- updated_at helper (si ya tienes una función genérica, puedes reutilizarla)
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_molines_set_updated_at ON public."ManufacturingOrderLines";
CREATE TRIGGER trg_molines_set_updated_at
    BEFORE UPDATE ON public."ManufacturingOrderLines"
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- STEP 2) Asegurar que ManufacturingOrders tenga sales_order_id (header)
-- (si ya existe, no hace nada; si no existe, lo crea)
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
            AND table_name = 'ManufacturingOrders'
            AND column_name = 'sales_order_id'
    ) THEN
        ALTER TABLE public."ManufacturingOrders"
            ADD COLUMN sales_order_id uuid;
    END IF;
END $$;

-- FK sales_order_id -> SalesOrders
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'manufacturingorders_sales_order_fk'
    ) THEN
        ALTER TABLE public."ManufacturingOrders"
            ADD CONSTRAINT manufacturingorders_sales_order_fk
            FOREIGN KEY (sales_order_id)
            REFERENCES public."SalesOrders"(id)
            ON DELETE SET NULL;
    END IF;
END $$;

-- ============================================================
-- STEP 3) Backfill MO Lines
-- - Para cada ManufacturingOrder con sales_order_id
--   insertamos líneas hijas desde SalesOrderLines
-- - Si ya existen, skip por el unique index
-- ============================================================
INSERT INTO public."ManufacturingOrderLines" (
    manufacturing_order_id,
    sales_order_line_id,
    organization_id
)
SELECT
    mo.id AS manufacturing_order_id,
    sol.id AS sales_order_line_id,
    COALESCE(mo.organization_id, sol.organization_id) AS organization_id
FROM public."ManufacturingOrders" mo
JOIN public."SalesOrderLines" sol
    ON sol.sales_order_id = mo.sales_order_id
WHERE mo.sales_order_id IS NOT NULL
    AND COALESCE(mo.deleted, false) = false
    AND COALESCE(mo.archived, false) = false
    AND COALESCE(sol.deleted, false) = false
    AND COALESCE(sol.archived, false) = false
ON CONFLICT (manufacturing_order_id, sales_order_line_id) DO NOTHING;

-- ============================================================
-- STEP 4) Actualizar generate_bom_for_manufacturing_order_v2(mo_id)
-- - Nuevo contrato: MO (header) -> MO Lines -> SalesOrderLines
-- - Ya NO depende de mo.sales_order_line_id
-- - Usa la lógica STRICT de la migración 425
-- ============================================================

CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order_v2(
    p_manufacturing_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_mo RECORD;
    v_count_lines integer := 0;
    v_mo_line RECORD;
    v_sales_order_line RECORD;
    v_bom_instance_id uuid;
    v_bom_template_id uuid;
    v_bom_component RECORD;
    v_catalog_item RECORD;
    v_fabric_count integer := 0;
    v_calculated_qty numeric;
    v_normalized_uom text;
    v_category_code text;
    v_unit_cost_exw numeric(12,4) := 0;
    v_total_cost_exw numeric(12,4) := 0;
    v_unit_msrp_sale_out numeric(12,4) := 0;
    v_total_msrp_sale_out numeric(12,4) := 0;
    v_bom_total_cost numeric(12,4) := 0;
    v_bom_labor_cost numeric(12,4) := 0;
    v_bom_total_cost_with_labor numeric(12,4) := 0;
    v_bom_msrp_sale_out numeric(12,4) := 0;
    v_cost_settings RECORD;
    v_shipping_percentage numeric(8,4) := 0;
    v_import_tax_percentage numeric(8,4) := 0;
    v_min_margin_pct numeric(8,4) := 35.0;
    v_max_discount_pct numeric(8,4) := 65.0;
    v_labor_percentage numeric(8,4) := 0;
    v_created_lines integer := 0;
    v_errors text[] := ARRAY[]::text[];
    v_formula_params jsonb;
    v_results jsonb := '[]'::jsonb;
    v_line_result jsonb;
BEGIN
    -- ====================================================
    -- STEP 1: Load ManufacturingOrder
    -- ====================================================
    SELECT *
    INTO v_mo
    FROM public."ManufacturingOrders"
    WHERE id = p_manufacturing_order_id;
    
    IF v_mo.id IS NULL THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    IF v_mo.deleted = true THEN
        RAISE EXCEPTION 'ManufacturingOrder % is deleted', p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '🚀 Starting STRICT BOM generation for ManufacturingOrder: % (Organization: %)', 
        v_mo.id, v_mo.organization_id;
    
    -- ====================================================
    -- STEP 2: Check/auto-create ManufacturingOrderLines
    -- ====================================================
    SELECT COUNT(*)
    INTO v_count_lines
    FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = p_manufacturing_order_id
        AND deleted = false
        AND archived = false;
    
    IF v_count_lines = 0 THEN
        IF v_mo.sales_order_id IS NULL THEN
            RAISE EXCEPTION 'ManufacturingOrder % has no sales_order_id and no MO lines', p_manufacturing_order_id;
        END IF;
        
        -- Auto-create lines from SalesOrderLines
        INSERT INTO public."ManufacturingOrderLines"(
            manufacturing_order_id, 
            sales_order_line_id, 
            organization_id
        )
        SELECT
            v_mo.id,
            sol.id,
            COALESCE(v_mo.organization_id, sol.organization_id)
FROM public."SalesOrderLines" sol
    WHERE sol.sales_order_id = v_mo.sales_order_id
            AND COALESCE(sol.deleted, false) = false
            AND COALESCE(sol.archived, false) = false
        ON CONFLICT (manufacturing_order_id, sales_order_line_id) DO NOTHING;
        
        SELECT COUNT(*)
        INTO v_count_lines
        FROM public."ManufacturingOrderLines"
        WHERE manufacturing_order_id = p_manufacturing_order_id
            AND deleted = false
            AND archived = false;
        
        IF v_count_lines = 0 THEN
            RAISE EXCEPTION 'ManufacturingOrder % has sales_order_id %, but no SalesOrderLines found',
                p_manufacturing_order_id, v_mo.sales_order_id;
        END IF;
        
        RAISE NOTICE '✅ Auto-created % ManufacturingOrderLines from SalesOrder %', 
            v_count_lines, v_mo.sales_order_id;
    END IF;
    
    -- ====================================================
    -- STEP 3: Load CostSettings (once for all lines)
    -- ====================================================
    SELECT 
        shipping_percentage,
        import_tax_percent,
        min_margin_pct,
        discount_distributor_pct,
        labor_percentage
    INTO v_cost_settings
    FROM "CostSettings"
    WHERE organization_id = v_mo.organization_id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        v_shipping_percentage := COALESCE(v_cost_settings.shipping_percentage, 0);
        v_import_tax_percentage := COALESCE(v_cost_settings.import_tax_percent, 0);
        v_min_margin_pct := COALESCE(v_cost_settings.min_margin_pct, 35.0);
        v_labor_percentage := COALESCE(v_cost_settings.labor_percentage, 0);
        v_max_discount_pct := COALESCE(v_cost_settings.discount_distributor_pct, 65.0);
    END IF;
    
    -- ====================================================
    -- STEP 4: Process each ManufacturingOrderLine
    -- ====================================================
    FOR v_mo_line IN
        SELECT mol.sales_order_line_id
        FROM public."ManufacturingOrderLines" mol
        WHERE mol.manufacturing_order_id = p_manufacturing_order_id
            AND mol.deleted = false
            AND mol.archived = false
        ORDER BY mol.created_at ASC
    LOOP
        -- Reset per-line variables
        v_bom_instance_id := NULL;
        v_bom_template_id := NULL;
        v_fabric_count := 0;
        v_bom_total_cost := 0;
        v_created_lines := 0;
        
        -- Load SalesOrderLine (SINGLE SOURCE OF TRUTH)
        SELECT 
            sol.id,
            sol.product_type,
            sol.collection_name,
            sol.variant_name,
            sol.width_m,
            sol.height_m,
            sol.area,
            sol.drive_type,
            sol.cassette,
            sol.cassette_type,
            sol.side_channel,
            sol.side_channel_type,
            sol.hardware_color,
            sol.bottom_rail_type,
            sol.quote_line_id
        INTO v_sales_order_line
        FROM "SalesOrderLines" sol
        WHERE sol.id = v_mo_line.sales_order_line_id
        AND sol.deleted = false;
        
        IF NOT FOUND THEN
            v_errors := v_errors || format('SalesOrderLine %s not found', v_mo_line.sales_order_line_id);
            CONTINUE;
        END IF;
        
        RAISE NOTICE '📦 Processing SalesOrderLine % (product_type: %, collection: %, variant: %)', 
            v_sales_order_line.id, v_sales_order_line.product_type, 
            v_sales_order_line.collection_name, v_sales_order_line.variant_name;
        
        -- Resolve BOMTemplate
        IF v_sales_order_line.product_type IS NULL OR TRIM(v_sales_order_line.product_type) = '' THEN
            v_errors := v_errors || format('SalesOrderLine %s has NULL or empty product_type', v_sales_order_line.id);
            CONTINUE;
        END IF;
        
        SELECT bt.id INTO v_bom_template_id
        FROM "BOMTemplates" bt
        INNER JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
        WHERE pt.code = v_sales_order_line.product_type
        AND bt.active = true
        AND bt.deleted = false
        ORDER BY bt.created_at DESC
        LIMIT 1;
        
        IF NOT FOUND THEN
            v_errors := v_errors || format('No active BOMTemplate found for product_type: %s (SalesOrderLine: %s)', 
                v_sales_order_line.product_type, v_sales_order_line.id);
            CONTINUE;
        END IF;
        
        -- Delete existing BOM for this SalesOrderLine
        UPDATE "BomInstanceLines" bil
        SET deleted = true, updated_at = now()
        WHERE bil.bom_instance_id IN (
            SELECT bi.id
            FROM "BomInstances" bi
            WHERE bi.sale_order_line_id = v_sales_order_line.id
            AND bi.deleted = false
        );
        
        UPDATE "BomInstances" bi
        SET deleted = true, updated_at = now()
        WHERE bi.sale_order_line_id = v_sales_order_line.id
        AND bi.deleted = false;
        
        -- Create new BomInstance
        INSERT INTO "BomInstances" (
            organization_id,
            sale_order_line_id,
            quote_line_id,
            bom_template_id,
            deleted,
            created_at,
            updated_at,
            generated_at
        ) VALUES (
            v_mo.organization_id,
            v_sales_order_line.id,
            v_sales_order_line.quote_line_id,
            v_bom_template_id,
            false,
            now(),
            now(),
            now()
        ) RETURNING id INTO v_bom_instance_id;
        
        -- Process BOMComponents (STRICT: NO auto-select, ONLY fixed components)
        FOR v_bom_component IN
            SELECT 
                bc.id,
                bc.component_role,
                bc.component_item_id,
                bc.qty_type,
                bc.qty_value,
                bc.qty_formula_code,
                bc.qty_formula_params,
                bc.uom
            FROM "BOMComponents" bc
            WHERE bc.bom_template_id = v_bom_template_id
            AND bc.deleted = false
            AND bc.component_item_id IS NOT NULL  -- ONLY fixed components (NO auto-select)
            ORDER BY bc.created_at
        LOOP
            -- STRICT FABRIC VALIDATION
            IF v_bom_component.component_role = 'fabric' THEN
                v_fabric_count := v_fabric_count + 1;
                
                IF v_fabric_count > 1 THEN
                    v_errors := v_errors || format('BOMTemplate %s allows MORE THAN ONE fabric component. Only EXACTLY ONE fabric is allowed. Component ID: %s', 
                        v_bom_template_id, v_bom_component.id);
                    CONTINUE;
                END IF;
                
                -- STRICT MATCH: collection_name + variant_name MUST match EXACTLY
                IF v_sales_order_line.collection_name IS NULL OR TRIM(v_sales_order_line.collection_name) = '' THEN
                    v_errors := v_errors || format('SalesOrderLine %s has NULL or empty collection_name. Cannot resolve fabric.', v_sales_order_line.id);
                    CONTINUE;
                END IF;
                
                -- Resolve fabric CatalogItem (EXACT match required)
                SELECT ci.id, ci.sku, ci.item_name, ci.description, ci.cost_exw
                INTO v_catalog_item
                FROM "CatalogItems" ci
                INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                WHERE ci.id = v_bom_component.component_item_id
                AND ci.organization_id = v_mo.organization_id
                AND ci.deleted = false
                AND ci.active = true
                AND ic.code = 'FABRIC'
                AND ci.collection_name = v_sales_order_line.collection_name
                AND (
                    (v_sales_order_line.variant_name IS NULL AND ci.variant_name IS NULL)
                    OR ci.variant_name = v_sales_order_line.variant_name
                );
                
                IF NOT FOUND THEN
                    v_errors := v_errors || format('Fabric CatalogItem %s does NOT match SalesOrderLine collection_name=%s variant_name=%s. EXACT match required. SalesOrderLine: %s', 
                        v_bom_component.component_item_id, 
                        v_sales_order_line.collection_name, 
                        v_sales_order_line.variant_name,
                        v_sales_order_line.id);
                    CONTINUE;
                END IF;
            ELSE
                -- Non-fabric component: use component_item_id directly
                SELECT ci.id, ci.sku, ci.item_name, ci.description, ci.cost_exw
                INTO v_catalog_item
                FROM "CatalogItems" ci
                WHERE ci.id = v_bom_component.component_item_id
                AND ci.organization_id = v_mo.organization_id
                AND ci.deleted = false
                AND ci.active = true;
                
                IF NOT FOUND THEN
                    v_errors := v_errors || format('CatalogItem %s (component_id: %s, role: %s) not found or inactive. SalesOrderLine: %s', 
                        v_bom_component.component_item_id, v_bom_component.id, v_bom_component.component_role,
                        v_sales_order_line.id);
                    CONTINUE;
                END IF;
            END IF;
            
            -- Calculate quantity (using ONLY SalesOrderLine dimensions)
            IF v_bom_component.qty_formula_code IS NOT NULL THEN
                IF v_bom_component.qty_formula_code = 'CHAIN_HEIGHT_FACTOR' THEN
                    v_formula_params := v_bom_component.qty_formula_params;
                    
                    IF v_formula_params IS NULL OR 
                       (v_formula_params->>'height_factor') IS NULL OR 
                       (v_formula_params->>'mult') IS NULL THEN
                        v_errors := v_errors || format('Invalid qty_formula_params for CHAIN_HEIGHT_FACTOR. Component: %s', v_bom_component.id);
                        CONTINUE;
                    END IF;
                    
                    IF v_sales_order_line.height_m IS NULL THEN
                        v_errors := v_errors || format('SalesOrderLine %s has NULL height_m. Cannot calculate CHAIN_HEIGHT_FACTOR. Component: %s', 
                            v_sales_order_line.id, v_bom_component.id);
                        CONTINUE;
                    END IF;
                    
                    v_calculated_qty := v_sales_order_line.height_m 
                        * COALESCE((v_formula_params->>'height_factor')::numeric, 0.75)
                        * COALESCE((v_formula_params->>'mult')::numeric, 2);
                ELSE
                    v_errors := v_errors || format('Unknown qty_formula_code: %s for component %s', 
                        v_bom_component.qty_formula_code, v_bom_component.id);
                    CONTINUE;
                END IF;
            ELSIF v_bom_component.qty_type = 'per_width' THEN
                IF v_sales_order_line.width_m IS NULL THEN
                    v_errors := v_errors || format('SalesOrderLine %s has NULL width_m. Cannot calculate per_width quantity. Component: %s', 
                        v_sales_order_line.id, v_bom_component.id);
                    CONTINUE;
                END IF;
                v_calculated_qty := v_sales_order_line.width_m * COALESCE(v_bom_component.qty_value, 1);
            ELSIF v_bom_component.qty_type = 'per_area' THEN
                IF v_sales_order_line.width_m IS NULL OR v_sales_order_line.height_m IS NULL THEN
                    v_errors := v_errors || format('SalesOrderLine %s has NULL width_m or height_m. Cannot calculate per_area quantity. Component: %s', 
                        v_sales_order_line.id, v_bom_component.id);
                    CONTINUE;
                END IF;
                v_calculated_qty := v_sales_order_line.width_m * v_sales_order_line.height_m * COALESCE(v_bom_component.qty_value, 1);
            ELSIF v_bom_component.qty_type = 'fixed' THEN
                v_calculated_qty := COALESCE(v_bom_component.qty_value, 1);
            ELSE
                v_errors := v_errors || format('Invalid or missing qty_type for component %s. Must be: fixed, per_width, per_area, or have qty_formula_code.', 
                    v_bom_component.id);
                CONTINUE;
            END IF;
            
            IF v_calculated_qty IS NULL OR v_calculated_qty <= 0 THEN
                v_errors := v_errors || format('Calculated qty is NULL or <= 0 for component %s. Component: %s, qty_type: %s, qty_value: %s', 
                    v_calculated_qty, v_bom_component.id, v_bom_component.qty_type, v_bom_component.qty_value);
                CONTINUE;
            END IF;
            
            -- Normalize UOM (MANDATORY)
            IF v_bom_component.uom IS NULL OR TRIM(v_bom_component.uom) = '' THEN
                v_errors := v_errors || format('Component %s has NULL or empty uom. UOM is MANDATORY.', v_bom_component.id);
                CONTINUE;
            END IF;
            
            v_normalized_uom := CASE 
                WHEN UPPER(TRIM(v_bom_component.uom)) IN ('PCS', 'PIECE', 'PIECES') THEN 'ea'
                WHEN UPPER(TRIM(v_bom_component.uom)) IN ('SET', 'SETS') THEN 'ea'
                WHEN v_bom_component.component_role = 'fabric' THEN 'm2'  -- Fabric ALWAYS m2
                WHEN v_bom_component.component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile', 'chain') THEN 'm'  -- Linear ALWAYS m
                WHEN UPPER(TRIM(v_bom_component.uom)) IN ('FT', 'FEET', 'FOOT', 'MTS', 'M', 'METER', 'METERS') THEN 'm'
                WHEN UPPER(TRIM(v_bom_component.uom)) IN ('M2', 'SQM', 'SQ_M') THEN 'm2'
                WHEN UPPER(TRIM(v_bom_component.uom)) IN ('EA', 'EACH') THEN 'ea'
                ELSE NULL
            END;
            
            IF v_normalized_uom IS NULL THEN
                v_errors := v_errors || format('Invalid UOM "%s" for component %s (role: %s). Allowed: m, m2, ea (or normalized: pcs→ea, set→ea, ft→m)', 
                    v_bom_component.uom, v_bom_component.id, v_bom_component.component_role);
                CONTINUE;
            END IF;
            
            -- Map category_code
            v_category_code := CASE 
                WHEN v_bom_component.component_role = 'fabric' THEN 'fabric'
                WHEN v_bom_component.component_role = 'tube' THEN 'tube'
                WHEN v_bom_component.component_role = 'motor' THEN 'motor'
                WHEN v_bom_component.component_role = 'bracket' THEN 'bracket'
                WHEN v_bom_component.component_role LIKE '%cassette%' THEN 'cassette'
                WHEN v_bom_component.component_role LIKE '%side_channel%' THEN 'side_channel'
                WHEN v_bom_component.component_role LIKE '%bottom_rail%' 
                     OR v_bom_component.component_role LIKE '%bottom_channel%' 
                     OR v_bom_component.component_role LIKE '%bottom_bar%' THEN 'bottom_channel'
                ELSE 'accessory'
            END;
            
            -- Calculate costs
            v_unit_cost_exw := COALESCE(CAST(v_catalog_item.cost_exw AS numeric(12,4)), 0);
            v_total_cost_exw := v_unit_cost_exw * v_calculated_qty;
            
            IF v_unit_cost_exw > 0 THEN
                DECLARE
                    v_unit_cost_with_taxes numeric(12,4);
                    v_msrp_sale_in numeric(12,4);
                BEGIN
                    v_unit_cost_with_taxes := v_unit_cost_exw * (1 + (v_shipping_percentage / 100.0) + (v_import_tax_percentage / 100.0));
                    v_msrp_sale_in := v_unit_cost_with_taxes / (1 - (v_min_margin_pct / 100.0));
                    v_unit_msrp_sale_out := v_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
                    v_total_msrp_sale_out := v_unit_msrp_sale_out * v_calculated_qty;
                END;
            ELSE
                v_unit_msrp_sale_out := 0;
                v_total_msrp_sale_out := 0;
            END IF;
            
            v_bom_total_cost := v_bom_total_cost + v_total_cost_exw;
            
            -- Insert BomInstanceLine
            INSERT INTO "BomInstanceLines" (
                organization_id,
                bom_instance_id,
                resolved_part_id,
                resolved_sku,
                part_role,
                qty,
                uom,
                description,
                category_code,
                unit_cost_exw,
                total_cost_exw,
                unit_msrp_sale_out,
                total_msrp_sale_out,
                cut_l_mm,
                deleted,
                created_at,
                updated_at
            ) VALUES (
                v_mo.organization_id,
                v_bom_instance_id,
                v_catalog_item.id,
                v_catalog_item.sku,
                v_bom_component.component_role,
                v_calculated_qty,
                v_normalized_uom,
                COALESCE(v_catalog_item.description, v_catalog_item.item_name),
                v_category_code,
                COALESCE(v_unit_cost_exw, 0)::numeric(12,4),
                COALESCE(v_total_cost_exw, 0)::numeric(12,4),
                COALESCE(v_unit_msrp_sale_out, 0)::numeric(12,4),
                COALESCE(v_total_msrp_sale_out, 0)::numeric(12,4),
                CASE 
                    WHEN v_bom_component.qty_type = 'per_width' 
                         OR v_bom_component.component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile')
                    THEN COALESCE(v_sales_order_line.width_m, 0) * 1000.0  -- Convert m to mm
                    ELSE NULL 
                END,
                false,
                now(),
                now()
            );
            
            v_created_lines := v_created_lines + 1;
        END LOOP;
        
        -- Calculate BOM-level costs (with labor)
        v_bom_labor_cost := v_bom_total_cost * (v_labor_percentage / 100.0);
        v_bom_total_cost_with_labor := v_bom_total_cost + v_bom_labor_cost;
        
        DECLARE
            v_bom_msrp_sale_in numeric(12,4);
        BEGIN
            v_bom_msrp_sale_in := v_bom_total_cost_with_labor / (1 - (v_min_margin_pct / 100.0));
            v_bom_msrp_sale_out := v_bom_msrp_sale_in / (1 - (v_max_discount_pct / 100.0));
        END;
        
        -- Update BomInstance with totals
        UPDATE "BomInstances"
        SET 
            labor_cost = v_bom_labor_cost,
            total_cost_with_labor = v_bom_total_cost_with_labor,
            total_msrp_sale_out_with_labor = v_bom_msrp_sale_out,
            updated_at = now()
        WHERE id = v_bom_instance_id;
        
        -- Build result for this line
        v_line_result := jsonb_build_object(
            'sales_order_line_id', v_sales_order_line.id,
            'bom_instance_id', v_bom_instance_id,
            'created_lines', v_created_lines,
            'total_cost', v_bom_total_cost_with_labor,
            'total_msrp_sale_out', v_bom_msrp_sale_out
        );
        
        v_results := v_results || jsonb_build_array(v_line_result);
    END LOOP;
    
    -- Return summary
    RETURN jsonb_build_object(
        'ok', array_length(v_errors, 1) IS NULL OR array_length(v_errors, 1) = 0,
        'manufacturing_order_id', p_manufacturing_order_id,
        'lines_count', v_count_lines,
        'results', v_results,
        'errors', COALESCE(v_errors, ARRAY[]::text[])
    );
END;
$$;

COMMENT ON FUNCTION public.generate_bom_for_manufacturing_order_v2 IS 
    'STRICT BOM generation: SalesOrderLine is the SINGLE SOURCE OF TRUTH. Processes all ManufacturingOrderLines. NO inference, NO auto-select, NO heuristics. Fabric MUST match collection_name + variant_name EXACTLY.';

GRANT EXECUTE ON FUNCTION public.generate_bom_for_manufacturing_order_v2(uuid) TO authenticated;

-- ============================================================
-- STEP 5) Trigger opcional: al crear MO, auto-popular líneas del SalesOrder
-- ============================================================
CREATE OR REPLACE FUNCTION public.mo_after_insert_populate_lines()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.sales_order_id IS NULL THEN
        RETURN NEW;
    END IF;
    
    INSERT INTO public."ManufacturingOrderLines"(
        manufacturing_order_id, 
        sales_order_line_id, 
        organization_id
    )
    SELECT
        NEW.id,
        sol.id,
        COALESCE(NEW.organization_id, sol.organization_id)
    FROM public."SalesOrderLines" sol
    WHERE sol.sales_order_id = NEW.sales_order_id
        AND COALESCE(sol.deleted, false) = false
        AND COALESCE(sol.archived, false) = false
    ON CONFLICT (manufacturing_order_id, sales_order_line_id) DO NOTHING;
    
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mo_after_insert_populate_lines ON public."ManufacturingOrders";
CREATE TRIGGER trg_mo_after_insert_populate_lines
    AFTER INSERT ON public."ManufacturingOrders"
    FOR EACH ROW
    EXECUTE FUNCTION public.mo_after_insert_populate_lines();

-- RLS Policies for ManufacturingOrderLines
ALTER TABLE public."ManufacturingOrderLines" ENABLE ROW LEVEL SECURITY;

-- SELECT: Users can see MO Lines for their organization
CREATE POLICY IF NOT EXISTS "molines_select_own_org"
    ON public."ManufacturingOrderLines"
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- INSERT: Users can create MO Lines for their organization
CREATE POLICY IF NOT EXISTS "molines_insert_own_org"
    ON public."ManufacturingOrderLines"
    FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- UPDATE: Users can update MO Lines for their organization
CREATE POLICY IF NOT EXISTS "molines_update_own_org"
    ON public."ManufacturingOrderLines"
    FOR UPDATE
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

COMMENT ON TABLE public."ManufacturingOrderLines" IS 'Lines (SalesOrderLines) associated with a ManufacturingOrder. One MO can have multiple lines.';

COMMIT;

