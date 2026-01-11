-- ============================================================
-- Migration: Fix DirectoryContacts organization_id NULL issue
-- ============================================================
-- OBJETIVO:
-- 1) Actualizar DirectoryContacts existentes que tienen organization_id = NULL
-- 2) Para contacts con company_id, derivar organization_id de Companies.organization_id
-- 3) Para contacts sin company_id pero en una organización activa, usar el organization_id del contexto
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Actualizar DirectoryContacts con company_id pero organization_id = NULL
-- ============================================================
UPDATE public."DirectoryContacts" dc
SET organization_id = c.organization_id
FROM public."Companies" c
WHERE dc.company_id = c.id
  AND dc.organization_id IS NULL
  AND dc.deleted = false
  AND c.deleted = false
  AND c.organization_id IS NOT NULL;

-- Log how many were updated
DO $$
DECLARE
  updated_count integer;
BEGIN
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE 'Updated % DirectoryContacts with organization_id from Companies', updated_count;
END $$;

-- ============================================================
-- 2) Para contacts sin company_id, intentar establecer organization_id basado en created_by_user_id
-- Si el usuario es OrganizationUser, usar su organization_id
-- Si el usuario es CompanyPortalUser, obtener organization_id de su company
-- ============================================================
-- This is more complex and might require manual review, so we'll leave it as-is
-- The important fix is step 1, which handles the most common case (portal users creating contacts)

COMMIT;

-- ============================================================
-- NOTAS:
-- - Los nuevos contacts ya deberían tener organization_id siempre (fix en useDirectoryContacts.ts)
-- - Si hay contacts huérfanos (sin company_id ni organization_id), se requerirá revisión manual
-- - La política RLS ya está correcta: requiere organization_id IS NOT NULL para OrganizationUsers
-- ============================================================
