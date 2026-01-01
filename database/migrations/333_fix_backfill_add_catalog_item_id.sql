-- ====================================================
-- Migration 333: Fix Backfill - Add catalog_item_id
-- ====================================================
-- Corrige el backfill para incluir catalog_item_id (requerido)
-- ====================================================

DO $$
DECLARE
    v_so RECORD;
    v_ql RECORD;
    v_line_number integer;
    v_so_line_id uuid;
    v_created_count integer := 0;
    v_error_count integer := 0;
    v_total_sos integer := 0;
    v_validated_side_channel_type text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔧 Backfilling missing SalesOrderLines (Fixed)';
    RAISE NOTICE '========================================';
    
    -- Contar cuántos SalesOrders sin líneas
    SELECT COUNT(*) INTO v_total_sos
    FROM "SalesOrders" so
    WHERE so.deleted = false
    AND NOT EXISTS (
        SELECT 1
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = so.id
        AND sol.deleted = false
    );
    
    RAISE NOTICE 'Found % SalesOrder(s) without lines', v_total_sos;
    RAISE NOTICE '';
    
    FOR v_so IN
        SELECT 
            so.id, 
            so.quote_id, 
            so.organization_id,
            so.sale_order_no
        FROM "SalesOrders" so
        WHERE so.deleted = false
        AND NOT EXISTS (
            SELECT 1
            FROM "SalesOrderLines" sol
            WHERE sol.sale_order_id = so.id
            AND sol.deleted = false
        )
        ORDER BY so.created_at
    LOOP
        RAISE NOTICE '📦 Processing: % (ID: %)', v_so.sale_order_no, v_so.id;
        
        -- Procesar cada QuoteLine
        FOR v_ql IN
            SELECT 
                ql.*
            FROM "QuoteLines" ql
            WHERE ql.quote_id = v_so.quote_id
            AND ql.deleted = false
            ORDER BY ql.created_at
        LOOP
            -- Verificar si ya existe
            SELECT id INTO v_so_line_id
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_so.id
            AND quote_line_id = v_ql.id
            AND deleted = false;
            
            IF v_so_line_id IS NOT NULL THEN
                RAISE NOTICE '   ⏭️  Line already exists for QuoteLine %', v_ql.id;
                CONTINUE;
            END IF;
            
            -- Verificar que catalog_item_id existe
            IF v_ql.catalog_item_id IS NULL THEN
                RAISE WARNING '   ⚠️  QuoteLine % has NULL catalog_item_id, skipping', v_ql.id;
                v_error_count := v_error_count + 1;
                CONTINUE;
            END IF;
            
            -- Get line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_so.id
            AND deleted = false;
            
            -- Validate and normalize side_channel_type
            IF v_ql.side_channel_type IS NULL THEN
                v_validated_side_channel_type := NULL;
            ELSIF LOWER(v_ql.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_validated_side_channel_type := LOWER(v_ql.side_channel_type);
            ELSIF LOWER(v_ql.side_channel_type) LIKE '%side_only%' OR 
                  LOWER(v_ql.side_channel_type) = 'side' THEN
                v_validated_side_channel_type := 'side_only';
            ELSIF LOWER(v_ql.side_channel_type) LIKE '%side_and_bottom%' OR
                  LOWER(v_ql.side_channel_type) LIKE '%both%' THEN
                v_validated_side_channel_type := 'side_and_bottom';
            ELSE
                v_validated_side_channel_type := NULL;
            END IF;
            
            -- Create SalesOrderLine (con catalog_item_id)
            BEGIN
                INSERT INTO "SalesOrderLines" (
                    sale_order_id,
                    quote_line_id,
                    line_number,
                    catalog_item_id,
                    qty,
                    width_m,
                    height_m,
                    area,
                    position,
                    collection_name,
                    variant_name,
                    product_type,
                    product_type_id,
                    drive_type,
                    bottom_rail_type,
                    cassette,
                    cassette_type,
                    side_channel,
                    side_channel_type,
                    hardware_color,
                    tube_type,
                    operating_system_variant,
                    top_rail_type,
                    organization_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_so.id,
                    v_ql.id,
                    v_line_number,
                    v_ql.catalog_item_id,  -- ✅ CRITICAL: catalog_item_id is required
                    v_ql.qty,
                    v_ql.width_m,
                    v_ql.height_m,
                    v_ql.area,
                    v_ql.position,
                    v_ql.collection_name,
                    v_ql.variant_name,
                    v_ql.product_type,
                    v_ql.product_type_id,
                    v_ql.drive_type,
                    v_ql.bottom_rail_type,
                    v_ql.cassette,
                    v_ql.cassette_type,
                    v_ql.side_channel,
                    v_validated_side_channel_type,
                    v_ql.hardware_color,
                    v_ql.tube_type,
                    v_ql.operating_system_variant,
                    v_ql.top_rail_type,
                    v_so.organization_id,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_so_line_id;
                
                v_created_count := v_created_count + 1;
                RAISE NOTICE '   ✅ Created SalesOrderLine % for QuoteLine %', v_so_line_id, v_ql.id;
                
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_count := v_error_count + 1;
                    RAISE WARNING '   ❌ ERROR creating line for QuoteLine %: %', v_ql.id, SQLERRM;
            END;
        END LOOP;
        
        RAISE NOTICE '   ✅ Completed: %', v_so.sale_order_no;
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Backfill Summary:';
    RAISE NOTICE '   Processed: % SalesOrder(s)', v_total_sos;
    RAISE NOTICE '   Created: % SalesOrderLine(s)', v_created_count;
    RAISE NOTICE '   Errors: %', v_error_count;
    RAISE NOTICE '========================================';
END $$;

-- Verificación final
SELECT 
    'Final Verification' as check_name,
    COUNT(*) as so_without_lines,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ All SalesOrders have SalesOrderLines'
        ELSE '❌ ' || COUNT(*) || ' SalesOrder(s) still missing lines'
    END as status
FROM "SalesOrders" so
WHERE so.deleted = false
AND NOT EXISTS (
    SELECT 1
    FROM "SalesOrderLines" sol
    WHERE sol.sale_order_id = so.id
    AND sol.deleted = false
);


