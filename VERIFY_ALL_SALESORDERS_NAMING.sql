-- ====================================================
-- Verify All SalesOrders Naming Convention
-- ====================================================
-- This script verifies that all references follow the convention:
-- - Módulo/menú: "Sales Orders"
-- - Entidad singular: "Sales Order"
-- - Tabla: "SalesOrders" (plural)
-- - Líneas: "SalesOrderLines" (plural)
-- ====================================================

DO $$
DECLARE
    v_table_exists boolean;
    v_trigger_exists boolean;
    v_function_exists boolean;
    v_wrong_references text[];
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Verifying SalesOrders Naming Convention';
    RAISE NOTICE '====================================================';
    
    -- 1. Verify table name is "SalesOrders" (plural)
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrders'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        RAISE NOTICE '✅ Table name is correct: "SalesOrders" (plural)';
    ELSE
        RAISE WARNING '❌ Table "SalesOrders" does not exist!';
    END IF;
    
    -- 2. Verify table "SaleOrders" (singular) does NOT exist
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrders'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        RAISE WARNING '⚠️  Table "SaleOrders" (singular) still exists! Should be renamed to "SalesOrders"';
    ELSE
        RAISE NOTICE '✅ No incorrect table "SaleOrders" (singular) found';
    END IF;
    
    -- 3. Verify SalesOrderLines table name
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        RAISE NOTICE '✅ Table name is correct: "SalesOrderLines" (plural)';
    ELSE
        RAISE WARNING '❌ Table "SalesOrderLines" does not exist!';
    END IF;
    
    -- 4. Verify trigger exists and is active
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'trg_on_quote_approved_create_operational_docs'
        AND tgrelid = '"Quotes"'::regclass
    ) INTO v_trigger_exists;
    
    IF v_trigger_exists THEN
        RAISE NOTICE '✅ Trigger "trg_on_quote_approved_create_operational_docs" exists';
    ELSE
        RAISE WARNING '⚠️  Trigger "trg_on_quote_approved_create_operational_docs" does not exist!';
    END IF;
    
    -- 5. Verify function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'on_quote_approved_create_operational_docs'
        AND pronamespace = 'public'::regnamespace
    ) INTO v_function_exists;
    
    IF v_function_exists THEN
        RAISE NOTICE '✅ Function "on_quote_approved_create_operational_docs" exists';
    ELSE
        RAISE WARNING '⚠️  Function "on_quote_approved_create_operational_docs" does not exist!';
    END IF;
    
    -- 6. Check function body for incorrect table references
    -- This is a basic check - full verification requires reading the function definition
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Summary:';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Convention:';
    RAISE NOTICE '  - Módulo/menú: "Sales Orders"';
    RAISE NOTICE '  - Entidad singular: "Sales Order"';
    RAISE NOTICE '  - Tabla: "SalesOrders" (plural)';
    RAISE NOTICE '  - Líneas: "SalesOrderLines" (plural)';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Execute FIX_TRIGGER_SALESORDERS_TABLE_NAME.sql to fix trigger';
    RAISE NOTICE '  2. Verify all SQL files use "SalesOrders" (not "SaleOrders")';
    RAISE NOTICE '  3. Verify all TypeScript interfaces use "SaleOrder" (singular) for types';
    RAISE NOTICE '====================================================';
    
END;
$$;






