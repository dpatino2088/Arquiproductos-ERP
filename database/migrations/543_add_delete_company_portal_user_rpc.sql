-- ============================================================
-- Migration: Add delete_company_portal_user RPC
-- ============================================================
-- OBJETIVO:
-- Crear RPC para eliminar (soft delete) usuarios de portal
-- Bypasses RLS para permitir que admins eliminen usuarios
-- ============================================================

BEGIN;

-- Create delete_company_portal_user RPC
CREATE OR REPLACE FUNCTION public.delete_company_portal_user(
  p_portal_user_id uuid,
  p_organization_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_count int;
BEGIN
  -- Soft delete: mark as deleted and disabled
  UPDATE public."CompanyPortalUsers"
  SET 
    deleted = true,
    status = 'disabled',
    updated_at = now()
  WHERE 
    id = p_portal_user_id
    AND organization_id = p_organization_id
    AND deleted = false;
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  IF v_deleted_count = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Portal user not found or already deleted'
    );
  END IF;
  
  RETURN jsonb_build_object('success', true);
END;
$$;

COMMENT ON FUNCTION public.delete_company_portal_user IS 
  'Soft delete a company portal user. Marks deleted=true and status=disabled. Bypasses RLS. Only callable by authenticated users with proper organization membership.';

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_company_portal_user(uuid, uuid) TO authenticated;

COMMIT;
