-- ====================================================
-- Fix: Verificar y corregir nombre de tabla SalesOrders
-- ====================================================
-- Este script verifica si la tabla se llama "SaleOrders" o "SalesOrders"
-- y la renombra si es necesario para que coincida con el código TypeScript
-- ====================================================

SET client_min_messages TO NOTICE;

-- ====================================================
-- STEP 1: Verificar qué nombre tiene la tabla actualmente
-- ====================================================

DO $$
DECLARE
    v_table_name text;
BEGIN
    -- Verificar si existe "SaleOrders" (sin 's')
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrders'
    ) THEN
        RAISE NOTICE '⚠️  Tabla encontrada: "SaleOrders" (sin "s")';
        RAISE NOTICE '🔧 Renombrando a "SalesOrders" para coincidir con el código TypeScript...';
        
        ALTER TABLE "SaleOrders" RENAME TO "SalesOrders";
        RAISE NOTICE '✅ Tabla renombrada exitosamente a "SalesOrders"';
        
    -- Verificar si existe "SalesOrders" (con 's')
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrders'
    ) THEN
        RAISE NOTICE '✅ Tabla "SalesOrders" ya existe con el nombre correcto';
        
    ELSE
        RAISE WARNING '❌ No se encontró ninguna tabla SaleOrders ni SalesOrders';
        RAISE WARNING '⚠️  Es posible que necesites ejecutar las migraciones de creación de tablas primero';
    END IF;
END;
$$;

-- ====================================================
-- STEP 2: Verificar y renombrar SaleOrderLines si existe
-- ====================================================

DO $$
BEGIN
    -- Verificar si existe "SaleOrderLines" (sin 's')
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrderLines'
    ) THEN
        RAISE NOTICE '⚠️  Tabla encontrada: "SaleOrderLines" (sin "s")';
        RAISE NOTICE '🔧 Renombrando a "SalesOrderLines" para coincidir con el código TypeScript...';
        
        ALTER TABLE "SaleOrderLines" RENAME TO "SalesOrderLines";
        RAISE NOTICE '✅ Tabla renombrada exitosamente a "SalesOrderLines"';
        
    -- Verificar si existe "SalesOrderLines" (con 's')
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SalesOrderLines'
    ) THEN
        RAISE NOTICE '✅ Tabla "SalesOrderLines" ya existe con el nombre correcto';
        
    ELSE
        RAISE NOTICE 'ℹ️  Tabla "SalesOrderLines" no existe (esto es normal si no hay líneas aún)';
    END IF;
END;
$$;

-- ====================================================
-- STEP 3: Verificación final
-- ====================================================

SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'SalesOrders'
        ) THEN '✅ Tabla "SalesOrders" existe'
        ELSE '❌ Tabla "SalesOrders" NO existe'
    END AS sales_orders_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'SalesOrderLines'
        ) THEN '✅ Tabla "SalesOrderLines" existe'
        ELSE 'ℹ️  Tabla "SalesOrderLines" no existe (normal si no hay datos)'
    END AS sales_order_lines_status;

-- ====================================================
-- STEP 4: Verificar triggers que usan estas tablas
-- ====================================================

SELECT 
    t.tgname AS trigger_name,
    c.relname AS table_name,
    CASE t.tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        ELSE 'Unknown'
    END AS status
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname IN ('SalesOrders', 'SaleOrders', 'Quotes')
AND t.tgname LIKE '%quote%approved%'
ORDER BY c.relname, t.tgname;

