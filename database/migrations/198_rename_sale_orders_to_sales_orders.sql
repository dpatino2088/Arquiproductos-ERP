-- ====================================================
-- Migration: Rename SaleOrders to SalesOrders (Convention Fix)
-- ====================================================
-- This migration renames tables to follow the convention:
-- Domain (plural) + Entity (singular) + Lines (plural)
-- Examples: SalesOrders, SalesOrderLines, PurchaseOrders, PurchaseOrderLines
-- ====================================================

SET client_min_messages TO WARNING;

-- ====================================================
-- STEP 1: Rename Tables
-- ====================================================

DO $$
BEGIN
    -- Rename SaleOrders to SalesOrders (if it exists and hasn't been renamed)
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrders'
    ) THEN
        ALTER TABLE "SaleOrders" RENAME TO "SalesOrders";
        RAISE NOTICE '✅ Renamed table SaleOrders to SalesOrders';
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrders'
    ) THEN
        RAISE NOTICE 'ℹ️  Table SalesOrders already exists, skipping rename';
    ELSE
        RAISE WARNING '⚠️  Table SaleOrders does not exist';
    END IF;
    
    -- Rename SaleOrderLines to SalesOrderLines (if it exists and hasn't been renamed)
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrderLines'
    ) THEN
        ALTER TABLE "SaleOrderLines" RENAME TO "SalesOrderLines";
        RAISE NOTICE '✅ Renamed table SaleOrderLines to SalesOrderLines';
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines'
    ) THEN
        RAISE NOTICE 'ℹ️  Table SalesOrderLines already exists, skipping rename';
    ELSE
        RAISE WARNING '⚠️  Table SaleOrderLines does not exist';
    END IF;
END;
$$;

-- ====================================================
-- STEP 2: Update Foreign Key Constraints
-- ====================================================

-- Update foreign keys in SalesOrderLines that reference SalesOrders
DO $$
DECLARE
    v_constraint_name text;
    v_table_exists boolean;
    v_sales_orders_oid oid;
    v_sales_order_lines_oid oid;
BEGIN
    -- Check if both tables exist
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines'
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE NOTICE '⚠️  Table SalesOrderLines does not exist, skipping foreign key updates';
        RETURN;
    END IF;
    
    -- Get OIDs safely
    SELECT oid INTO v_sales_orders_oid FROM pg_class WHERE relname = 'SalesOrders' AND relnamespace = 'public'::regnamespace;
    SELECT oid INTO v_sales_order_lines_oid FROM pg_class WHERE relname = 'SalesOrderLines' AND relnamespace = 'public'::regnamespace;
    
    IF v_sales_orders_oid IS NULL OR v_sales_order_lines_oid IS NULL THEN
        RAISE NOTICE '⚠️  Could not find table OIDs, skipping foreign key updates';
        RETURN;
    END IF;
    
    -- Find and rename the foreign key constraint
    FOR v_constraint_name IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = v_sales_order_lines_oid
        AND contype = 'f'
        AND confrelid = v_sales_orders_oid
    LOOP
        BEGIN
            EXECUTE format('ALTER TABLE "SalesOrderLines" RENAME CONSTRAINT %I TO %I', 
                v_constraint_name, 
                replace(v_constraint_name, 'sale_order', 'sales_order'));
            RAISE NOTICE '✅ Renamed constraint % to %', v_constraint_name, replace(v_constraint_name, 'sale_order', 'sales_order');
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '⚠️  Could not rename constraint %: %', v_constraint_name, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- Update foreign keys in other tables that reference SalesOrders
DO $$
DECLARE
    v_table_name text;
    v_constraint_name text;
    v_table_exists boolean;
    v_sales_orders_oid oid;
BEGIN
    -- Check if SalesOrders table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrders'
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE NOTICE '⚠️  Table SalesOrders does not exist, skipping foreign key updates';
        RETURN;
    END IF;
    
    -- Get OID safely
    SELECT oid INTO v_sales_orders_oid FROM pg_class WHERE relname = 'SalesOrders' AND relnamespace = 'public'::regnamespace;
    
    IF v_sales_orders_oid IS NULL THEN
        RAISE NOTICE '⚠️  Could not find SalesOrders OID, skipping foreign key updates';
        RETURN;
    END IF;
    
    -- Find all tables with foreign keys to SalesOrders
    FOR v_table_name, v_constraint_name IN
        SELECT 
            c.relname,
            con.conname
        FROM pg_constraint con
        JOIN pg_class c ON con.conrelid = c.oid
        WHERE con.confrelid = v_sales_orders_oid
        AND con.contype = 'f'
    LOOP
        BEGIN
            -- Rename constraint to reflect new table name
            EXECUTE format('ALTER TABLE %I RENAME CONSTRAINT %I TO %I', 
                v_table_name,
                v_constraint_name,
                replace(v_constraint_name, 'sale_order', 'sales_order'));
            RAISE NOTICE '✅ Renamed constraint % on table %', v_constraint_name, v_table_name;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '⚠️  Could not rename constraint % on table %: %', v_constraint_name, v_table_name, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- ====================================================
-- STEP 3: Update Indexes
-- ====================================================

-- Rename indexes on SalesOrders
DO $$
DECLARE
    v_index_name text;
    v_new_name text;
    v_table_exists boolean;
BEGIN
    -- Check if SalesOrders table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrders'
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE NOTICE '⚠️  Table SalesOrders does not exist, skipping index updates';
        RETURN;
    END IF;
    
    FOR v_index_name IN
        SELECT indexname
        FROM pg_indexes
        WHERE tablename = 'SalesOrders'
        AND schemaname = 'public'
    LOOP
        v_new_name := replace(v_index_name, 'sale_orders', 'sales_orders');
        IF v_index_name != v_new_name THEN
            BEGIN
                EXECUTE format('ALTER INDEX IF EXISTS %I RENAME TO %I', v_index_name, v_new_name);
                RAISE NOTICE '✅ Renamed index % to %', v_index_name, v_new_name;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE NOTICE '⚠️  Could not rename index %: %', v_index_name, SQLERRM;
            END;
        END IF;
    END LOOP;
END;
$$;

-- Rename indexes on SalesOrderLines
DO $$
DECLARE
    v_index_name text;
    v_new_name text;
    v_table_exists boolean;
BEGIN
    -- Check if SalesOrderLines table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines'
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE NOTICE '⚠️  Table SalesOrderLines does not exist, skipping index updates';
        RETURN;
    END IF;
    
    FOR v_index_name IN
        SELECT indexname
        FROM pg_indexes
        WHERE tablename = 'SalesOrderLines'
        AND schemaname = 'public'
    LOOP
        v_new_name := replace(v_index_name, 'sale_order_lines', 'sales_order_lines');
        IF v_index_name != v_new_name THEN
            BEGIN
                EXECUTE format('ALTER INDEX IF EXISTS %I RENAME TO %I', v_index_name, v_new_name);
                RAISE NOTICE '✅ Renamed index % to %', v_index_name, v_new_name;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE NOTICE '⚠️  Could not rename index %: %', v_index_name, SQLERRM;
            END;
        END IF;
    END LOOP;
END;
$$;

-- ====================================================
-- STEP 4: Update Unique Constraints
-- ====================================================

-- Rename unique constraint on SalesOrders
DO $$
DECLARE
    v_constraint_name text;
    v_table_exists boolean;
    v_table_oid oid;
BEGIN
    -- Check if SalesOrders table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrders'
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE NOTICE '⚠️  Table SalesOrders does not exist, skipping unique constraint updates';
        RETURN;
    END IF;
    
    -- Get OID safely
    SELECT oid INTO v_table_oid FROM pg_class WHERE relname = 'SalesOrders' AND relnamespace = 'public'::regnamespace;
    
    IF v_table_oid IS NULL THEN
        RAISE NOTICE '⚠️  Could not find SalesOrders OID, skipping unique constraint updates';
        RETURN;
    END IF;
    
    FOR v_constraint_name IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = v_table_oid
        AND contype = 'u'
    LOOP
        BEGIN
            EXECUTE format('ALTER TABLE "SalesOrders" RENAME CONSTRAINT %I TO %I', 
                v_constraint_name,
                replace(v_constraint_name, 'sale_orders', 'sales_orders'));
            RAISE NOTICE '✅ Renamed unique constraint %', v_constraint_name;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '⚠️  Could not rename unique constraint %: %', v_constraint_name, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- Rename unique constraint on SalesOrderLines
DO $$
DECLARE
    v_constraint_name text;
    v_table_exists boolean;
    v_table_oid oid;
BEGIN
    -- Check if SalesOrderLines table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines'
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE NOTICE '⚠️  Table SalesOrderLines does not exist, skipping unique constraint updates';
        RETURN;
    END IF;
    
    -- Get OID safely
    SELECT oid INTO v_table_oid FROM pg_class WHERE relname = 'SalesOrderLines' AND relnamespace = 'public'::regnamespace;
    
    IF v_table_oid IS NULL THEN
        RAISE NOTICE '⚠️  Could not find SalesOrderLines OID, skipping unique constraint updates';
        RETURN;
    END IF;
    
    FOR v_constraint_name IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = v_table_oid
        AND contype = 'u'
    LOOP
        BEGIN
            EXECUTE format('ALTER TABLE "SalesOrderLines" RENAME CONSTRAINT %I TO %I', 
                v_constraint_name,
                replace(v_constraint_name, 'sale_order_lines', 'sales_order_lines'));
            RAISE NOTICE '✅ Renamed unique constraint %', v_constraint_name;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '⚠️  Could not rename unique constraint %: %', v_constraint_name, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- ====================================================
-- STEP 5: Update Check Constraints
-- ====================================================

-- Rename check constraints on SalesOrders
DO $$
DECLARE
    v_constraint_name text;
    v_table_exists boolean;
    v_table_oid oid;
BEGIN
    -- Check if SalesOrders table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrders'
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE NOTICE '⚠️  Table SalesOrders does not exist, skipping check constraint updates';
        RETURN;
    END IF;
    
    -- Get OID safely
    SELECT oid INTO v_table_oid FROM pg_class WHERE relname = 'SalesOrders' AND relnamespace = 'public'::regnamespace;
    
    IF v_table_oid IS NULL THEN
        RAISE NOTICE '⚠️  Could not find SalesOrders OID, skipping check constraint updates';
        RETURN;
    END IF;
    
    FOR v_constraint_name IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = v_table_oid
        AND contype = 'c'
    LOOP
        BEGIN
            EXECUTE format('ALTER TABLE "SalesOrders" RENAME CONSTRAINT %I TO %I', 
                v_constraint_name,
                replace(v_constraint_name, 'sale_orders', 'sales_orders'));
            RAISE NOTICE '✅ Renamed check constraint %', v_constraint_name;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '⚠️  Could not rename check constraint %: %', v_constraint_name, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- Rename check constraints on SalesOrderLines
DO $$
DECLARE
    v_constraint_name text;
    v_table_exists boolean;
    v_table_oid oid;
BEGIN
    -- Check if SalesOrderLines table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines'
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE NOTICE '⚠️  Table SalesOrderLines does not exist, skipping check constraint updates';
        RETURN;
    END IF;
    
    -- Get OID safely
    SELECT oid INTO v_table_oid FROM pg_class WHERE relname = 'SalesOrderLines' AND relnamespace = 'public'::regnamespace;
    
    IF v_table_oid IS NULL THEN
        RAISE NOTICE '⚠️  Could not find SalesOrderLines OID, skipping check constraint updates';
        RETURN;
    END IF;
    
    FOR v_constraint_name IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = v_table_oid
        AND contype = 'c'
    LOOP
        BEGIN
            EXECUTE format('ALTER TABLE "SalesOrderLines" RENAME CONSTRAINT %I TO %I', 
                v_constraint_name,
                replace(v_constraint_name, 'sale_order_lines', 'sales_order_lines'));
            RAISE NOTICE '✅ Renamed check constraint %', v_constraint_name;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '⚠️  Could not rename check constraint %: %', v_constraint_name, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- ====================================================
-- STEP 6: Update Triggers
-- ====================================================

-- Rename triggers on SalesOrders
DO $$
DECLARE
    v_trigger_name text;
    v_table_exists boolean;
    v_table_oid oid;
BEGIN
    -- Check if SalesOrders table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrders'
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE NOTICE '⚠️  Table SalesOrders does not exist, skipping trigger updates';
        RETURN;
    END IF;
    
    -- Get OID safely
    SELECT oid INTO v_table_oid FROM pg_class WHERE relname = 'SalesOrders' AND relnamespace = 'public'::regnamespace;
    
    IF v_table_oid IS NULL THEN
        RAISE NOTICE '⚠️  Could not find SalesOrders OID, skipping trigger updates';
        RETURN;
    END IF;
    
    FOR v_trigger_name IN
        SELECT tgname
        FROM pg_trigger
        WHERE tgrelid = v_table_oid
        AND NOT tgisinternal
    LOOP
        BEGIN
            EXECUTE format('ALTER TRIGGER %I ON "SalesOrders" RENAME TO %I', 
                v_trigger_name,
                replace(v_trigger_name, 'sale_orders', 'sales_orders'));
            RAISE NOTICE '✅ Renamed trigger %', v_trigger_name;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '⚠️  Could not rename trigger %: %', v_trigger_name, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- Rename triggers on SalesOrderLines
DO $$
DECLARE
    v_trigger_name text;
    v_table_exists boolean;
    v_table_oid oid;
BEGIN
    -- Check if SalesOrderLines table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines'
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE NOTICE '⚠️  Table SalesOrderLines does not exist, skipping trigger updates';
        RETURN;
    END IF;
    
    -- Get OID safely
    SELECT oid INTO v_table_oid FROM pg_class WHERE relname = 'SalesOrderLines' AND relnamespace = 'public'::regnamespace;
    
    IF v_table_oid IS NULL THEN
        RAISE NOTICE '⚠️  Could not find SalesOrderLines OID, skipping trigger updates';
        RETURN;
    END IF;
    
    FOR v_trigger_name IN
        SELECT tgname
        FROM pg_trigger
        WHERE tgrelid = v_table_oid
        AND NOT tgisinternal
    LOOP
        BEGIN
            EXECUTE format('ALTER TRIGGER %I ON "SalesOrderLines" RENAME TO %I', 
                v_trigger_name,
                replace(v_trigger_name, 'sale_order_lines', 'sales_order_lines'));
            RAISE NOTICE '✅ Renamed trigger %', v_trigger_name;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '⚠️  Could not rename trigger %: %', v_trigger_name, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- ====================================================
-- STEP 7: Update RLS Policies
-- ====================================================

-- Drop and recreate RLS policies with new names
DROP POLICY IF EXISTS "sale_orders_select_own_org" ON "SalesOrders";
DROP POLICY IF EXISTS "sale_orders_insert_own_org" ON "SalesOrders";
DROP POLICY IF EXISTS "sale_orders_update_own_org" ON "SalesOrders";
DROP POLICY IF EXISTS "sale_orders_delete_own_org" ON "SalesOrders";

DROP POLICY IF EXISTS "sale_order_lines_select_own_org" ON "SalesOrderLines";
DROP POLICY IF EXISTS "sale_order_lines_insert_own_org" ON "SalesOrderLines";
DROP POLICY IF EXISTS "sale_order_lines_update_own_org" ON "SalesOrderLines";
DROP POLICY IF EXISTS "sale_order_lines_delete_own_org" ON "SalesOrderLines";

-- Recreate policies with new names
CREATE POLICY "sales_orders_select_own_org"
    ON "SalesOrders"
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

CREATE POLICY "sales_orders_insert_own_org"
    ON "SalesOrders"
    FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

CREATE POLICY "sales_orders_update_own_org"
    ON "SalesOrders"
    FOR UPDATE
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    )
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

CREATE POLICY "sales_orders_delete_own_org"
    ON "SalesOrders"
    FOR DELETE
    USING (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    );

CREATE POLICY "sales_order_lines_select_own_org"
    ON "SalesOrderLines"
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

CREATE POLICY "sales_order_lines_insert_own_org"
    ON "SalesOrderLines"
    FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

CREATE POLICY "sales_order_lines_update_own_org"
    ON "SalesOrderLines"
    FOR UPDATE
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    )
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

CREATE POLICY "sales_order_lines_delete_own_org"
    ON "SalesOrderLines"
    FOR DELETE
    USING (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    );

-- ====================================================
-- STEP 8: Update Comments
-- ====================================================

COMMENT ON TABLE "SalesOrders" IS 'Sales Orders created from approved Quotes';
COMMENT ON COLUMN "SalesOrders".quote_id IS 'Reference to the approved Quote that this Sales Order was created from';
COMMENT ON COLUMN "SalesOrders".status IS 'Order status: Draft, Confirmed, In Production, Ready for Delivery, Delivered, Cancelled';
COMMENT ON COLUMN "SalesOrders".sale_order_no IS 'Unique sales order number per organization';

COMMENT ON TABLE "SalesOrderLines" IS 'Line items for Sales Orders';
COMMENT ON COLUMN "SalesOrderLines".quote_line_id IS 'Reference to the QuoteLine that this SalesOrderLine was created from (optional, for traceability)';
COMMENT ON COLUMN "SalesOrderLines".line_number IS 'Line number within the sales order (1, 2, 3, ...)';

-- ====================================================
-- STEP 9: Summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Tables renamed:';
    RAISE NOTICE '   - SaleOrders → SalesOrders';
    RAISE NOTICE '   - SaleOrderLines → SalesOrderLines';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '   1. Update all SQL functions that reference these tables';
    RAISE NOTICE '   2. Update all triggers that reference these tables';
    RAISE NOTICE '   3. Update all views that reference these tables';
    RAISE NOTICE '   4. Update TypeScript/React code';
    RAISE NOTICE '';
END;
$$;

