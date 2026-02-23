-- ============================================================
-- PASO 8: Deprecar funciones legacy
-- ============================================================
-- Añadir comentario DEPRECATED a funciones sustituidas por session_is_*.
-- No se eliminan; otras tablas/políticas pueden seguir usándolas hasta auditoría.
-- ============================================================

COMMENT ON FUNCTION public.is_org_user_member_strict(uuid) IS
  'DEPRECATED: Use session_is_org_user(uuid) after init_session_context(). Replaced in Quotes, Proposals, Directory RLS by 20260224_005.';

COMMENT ON FUNCTION public.is_portal_user_in_org(uuid) IS
  'DEPRECATED: Prefer session_is_dealer_user(uuid) after init_session_context(). Still used by org-only tables (catalog, BOM, etc.).';

COMMENT ON FUNCTION public.is_org_user_member(uuid) IS
  'DEPRECATED: Includes DealerUsers; use is_org_user_member_strict or session_is_org_user/session_is_dealer_user.';

COMMENT ON FUNCTION public.is_org_user_superadmin(uuid) IS
  'DEPRECATED: Prefer session_is_admin(uuid) for org-scoped admin check after init_session_context().';

-- -----------------------------------------------------------------------------
-- Auditoría: políticas que aún referencian estas funciones (para migración futura)
-- Ejecutar en SQL Editor para listar políticas a actualizar:
-- -----------------------------------------------------------------------------
/*
SELECT n.nspname AS schema_name,
       c.relname AS table_name,
       p.polname AS policy_name,
       CASE WHEN pg_get_expr(p.polqual, p.polrelid) ILIKE '%is_org_user_member_strict%' THEN 'polqual' ELSE NULL END AS in_using,
       CASE WHEN pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%is_org_user_member_strict%' THEN 'polwithcheck' ELSE NULL END AS in_with_check
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND (
    pg_get_expr(p.polqual, p.polrelid) ILIKE '%is_org_user_member_strict%'
    OR pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%is_org_user_member_strict%'
    OR pg_get_expr(p.polqual, p.polrelid) ILIKE '%is_portal_user_in_org%'
    OR pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%is_portal_user_in_org%'
    OR pg_get_expr(p.polqual, p.polrelid) ILIKE '%is_org_user_member%'
    OR pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%is_org_user_member%'
    OR pg_get_expr(p.polqual, p.polrelid) ILIKE '%is_org_user_superadmin%'
    OR pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%is_org_user_superadmin%'
  );
*/
