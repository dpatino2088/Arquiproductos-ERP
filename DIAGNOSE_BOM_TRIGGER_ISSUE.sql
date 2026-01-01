-- ====================================================
-- Diagnóstico Completo del Trigger de BOM
-- ====================================================
-- Este script diagnostica por qué el trigger no está funcionando
-- ====================================================

DO $$
DECLARE
    v_function_exists boolean;
    v_trigger_exists boolean;
    v_trigger_enabled boolean;
    v_mo_count integer;
    v_so_count integer;
    v_bom_instance_count integer;
    v_bom_line_count integer;
    v_qlc_count integer;
    v_recent_mo RECORD;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'DIAGNÓSTICO COMPLETO DEL TRIGGER DE BOM';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    -- Paso 1: Verificar función
    RAISE NOTICE 'Paso 1: Verificando función...';
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_manufacturing_order_insert_generate_bom'
    ) INTO v_function_exists;
    
    IF v_function_exists THEN
        RAISE NOTICE '✅ Función on_manufacturing_order_insert_generate_bom existe';
    ELSE
        RAISE WARNING '❌ Función on_manufacturing_order_insert_generate_bom NO existe';
        RAISE NOTICE '   SOLUCIÓN: Ejecutar FIX_BOM_TRIGGER_FINAL.sql';
    END IF;

    -- Paso 2: Verificar trigger
    RAISE NOTICE '';
    RAISE NOTICE 'Paso 2: Verificando trigger...';
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'ManufacturingOrders'
        AND tgname = 'trg_mo_insert_generate_bom'
        AND t.tgenabled = 'O'
    ) INTO v_trigger_exists;
    
    IF v_trigger_exists THEN
        RAISE NOTICE '✅ Trigger trg_mo_insert_generate_bom existe y está ACTIVO';
    ELSE
        SELECT EXISTS (
            SELECT 1 FROM pg_trigger t
            JOIN pg_class c ON t.tgrelid = c.oid
            WHERE c.relname = 'ManufacturingOrders'
            AND tgname = 'trg_mo_insert_generate_bom'
        ) INTO v_trigger_enabled;
        
        IF v_trigger_enabled THEN
            RAISE WARNING '⚠️ Trigger trg_mo_insert_generate_bom existe pero está DESHABILITADO';
            RAISE NOTICE '   SOLUCIÓN: Ejecutar FIX_BOM_TRIGGER_FINAL.sql para reactivarlo';
        ELSE
            RAISE WARNING '❌ Trigger trg_mo_insert_generate_bom NO existe';
            RAISE NOTICE '   SOLUCIÓN: Ejecutar FIX_BOM_TRIGGER_FINAL.sql';
        END IF;
    END IF;

    -- Paso 3: Verificar Manufacturing Orders
    RAISE NOTICE '';
    RAISE NOTICE 'Paso 3: Verificando Manufacturing Orders...';
    SELECT COUNT(*) INTO v_mo_count
    FROM "ManufacturingOrders"
    WHERE deleted = false;
    
    RAISE NOTICE '   Manufacturing Orders encontrados: %', v_mo_count;
    
    IF v_mo_count = 0 THEN
        RAISE WARNING '⚠️ No hay Manufacturing Orders. El trigger solo se ejecuta cuando se crea un MO.';
    ELSE
        -- Obtener el MO más reciente
        SELECT * INTO v_recent_mo
        FROM "ManufacturingOrders"
        WHERE deleted = false
        ORDER BY created_at DESC
        LIMIT 1;
        
        IF v_recent_mo IS NOT NULL THEN
            RAISE NOTICE '   MO más reciente: % (creado: %)', v_recent_mo.manufacturing_order_no, v_recent_mo.created_at;
            RAISE NOTICE '   Sale Order ID: %', v_recent_mo.sale_order_id;
        END IF;
    END IF;

    -- Paso 4: Verificar Sales Orders
    RAISE NOTICE '';
    RAISE NOTICE 'Paso 4: Verificando Sales Orders...';
    SELECT COUNT(*) INTO v_so_count
    FROM "SalesOrders"
    WHERE deleted = false
    AND status = 'Confirmed';
    
    RAISE NOTICE '   Sales Orders confirmados: %', v_so_count;

    -- Paso 5: Verificar BomInstances
    RAISE NOTICE '';
    RAISE NOTICE 'Paso 5: Verificando BomInstances...';
    SELECT COUNT(*) INTO v_bom_instance_count
    FROM "BomInstances"
    WHERE deleted = false;
    
    RAISE NOTICE '   BomInstances encontrados: %', v_bom_instance_count;
    
    IF v_bom_instance_count = 0 AND v_mo_count > 0 THEN
        RAISE WARNING '⚠️ Hay Manufacturing Orders pero NO hay BomInstances.';
        RAISE WARNING '   Esto indica que el trigger NO se ejecutó o falló silenciosamente.';
    END IF;

    -- Paso 6: Verificar BomInstanceLines
    RAISE NOTICE '';
    RAISE NOTICE 'Paso 6: Verificando BomInstanceLines...';
    SELECT COUNT(*) INTO v_bom_line_count
    FROM "BomInstanceLines"
    WHERE deleted = false;
    
    RAISE NOTICE '   BomInstanceLines encontrados: %', v_bom_line_count;
    
    IF v_bom_line_count = 0 AND v_bom_instance_count > 0 THEN
        RAISE WARNING '⚠️ Hay BomInstances pero NO hay BomInstanceLines.';
        RAISE WARNING '   Esto indica que el trigger no copió QuoteLineComponents a BomInstanceLines.';
    END IF;

    -- Paso 7: Verificar QuoteLineComponents
    RAISE NOTICE '';
    RAISE NOTICE 'Paso 7: Verificando QuoteLineComponents...';
    SELECT COUNT(*) INTO v_qlc_count
    FROM "QuoteLineComponents"
    WHERE deleted = false
    AND source = 'configured_component';
    
    RAISE NOTICE '   QuoteLineComponents encontrados: %', v_qlc_count;
    
    IF v_qlc_count = 0 THEN
        RAISE WARNING '⚠️ No hay QuoteLineComponents. El trigger necesita estos para generar BomInstanceLines.';
    END IF;

    -- Paso 8: Verificar columna organization_id
    RAISE NOTICE '';
    RAISE NOTICE 'Paso 8: Verificando columna organization_id en BomInstanceLines...';
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'BomInstanceLines'
        AND column_name = 'organization_id'
    ) THEN
        RAISE NOTICE '✅ Columna organization_id existe en BomInstanceLines';
    ELSE
        RAISE WARNING '❌ Columna organization_id NO existe en BomInstanceLines';
        RAISE NOTICE '   SOLUCIÓN: Ejecutar FIX_BOM_TRIGGER_FINAL.sql';
    END IF;

    -- Resumen
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'RESUMEN DEL DIAGNÓSTICO';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Manufacturing Orders: %', v_mo_count;
    RAISE NOTICE 'Sales Orders confirmados: %', v_so_count;
    RAISE NOTICE 'BomInstances: %', v_bom_instance_count;
    RAISE NOTICE 'BomInstanceLines: %', v_bom_line_count;
    RAISE NOTICE 'QuoteLineComponents: %', v_qlc_count;
    RAISE NOTICE '';
    
    IF v_mo_count > 0 AND v_bom_instance_count = 0 THEN
        RAISE WARNING '❌ PROBLEMA DETECTADO: Hay MOs pero NO hay BomInstances';
        RAISE NOTICE '   El trigger probablemente NO se ejecutó o falló.';
        RAISE NOTICE '   ACCIÓN: Ejecutar FIX_BOM_TRIGGER_FINAL.sql y luego crear un nuevo MO.';
    ELSIF v_bom_instance_count > 0 AND v_bom_line_count = 0 THEN
        RAISE WARNING '❌ PROBLEMA DETECTADO: Hay BomInstances pero NO hay BomInstanceLines';
        RAISE NOTICE '   El trigger no copió QuoteLineComponents a BomInstanceLines.';
        RAISE NOTICE '   ACCIÓN: Ejecutar FIX_BOM_TRIGGER_FINAL.sql y regenerar BOMs.';
    ELSIF v_qlc_count = 0 THEN
        RAISE WARNING '❌ PROBLEMA DETECTADO: No hay QuoteLineComponents';
        RAISE NOTICE '   Los QuoteLineComponents son necesarios para generar BomInstanceLines.';
        RAISE NOTICE '   ACCIÓN: Aprobar un Quote o generar QuoteLineComponents manualmente.';
    ELSIF v_function_exists AND v_trigger_exists THEN
        RAISE NOTICE '✅ El trigger parece estar configurado correctamente.';
        RAISE NOTICE '   Si aún no funciona, revisa los logs de PostgreSQL para errores.';
    END IF;
    
    RAISE NOTICE '====================================================';
END;
$$;

-- Verificar el MO más reciente y sus datos relacionados
SELECT 
    'MO más reciente' as tipo,
    mo.manufacturing_order_no,
    mo.created_at as mo_created_at,
    so.sale_order_no,
    so.status as so_status,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines,
    COUNT(DISTINCT qlc.id) as quote_line_components
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false AND qlc.source = 'configured_component'
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, mo.created_at, so.sale_order_no, so.status
ORDER BY mo.created_at DESC
LIMIT 5;






