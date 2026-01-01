-- ====================================================
-- Update All SQL References: SaleOrders → SalesOrders
-- ====================================================
-- This script updates all functions, triggers, and views
-- to use the new table names: SalesOrders and SalesOrderLines
-- ====================================================

SET client_min_messages TO NOTICE;

-- ====================================================
-- STEP 1: Update Functions
-- ====================================================

-- Function: on_quote_approved_create_operational_docs
-- This function is already updated in RECREATE_TRIGGER_FUNCTION_COMPLETE.sql
-- But we need to ensure it uses SalesOrders

-- Function: on_sale_order_confirmed_create_manufacturing_order
-- Update to use SalesOrders
CREATE OR REPLACE FUNCTION public.on_sale_order_confirmed_create_manufacturing_order()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
AS $$
DECLARE
    v_manufacturing_order_no text;
    v_manufacturing_order_id uuid;
    v_next_number integer;
    v_last_order_no text;
BEGIN
    -- Only process when status changes to 'Confirmed'
    IF NEW.status != 'Confirmed' OR OLD.status = 'Confirmed' THEN
        RETURN NEW;
    END IF;
    
    -- Check if ManufacturingOrder already exists for this SalesOrder
    SELECT id INTO v_manufacturing_order_id
    FROM "ManufacturingOrders"
    WHERE sale_order_id = NEW.id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '⏭️  ManufacturingOrder already exists for SalesOrder %, skipping creation', NEW.id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '🔔 SalesOrder % status changed to Confirmed, creating ManufacturingOrder', NEW.id;
    
    -- Generate manufacturing_order_no (try get_next_document_number first, then fallback)
    IF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'get_next_document_number' 
        AND pronamespace = 'public'::regnamespace
    ) THEN
        SELECT public.get_next_document_number(NEW.organization_id, 'MO') INTO v_manufacturing_order_no;
        RAISE NOTICE '   Using get_next_document_number: %', v_manufacturing_order_no;
    ELSIF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'get_next_sequential_number' 
        AND pronamespace = 'public'::regnamespace
    ) THEN
        SELECT public.get_next_sequential_number('ManufacturingOrders', 'manufacturing_order_no', 'MO-')
        INTO v_manufacturing_order_no;
        RAISE NOTICE '   Using get_next_sequential_number: %', v_manufacturing_order_no;
    ELSE
        -- Fallback: manual generation
        SELECT manufacturing_order_no INTO v_last_order_no
        FROM "ManufacturingOrders"
        WHERE organization_id = NEW.organization_id
        AND deleted = false
        ORDER BY created_at DESC
        LIMIT 1;

        IF v_last_order_no IS NULL THEN
            v_next_number := 1;
        ELSE
            v_next_number := COALESCE(
                (SELECT (regexp_match(v_last_order_no, 'MO-(\d+)'))[1]::integer),
                0
            ) + 1;
        END IF;
        
        v_manufacturing_order_no := 'MO-' || LPAD(v_next_number::text, 6, '0');
        RAISE NOTICE '   Using manual generation: %', v_manufacturing_order_no;
    END IF;
    
    -- Create ManufacturingOrder with status 'planned'
    INSERT INTO "ManufacturingOrders" (
        organization_id,
        sale_order_id,
        manufacturing_order_no,
        status,
        created_by,
        updated_by
    ) VALUES (
        NEW.organization_id,
        NEW.id,
        v_manufacturing_order_no,
        'planned',
        NEW.updated_by,
        NEW.updated_by
    ) RETURNING id INTO v_manufacturing_order_id;
    
    RAISE NOTICE '✅ Created ManufacturingOrder % (%) for SalesOrder %', v_manufacturing_order_id, v_manufacturing_order_no, NEW.id;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_sale_order_confirmed_create_manufacturing_order for SalesOrder %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_sale_order_confirmed_create_manufacturing_order IS 
'Automatically creates a ManufacturingOrder (Order List) when SalesOrder.status changes to Confirmed. Sets ManufacturingOrder.status to planned. Uses get_next_document_number if available, with fallbacks.';

-- ====================================================
-- STEP 2: Update Trigger on SalesOrders
-- ====================================================

DROP TRIGGER IF EXISTS trg_on_sale_order_confirmed_create_manufacturing_order ON "SalesOrders";

CREATE TRIGGER trg_on_sale_order_confirmed_create_manufacturing_order
    AFTER UPDATE OF status ON "SalesOrders"
    FOR EACH ROW
    WHEN (NEW.status = 'Confirmed' AND OLD.status IS DISTINCT FROM 'Confirmed')
    EXECUTE FUNCTION public.on_sale_order_confirmed_create_manufacturing_order();

COMMENT ON TRIGGER trg_on_sale_order_confirmed_create_manufacturing_order ON "SalesOrders" IS 
'Automatically creates ManufacturingOrder when SalesOrder status changes to Confirmed.';

-- ====================================================
-- STEP 3: Update Views
-- ====================================================

-- Update SaleOrderMaterialList view (if it exists)
DROP VIEW IF EXISTS "SaleOrderMaterialList" CASCADE;

CREATE OR REPLACE VIEW "SaleOrderMaterialList" AS
SELECT 
    sol.id AS line_id,
    so.id AS sales_order_id,
    so.sale_order_no,
    so.status AS sales_order_status,
    so.organization_id,
    sol.catalog_item_id,
    ci.sku,
    ci.item_name,
    sol.qty,
    sol.uom,
    sol.unit_price,
    sol.line_total,
    sol.line_number,
    sol.collection_name,
    sol.variant_name,
    sol.product_type,
    sol.width_m,
    sol.height_m,
    sol.area,
    sol.position,
    so.created_at AS sales_order_created_at
FROM "SalesOrders" so
JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = sol.catalog_item_id
WHERE so.deleted = false;

COMMENT ON VIEW "SaleOrderMaterialList" IS 'Material list view for Sales Orders';

-- ====================================================
-- STEP 4: Update Functions that Reference SaleOrders
-- ====================================================

-- Function: map_mo_status_to_so_status (if exists)
-- This function should already work, but verify it references SalesOrders

-- Function: on_manufacturing_order_status_change (if exists)
-- Update to use SalesOrders
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = 'on_manufacturing_order_status_change'
    ) THEN
        -- Function exists, we'll need to recreate it
        -- For now, just note that it needs to be updated
        RAISE NOTICE '⚠️  Function on_manufacturing_order_status_change exists and may need manual update';
    END IF;
END;
$$;

-- ====================================================
-- STEP 5: Update get_next_sequential_number function references
-- ====================================================

-- The get_next_sequential_number function may reference 'SaleOrders'
-- We need to update those references to 'SalesOrders'
-- This is typically done in the function body, so we'll need to recreate it
-- For now, we'll note that it needs to be checked

-- ====================================================
-- STEP 6: Summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SQL References Updated!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Updated:';
    RAISE NOTICE '   ✅ Function: on_sale_order_confirmed_create_manufacturing_order';
    RAISE NOTICE '   ✅ Trigger: trg_on_sale_order_confirmed_create_manufacturing_order';
    RAISE NOTICE '   ✅ View: SaleOrderMaterialList';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '   1. Update RECREATE_TRIGGER_FUNCTION_COMPLETE.sql to use SalesOrders';
    RAISE NOTICE '   2. Update all TypeScript/React code';
    RAISE NOTICE '   3. Test all functionality';
    RAISE NOTICE '';
END;
$$;








