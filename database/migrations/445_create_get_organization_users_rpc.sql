-- ====================================================
-- Migration: Create get_organization_users RPC function
-- ====================================================
-- OBJETIVO: Crear función RPC para obtener usuarios de organización
-- con manejo correcto de VOLATILE para permitir SET si es necesario
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Drop existing function if it exists (to avoid conflicts)
-- ====================================================
DROP FUNCTION IF EXISTS public.get_organization_users(uuid);

-- ====================================================
-- STEP 2: Create the RPC function
-- ====================================================
-- ✅ VOLATILE: Permite usar SET si es necesario
-- ✅ SECURITY DEFINER: Ejecuta con permisos del creador (bypass RLS si es necesario)
-- ✅ Returns table: Estructura compatible con OrganizationUsers
CREATE OR REPLACE FUNCTION public.get_organization_users(
    p_organization_id uuid
)
RETURNS TABLE (
    id uuid,
    role text,
    created_at timestamptz,
    user_id uuid,
    email text,
    invited_by uuid,
    contact_id uuid,
    customer_id uuid,
    customer_name text,
    user_name text,
    organization_id uuid
)
LANGUAGE plpgsql
VOLATILE  -- ✅ CRÍTICO: VOLATILE permite usar SET si es necesario
SECURITY DEFINER  -- ✅ Ejecuta con permisos del creador
SET search_path = public  -- ✅ Ahora permitido porque es VOLATILE
AS $$
BEGIN
    -- Return organization users with related data
    RETURN QUERY
    SELECT 
        ou.id,
        ou.role,
        ou.created_at,
        ou.user_id,
        ou.email,
        ou.invited_by,
        ou.contact_id,
        ou.customer_id,
        COALESCE(dc.customer_name, 'N/A')::text AS customer_name,
        COALESCE(dct.contact_name, NULL)::text AS user_name,
        ou.organization_id
    FROM public."OrganizationUsers" ou
    LEFT JOIN public."DirectoryCustomers" dc ON dc.id = ou.customer_id AND dc.deleted = false
    LEFT JOIN public."DirectoryContacts" dct ON dct.id = ou.contact_id AND dct.deleted = false
    WHERE ou.organization_id = p_organization_id
      AND ou.deleted = false
      AND ou.is_system = false
    ORDER BY ou.created_at DESC;
END;
$$;

-- ====================================================
-- STEP 3: Grant execute permissions
-- ====================================================
GRANT EXECUTE ON FUNCTION public.get_organization_users(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.get_organization_users(uuid) TO authenticated;

-- ====================================================
-- STEP 4: Add comment
-- ====================================================
COMMENT ON FUNCTION public.get_organization_users(uuid) IS 
    'Returns organization users for a given organization_id. Includes related customer and contact names. Marked as VOLATILE to allow SET search_path.';

-- ====================================================
-- STEP 5: Notify PostgREST to reload schema
-- ====================================================
NOTIFY pgrst, 'reload schema';

COMMIT;

