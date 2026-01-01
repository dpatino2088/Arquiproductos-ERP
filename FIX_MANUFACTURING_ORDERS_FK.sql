-- ====================================================
-- Fix ManufacturingOrders Foreign Key
-- ====================================================
-- Este script corrige la foreign key de ManufacturingOrders
-- para que referencie "SalesOrders" (plural) en lugar de "SaleOrders" (singular)
-- ====================================================

-- Verificar si la foreign key existe y qué tabla referencia
DO $$
DECLARE
    v_constraint_name text;
    v_table_name text;
BEGIN
    -- Buscar la constraint de foreign key
    SELECT 
        tc.constraint_name,
        ccu.table_name
    INTO v_constraint_name, v_table_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu 
        ON ccu.constraint_name = tc.constraint_name
    WHERE tc.table_name = 'ManufacturingOrders'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'public'
        AND (
            SELECT column_name 
            FROM information_schema.key_column_usage 
            WHERE constraint_name = tc.constraint_name 
            AND table_name = 'ManufacturingOrders'
            LIMIT 1
        ) = 'sale_order_id';
    
    IF v_constraint_name IS NOT NULL THEN
        RAISE NOTICE 'Found foreign key constraint: %', v_constraint_name;
        RAISE NOTICE 'Currently references table: %', v_table_name;
        
        -- Si referencia "SaleOrders" (singular), necesitamos corregirlo
        IF v_table_name = 'SaleOrders' THEN
            RAISE NOTICE '⚠️ Foreign key references "SaleOrders" (singular), but table is now "SalesOrders" (plural)';
            RAISE NOTICE 'Dropping old constraint...';
            
            -- Dropar la constraint antigua
            EXECUTE format('ALTER TABLE "ManufacturingOrders" DROP CONSTRAINT IF EXISTS %I', v_constraint_name);
            
            RAISE NOTICE 'Creating new constraint referencing "SalesOrders"...';
            
            -- Crear la nueva constraint con el nombre correcto
            ALTER TABLE "ManufacturingOrders"
            ADD CONSTRAINT fk_manufacturing_orders_sales_orders
            FOREIGN KEY (sale_order_id)
            REFERENCES "SalesOrders"(id)
            ON DELETE RESTRICT;
            
            RAISE NOTICE '✅ Foreign key constraint updated to reference "SalesOrders"';
        ELSE
            RAISE NOTICE '✅ Foreign key already references correct table: %', v_table_name;
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No foreign key constraint found for sale_order_id in ManufacturingOrders';
        RAISE NOTICE 'Creating new constraint...';
        
        -- Crear la constraint si no existe
        ALTER TABLE "ManufacturingOrders"
        ADD CONSTRAINT fk_manufacturing_orders_sales_orders
        FOREIGN KEY (sale_order_id)
        REFERENCES "SalesOrders"(id)
        ON DELETE RESTRICT;
        
        RAISE NOTICE '✅ Foreign key constraint created';
    END IF;
END;
$$;

-- Verificar el resultado
SELECT 
    tc.constraint_name,
    ccu.table_name AS referenced_table,
    kcu.column_name AS column_name,
    ccu.column_name AS referenced_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON kcu.constraint_name = tc.constraint_name
JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'ManufacturingOrders'
    AND tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND kcu.column_name = 'sale_order_id';






