-- ====================================================
-- Fix BOM Trigger - Versión Final y Estable
-- ====================================================
-- Este script asegura que el trigger funcione correctamente
-- cuando se crea un Manufacturing Order desde OrderList
-- ====================================================

-- STEP 1: Verificar y corregir estructura de BomInstanceLines
DO $$
BEGIN
    -- Verificar si organization_id existe en BomInstanceLines
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'BomInstanceLines' 
        AND column_name = 'organization_id'
    ) THEN
        RAISE NOTICE 'Agregando columna organization_id a BomInstanceLines...';
        ALTER TABLE "BomInstanceLines" ADD COLUMN organization_id uuid;
        CREATE INDEX IF NOT EXISTS idx_bominstancelines_organization_id ON "BomInstanceLines"(organization_id);
        RAISE NOTICE '✅ Columna organization_id agregada a BomInstanceLines';
    ELSE
        RAISE NOTICE '✅ Columna organization_id ya existe en BomInstanceLines';
    END IF;
END;
$$;

-- STEP 2: Recrear función con lógica completa y robusta
CREATE OR REPLACE FUNCTION public.on_manufacturing_order_insert_generate_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sales_order_record RECORD;
    v_quote_id uuid;
    v_quote_line_record RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component_record RECORD;
    v_canonical_uom text;
    v_unit_cost_exw numeric;
    v_total_cost_exw numeric;
    v_category_code text;
    v_copied_count integer;
BEGIN
    -- Get SalesOrder record (FIXED: Use "SalesOrders" plural)
    SELECT * INTO v_sales_order_record
    FROM "SalesOrders"
    WHERE id = NEW.sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '⚠️ SalesOrder % not found for ManufacturingOrder %', NEW.sale_order_id, NEW.id;
        RETURN NEW;
    END IF;
    
    v_quote_id := v_sales_order_record.quote_id;
    
    RAISE NOTICE '🔔 ManufacturingOrder % created manually, generating BOM for SalesOrder %', NEW.manufacturing_order_no, v_sales_order_record.sale_order_no;
    
    -- Update SalesOrder status to 'In Production' (FIXED: Use "SalesOrders" plural)
    UPDATE "SalesOrders"
    SET status = 'In Production',
        updated_at = now()
    WHERE id = NEW.sale_order_id
    AND deleted = false
    AND status <> 'Delivered';
    
    -- Generate BOM for all QuoteLines in this SalesOrder
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.product_type_id,
            ql.organization_id,
            ql.drive_type,
            ql.bottom_rail_type,
            COALESCE(ql.cassette, false) as cassette,
            ql.cassette_type,
            COALESCE(ql.side_channel, false) as side_channel,
            ql.side_channel_type,
            ql.hardware_color,
            ql.width_m,
            ql.height_m,
            ql.qty,
            sol.id as sale_order_line_id
        FROM "SalesOrderLines" sol
        INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
        WHERE sol.sale_order_id = NEW.sale_order_id
            AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        -- Skip if no product_type_id
        IF v_quote_line_record.product_type_id IS NULL THEN
            RAISE NOTICE '⚠️ QuoteLine % has no product_type_id, skipping BOM generation', v_quote_line_record.quote_line_id;
            CONTINUE;
        END IF;
        
        -- Ensure organization_id is set
        IF v_quote_line_record.organization_id IS NULL THEN
            UPDATE "QuoteLines"
            SET organization_id = NEW.organization_id
            WHERE id = v_quote_line_record.quote_line_id;
            v_quote_line_record.organization_id := NEW.organization_id;
        END IF;
        
        -- Generate BOM for this QuoteLine
        BEGIN
            RAISE NOTICE '🔧 Generating BOM for QuoteLine %...', v_quote_line_record.quote_line_id;
            
            -- Generate QuoteLineComponents using the function
            v_result := public.generate_configured_bom_for_quote_line(
                v_quote_line_record.quote_line_id,
                v_quote_line_record.product_type_id,
                v_quote_line_record.organization_id,
                v_quote_line_record.drive_type,
                v_quote_line_record.bottom_rail_type,
                v_quote_line_record.cassette,
                v_quote_line_record.cassette_type,
                v_quote_line_record.side_channel,
                v_quote_line_record.side_channel_type,
                v_quote_line_record.hardware_color,
                v_quote_line_record.width_m,
                v_quote_line_record.height_m,
                v_quote_line_record.qty
            );
            
            RAISE NOTICE '✅ generate_configured_bom_for_quote_line executed for QuoteLine %', v_quote_line_record.quote_line_id;
            
            -- Find or create BomInstance for this SaleOrderLine
            SELECT id INTO v_bom_instance_id
            FROM "BomInstances"
            WHERE sale_order_line_id = v_quote_line_record.sale_order_line_id
            AND deleted = false
            LIMIT 1;
            
            IF NOT FOUND THEN
                INSERT INTO "BomInstances" (
                    organization_id,
                    sale_order_line_id,
                    quote_line_id,
                    configured_product_id,
                    status,
                    created_at,
                    updated_at
                ) VALUES (
                    NEW.organization_id,
                    v_quote_line_record.sale_order_line_id,
                    v_quote_line_record.quote_line_id,
                    NULL, -- configured_product_id can be NULL
                    'locked', -- Status: locked because it's for a Manufacturing Order
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
                
                RAISE NOTICE '✅ Created BomInstance % for SaleOrderLine %', v_bom_instance_id, v_quote_line_record.sale_order_line_id;
            ELSE
                RAISE NOTICE '✅ BomInstance % already exists for SaleOrderLine %', v_bom_instance_id, v_quote_line_record.sale_order_line_id;
            END IF;
            
            -- CRITICAL: Copy QuoteLineComponents to BomInstanceLines
            -- This is the key step that must work
            RAISE NOTICE '🔧 Copying QuoteLineComponents to BomInstanceLines for BomInstance %...', v_bom_instance_id;
            v_copied_count := 0;
            
            FOR v_component_record IN
                SELECT
                    qlc.*,
                    ci.item_name,
                    ci.sku
                FROM "QuoteLineComponents" qlc
                INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
                WHERE qlc.quote_line_id = v_quote_line_record.quote_line_id
                AND qlc.source = 'configured_component'
                AND qlc.deleted = false
                AND ci.deleted = false
            LOOP
                BEGIN
                    -- Normalize UOM to canonical form
                    v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
                    
                    -- Get unit cost in the correct UOM
                    v_unit_cost_exw := public.get_unit_cost_in_uom(
                        v_component_record.catalog_item_id,
                        v_canonical_uom,
                        NEW.organization_id
                    );
                    
                    -- Fallback to stored unit_cost_exw if function returns NULL or 0
                    IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                        v_unit_cost_exw := COALESCE(v_component_record.unit_cost_exw, 0);
                    END IF;
                    
                    -- Calculate total cost
                    v_total_cost_exw := v_component_record.qty * v_unit_cost_exw;
                    
                    -- Derive category code from component role
                    v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
                    
                    -- Insert or update BomInstanceLine
                    -- CRITICAL: Include organization_id if column exists, otherwise skip it
                    -- First check if organization_id column exists
                    IF EXISTS (
                        SELECT 1 FROM information_schema.columns
                        WHERE table_name = 'BomInstanceLines'
                        AND column_name = 'organization_id'
                    ) THEN
                        -- Insert WITH organization_id
                        INSERT INTO "BomInstanceLines" (
                            bom_instance_id,
                            source_template_line_id,
                            resolved_part_id,
                            resolved_sku,
                            part_role,
                            qty,
                            uom,
                            description,
                            unit_cost_exw,
                            total_cost_exw,
                            category_code,
                            organization_id, -- CRITICAL: Include organization_id
                            created_at,
                            updated_at,
                            deleted
                        ) VALUES (
                            v_bom_instance_id,
                            NULL, -- source_template_line_id (optional)
                            v_component_record.catalog_item_id,
                            v_component_record.sku,
                            v_component_record.component_role,
                            v_component_record.qty,
                            v_canonical_uom,
                            v_component_record.item_name, -- Use item_name from CatalogItems
                            v_unit_cost_exw,
                            v_total_cost_exw,
                            v_category_code,
                            NEW.organization_id, -- CRITICAL: Set organization_id
                            now(),
                            now(),
                            false
                        ) ON CONFLICT (bom_instance_id, resolved_part_id, part_role, uom, deleted) DO UPDATE SET
                            qty = EXCLUDED.qty,
                            unit_cost_exw = EXCLUDED.unit_cost_exw,
                            total_cost_exw = EXCLUDED.total_cost_exw,
                            description = EXCLUDED.description,
                            organization_id = EXCLUDED.organization_id, -- Update organization_id too
                            updated_at = now();
                    ELSE
                        -- Insert WITHOUT organization_id (fallback for older schemas)
                        INSERT INTO "BomInstanceLines" (
                            bom_instance_id,
                            source_template_line_id,
                            resolved_part_id,
                            resolved_sku,
                            part_role,
                            qty,
                            uom,
                            description,
                            unit_cost_exw,
                            total_cost_exw,
                            category_code,
                            created_at,
                            updated_at,
                            deleted
                        ) VALUES (
                            v_bom_instance_id,
                            NULL, -- source_template_line_id (optional)
                            v_component_record.catalog_item_id,
                            v_component_record.sku,
                            v_component_record.component_role,
                            v_component_record.qty,
                            v_canonical_uom,
                            v_component_record.item_name, -- Use item_name from CatalogItems
                            v_unit_cost_exw,
                            v_total_cost_exw,
                            v_category_code,
                            now(),
                            now(),
                            false
                        ) ON CONFLICT (bom_instance_id, resolved_part_id, part_role, uom, deleted) DO UPDATE SET
                            qty = EXCLUDED.qty,
                            unit_cost_exw = EXCLUDED.unit_cost_exw,
                            total_cost_exw = EXCLUDED.total_cost_exw,
                            description = EXCLUDED.description,
                            updated_at = now();
                    END IF;
                    
                    v_copied_count := v_copied_count + 1;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '❌ Error copying QuoteLineComponent % to BomInstanceLines: %', v_component_record.id, SQLERRM;
                        RAISE WARNING '   SQLSTATE: %', SQLSTATE;
                END;
            END LOOP;
            
            RAISE NOTICE '✅ Copied % QuoteLineComponents to BomInstanceLines for BomInstance %', v_copied_count, v_bom_instance_id;
            
            IF v_copied_count = 0 THEN
                RAISE WARNING '⚠️ No QuoteLineComponents were copied to BomInstanceLines for QuoteLine %', v_quote_line_record.quote_line_id;
                RAISE WARNING '   This may indicate that generate_configured_bom_for_quote_line did not create QuoteLineComponents';
            END IF;
            
            RAISE NOTICE '✅ BOM generated for QuoteLine %', v_quote_line_record.quote_line_id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error generating BOM for QuoteLine %: %', v_quote_line_record.quote_line_id, SQLERRM;
                RAISE WARNING '   SQLSTATE: %', SQLSTATE;
        END;
    END LOOP;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_manufacturing_order_insert_generate_bom for ManufacturingOrder %: %', NEW.id, SQLERRM;
        RAISE WARNING '   SQLSTATE: %', SQLSTATE;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_insert_generate_bom IS 
'Generates BOM automatically when a ManufacturingOrder is created manually from OrderList. This is the ONLY point where BOM is generated. Updates SO status to "In Production". Uses "SalesOrders" (plural) table name. CRITICAL: Copies QuoteLineComponents to BomInstanceLines after generating them. Includes organization_id for multi-organization support.';

-- STEP 3: Asegurar que el trigger existe y está activo
DROP TRIGGER IF EXISTS trg_mo_insert_generate_bom ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_insert_generate_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.on_manufacturing_order_insert_generate_bom();

COMMENT ON TRIGGER trg_mo_insert_generate_bom ON "ManufacturingOrders" IS 
'Automatically generates BOM when a ManufacturingOrder is created manually from OrderList. This is the ONLY point where BOM is generated.';

-- STEP 4: Verificación final
DO $$
DECLARE
    v_function_exists boolean;
    v_trigger_exists boolean;
    v_trigger_enabled boolean;
    v_org_id_column_exists boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Trigger reparado exitosamente!';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Verificando estado final...';
    
    -- Verificar función
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_manufacturing_order_insert_generate_bom'
    ) INTO v_function_exists;
    IF v_function_exists THEN
        RAISE NOTICE '✅ Función existe y está activa';
    ELSE
        RAISE WARNING '❌ Función NO existe después de la reparación';
    END IF;

    -- Verificar trigger
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'ManufacturingOrders'
        AND tgname = 'trg_mo_insert_generate_bom'
        AND t.tgenabled = 'O'
    ) INTO v_trigger_exists;
    IF v_trigger_exists THEN
        RAISE NOTICE '✅ Trigger existe y está ACTIVO';
    ELSE
        SELECT EXISTS (
            SELECT 1 FROM pg_trigger t
            JOIN pg_class c ON t.tgrelid = c.oid
            WHERE c.relname = 'ManufacturingOrders'
            AND tgname = 'trg_mo_insert_generate_bom'
        ) INTO v_trigger_enabled;
        
        IF v_trigger_enabled THEN
            RAISE WARNING '⚠️ Trigger existe pero está DESHABILITADO';
        ELSE
            RAISE WARNING '❌ Trigger NO existe después de la reparación';
        END IF;
    END IF;
    
    -- Verificar columna organization_id en BomInstanceLines
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'BomInstanceLines'
        AND column_name = 'organization_id'
    ) INTO v_org_id_column_exists;
    IF v_org_id_column_exists THEN
        RAISE NOTICE '✅ Columna organization_id existe en BomInstanceLines';
    ELSE
        RAISE WARNING '⚠️ Columna organization_id NO existe en BomInstanceLines';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE 'El trigger ahora generará BOM cuando se cree un Manufacturing Order.';
    RAISE NOTICE 'CRITICAL: Copia QuoteLineComponents a BomInstanceLines automáticamente.';
    RAISE NOTICE 'CRITICAL: Incluye organization_id para soporte multi-organización.';
END;
$$;

