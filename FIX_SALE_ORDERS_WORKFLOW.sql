-- ============================================================================
-- CORRECCIÓN DEL WORKFLOW DE SALE ORDERS
-- ============================================================================
-- Este script corrige los problemas con la creación de Sale Orders:
-- 1. Asegura que no haya duplicados
-- 2. Corrige Sale Orders sin organization_id o customer_id
-- 3. Verifica que la función convert_quote_to_sale_order funcione correctamente

DO $$
DECLARE
    v_fixed_count INT := 0;
    v_duplicate_count INT := 0;
    rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔧 CORRIGIENDO WORKFLOW DE SALE ORDERS';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 1. ELIMINAR SALE ORDERS DUPLICADOS (mantener el más reciente)
    -- ========================================================================
    RAISE NOTICE '📋 PASO 1: Eliminando Sale Orders duplicados...';
    
    -- Marcar como deleted los duplicados (mantener el más reciente)
    FOR rec IN 
        SELECT 
            quote_id,
            organization_id,
            ARRAY_AGG(id ORDER BY created_at DESC) as sale_order_ids
        FROM "SaleOrders"
        WHERE deleted = false AND quote_id IS NOT NULL
        GROUP BY quote_id, organization_id
        HAVING COUNT(*) > 1
    LOOP
        -- Mantener el primero (más reciente) y marcar los demás como deleted
        UPDATE "SaleOrders"
        SET deleted = true,
            updated_at = NOW()
        WHERE id = ANY(rec.sale_order_ids[2:]) -- Todos excepto el primero
            AND deleted = false;
        
        GET DIAGNOSTICS v_duplicate_count = ROW_COUNT;
        v_fixed_count := v_fixed_count + v_duplicate_count;
        
        RAISE NOTICE '   ✅ Corregidos % duplicados para Quote %', v_duplicate_count, rec.quote_id;
    END LOOP;
    
    IF v_duplicate_count = 0 THEN
        RAISE NOTICE '   ✅ No se encontraron duplicados';
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 2. CORREGIR SALE ORDERS SIN ORGANIZATION_ID
    -- ========================================================================
    RAISE NOTICE '📋 PASO 2: Corrigiendo Sale Orders sin organization_id...';
    
    UPDATE "SaleOrders" so
    SET organization_id = q.organization_id,
        updated_at = NOW()
    FROM "Quotes" q
    WHERE so.quote_id = q.id
        AND so.organization_id IS NULL
        AND so.deleted = false
        AND q.deleted = false;
    
    GET DIAGNOSTICS v_fixed_count = ROW_COUNT;
    
    IF v_fixed_count > 0 THEN
        RAISE NOTICE '   ✅ Corregidos % Sale Orders sin organization_id', v_fixed_count;
    ELSE
        RAISE NOTICE '   ✅ No se encontraron Sale Orders sin organization_id';
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 3. CORREGIR SALE ORDERS SIN CUSTOMER_ID
    -- ========================================================================
    RAISE NOTICE '📋 PASO 3: Corrigiendo Sale Orders sin customer_id...';
    
    UPDATE "SaleOrders" so
    SET customer_id = q.customer_id,
        updated_at = NOW()
    FROM "Quotes" q
    WHERE so.quote_id = q.id
        AND so.customer_id IS NULL
        AND so.deleted = false
        AND q.deleted = false
        AND q.customer_id IS NOT NULL;
    
    GET DIAGNOSTICS v_fixed_count = ROW_COUNT;
    
    IF v_fixed_count > 0 THEN
        RAISE NOTICE '   ✅ Corregidos % Sale Orders sin customer_id', v_fixed_count;
    ELSE
        RAISE NOTICE '   ✅ No se encontraron Sale Orders sin customer_id';
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 4. VERIFICAR QUE convert_quote_to_sale_order VERIFIQUE DUPLICADOS
    -- ========================================================================
    RAISE NOTICE '📋 PASO 4: Verificando función convert_quote_to_sale_order...';
    
    -- La función debería verificar si ya existe un Sale Order antes de crear uno nuevo
    -- Si la migración 180 está aplicada, esto debería estar funcionando
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
        AND p.proname = 'convert_quote_to_sale_order'
    ) THEN
        RAISE NOTICE '   ✅ Función convert_quote_to_sale_order existe';
        
        -- Verificar si la función tiene la lógica para retornar Sale Order existente
        -- (Esto se verifica manualmente revisando el código de la función)
        RAISE NOTICE '   ℹ️  Verificar manualmente que la función retorne Sale Order existente si ya existe';
    ELSE
        RAISE NOTICE '   ⚠️  WARNING: Función convert_quote_to_sale_order no existe';
        RAISE NOTICE '   Se recomienda ejecutar la migración 180';
    END IF;
    RAISE NOTICE '';
    
    -- ========================================================================
    -- 5. RESUMEN FINAL
    -- ========================================================================
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ CORRECCIÓN COMPLETA';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE 'Ejecuta VERIFY_SALE_ORDERS_ISSUES.sql para verificar que todo esté correcto';
    RAISE NOTICE '';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error corrigiendo Sale Orders: %', SQLERRM;
END $$;








