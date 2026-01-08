-- ====================================================
-- Migration 428: Remove sales_order_line_id constraint from ManufacturingOrders
-- ====================================================
-- PROBLEMA: La migración 425 agregó un constraint que requiere sales_order_line_id
-- pero la arquitectura correcta es: ManufacturingOrders tiene sales_order_id (header)
-- NO debe tener sales_order_line_id (eso es para ManufacturingOrderLines)
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 1: Eliminar el constraint que bloquea la inserción
-- ====================================================

DO $$
BEGIN
    -- Eliminar el constraint check_manufacturing_orders_has_sales_order_line_id
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'ManufacturingOrders' 
        AND constraint_name = 'check_manufacturing_orders_has_sales_order_line_id'
    ) THEN
        ALTER TABLE "ManufacturingOrders"
        DROP CONSTRAINT check_manufacturing_orders_has_sales_order_line_id;
        
        RAISE NOTICE '✅ Removed constraint check_manufacturing_orders_has_sales_order_line_id';
    ELSE
        RAISE NOTICE '⚠️ Constraint check_manufacturing_orders_has_sales_order_line_id does not exist (already removed or never created)';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Verificar que sales_order_id existe y es NOT NULL
-- ====================================================

DO $$
BEGIN
    -- Asegurar que sales_order_id existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ManufacturingOrders' 
        AND column_name = 'sales_order_id'
    ) THEN
        ALTER TABLE "ManufacturingOrders" 
        ADD COLUMN sales_order_id uuid NULL 
        REFERENCES "SalesOrders"(id) ON DELETE SET NULL;
        
        RAISE NOTICE '✅ Added sales_order_id column to ManufacturingOrders';
    END IF;
    
    -- Agregar constraint para asegurar que sales_order_id es NOT NULL (a menos que esté deleted)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'ManufacturingOrders' 
        AND constraint_name = 'check_manufacturing_orders_has_sales_order_id'
    ) THEN
        ALTER TABLE "ManufacturingOrders"
        ADD CONSTRAINT check_manufacturing_orders_has_sales_order_id
        CHECK (
            deleted = true OR sales_order_id IS NOT NULL
        );
        
        RAISE NOTICE '✅ Added check constraint: ManufacturingOrders MUST have sales_order_id (unless deleted)';
    END IF;
END $$;

-- ====================================================
-- STEP 3: (Opcional) Si sales_order_line_id existe, puede quedarse pero NO es requerido
-- ====================================================
-- NOTA: Si la columna sales_order_line_id existe, la dejamos pero sin constraint
-- La nueva arquitectura usa ManufacturingOrderLines para relacionar MO con SalesOrderLines
-- ====================================================

COMMENT ON COLUMN "ManufacturingOrders".sales_order_id IS 
    'FK to SalesOrders (header). ManufacturingOrders represents a complete SalesOrder. Use ManufacturingOrderLines to link to individual SalesOrderLines.';

COMMENT ON COLUMN "ManufacturingOrders".sales_order_line_id IS 
    'DEPRECATED: This column may exist for backward compatibility but is NOT required. Use ManufacturingOrderLines table instead.';

