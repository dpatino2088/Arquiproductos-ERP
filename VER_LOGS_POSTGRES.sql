-- ====================================================
-- Ver Logs de Postgres (para debugging)
-- ====================================================
-- Los RAISE NOTICE aparecen en los logs, no en Results
-- ====================================================

-- Nota: En Supabase, ve a:
-- Dashboard → Logs → Postgres Logs
-- 
-- O ejecuta este query para verificar si hay mensajes recientes

-- Alternativa: Este query muestra información sobre funciones ejecutadas recientemente
SELECT 
    'Last function executions' as info,
    schemaname,
    funcname,
    calls,
    total_time,
    self_time
FROM pg_stat_user_functions
WHERE funcname LIKE '%salesorder%'
ORDER BY calls DESC
LIMIT 10;

-- También puedes verificar directamente si las líneas se crearon
SELECT 
    'SalesOrderLines created' as info,
    COUNT(*) as total_lines,
    COUNT(DISTINCT sale_order_id) as salesorders_with_lines
FROM "SalesOrderLines"
WHERE deleted = false
AND created_at > now() - interval '10 minutes';


