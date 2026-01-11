-- ====================================================
-- Migration: Create RPC link_my_org_invites
-- ====================================================
-- OBJETIVO: RPC para linkear OrganizationUsers cuando el usuario acepta invite
-- Se ejecuta desde frontend al entrar por MagicLink
-- ====================================================

BEGIN;

-- Function to link organization invites for current user
CREATE OR REPLACE FUNCTION public.link_my_org_invites()
RETURNS TABLE (
    linked_count integer,
    updated_ids uuid[]
)
LANGUAGE plpgsql
SECURITY DEFINER  -- ✅ Ejecuta con permisos del creador
AS $$
DECLARE
    v_user_id uuid;
    v_user_email text;
    v_linked_count integer := 0;
    v_updated_ids uuid[] := ARRAY[]::uuid[];
BEGIN
    -- ✅ Obtener user_id y email del usuario actual autenticado
    v_user_id := auth.uid();
    v_user_email := (SELECT email FROM auth.users WHERE id = v_user_id);
    
    -- Validar que tenemos user_id y email
    IF v_user_id IS NULL OR v_user_email IS NULL THEN
        RAISE WARNING 'No authenticated user or email found. Skipping link.';
        RETURN QUERY SELECT 0::integer, ARRAY[]::uuid[];
        RETURN;
    END IF;

    -- ✅ Buscar OrganizationUsers donde:
    --    lower(user_email)=lower(session.email) 
    --    y user_id is null 
    --    y deleted=false
    -- ✅ Set user_id=session.user.id, status='active', accepted_at=now()
    WITH updated AS (
        UPDATE public."OrganizationUsers"
        SET 
            user_id = v_user_id,
            status = 'active',
            accepted_at = now(),
            updated_at = now()
        WHERE 
            lower(user_email) = lower(v_user_email)
            AND user_id IS NULL
            AND deleted = false
        RETURNING id
    )
    SELECT 
        COUNT(*)::integer,
        ARRAY_AGG(id)::uuid[]
    INTO v_linked_count, v_updated_ids
    FROM updated;

    -- ✅ Retornar resultado
    RETURN QUERY SELECT v_linked_count, COALESCE(v_updated_ids, ARRAY[]::uuid[]);
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.link_my_org_invites() TO authenticated;
GRANT EXECUTE ON FUNCTION public.link_my_org_invites() TO anon;

-- Add comment
COMMENT ON FUNCTION public.link_my_org_invites() IS 
    'Links OrganizationUsers to the current authenticated user when called from frontend after accepting invite via MagicLink. Searches for OrganizationUsers where lower(user_email)=lower(session.email) and user_id is null and deleted=false, then sets user_id=session.user.id, status=active, and accepted_at=now(). Returns count of linked records and array of updated IDs.';

COMMIT;
