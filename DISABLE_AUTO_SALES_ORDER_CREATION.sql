-- ====================================================
-- Deshabilitar Creación Automática de Sales Orders
-- ====================================================
-- Este script deshabilita el trigger que crea Sales Orders
-- automáticamente cuando se aprueba un Quote.
-- Los Quotes aprobados seguirán apareciendo en QuoteApproved,
-- pero NO se creará el SalesOrder automáticamente.
-- ====================================================

-- ====================================================
-- STEP 1: Deshabilitar el trigger (sin eliminarlo)
-- ====================================================

-- Deshabilitar el trigger (mantiene la función por si se necesita reactivar)
ALTER TABLE "Quotes" DISABLE TRIGGER trg_on_quote_approved_create_operational_docs;

-- ====================================================
-- STEP 2: Verificación
-- ====================================================

DO $$
DECLARE
    v_trigger_enabled boolean;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Deshabilitando creación automática de Sales Orders';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    -- Verificar estado del trigger
    SELECT t.tgenabled = 'O' INTO v_trigger_enabled
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE c.relname = 'Quotes'
    AND t.tgname = 'trg_on_quote_approved_create_operational_docs';
    
    IF v_trigger_enabled THEN
        RAISE NOTICE '✅ Trigger deshabilitado correctamente';
        RAISE NOTICE '';
        RAISE NOTICE 'Ahora cuando se apruebe un Quote:';
        RAISE NOTICE '  ✅ Aparecerá en QuoteApproved (vista)';
        RAISE NOTICE '  ❌ NO se creará SalesOrder automáticamente';
        RAISE NOTICE '';
        RAISE NOTICE 'Para crear SalesOrder, debe hacerse manualmente desde QuoteApproved.';
    ELSE
        RAISE WARNING '⚠️ El trigger ya estaba deshabilitado o no existe';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Proceso completado';
    RAISE NOTICE '====================================================';
END;
$$;

-- ====================================================
-- NOTA: Para reactivar el trigger en el futuro, ejecutar:
-- ====================================================
-- ALTER TABLE "Quotes" ENABLE TRIGGER trg_on_quote_approved_create_operational_docs;
-- ====================================================






