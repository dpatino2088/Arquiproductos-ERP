-- ====================================================
-- Migration 328: Add SalesOrderLines to Minimal Trigger
-- ====================================================
-- Updates the minimal trigger to also create SalesOrderLines
-- WITHOUT creating BOM/components (those are created in Manufacturing step)
-- ====================================================

-- This migration updates the trigger function created in 326
-- to also create SalesOrderLines, which are required for Manufacturing Order creation

CREATE OR REPLACE FUNCTION public.on_quote_approved_create_operational_docs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_so_id uuid;
    v_quote_record RECORD;
    v_quote_line_record RECORD;
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_validated_side_channel_type text;
BEGIN
    -- Log trigger execution
    RAISE NOTICE '🔔 Trigger on_quote_approved_create_operational_docs FIRED for Quote % (status: %)', 
        NEW.id, NEW.status;
    
    -- STEP 1: Create SalesOrder (idempotent)
    BEGIN
        v_so_id := public.ensure_sales_order_for_approved_quote(NEW.id);
        
        IF v_so_id IS NOT NULL THEN
            RAISE NOTICE '✅ SalesOrder created/verified: % for Quote %', v_so_id, NEW.id;
        ELSE
            RAISE WARNING '⚠️ ensure_sales_order_for_approved_quote returned NULL for Quote %', NEW.id;
            RETURN NEW;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ Error creating SalesOrder for Quote %: %', NEW.id, SQLERRM;
            RAISE;
    END;
    
    -- STEP 2: Load quote record (for organization_id)
    SELECT organization_id INTO v_quote_record
    FROM "Quotes"
    WHERE id = NEW.id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '⚠️ Quote % not found or deleted', NEW.id;
        RETURN NEW;
    END IF;
    
    -- STEP 3: Create SalesOrderLines for each QuoteLine (idempotent)
    FOR v_quote_line_record IN
        SELECT ql.*
        FROM "QuoteLines" ql
        WHERE ql.quote_id = NEW.id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        -- Check if SalesOrderLine already exists
        SELECT id INTO v_sale_order_line_id
        FROM "SalesOrderLines"
        WHERE sale_order_id = v_so_id
        AND quote_line_id = v_quote_line_record.id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Get next line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_so_id
            AND deleted = false;
            
            -- Validate and normalize side_channel_type
            IF v_quote_line_record.side_channel_type IS NULL THEN
                v_validated_side_channel_type := NULL;
            ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
            ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_only%' OR 
                  LOWER(v_quote_line_record.side_channel_type) = 'side' THEN
                v_validated_side_channel_type := 'side_only';
            ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_and_bottom%' OR
                  LOWER(v_quote_line_record.side_channel_type) LIKE '%both%' THEN
                v_validated_side_channel_type := 'side_and_bottom';
            ELSE
                v_validated_side_channel_type := NULL;
            END IF;
            
            -- Create SalesOrderLine (using only columns that exist)
            BEGIN
                INSERT INTO "SalesOrderLines" (
                    sale_order_id,
                    quote_line_id,
                    line_number,
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
                    v_so_id,
                    v_quote_line_record.id,
                    v_line_number,
                    v_quote_line_record.qty,
                    v_quote_line_record.width_m,
                    v_quote_line_record.height_m,
                    v_quote_line_record.area,
                    v_quote_line_record.position,
                    v_quote_line_record.collection_name,
                    v_quote_line_record.variant_name,
                    v_quote_line_record.product_type,
                    v_quote_line_record.product_type_id,
                    v_quote_line_record.drive_type,
                    v_quote_line_record.bottom_rail_type,
                    v_quote_line_record.cassette,
                    v_quote_line_record.cassette_type,
                    v_quote_line_record.side_channel,
                    v_validated_side_channel_type,
                    v_quote_line_record.hardware_color,
                    v_quote_line_record.tube_type,
                    v_quote_line_record.operating_system_variant,
                    v_quote_line_record.top_rail_type,
                    v_quote_record.organization_id,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_sale_order_line_id;
                
                RAISE NOTICE '  ✅ Created SalesOrderLine % for QuoteLine %', v_sale_order_line_id, v_quote_line_record.id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '  ❌ Error creating SalesOrderLine for QuoteLine %: %', 
                        v_quote_line_record.id, SQLERRM;
                    -- Continue with next line instead of failing entire trigger
            END;
        ELSE
            RAISE NOTICE '  ⏭️  SalesOrderLine already exists for QuoteLine %', v_quote_line_record.id;
        END IF;
    END LOOP;
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_quote_approved_create_operational_docs IS 
    'Minimal trigger function: Creates SalesOrder and SalesOrderLines only. BOM/components generation must be done separately (e.g., in Manufacturing step).';

-- ====================================================
-- Backfill: Create SalesOrderLines for existing SalesOrders
-- ====================================================

DO $$
DECLARE
    v_so RECORD;
    v_quote_line_record RECORD;
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_validated_side_channel_type text;
    v_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Backfilling missing SalesOrderLines...';
    
    FOR v_so IN
        SELECT so.id, so.quote_id, so.organization_id
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
        RAISE NOTICE '  Processing SalesOrder % (Quote %)', v_so.id, v_so.quote_id;
        
        FOR v_quote_line_record IN
            SELECT ql.*
            FROM "QuoteLines" ql
            WHERE ql.quote_id = v_so.quote_id
            AND ql.deleted = false
            ORDER BY ql.created_at ASC
        LOOP
            -- Get next line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_so.id
            AND deleted = false;
            
            -- Validate side_channel_type
            IF v_quote_line_record.side_channel_type IS NULL THEN
                v_validated_side_channel_type := NULL;
            ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
            ELSE
                v_validated_side_channel_type := NULL;
            END IF;
            
            -- Create SalesOrderLine
            BEGIN
                INSERT INTO "SalesOrderLines" (
                    sale_order_id,
                    quote_line_id,
                    line_number,
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
                    v_quote_line_record.id,
                    v_line_number,
                    v_quote_line_record.qty,
                    v_quote_line_record.width_m,
                    v_quote_line_record.height_m,
                    v_quote_line_record.area,
                    v_quote_line_record.position,
                    v_quote_line_record.collection_name,
                    v_quote_line_record.variant_name,
                    v_quote_line_record.product_type,
                    v_quote_line_record.product_type_id,
                    v_quote_line_record.drive_type,
                    v_quote_line_record.bottom_rail_type,
                    v_quote_line_record.cassette,
                    v_quote_line_record.cassette_type,
                    v_quote_line_record.side_channel,
                    v_validated_side_channel_type,
                    v_quote_line_record.hardware_color,
                    v_quote_line_record.tube_type,
                    v_quote_line_record.operating_system_variant,
                    v_quote_line_record.top_rail_type,
                    v_so.organization_id,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_sale_order_line_id;
                
                v_count := v_count + 1;
                RAISE NOTICE '    ✅ Created SalesOrderLine %', v_sale_order_line_id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '    ❌ Error: %', SQLERRM;
            END;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '✅ Backfill complete: % SalesOrderLines created', v_count;
END $$;

-- ====================================================
-- Verification Query
-- ====================================================

SELECT 
    'Verification: SalesOrders without SalesOrderLines' as check_name,
    COUNT(*) as so_without_lines,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ All SalesOrders have SalesOrderLines'
        ELSE '❌ Some SalesOrders are missing SalesOrderLines'
    END as status
FROM "SalesOrders" so
WHERE so.deleted = false
AND NOT EXISTS (
    SELECT 1
    FROM "SalesOrderLines" sol
    WHERE sol.sale_order_id = so.id
    AND sol.deleted = false
);


