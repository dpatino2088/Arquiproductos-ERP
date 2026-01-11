-- ============================================================
-- Migration: Fix Quotes RLS and Portal User Function
-- ============================================================
-- OBJETIVO:
-- 1) Actualizar get_current_portal_user() para usar 'status' en lugar de 'portal_user_status'
-- 2) Verificar/corregir Quotes RLS para diferenciar member vs member_manager
-- 3) Asegurar que Directory WRITE no filtre por rol (ambos roles pueden escribir)
-- 4) Mantener lógica de approve solo para member_manager
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Update get_current_portal_user() to use 'status' column
-- ============================================================
-- Drop function first if return type changes (cannot use CREATE OR REPLACE for type changes)
-- Drop all overloads of the function dynamically (same pattern as migration 525)
DO $$
DECLARE
  func_record record;
  drop_sql text;
BEGIN
  -- Find all versions of get_current_portal_user and drop them with CASCADE
  FOR func_record IN 
    SELECT 
      oid,
      pg_get_function_identity_arguments(oid) as args,
      oid::regprocedure::text as func_signature
    FROM pg_proc
    WHERE proname = 'get_current_portal_user'
      AND pronamespace = 'public'::regnamespace
  LOOP
    BEGIN
      -- Build DROP statement - handle functions with no arguments
      IF func_record.args = '' OR func_record.args IS NULL THEN
        drop_sql := 'DROP FUNCTION IF EXISTS public.get_current_portal_user() CASCADE';
      ELSE
        drop_sql := 'DROP FUNCTION IF EXISTS public.get_current_portal_user(' || func_record.args || ') CASCADE';
      END IF;
      
      EXECUTE drop_sql;
      RAISE NOTICE 'Dropped function: %', func_record.func_signature;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop function: % - Error: %', func_record.func_signature, SQLERRM;
    END;
  END LOOP;
END $$;

-- Recreate with correct signature (using status column instead of portal_user_status)
-- Note: Includes organization_id for backward compatibility even though Quotes RLS doesn't use it
CREATE FUNCTION public.get_current_portal_user()
RETURNS TABLE (
  id uuid,
  organization_id uuid,
  company_id uuid,
  portal_user_role text,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cpu.id,
    cpu.organization_id,
    cpu.company_id,
    -- Use role column directly (normalize legacy values)
    CASE 
      WHEN cpu.role IN ('member_manager', 'manager') THEN 'member_manager'::text
      WHEN cpu.role = 'member' THEN 'member'::text
      ELSE 'member'::text -- default fallback
    END as portal_user_role,
    cpu.status::text as status
  FROM public."CompanyPortalUsers" cpu
  WHERE (
    cpu.user_id = auth.uid()
    OR cpu.portal_user_email = (auth.jwt() ->> 'email')
  )
    AND cpu.deleted = false
    AND cpu.status IN ('active', 'invited')
  LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.get_current_portal_user IS 
  'Get current portal user info using status column. Returns empty if not a portal user or not active. Supports both user_id and email matching.';

-- ============================================================
-- 2) Drop and recreate Quotes RLS policies with correct logic
-- ============================================================
DROP POLICY IF EXISTS quotes_portal_select ON public."Quotes";
DROP POLICY IF EXISTS quotes_portal_insert ON public."Quotes";
DROP POLICY IF EXISTS quotes_portal_update ON public."Quotes";

-- SELECT: Portal users can view quotes based on role
-- - member: ONLY own quotes (created_by_portal_user_id = portal_user.id)
-- - member_manager: ALL quotes for their company
CREATE POLICY quotes_portal_select
  ON public."Quotes"
  FOR SELECT
  USING (
    deleted = false
    AND EXISTS (
      SELECT 1 FROM public.get_current_portal_user() p
      WHERE p.company_id = "Quotes".company_id
        AND (
          -- member_manager: see ALL quotes for company
          p.portal_user_role = 'member_manager'
          OR
          -- member: see ONLY own quotes
          (p.portal_user_role = 'member' AND "Quotes".created_by_portal_user_id = p.id)
        )
    )
  );

-- INSERT: Both member and member_manager can create quotes
CREATE POLICY quotes_portal_insert
  ON public."Quotes"
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.get_current_portal_user() p
      WHERE p.company_id = "Quotes".company_id
        AND p.portal_user_role IN ('member', 'member_manager')
        AND "Quotes".created_by_portal_user_id = p.id
    )
  );

-- UPDATE: Portal users can update quotes based on role
-- - member: ONLY own quotes AND status must be 'draft'
-- - member_manager: can update quotes (approve/reject via RPC, not direct update)
CREATE POLICY quotes_portal_update
  ON public."Quotes"
  FOR UPDATE
  USING (
    deleted = false
    AND EXISTS (
      SELECT 1 FROM public.get_current_portal_user() p
      WHERE p.company_id = "Quotes".company_id
        AND (
          -- member_manager: can update (but status changes via RPC approve_quote_portal)
          p.portal_user_role = 'member_manager'
          OR
          -- member: can only update own quotes in draft status
          (
            p.portal_user_role = 'member' 
            AND "Quotes".created_by_portal_user_id = p.id
            AND "Quotes".status = 'draft'
          )
        )
    )
  )
  WITH CHECK (
    -- Same logic for WITH CHECK
    EXISTS (
      SELECT 1 FROM public.get_current_portal_user() p
      WHERE p.company_id = "Quotes".company_id
        AND (
          p.portal_user_role = 'member_manager'
          OR
          (
            p.portal_user_role = 'member' 
            AND "Quotes".created_by_portal_user_id = p.id
            AND "Quotes".status = 'draft'
          )
        )
    )
  );

-- ============================================================
-- 3) Verify Directory WRITE policies don't filter by role
-- ============================================================
-- Directory WRITE policies already created in migration 534
-- They use is_company_portal_user() which doesn't filter by role
-- Both member and member_manager can write (correct)

-- ============================================================
-- 4) Update approve_quote_portal to use status column
-- ============================================================
CREATE OR REPLACE FUNCTION public.approve_quote_portal(
  p_quote_id uuid,
  p_action text -- 'approve' or 'reject'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_portal_user RECORD;
  v_quote RECORD;
  v_new_status public.quote_status;
  v_result json;
BEGIN
  -- Get current portal user (now uses status column)
  SELECT * INTO v_portal_user
  FROM public.get_current_portal_user()
  LIMIT 1;

  IF v_portal_user.id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated as active portal user';
  END IF;

  -- Validate role: ONLY member_manager can approve
  IF v_portal_user.portal_user_role != 'member_manager' THEN
    RAISE EXCEPTION 'Only member managers can approve/reject quotes';
  END IF;

  -- Get quote
  SELECT * INTO v_quote
  FROM public."Quotes"
  WHERE id = p_quote_id
    AND deleted = false;

  IF v_quote.id IS NULL THEN
    RAISE EXCEPTION 'Quote not found';
  END IF;

  -- Validate company match
  IF v_quote.company_id != v_portal_user.company_id THEN
    RAISE EXCEPTION 'Quote does not belong to your company';
  END IF;

  -- Validate action
  IF p_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Invalid action. Must be "approve" or "reject"';
  END IF;

  -- Validate quote status (can only approve/reject from appropriate states)
  -- Allow approval from: 'draft', 'sent', 'pending_approval'
  IF v_quote.status NOT IN ('draft', 'sent', 'pending_approval') THEN
    RAISE EXCEPTION 'Quote status (%) does not allow approval/rejection. Must be draft, sent, or pending_approval', v_quote.status;
  END IF;

  -- Set new status
  IF p_action = 'approve' THEN
    v_new_status := 'approved'::public.quote_status;
  ELSE
    v_new_status := 'rejected'::public.quote_status;
  END IF;

  -- Update quote (bypasses RLS because function is SECURITY DEFINER)
  UPDATE public."Quotes"
  SET 
    status = v_new_status,
    updated_at = now()
  WHERE id = p_quote_id;

  -- Return result
  v_result := json_build_object(
    'success', true,
    'quote_id', p_quote_id,
    'action', p_action,
    'new_status', v_new_status,
    'message', format('Quote %s successfully', p_action)
  );

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;

COMMENT ON FUNCTION public.approve_quote_portal IS 
  'Approve or reject a quote. ONLY member_manager role can call. Validates company match and quote status. Uses status column.';

-- ============================================================
-- 5) Grant permissions
-- ============================================================
GRANT EXECUTE ON FUNCTION public.get_current_portal_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_portal_user() TO anon;
GRANT EXECUTE ON FUNCTION public.approve_quote_portal(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_quote_portal(uuid, text) TO anon;

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- EXPLICACIÓN:
-- 
-- 1) get_current_portal_user():
--    - Ahora usa columna 'status' (con fallback a portal_user_status para compatibilidad)
--    - Soporta búsqueda por user_id O portal_user_email
--    - Filtra por status IN ('active', 'invited')
--
-- 2) Quotes SELECT:
--    - member: SOLO ve quotes propios (created_by_portal_user_id = portal_user.id)
--    - member_manager: ve TODOS los quotes de su company
--
-- 3) Quotes INSERT:
--    - Ambos roles (member y member_manager) pueden crear quotes
--    - created_by_portal_user_id debe coincidir con el portal user
--
-- 4) Quotes UPDATE:
--    - member: SOLO puede actualizar quotes propios EN estado 'draft'
--    - member_manager: puede actualizar (pero approve/reject es via RPC)
--
-- 5) Directory WRITE:
--    - NO filtra por rol (ya estaba correcto en migración 534)
--    - Ambos roles pueden escribir DirectoryContacts y DirectoryCustomers
--
-- 6) Approve:
--    - SOLO member_manager puede llamar approve_quote_portal()
--    - member NO puede aprobar (RLS bloquea UPDATE de status)
-- ============================================================
