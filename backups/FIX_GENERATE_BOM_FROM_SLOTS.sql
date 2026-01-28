-- ============================================================================
-- FIX: generate_bom_from_slots - Verificar y convertir a SECURITY DEFINER
-- ============================================================================
-- Esto arregla el problema de RLS que bloquea inserts en BOMInstances/BOMInstanceLines
-- ============================================================================

-- 1) Verificar la función actual (firma y si es SECURITY DEFINER)
SELECT
  p.oid::regprocedure AS signature,
  p.prosecdef AS is_security_definer,
  n.nspname AS schema,
  p.proname AS function_name
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'generate_bom_from_slots';

-- 2) Verificar si RLS está activo en tablas BOM
SELECT 
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('BOMInstances', 'BOMInstanceLines', 'BOMTemplates', 'BOMTemplateSlots')
ORDER BY c.relname;

-- 3) Ver policies existentes (para confirmar bloqueo)
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('BOMInstances', 'BOMInstanceLines', 'BOMTemplates', 'BOMTemplateSlots')
ORDER BY tablename, policyname;

-- ============================================================================
-- FIX: Convertir función a SECURITY DEFINER
-- ============================================================================
-- IMPORTANTE: Ejecutar esto SOLO después de verificar la firma exacta del paso 1
-- Reemplazar <FIRMA_EXACTA> con el resultado del paso 1

-- Ejemplo (NO copiar sin verificar la firma):
-- ALTER FUNCTION public.generate_bom_from_slots(uuid, uuid, uuid)
--   SECURITY DEFINER;

-- ALTER FUNCTION public.generate_bom_from_slots(uuid, uuid, uuid)
--   SET search_path = public;

-- GRANT EXECUTE ON FUNCTION public.generate_bom_from_slots(uuid, uuid, uuid) 
--   TO authenticated;

-- ============================================================================
-- ALTERNATIVA: Si la función tiene parámetros nombrados, usar esto:
-- ============================================================================

-- ALTER FUNCTION public.generate_bom_from_slots(
--   p_org_id uuid,
--   p_quote_line_id uuid,
--   p_product_type_id uuid
-- ) SECURITY DEFINER;

-- ALTER FUNCTION public.generate_bom_from_slots(
--   p_org_id uuid,
--   p_quote_line_id uuid,
--   p_product_type_id uuid
-- ) SET search_path = public;

-- GRANT EXECUTE ON FUNCTION public.generate_bom_from_slots(
--   p_org_id uuid,
--   p_quote_line_id uuid,
--   p_product_type_id uuid
-- ) TO authenticated;

-- ============================================================================
-- NOTAS:
-- ============================================================================
-- 1. Ejecuta primero el paso 1 para obtener la firma exacta
-- 2. Usa esa firma en los ALTER FUNCTION
-- 3. Con SECURITY DEFINER, la función ejecuta como el owner (postgres)
-- 4. Esto bypassea RLS (a menos que tengas FORCE RLS)
-- 5. Siempre usa SET search_path = public para seguridad
