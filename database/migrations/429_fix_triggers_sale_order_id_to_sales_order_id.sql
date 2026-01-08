-- ====================================================
-- Migration 429: Fix Triggers - sale_order_id → sales_order_id
-- ====================================================
-- PROBLEMA: Varios triggers/funciones usan sale_order_id (sin 's') cuando debe ser sales_order_id (con 's')
-- ERROR: "record 'new' has no field 'sale_order_id'"
-- ====================================================

SET search_path = public;

-- ====================================================
-- FUNCTION 1: on_manufacturing_order_deleted_delete_bom
-- ====================================================
-- Trigger: AFTER UPDATE OF deleted ON ManufacturingOrders
-- Usa: OLD.sale_order_id → debe ser OLD.sales_order_id
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_manufacturing_order_deleted_delete_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_order_id uuid;
    v_bom_instance_ids uuid[];
    v_deleted_bom_instances_count integer;
    v_deleted_bom_lines_count integer;
BEGIN
    -- Get sales_order_id from the deleted ManufacturingOrder
    v_sale_order_id := OLD.sales_order_id;  -- ✅ CORREGIDO: sales_order_id (con 's')
    
    IF v_sale_order_id IS NULL THEN
        RETURN OLD;
    END IF;
    
    RAISE NOTICE '🔔 ManufacturingOrder % deleted, cleaning up BOM for SaleOrder %', OLD.id, v_sale_order_id;
    
    -- Get all BomInstance IDs related to this SaleOrder (through SaleOrderLines)
    SELECT ARRAY_AGG(bi.id) INTO v_bom_instance_ids
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sales_order_id = v_sale_order_id  -- ✅ CORREGIDO: sales_order_id (con 's')
    AND bi.deleted = false;
    
    IF v_bom_instance_ids IS NULL OR array_length(v_bom_instance_ids, 1) = 0 THEN
        RAISE NOTICE '⏭️  No BomInstances found for SaleOrder %, nothing to delete', v_sale_order_id;
        RETURN OLD;
    END IF;
    
    -- Soft delete BomInstanceLines first (child records)
    UPDATE "BomInstanceLines"
    SET deleted = true,
        updated_at = now()
    WHERE bom_instance_id = ANY(v_bom_instance_ids)
    AND deleted = false;
    
    GET DIAGNOSTICS v_deleted_bom_lines_count = ROW_COUNT;
    
    -- Soft delete BomInstances
    UPDATE "BomInstances"
    SET deleted = true,
        updated_at = now()
    WHERE id = ANY(v_bom_instance_ids)
    AND deleted = false;
    
    GET DIAGNOSTICS v_deleted_bom_instances_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Deleted % BomInstances and % BomInstanceLines for SaleOrder %', 
        v_deleted_bom_instances_count, v_deleted_bom_lines_count, v_sale_order_id;
    
    RETURN OLD;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_manufacturing_order_deleted_delete_bom for ManufacturingOrder %: %', OLD.id, SQLERRM;
        RETURN OLD;
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_deleted_delete_bom IS 
'Soft-deletes BomInstances and BomInstanceLines when a ManufacturingOrder is deleted. FIXED: Uses sales_order_id (with s) instead of sale_order_id.';

-- ====================================================
-- FUNCTION 2: on_manufacturing_order_status_change
-- ====================================================
-- Trigger: AFTER UPDATE OF status ON ManufacturingOrders
-- Usa: NEW.sale_order_id y OLD.sale_order_id → debe ser NEW.sales_order_id y OLD.sales_order_id
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_manufacturing_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_order_id uuid;
    v_mapped_status text;
    v_current_so_status text;
BEGIN
    -- Only process if status actually changed
    IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
        RETURN NEW;
    END IF;
    
    -- Get sales_order_id from ManufacturingOrder
    v_sale_order_id := COALESCE(NEW.sales_order_id, OLD.sales_order_id);  -- ✅ CORREGIDO: sales_order_id (con 's')
    
    IF v_sale_order_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Get current SaleOrder status
    SELECT status INTO v_current_so_status
    FROM "SalesOrders"
    WHERE id = v_sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Rule 1: Never overwrite 'Delivered'
    IF v_current_so_status = 'Delivered' THEN
        RAISE NOTICE '⏭️  SaleOrder % status is "Delivered", skipping automatic update from ManufacturingOrder %', 
            v_sale_order_id, COALESCE(NEW.id, OLD.id);
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Map ManufacturingOrder status to SaleOrder status
    v_mapped_status := public.map_mo_status_to_so_status(NEW.status);
    
    -- Only update if mapping exists and status would change
    IF v_mapped_status IS NOT NULL AND v_mapped_status IS DISTINCT FROM v_current_so_status THEN
        UPDATE "SalesOrders"
        SET status = v_mapped_status,
            updated_at = now()
        WHERE id = v_sale_order_id
        AND deleted = false
        AND status <> 'Delivered'; -- Extra safety check
        
        RAISE NOTICE '✅ Updated SaleOrder % status from "%" to "%" (triggered by ManufacturingOrder % status: %)', 
            v_sale_order_id, v_current_so_status, v_mapped_status, COALESCE(NEW.id, OLD.id), NEW.status;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_status_change IS 
'Syncs SaleOrders.status from ManufacturingOrders.status changes. FIXED: Uses sales_order_id (with s) instead of sale_order_id.';

-- ====================================================
-- FUNCTION 3: sync_sale_order_progress_from_manufacturing
-- ====================================================
-- Trigger: AFTER INSERT OR UPDATE ON ManufacturingOrders
-- Usa: NEW.sale_order_id y OLD.sale_order_id → debe ser NEW.sales_order_id y OLD.sales_order_id
-- ====================================================

CREATE OR REPLACE FUNCTION public.sync_sale_order_progress_from_manufacturing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_order_id uuid;
    v_new_status text;
    v_current_status text;
    v_manufacturing_status text;
BEGIN
    -- Get sales_order_id from ManufacturingOrder
    v_sale_order_id := COALESCE(NEW.sales_order_id, OLD.sales_order_id);  -- ✅ CORREGIDO: sales_order_id (con 's')
    
    IF v_sale_order_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Get current order_progress_status
    SELECT order_progress_status INTO v_current_status
    FROM "SalesOrders"
    WHERE id = v_sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Determine new status based on ManufacturingOrder changes
    IF TG_OP = 'INSERT' THEN
        -- ManufacturingOrder created -> set to 'scheduled'
        v_new_status := 'scheduled';
        RAISE NOTICE '🔔 ManufacturingOrder % created for SaleOrder %, setting order_progress_status to scheduled', 
            COALESCE(NEW.id, 'unknown'), v_sale_order_id;
    ELSIF TG_OP = 'UPDATE' AND TG_LEVEL = 'ROW' THEN
        -- ManufacturingOrder status changed
        v_manufacturing_status := NEW.status;
        
        IF v_manufacturing_status = 'in_production' THEN
            v_new_status := 'in_production';
            RAISE NOTICE '🔔 ManufacturingOrder % status changed to in_production for SaleOrder %, setting order_progress_status to in_production', 
                NEW.id, v_sale_order_id;
        ELSIF v_manufacturing_status = 'completed' THEN
            v_new_status := 'production_completed';
            RAISE NOTICE '🔔 ManufacturingOrder % status changed to completed for SaleOrder %, setting order_progress_status to production_completed', 
                NEW.id, v_sale_order_id;
        ELSE
            -- No status change needed
            RETURN COALESCE(NEW, OLD);
        END IF;
    ELSE
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Update SaleOrder order_progress_status if it would change
    IF v_new_status IS NOT NULL AND v_new_status IS DISTINCT FROM v_current_status THEN
        UPDATE "SalesOrders"
        SET order_progress_status = v_new_status,
            updated_at = now()
        WHERE id = v_sale_order_id
        AND deleted = false;
        
        RAISE NOTICE '✅ Updated SaleOrder % order_progress_status from "%" to "%"', 
            v_sale_order_id, v_current_status, v_new_status;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION public.sync_sale_order_progress_from_manufacturing IS 
'Syncs SaleOrders.order_progress_status from ManufacturingOrders changes. FIXED: Uses sales_order_id (with s) instead of sale_order_id.';

-- ====================================================
-- FUNCTION 4: create_bom_instances_for_manufacturing_order
-- ====================================================
-- Esta función se llama desde el trigger on_manufacturing_order_created_create_bom
-- Usa: mo.sale_order_id → debe ser mo.sales_order_id
-- ====================================================

CREATE OR REPLACE FUNCTION public.create_bom_instances_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mo RECORD;
    v_so RECORD;
    v_sol RECORD;
    v_ql RECORD;
    v_qlc RECORD;
    v_bom_instance_id uuid;
    v_created_instances integer := 0;
    v_created_lines integer := 0;
    v_lines_for_instance integer := 0;
    v_validated_uom text;
BEGIN
    -- Get Manufacturing Order
    SELECT mo.id, mo.sales_order_id, mo.organization_id, mo.manufacturing_order_no  -- ✅ CORREGIDO: sales_order_id (con 's')
    INTO v_mo
    FROM "ManufacturingOrders" mo
    WHERE mo.id = p_manufacturing_order_id
    AND mo.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Creating BOM for Manufacturing Order: %', v_mo.manufacturing_order_no;
    
    -- Get Sale Order
    SELECT so.id, so.sale_order_no
    INTO v_so
    FROM "SalesOrders" so
    WHERE so.id = v_mo.sales_order_id  -- ✅ CORREGIDO: sales_order_id (con 's')
    AND so.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SaleOrder % not found for ManufacturingOrder %', v_mo.sales_order_id, p_manufacturing_order_id;  -- ✅ CORREGIDO
    END IF;
    
    RAISE NOTICE '   Sale Order: %', v_so.sale_order_no;
    
    -- Process each SalesOrderLine
    FOR v_sol IN
        SELECT sol.id, sol.quote_line_id, sol.line_number, sol.product_type_id
        FROM "SalesOrderLines" sol
        WHERE sol.sales_order_id = v_so.id  -- ✅ CORREGIDO: sales_order_id (con 's')
        AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        -- Check if BomInstance already exists
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sol.id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Get QuoteLine for bom_template_id
            SELECT ql.id, ql.bom_template_id
            INTO v_ql
            FROM "QuoteLines" ql
            WHERE ql.id = v_sol.quote_line_id
            AND ql.deleted = false
            LIMIT 1;
            
            -- Create BomInstance
            BEGIN
                INSERT INTO "BomInstances" (
                    organization_id,
                    sale_order_line_id,
                    quote_line_id,
                    bom_template_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_mo.organization_id,
                    v_sol.id,
                    v_sol.quote_line_id,
                    COALESCE(v_ql.bom_template_id, NULL),
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
                
                RAISE NOTICE '   ✅ Created BomInstance % for SalesOrderLine % (line_number: %)', 
                    v_bom_instance_id, v_sol.id, v_sol.line_number;
                v_created_instances := v_created_instances + 1;
                
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '   ❌ Error creating BomInstance for SalesOrderLine %: %', v_sol.id, SQLERRM;
                    CONTINUE;
            END;
        ELSE
            RAISE NOTICE '   ⏭️  BomInstance % already exists for SalesOrderLine %', v_bom_instance_id, v_sol.id;
        END IF;
        
        -- Create BomInstanceLines from QuoteLineComponents
        v_lines_for_instance := 0; -- Reset counter for this BomInstance
        
        FOR v_qlc IN
                SELECT 
                    qlc.id,
                    qlc.catalog_item_id,
                    qlc.component_role,
                    qlc.qty,
                    qlc.uom,
                    ci.sku,
                    ci.item_name,
                    ci.category_code
                FROM "QuoteLineComponents" qlc
                INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
                WHERE qlc.quote_line_id = v_sol.quote_line_id
                AND qlc.deleted = false
                AND qlc.source = 'configured_component'
                ORDER BY qlc.component_role
            LOOP
                -- Check if BomInstanceLine already exists
                IF EXISTS (
                    SELECT 1
                    FROM "BomInstanceLines" bil
                    WHERE bil.bom_instance_id = v_bom_instance_id
                    AND bil.resolved_part_id = v_qlc.catalog_item_id
                    AND COALESCE(bil.part_role, '') = COALESCE(v_qlc.component_role, '')
                    AND bil.deleted = false
                ) THEN
                    CONTINUE; -- Skip if already exists
                END IF;
                
                -- Normalize UOM
                v_validated_uom := CASE 
                    WHEN v_qlc.uom = 'm' THEN 'mts'
                    ELSE v_qlc.uom
                END;
                
                -- Create BomInstanceLine
                BEGIN
                    INSERT INTO "BomInstanceLines" (
                        bom_instance_id,
                        resolved_part_id,
                        resolved_sku,
                        part_role,
                        qty,
                        uom,
                        description,
                        category_code,
                        organization_id,
                        deleted,
                        created_at,
                        updated_at
                    ) VALUES (
                        v_bom_instance_id,
                        v_qlc.catalog_item_id,
                        v_qlc.sku,
                        v_qlc.component_role,
                        v_qlc.qty,
                        v_validated_uom,
                        COALESCE(v_qlc.item_name, ''),
                        v_qlc.category_code,
                        v_mo.organization_id,
                        false,
                        now(),
                        now()
                    );
                    
                    v_lines_for_instance := v_lines_for_instance + 1;
                    v_created_lines := v_created_lines + 1;
                    
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '   ❌ Error creating BomInstanceLine for component % (role: %): %', 
                            v_qlc.sku, v_qlc.component_role, SQLERRM;
                END;
        END LOOP;
        
        RAISE NOTICE '   📊 Created % BomInstanceLines for BomInstance %', v_lines_for_instance, v_bom_instance_id;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ BOM creation completed:';
    RAISE NOTICE '   - BomInstances created: %', v_created_instances;
    RAISE NOTICE '   - BomInstanceLines created: %', v_created_lines;
    
    RETURN jsonb_build_object(
        'success', true,
        'manufacturing_order_id', p_manufacturing_order_id,
        'bom_instances_created', v_created_instances,
        'bom_instance_lines_created', v_created_lines
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in create_bom_instances_for_manufacturing_order: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

COMMENT ON FUNCTION public.create_bom_instances_for_manufacturing_order IS 
'Creates BomInstances and BomInstanceLines for a ManufacturingOrder from SalesOrderLines and QuoteLineComponents. FIXED: Uses sales_order_id (with s) instead of sale_order_id.';

-- ====================================================
-- FUNCTION 5: reset_bom_for_manufacturing_order
-- ====================================================
-- Esta función se llama desde el frontend para resetear BOM
-- Usa: mo.sale_order_id → debe ser mo.sales_order_id
-- ====================================================

CREATE OR REPLACE FUNCTION public.reset_bom_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_manufacturing_order RECORD;
    v_sale_order RECORD;
    v_bom_instance_ids uuid[];
    v_deleted_lines_count integer := 0;
    v_deleted_instances_count integer := 0;
BEGIN
    -- Get ManufacturingOrder and SaleOrder
    SELECT mo.id, mo.organization_id, mo.sales_order_id  -- ✅ CORREGIDO: sales_order_id (con 's')
    INTO v_manufacturing_order
    FROM "ManufacturingOrders" mo
    WHERE mo.id = p_manufacturing_order_id
    AND mo.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    -- Get SaleOrder
    SELECT so.id, so.organization_id
    INTO v_sale_order
    FROM "SalesOrders" so
    WHERE so.id = v_manufacturing_order.sales_order_id  -- ✅ CORREGIDO: sales_order_id (con 's')
    AND so.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SaleOrder % not found for ManufacturingOrder %', v_manufacturing_order.sales_order_id, p_manufacturing_order_id;  -- ✅ CORREGIDO
    END IF;
    
    RAISE NOTICE '🔄 [Reset BOM] Starting reset for ManufacturingOrder % (SaleOrder: %)', 
        p_manufacturing_order_id, v_sale_order.id;
    
    -- Step A: Find all BomInstances associated with SaleOrderLines of this MO's SaleOrder
    SELECT ARRAY_AGG(bi.id)
    INTO v_bom_instance_ids
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sales_order_id = v_sale_order.id  -- ✅ CORREGIDO: sales_order_id (con 's')
    AND bi.deleted = false;
    
    -- Step B: Soft-delete BomInstanceLines
    IF v_bom_instance_ids IS NOT NULL AND array_length(v_bom_instance_ids, 1) > 0 THEN
        UPDATE "BomInstanceLines" bil
        SET deleted = true, updated_at = now()
        WHERE bil.bom_instance_id = ANY(v_bom_instance_ids)
        AND bil.deleted = false;
        
        GET DIAGNOSTICS v_deleted_lines_count = ROW_COUNT;
        RAISE NOTICE '   🗑️  Soft-deleted % BomInstanceLines', v_deleted_lines_count;
    END IF;
    
    -- Step C: Soft-delete BomInstances
    IF v_bom_instance_ids IS NOT NULL AND array_length(v_bom_instance_ids, 1) > 0 THEN
        UPDATE "BomInstances" bi
        SET deleted = true, updated_at = now()
        WHERE bi.id = ANY(v_bom_instance_ids)
        AND bi.deleted = false;
        
        GET DIAGNOSTICS v_deleted_instances_count = ROW_COUNT;
        RAISE NOTICE '   🗑️  Soft-deleted % BomInstances', v_deleted_instances_count;
    END IF;
    
    -- Return summary
    RETURN jsonb_build_object(
        'ok', true,
        'manufacturing_order_id', p_manufacturing_order_id,
        'sale_order_id', v_sale_order.id,
        'deleted_instances', v_deleted_instances_count,
        'deleted_lines', v_deleted_lines_count
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error in reset_bom_for_manufacturing_order: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.reset_bom_for_manufacturing_order IS 
'Soft-deletes all BomInstances and BomInstanceLines for a Manufacturing Order. FIXED: Uses sales_order_id (with s) instead of sale_order_id.';

-- ====================================================
-- VERIFICACIÓN: Confirmar que no existe sale_order_id en triggers/functions
-- ====================================================

DO $$
DECLARE
    v_func_name text;
    v_func_def text;
    v_has_sale_order_id boolean;
BEGIN
    -- Verificar funciones que podrían tener sale_order_id
    FOR v_func_name IN 
        SELECT proname 
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND proname IN (
            'on_manufacturing_order_deleted_delete_bom',
            'on_manufacturing_order_status_change',
            'sync_sale_order_progress_from_manufacturing',
            'mo_after_insert_populate_lines',
            'on_manufacturing_order_created_create_bom',
            'create_bom_instances_for_manufacturing_order',
            'reset_bom_for_manufacturing_order'
        )
    LOOP
        SELECT pg_get_functiondef(p.oid) INTO v_func_def
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = v_func_name;
        
        -- Buscar sale_order_id (sin 's') en la definición
        v_has_sale_order_id := v_func_def LIKE '%sale_order_id%' 
                            AND v_func_def NOT LIKE '%sales_order_id%';
        
        IF v_has_sale_order_id THEN
            RAISE WARNING '⚠️ Function % still contains sale_order_id (without s)', v_func_name;
        ELSE
            RAISE NOTICE '✅ Function % verified: no sale_order_id found', v_func_name;
        END IF;
    END LOOP;
END $$;

