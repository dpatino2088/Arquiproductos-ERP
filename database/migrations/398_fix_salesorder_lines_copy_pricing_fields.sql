-- ====================================================
-- Migration 398: Fix SalesOrderLines to copy pricing fields from QuoteLines
-- ====================================================
-- Updates the trigger to copy unit_price_snapshot, list_unit_price_snapshot,
-- discount_pct_used, computed_qty, and other pricing fields from QuoteLines
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 0: Add pricing columns to SalesOrderLines if they don't exist
-- ====================================================
DO $$
BEGIN
    -- Add list_unit_price_snapshot (MSRP Sale Out / PVP)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines' 
        AND column_name = 'list_unit_price_snapshot'
    ) THEN
        ALTER TABLE "SalesOrderLines" 
        ADD COLUMN list_unit_price_snapshot numeric(12,4) NULL;
        RAISE NOTICE '✅ Added list_unit_price_snapshot column to SalesOrderLines';
    END IF;
    
    -- Add unit_price_snapshot (net price with tier discount)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines' 
        AND column_name = 'unit_price_snapshot'
    ) THEN
        ALTER TABLE "SalesOrderLines" 
        ADD COLUMN unit_price_snapshot numeric(12,4) NULL;
        RAISE NOTICE '✅ Added unit_price_snapshot column to SalesOrderLines';
    END IF;
    
    -- Add unit_cost_snapshot
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines' 
        AND column_name = 'unit_cost_snapshot'
    ) THEN
        ALTER TABLE "SalesOrderLines" 
        ADD COLUMN unit_cost_snapshot numeric(12,4) NULL;
        RAISE NOTICE '✅ Added unit_cost_snapshot column to SalesOrderLines';
    END IF;
    
    -- Add total_unit_cost_snapshot
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines' 
        AND column_name = 'total_unit_cost_snapshot'
    ) THEN
        ALTER TABLE "SalesOrderLines" 
        ADD COLUMN total_unit_cost_snapshot numeric(12,4) NULL;
        RAISE NOTICE '✅ Added total_unit_cost_snapshot column to SalesOrderLines';
    END IF;
    
    -- Add computed_qty
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines' 
        AND column_name = 'computed_qty'
    ) THEN
        ALTER TABLE "SalesOrderLines" 
        ADD COLUMN computed_qty numeric(12,4) NULL;
        RAISE NOTICE '✅ Added computed_qty column to SalesOrderLines';
    END IF;
    
    -- Add discount_pct_used
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines' 
        AND column_name = 'discount_pct_used'
    ) THEN
        ALTER TABLE "SalesOrderLines" 
        ADD COLUMN discount_pct_used numeric(8,4) NULL;
        RAISE NOTICE '✅ Added discount_pct_used column to SalesOrderLines';
    END IF;
    
    -- Add customer_type_snapshot
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines' 
        AND column_name = 'customer_type_snapshot'
    ) THEN
        ALTER TABLE "SalesOrderLines" 
        ADD COLUMN customer_type_snapshot text NULL;
        RAISE NOTICE '✅ Added customer_type_snapshot column to SalesOrderLines';
    END IF;
    
    -- Add price_basis
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines' 
        AND column_name = 'price_basis'
    ) THEN
        ALTER TABLE "SalesOrderLines" 
        ADD COLUMN price_basis text NULL;
        RAISE NOTICE '✅ Added price_basis column to SalesOrderLines';
    END IF;
    
    -- Add margin_pct_used
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines' 
        AND column_name = 'margin_pct_used'
    ) THEN
        ALTER TABLE "SalesOrderLines" 
        ADD COLUMN margin_pct_used numeric(8,4) NULL;
        RAISE NOTICE '✅ Added margin_pct_used column to SalesOrderLines';
    END IF;
    
    -- Add measure_basis_snapshot
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines' 
        AND column_name = 'measure_basis_snapshot'
    ) THEN
        ALTER TABLE "SalesOrderLines" 
        ADD COLUMN measure_basis_snapshot text NULL;
        RAISE NOTICE '✅ Added measure_basis_snapshot column to SalesOrderLines';
    END IF;
END $$;

-- ====================================================
-- STEP 1: Update trigger function to copy pricing fields
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
        WHERE sales_order_id = v_so_id
        AND quote_line_id = v_quote_line_record.id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Get next line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SalesOrderLines"
            WHERE sales_order_id = v_so_id
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
                    sales_order_id,
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
    'Creates SalesOrder and SalesOrderLines when Quote is approved. Includes pricing fields (unit_price_snapshot, list_unit_price_snapshot, discount_pct_used, computed_qty) copied from QuoteLines.';

-- ====================================================
-- STEP 2: Backfill existing SalesOrderLines with pricing from QuoteLines
-- ====================================================
-- NOTE: This step requires STEP 0 to have executed successfully first
-- ====================================================

DO $$
DECLARE
    v_sol RECORD;
    v_ql RECORD;
    v_updated_count integer := 0;
    v_has_unit_price_snapshot boolean;
    v_current_price numeric;
BEGIN
    -- Check if unit_price_snapshot column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines' 
        AND column_name = 'unit_price_snapshot'
    ) INTO v_has_unit_price_snapshot;
    
    IF NOT v_has_unit_price_snapshot THEN
        RAISE NOTICE '⚠️  unit_price_snapshot column does not exist. Skipping backfill.';
        RAISE NOTICE '   Please ensure STEP 0 executed successfully to create pricing columns.';
        RAISE EXCEPTION 'STEP 0 must be executed before STEP 2. Column unit_price_snapshot does not exist.';
    END IF;
    
    RAISE NOTICE '🔧 Backfilling pricing fields in existing SalesOrderLines...';
    
    -- Use a simpler query that doesn't reference unit_price_snapshot in WHERE clause
    -- We'll check for NULL/0 inside the loop using dynamic SQL
    FOR v_sol IN
        SELECT sol.id, sol.quote_line_id
        FROM "SalesOrderLines" sol
        WHERE sol.quote_line_id IS NOT NULL
        AND sol.deleted = false
    LOOP
        -- Check if pricing is missing using dynamic SQL (only if column exists)
        BEGIN
            -- Use USING clause correctly with EXECUTE
            EXECUTE 'SELECT unit_price_snapshot FROM "SalesOrderLines" WHERE id = $1'
            INTO v_current_price
            USING v_sol.id;
            
            -- Skip if price already exists and is > 0
            IF v_current_price IS NOT NULL AND v_current_price > 0 THEN
                CONTINUE;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                -- If column doesn't exist or other error, skip this line
                RAISE NOTICE '  ⚠️  Error checking price for SalesOrderLine %: %', v_sol.id, SQLERRM;
                CONTINUE;
        END;
        -- Get pricing from QuoteLine
        SELECT 
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
            measure_basis_snapshot::text as measure_basis_snapshot
        INTO v_ql
        FROM "QuoteLines"
        WHERE id = v_sol.quote_line_id
        AND deleted = false;
        
        IF FOUND THEN
            -- Update SalesOrderLine with pricing from QuoteLine
            UPDATE "SalesOrderLines"
            SET 
                unit_price_snapshot = COALESCE(v_ql.unit_price_snapshot, unit_price_snapshot),
                list_unit_price_snapshot = COALESCE(v_ql.list_unit_price_snapshot, list_unit_price_snapshot),
                unit_cost_snapshot = COALESCE(v_ql.unit_cost_snapshot, unit_cost_snapshot),
                total_unit_cost_snapshot = COALESCE(v_ql.total_unit_cost_snapshot, total_unit_cost_snapshot),
                line_total = COALESCE(v_ql.line_total, line_total),
                computed_qty = COALESCE(v_ql.computed_qty, computed_qty),
                discount_pct_used = COALESCE(v_ql.discount_pct_used, discount_pct_used),
                customer_type_snapshot = COALESCE(v_ql.customer_type_snapshot, customer_type_snapshot),
                price_basis = COALESCE(v_ql.price_basis, price_basis),
                margin_pct_used = COALESCE(v_ql.margin_pct_used, margin_pct_used),
                measure_basis_snapshot = COALESCE(v_ql.measure_basis_snapshot::text, measure_basis_snapshot),
                updated_at = now()
            WHERE id = v_sol.id;
            
            v_updated_count := v_updated_count + 1;
            
            IF v_updated_count % 10 = 0 THEN
                RAISE NOTICE '  Updated % SalesOrderLines...', v_updated_count;
            END IF;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Backfill complete: % SalesOrderLines updated with pricing fields', v_updated_count;
END $$;

-- ====================================================
-- STEP 3: Verification query
-- ====================================================

SELECT 
    'Verification: SalesOrderLines with pricing' as check_name,
    COUNT(*) FILTER (WHERE unit_price_snapshot IS NOT NULL AND unit_price_snapshot > 0) as with_pricing,
    COUNT(*) FILTER (WHERE unit_price_snapshot IS NULL OR unit_price_snapshot = 0) as without_pricing,
    COUNT(*) as total_lines,
    CASE 
        WHEN COUNT(*) FILTER (WHERE unit_price_snapshot IS NULL OR unit_price_snapshot = 0) = 0 
        THEN '✅ All SalesOrderLines have pricing'
        ELSE '⚠️ Some SalesOrderLines are missing pricing'
    END as status
FROM "SalesOrderLines"
WHERE deleted = false
AND quote_line_id IS NOT NULL;

