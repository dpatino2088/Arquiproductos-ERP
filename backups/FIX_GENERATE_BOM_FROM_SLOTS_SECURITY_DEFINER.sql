-- ============================================================================
-- FIX: Convertir generate_bom_from_slots a SECURITY DEFINER
-- ============================================================================
-- Firma exacta: public.generate_bom_from_slots(p_org_id uuid, p_quote_line_id uuid, p_product_type_id uuid)
-- ============================================================================

-- Paso 1: Verificar estado actual
SELECT
  p.oid::regprocedure AS signature,
  p.prosecdef AS is_security_definer,
  n.nspname AS schema
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'generate_bom_from_slots';

-- Paso 2: Convertir a SECURITY DEFINER (ejecutar si is_security_definer = false)
ALTER FUNCTION public.generate_bom_from_slots(
  p_org_id uuid,
  p_quote_line_id uuid,
  p_product_type_id uuid
) SECURITY DEFINER;

-- Paso 3: Set search_path para seguridad
ALTER FUNCTION public.generate_bom_from_slots(
  p_org_id uuid,
  p_quote_line_id uuid,
  p_product_type_id uuid
) SET search_path = public;

-- Paso 4: Grant execute a authenticated
GRANT EXECUTE ON FUNCTION public.generate_bom_from_slots(
  p_org_id uuid,
  p_quote_line_id uuid,
  p_product_type_id uuid
) TO authenticated;

-- Paso 5: Verificar que quedó bien
SELECT
  p.oid::regprocedure AS signature,
  p.prosecdef AS is_security_definer,
  n.nspname AS schema
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'generate_bom_from_slots';
