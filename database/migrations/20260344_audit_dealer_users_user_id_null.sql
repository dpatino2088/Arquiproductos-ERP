-- =============================================================================
-- Migration: Auditoría DealerUsers con user_id NULL
-- =============================================================================
-- Detecta filas DealerUsers activas sin user_id linkeado a auth.users.
-- Estas filas pueden causar fallos en RLS y en link_portal_user.
--
-- Este script solo CREA una vista de auditoría y documenta el proceso de fix.
-- La corrección (UPDATE user_id) debe hacerse manualmente validando 1:1 email.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Vista de auditoría: DealerUsers activos sin user_id
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_audit_dealer_users_missing_user_id
AS
SELECT
  du.id,
  du.portal_user_email,
  du.dealer_id,
  du.organization_id,
  du.role,
  du.status,
  du.deleted,
  du.created_at
FROM public."DealerUsers" du
WHERE du.user_id IS NULL
  AND (du.deleted IS NULL OR du.deleted = false);

COMMENT ON VIEW public.v_audit_dealer_users_missing_user_id
  IS 'DealerUsers activos sin user_id. Requieren corrección manual: mapear portal_user_email a auth.users.id y UPDATE.';

-- -----------------------------------------------------------------------------
-- Función de reporte (opcional): devuelve filas para revisión
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.audit_dealer_users_missing_user_id()
RETURNS TABLE(
  id uuid,
  portal_user_email text,
  dealer_id uuid,
  organization_id uuid,
  role text,
  status text,
  count_total bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH missing AS (
    SELECT du.id, du.portal_user_email, du.dealer_id, du.organization_id, du.role, du.status
    FROM public."DealerUsers" du
    WHERE du.user_id IS NULL
      AND (du.deleted IS NULL OR du.deleted = false)
  ),
  total AS (
    SELECT count(*) AS cnt FROM missing
  )
  SELECT
    m.id,
    m.portal_user_email,
    m.dealer_id,
    m.organization_id,
    m.role,
    m.status,
    t.cnt AS count_total
  FROM missing m
  CROSS JOIN total t;
$$;

COMMENT ON FUNCTION public.audit_dealer_users_missing_user_id()
  IS 'Reporta DealerUsers activos sin user_id. Corrección manual: UPDATE "DealerUsers" SET user_id = <auth_users_id> WHERE id = <id>; validar 1:1 email primero.';

-- -----------------------------------------------------------------------------
-- Queries de ejemplo para corrección manual (NO ejecutar sin validar)
-- -----------------------------------------------------------------------------
-- 1. Listar emails que podrían mapear a auth.users:
--    SELECT au.id AS auth_user_id, au.email
--    FROM auth.users au
--    WHERE LOWER(TRIM(au.email)) IN (
--      SELECT LOWER(TRIM(portal_user_email)) FROM public.v_audit_dealer_users_missing_user_id
--    );
--
-- 2. Actualizar una fila específica (ejemplo):
--    UPDATE public."DealerUsers"
--    SET user_id = '<auth_users_id>'
--    WHERE id = '<dealer_user_id>'
--      AND user_id IS NULL;
--
-- 3. Verificar antes de actualizar que no haya duplicados email:
--    SELECT portal_user_email, count(*) FROM public.v_audit_dealer_users_missing_user_id
--    GROUP BY portal_user_email HAVING count(*) > 1;
