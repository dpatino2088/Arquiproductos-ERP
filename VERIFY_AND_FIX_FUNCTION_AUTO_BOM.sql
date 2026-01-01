-- ============================================================================
-- VERIFICAR Y CORREGIR: Función on_quote_approved_create_operational_docs
-- ============================================================================

-- Verificar si la función tiene la lógica de generación automática
SELECT 
    CASE 
        WHEN pg_get_functiondef(p.oid) LIKE '%v_qlc_count%' 
            AND pg_get_functiondef(p.oid) LIKE '%generate_configured_bom_for_quote_line%'
        THEN '✅ Tiene generación automática'
        ELSE '❌ NO tiene generación automática'
    END as status_funcion,
    LENGTH(pg_get_functiondef(p.oid)) as function_length
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
    AND p.proname = 'on_quote_approved_create_operational_docs';

-- Si la función NO tiene generación automática, ejecutar la migración 190
-- (Este script solo verifica, la migración se debe ejecutar manualmente)








