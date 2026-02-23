-- ============================================================================
-- Fix: current_dealer_id — busca por user_id Y por email (legacy rows)
-- 
-- Problema: un usuario puede tener múltiples filas en DealerUsers:
--   - Una fila "legacy" con el auth.uid() real → apunta a Claroscuro
--   - Una fila "correcta" con email pero user_id distinto → apunta a Arquiluz
--
-- La función anterior solo buscaba por user_id = auth.uid(), devolviendo
-- siempre Claroscuro.
--
-- Solución: buscar también por email del usuario autenticado.
-- Prioridad: primero el dealer cuyo DealerUsers tiene user_id = auth.uid()
-- correcto Y cuyo dealer_name sea el más adecuado; si hay empate, ordenar
-- por dealer_name ASC (Arquiluz < Claroscuro).
--
-- Nota: la solución definitiva es limpiar la data (ver DIAGNOSTIC_QUOTES_VISIBILITY.sql).
-- Esta función es el safety net para usuarios con rows legacy.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.current_dealer_id(p_org_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT du.dealer_id
  FROM public."DealerUsers" du
  LEFT JOIN public."Dealers" d ON d.id = du.dealer_id
  WHERE du.organization_id = p_org_id
    AND (
      du.user_id = auth.uid()
      OR LOWER(TRIM(COALESCE(du.portal_user_email, ''))) =
         LOWER(TRIM(COALESCE(
           (SELECT u.email FROM auth.users u WHERE u.id = auth.uid()),
           ''
         )))
    )
    AND (du.deleted IS NULL OR du.deleted = false)
    AND (du.status IS NULL OR du.status IN ('active', 'invited'))
  ORDER BY
    -- Primero filas donde user_id coincide exactamente
    CASE WHEN du.user_id = auth.uid() THEN 0 ELSE 1 END ASC,
    -- Luego alfabético por nombre de dealer (Arquiluz antes que Claroscuro)
    COALESCE(d.dealer_name, '') ASC
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.current_dealer_id(uuid) IS
'Returns dealer_id for the current portal user in the given org.
Matches by user_id (exact) OR portal_user_email (legacy fallback).
Priority: 1) user_id exact match, 2) alphabetical dealer_name.
Multiple DealerUsers rows (e.g. Arquiluz + Claroscuro) are resolved deterministically.
Data fix: update legacy DealerUsers rows to set the correct user_id (see DIAGNOSTIC_QUOTES_VISIBILITY.sql).';
