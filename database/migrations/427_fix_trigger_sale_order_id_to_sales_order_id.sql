-- ====================================================
-- Migration 427: Fix Trigger - sale_order_id → sales_order_id
-- ====================================================
-- PROBLEMA: El trigger on_quote_approved_create_operational_docs
-- estaba usando sale_order_id (sin 's') cuando debe usar sales_order_id (con 's')
-- ====================================================

-- ====================================================
-- STEP 1: Actualizar función del trigger
-- ====================================================

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
        WHERE sales_order_id = v_so_id  -- ✅ CORREGIDO: sales_order_id (con 's')
        AND quote_line_id = v_quote_line_record.id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Get next line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SalesOrderLines"
            WHERE sales_order_id = v_so_id  -- ✅ CORREGIDO: sales_order_id (con 's')
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
            
            -- Create SalesOrderLine (including pricing fields)
            BEGIN
                INSERT INTO "SalesOrderLines" (
                    sales_order_id,  -- ✅ CORREGIDO: sales_order_id (con 's')
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
                    -- ✅ PRICING FIELDS (copied from QuoteLines)
                    unit_price_snapshot,
                    list_unit_price_snapshot,
                    unit_cost_snapshot,
                    total_unit_cost_snapshot,
                    line_total,
                    computed_qty,
                    discount_pct_used,
                    customer_type_snapshot,
                    price_basis,
                    margin_pct_used,
                    measure_basis_snapshot,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_so_id,
                    v_quote_line_record.id,
                    v_line_number,
                    v_quote_line_record.catalog_item_id,
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
                    -- ✅ PRICING FIELDS (copied from QuoteLines)
                    v_quote_line_record.unit_price_snapshot,
                    v_quote_line_record.list_unit_price_snapshot,
                    v_quote_line_record.unit_cost_snapshot,
                    v_quote_line_record.total_unit_cost_snapshot,
                    v_quote_line_record.line_total,
                    v_quote_line_record.computed_qty,
                    v_quote_line_record.discount_pct_used,
                    v_quote_line_record.customer_type_snapshot,
                    v_quote_line_record.price_basis,
                    v_quote_line_record.margin_pct_used,
                    v_quote_line_record.measure_basis_snapshot::text,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_sale_order_line_id;
                
                RAISE NOTICE '  ✅ Created SalesOrderLine % for QuoteLine % (unit_price_snapshot: %, line_total: %)', 
                    v_sale_order_line_id, 
                    v_quote_line_record.id,
                    v_quote_line_record.unit_price_snapshot,
                    v_quote_line_record.line_total;
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
    'Creates SalesOrder and SalesOrderLines when Quote is approved. Includes pricing fields (unit_price_snapshot, list_unit_price_snapshot, discount_pct_used, computed_qty) copied from QuoteLines. FIXED: Uses sales_order_id (with s) instead of sale_order_id.';

