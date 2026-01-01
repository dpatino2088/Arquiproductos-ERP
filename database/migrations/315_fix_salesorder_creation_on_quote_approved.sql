-- ====================================================
-- Migration 315: Fix SalesOrder Creation on Quote Approved
-- ====================================================
-- PROBLEM: Sometimes Approved quotes don't create SalesOrder
-- SOLUTION: 
--   1. Add unique index for idempotency (one SO per quote/org)
--   2. Create idempotent helper function
--   3. Update trigger to use helper function
--   4. Handle case sensitivity ('Approved' vs 'approved')
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Add unique index for idempotency
-- ====================================================
DO $$
BEGIN
    -- Check if unique index already exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'SalesOrders'
        AND indexname = 'ux_salesorders_org_quote_active'
    ) THEN
        -- Create unique index to enforce one SalesOrder per (organization_id, quote_id) where deleted=false
        CREATE UNIQUE INDEX ux_salesorders_org_quote_active
        ON "SalesOrders"(organization_id, quote_id)
        WHERE deleted = false;
        
        RAISE NOTICE '✅ Created unique index ux_salesorders_org_quote_active';
    ELSE
        RAISE NOTICE '⏭️  Unique index ux_salesorders_org_quote_active already exists';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Create idempotent helper function
-- ====================================================
CREATE OR REPLACE FUNCTION public.ensure_sales_order_for_approved_quote(p_quote_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_record RECORD;
    v_existing_so_id uuid;
    v_sale_order_no text;
    v_next_counter integer;
    v_subtotal numeric(12,4) := 0;
    v_tax numeric(12,4) := 0;
    v_total numeric(12,4) := 0;
    v_so_id uuid;
BEGIN
    -- Load quote record
    SELECT 
        q.id,
        q.organization_id,
        q.customer_id,
        q.currency,
        q.notes,
        q.created_by,
        q.updated_by,
        q.totals
    INTO v_quote_record
    FROM "Quotes" q
    WHERE q.id = p_quote_id
    AND q.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quote % not found or deleted', p_quote_id;
    END IF;
    
    IF v_quote_record.organization_id IS NULL THEN
        RAISE EXCEPTION 'Quote % has NULL organization_id', p_quote_id;
    END IF;
    
    -- Check if SalesOrder already exists (idempotency)
    SELECT so.id INTO v_existing_so_id
    FROM "SalesOrders" so
    WHERE so.organization_id = v_quote_record.organization_id
    AND so.quote_id = p_quote_id
    AND so.deleted = false
    LIMIT 1;
    
    IF v_existing_so_id IS NOT NULL THEN
        RAISE NOTICE '✅ SalesOrder already exists for Quote %: %', p_quote_id, v_existing_so_id;
        RETURN v_existing_so_id;
    END IF;
    
    -- Generate sale order number using existing function
    BEGIN
        v_next_counter := public.get_next_counter_value(v_quote_record.organization_id, 'sale_order');
        v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '⚠️ Error generating sale_order_no: %, using fallback', SQLERRM;
            -- Fallback: use MAX + 1
            SELECT COALESCE(MAX(CAST(SUBSTRING(sale_order_no FROM 'SO-(\d+)') AS INTEGER)), 0) + 1
            INTO v_next_counter
            FROM "SalesOrders"
            WHERE organization_id = v_quote_record.organization_id;
            v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
    END;
    
    -- Extract totals from JSONB
    v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
    v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 
                      (v_quote_record.totals->>'tax_total')::numeric(12,4), 0);
    v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
    
    -- Create SalesOrder (idempotent: unique index will prevent duplicates)
    BEGIN
        INSERT INTO "SalesOrders" (
            organization_id,
            quote_id,
            customer_id,
            sale_order_no,
            status,
            currency,
            subtotal,
            tax,
            total,
            notes,
            order_date,
            created_by,
            updated_by,
            deleted,
            created_at,
            updated_at
        )
        VALUES (
            v_quote_record.organization_id,
            p_quote_id,
            v_quote_record.customer_id,
            v_sale_order_no,
            'Draft',  -- Must be 'Draft' (capital D) per SalesOrders_status_check constraint
            COALESCE(v_quote_record.currency, 'USD'),
            v_subtotal,
            v_tax,
            v_total,
            v_quote_record.notes,
            CURRENT_DATE,
            v_quote_record.created_by,
            v_quote_record.updated_by,
            false,
            now(),
            now()
        )
        RETURNING id INTO v_so_id;
        
        RAISE NOTICE '✅ Created SalesOrder % (sale_order_no: %) for Quote %', 
            v_so_id, v_sale_order_no, p_quote_id;
        
        RETURN v_so_id;
        
    EXCEPTION
        WHEN unique_violation THEN
            -- Concurrent insert happened, fetch existing
            RAISE NOTICE '⚠️ Concurrent insert detected, fetching existing SalesOrder';
            SELECT so.id INTO v_existing_so_id
            FROM "SalesOrders" so
            WHERE so.organization_id = v_quote_record.organization_id
            AND so.quote_id = p_quote_id
            AND so.deleted = false
            LIMIT 1;
            
            IF v_existing_so_id IS NOT NULL THEN
                RETURN v_existing_so_id;
            ELSE
                RAISE EXCEPTION 'Unique violation but SalesOrder not found for Quote %', p_quote_id;
            END IF;
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Error creating SalesOrder for Quote %: %', p_quote_id, SQLERRM;
    END;
END;
$$;

COMMENT ON FUNCTION public.ensure_sales_order_for_approved_quote IS 
    'Idempotent function to ensure a SalesOrder exists for an approved quote. Returns existing SO if present, creates new one if not. Handles concurrent inserts safely.';

-- ====================================================
-- STEP 3: Update trigger function to use helper (keep all existing logic)
-- ====================================================
-- Note: This replaces the SalesOrder creation part (lines 74-126) with the idempotent helper
-- All other logic (SalesOrderLines, BomInstances, etc.) remains unchanged
CREATE OR REPLACE FUNCTION public.on_quote_approved_create_operational_docs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_line_id uuid;
    v_bom_instance_id uuid;
    v_quote_line_record RECORD;
    v_component_record RECORD;
    v_line_number integer;
    v_canonical_uom text;
    v_unit_cost_exw numeric(12,4);
    v_total_cost_exw numeric(12,4);
    v_category_code text;
    v_item_name text;
    v_validated_side_channel_type text;
    v_qlc_count integer;
    v_bom_result jsonb;
BEGIN
    -- Only process when status is 'Approved' (case-insensitive check)
    -- Convert enum to text for comparison to avoid enum conversion issues
    IF NEW.status IS NULL OR (NEW.status::text ILIKE 'approved' = false) THEN
        RETURN NEW;
    END IF;
    
    -- Only process if status actually changed (transition check)
    IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
        RAISE NOTICE '⏭️  Quote % status unchanged (%), skipping', NEW.id, NEW.status;
        RETURN NEW;
    END IF;
    
    -- Only process if quote is not deleted
    IF NEW.deleted = true THEN
        RAISE NOTICE '⏭️  Quote % is deleted, skipping', NEW.id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '🔔 Trigger fired: Quote % status changed to Approved (from %)', NEW.id, OLD.status;
    
    -- Check if required tables exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrders'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines'
    ) THEN
        RAISE WARNING '⚠️ SalesOrders or SalesOrderLines tables do not exist, skipping operational docs creation';
        RETURN NEW;
    END IF;
    
    -- Load quote record
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = NEW.id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '⚠️ Quote % not found or deleted, skipping operational docs creation', NEW.id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '✅ Quote % loaded, organization_id: %', NEW.id, v_quote_record.organization_id;
    
    -- ⭐ STEP A: Use idempotent helper function to ensure SalesOrder exists
    BEGIN
        v_sale_order_id := public.ensure_sales_order_for_approved_quote(NEW.id);
        RAISE NOTICE '✅ SalesOrder ensured for Quote %: %', NEW.id, v_sale_order_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '❌ Error ensuring SalesOrder for Quote %: %', NEW.id, SQLERRM;
            -- Don't fail the trigger, just log the error and return
            RETURN NEW;
    END;
    
    -- ⭐ STEP B: For each QuoteLine, find or create SaleOrderLine (UNCHANGED from migration 226)
    FOR v_quote_line_record IN
        SELECT ql.*
        FROM "QuoteLines" ql
        WHERE ql.quote_id = NEW.id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        -- Find existing SaleOrderLine for this quote_line_id
        SELECT id INTO v_sale_order_line_id
        FROM "SalesOrderLines"
        WHERE sale_order_id = v_sale_order_id
        AND quote_line_id = v_quote_line_record.id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Get next line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SalesOrderLines"
            WHERE sale_order_id = v_sale_order_id
            AND deleted = false;
            
            -- Validate and normalize side_channel_type to match constraint
            IF v_quote_line_record.side_channel_type IS NULL THEN
                v_validated_side_channel_type := NULL;
            ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
            ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_only%' OR 
                  LOWER(v_quote_line_record.side_channel_type) = 'side' THEN
                v_validated_side_channel_type := 'side_only';
            ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_and_bottom%' OR
                  LOWER(v_quote_line_record.side_channel_type) LIKE '%both%' OR
                  LOWER(v_quote_line_record.side_channel_type) = 'side_and_bottom' THEN
                v_validated_side_channel_type := 'side_and_bottom';
            ELSE
                v_validated_side_channel_type := NULL;
            END IF;
            
            -- Create SaleOrderLine with ALL configuration fields (UNCHANGED)
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
                unit_price_snapshot,
                unit_cost_snapshot,
                line_total,
                measure_basis_snapshot,
                margin_percentage,
                deleted,
                created_at,
                updated_at
            ) VALUES (
                v_sale_order_id,
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
                v_quote_line_record.unit_price_snapshot,
                v_quote_line_record.unit_cost_snapshot,
                v_quote_line_record.line_total,
                v_quote_line_record.measure_basis_snapshot,
                v_quote_line_record.margin_percentage,
                false,
                now(),
                now()
            ) RETURNING id INTO v_sale_order_line_id;
        END IF;
        
        -- ⭐ Step C: Generate QuoteLineComponents if they don't exist (UNCHANGED)
        SELECT COUNT(*) INTO v_qlc_count
        FROM "QuoteLineComponents"
        WHERE quote_line_id = v_quote_line_record.id
            AND source = 'configured_component'
            AND deleted = false;
        
        IF v_qlc_count = 0 AND v_quote_line_record.product_type_id IS NOT NULL THEN
            RAISE NOTICE '🔧 No QuoteLineComponents found for QuoteLine %. Generating BOM...', v_quote_line_record.id;
            
            BEGIN
                IF v_quote_line_record.organization_id IS NULL THEN
                    UPDATE "QuoteLines"
                    SET organization_id = v_quote_record.organization_id
                    WHERE id = v_quote_line_record.id;
                END IF;
                
                v_bom_result := public.generate_configured_bom_for_quote_line(
                    v_quote_line_record.id,
                    v_quote_line_record.product_type_id,
                    COALESCE(v_quote_line_record.organization_id, v_quote_record.organization_id),
                    v_quote_line_record.drive_type,
                    v_quote_line_record.bottom_rail_type,
                    v_quote_line_record.cassette,
                    v_quote_line_record.cassette_type,
                    v_quote_line_record.side_channel,
                    v_quote_line_record.side_channel_type,
                    v_quote_line_record.hardware_color,
                    v_quote_line_record.width_m,
                    v_quote_line_record.height_m,
                    v_quote_line_record.qty,
                    v_quote_line_record.tube_type,
                    v_quote_line_record.operating_system_variant
                );
                
                RAISE NOTICE '✅ QuoteLineComponents generated for QuoteLine %', v_quote_line_record.id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️ Error generating QuoteLineComponents for QuoteLine %: %', v_quote_line_record.id, SQLERRM;
            END;
        ELSIF v_qlc_count = 0 AND v_quote_line_record.product_type_id IS NULL THEN
            RAISE WARNING '⚠️ QuoteLine % has no product_type_id, cannot generate BOM', v_quote_line_record.id;
        END IF;
        
        -- ⭐ Step D: Find or create BomInstance (UNCHANGED)
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            DECLARE
                v_bom_template_id uuid;
            BEGIN
                SELECT id INTO v_bom_template_id
                FROM "BOMTemplates"
                WHERE product_type_id = v_quote_line_record.product_type_id
                    AND deleted = false
                    AND active = true
                ORDER BY 
                    CASE WHEN organization_id = v_quote_record.organization_id THEN 0 ELSE 1 END,
                    created_at DESC
                LIMIT 1;
                
                INSERT INTO "BomInstances" (
                    organization_id,
                    sale_order_line_id,
                    quote_line_id,
                    bom_template_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_quote_record.organization_id,
                    v_sale_order_line_id,
                    v_quote_line_record.id,
                    v_bom_template_id,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️ Error creating BomInstance: %', SQLERRM;
            END;
        END IF;
        
        -- ⭐ Step E: Populate BomInstanceLines from QuoteLineComponents (UNCHANGED)
        FOR v_component_record IN
            SELECT 
                qlc.*,
                ci.item_name,
                ci.sku
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_quote_line_record.id
            AND qlc.source = 'configured_component'
            AND qlc.deleted = false
            AND ci.deleted = false
        LOOP
            IF v_bom_instance_id IS NOT NULL THEN
                v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
                
                v_unit_cost_exw := public.get_unit_cost_in_uom(
                    v_component_record.catalog_item_id,
                    v_canonical_uom,
                    v_quote_record.organization_id
                );
                
                IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                    v_unit_cost_exw := COALESCE(v_component_record.unit_cost_exw, 0);
                END IF;
                
                v_total_cost_exw := v_component_record.qty * v_unit_cost_exw;
                v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
                
                INSERT INTO "BomInstanceLines" (
                    organization_id,
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
                    v_quote_record.organization_id,
                    v_bom_instance_id,
                    NULL,
                    v_component_record.catalog_item_id,
                    v_component_record.sku,
                    v_component_record.component_role,
                    v_component_record.qty,
                    v_canonical_uom,
                    COALESCE(v_component_record.item_name, ''),
                    v_unit_cost_exw,
                    v_total_cost_exw,
                    v_category_code,
                    now(),
                    now(),
                    false
                )
                ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
                WHERE deleted = false
                DO NOTHING;
            END IF;
        END LOOP;
        
        -- ⭐ Step F: Apply engineering rules (UNCHANGED)
        IF v_bom_instance_id IS NOT NULL THEN
            BEGIN
                PERFORM public.apply_engineering_rules_and_convert_linear_uom(v_bom_instance_id);
                RAISE NOTICE '✅ Applied engineering rules for BomInstance %', v_bom_instance_id;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️ Error applying engineering rules for BomInstance %: %', v_bom_instance_id, SQLERRM;
            END;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Operational docs creation completed for Quote %', NEW.id;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_quote_approved_create_operational_docs for Quote %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_quote_approved_create_operational_docs IS 
    'Trigger function that creates SalesOrder when quote is approved. Uses ensure_sales_order_for_approved_quote() for idempotency. Handles case-insensitive status matching.';

-- ====================================================
-- STEP 4: Ensure trigger exists and is enabled
-- ====================================================
DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";

CREATE TRIGGER trg_on_quote_approved_create_operational_docs
AFTER UPDATE OF status ON "Quotes"
FOR EACH ROW
WHEN (
    NEW.deleted = false
    AND NEW.status IS NOT NULL
    AND (NEW.status::text ILIKE 'approved' OR NEW.status::text = 'Approved')
    AND (OLD.status IS DISTINCT FROM NEW.status)
)
EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

COMMENT ON TRIGGER trg_on_quote_approved_create_operational_docs ON "Quotes" IS 
    'Creates SalesOrder when quote status transitions to Approved. Idempotent and handles case-insensitive status matching.';

-- Enable the trigger
DO $$
BEGIN
    ALTER TABLE "Quotes" ENABLE TRIGGER trg_on_quote_approved_create_operational_docs;
    RAISE NOTICE '✅ Trigger trg_on_quote_approved_create_operational_docs created and enabled';
END $$;

-- ====================================================
-- STEP 5: Create SalesOrders for existing approved quotes
-- ====================================================
DO $$
DECLARE
    v_quote_record RECORD;
    v_created_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Creating SalesOrders for existing approved quotes...';
    
    FOR v_quote_record IN
        SELECT q.id, q.quote_no
        FROM "Quotes" q
        LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
        WHERE q.status IS NOT NULL
        AND (q.status::text ILIKE 'approved' OR q.status::text = 'Approved')
        AND q.deleted = false
        AND so.id IS NULL
    LOOP
        BEGIN
            PERFORM public.ensure_sales_order_for_approved_quote(v_quote_record.id);
            RAISE NOTICE '  ✅ Created SalesOrder for Quote % (%)', v_quote_record.quote_no, v_quote_record.id;
            v_created_count := v_created_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error creating SalesOrder for Quote % (%): %', 
                    v_quote_record.quote_no, v_quote_record.id, SQLERRM;
        END;
    END LOOP;
    
    IF v_created_count > 0 THEN
        RAISE NOTICE '✅ Created % SalesOrder(s) for existing approved quotes', v_created_count;
    ELSE
        RAISE NOTICE '✅ All approved quotes already have SalesOrders';
    END IF;
END $$;

-- ====================================================
-- STEP 6: Verification Queries
-- ====================================================

-- Query 1: Show approved quotes without SalesOrder (should be empty after fix)
DO $$
DECLARE
    v_missing_count integer;
BEGIN
    SELECT COUNT(*) INTO v_missing_count
    FROM "Quotes" q
    LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
    WHERE q.status IS NOT NULL
    AND (q.status::text ILIKE 'approved' OR q.status::text = 'Approved')
    AND q.deleted = false
    AND so.id IS NULL;
    
    IF v_missing_count > 0 THEN
        RAISE NOTICE '⚠️  Found % approved quotes without SalesOrder', v_missing_count;
    ELSE
        RAISE NOTICE '✅ All approved quotes have SalesOrders';
    END IF;
END $$;

-- Query 2: Show duplicates (should be impossible after unique index)
DO $$
DECLARE
    v_duplicate_count integer;
BEGIN
    SELECT COUNT(*) INTO v_duplicate_count
    FROM (
        SELECT organization_id, quote_id, COUNT(*) as cnt
        FROM "SalesOrders"
        WHERE deleted = false
        GROUP BY organization_id, quote_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    IF v_duplicate_count > 0 THEN
        RAISE WARNING '⚠️  Found % duplicate SalesOrders (organization_id, quote_id) pairs', v_duplicate_count;
    ELSE
        RAISE NOTICE '✅ No duplicate SalesOrders found';
    END IF;
END $$;

COMMIT;

-- ====================================================
-- MANUAL VERIFICATION QUERIES (run separately)
-- ====================================================

/*
-- Query 1: Approved quotes without SalesOrder
SELECT 
    q.id,
    q.quote_no,
    q.status,
    q.organization_id,
    CASE 
        WHEN so.id IS NULL THEN '❌ Missing SalesOrder'
        ELSE '✅ Has SalesOrder'
    END as status_check
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status IS NOT NULL
AND (q.status::text ILIKE 'approved' OR q.status::text = 'Approved')
AND q.deleted = false
AND so.id IS NULL
ORDER BY q.created_at DESC;

-- Query 2: Duplicate SalesOrders (should be empty)
SELECT 
    organization_id,
    quote_id,
    COUNT(*) as duplicate_count,
    STRING_AGG(id::text, ', ') as sales_order_ids
FROM "SalesOrders"
WHERE deleted = false
GROUP BY organization_id, quote_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Query 3: For a specific quote, show SalesOrder
SELECT 
    so.*,
    q.quote_no,
    q.status as quote_status
FROM "SalesOrders" so
JOIN "Quotes" q ON q.id = so.quote_id
WHERE so.quote_id = '<QUOTE_ID>'::uuid  -- Replace with actual quote_id
AND so.deleted = false;

-- Query 4: Test the helper function directly
SELECT public.ensure_sales_order_for_approved_quote('<QUOTE_ID>'::uuid);
*/

