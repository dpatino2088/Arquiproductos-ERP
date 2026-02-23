-- =============================================================================
-- Migration: DealerUsers.role member → dealer_member, member_manager → dealer_manager
-- =============================================================================
-- Align DB terminology with UI labels "Dealer Member" / "Dealer Manager".
-- 1) UPDATE existing rows
-- 2) DROP/ADD CHECK constraints
-- 3) Update SQL functions that compare role
-- 4) Update RLS policies that reference role directly
--
-- Depends on: 20260342 (is_org_user_member_strict)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) UPDATE DealerUsers.role
-- -----------------------------------------------------------------------------
UPDATE public."DealerUsers" SET role = 'dealer_member' WHERE role = 'member';
UPDATE public."DealerUsers" SET role = 'dealer_manager' WHERE role = 'member_manager';


-- -----------------------------------------------------------------------------
-- 2) CHECK constraints
-- -----------------------------------------------------------------------------
ALTER TABLE public."DealerUsers"
  DROP CONSTRAINT IF EXISTS "company_portal_role_check",
  DROP CONSTRAINT IF EXISTS "companyportalusers_portal_user_role_check",
  DROP CONSTRAINT IF EXISTS "companyportalusers_role_check";

ALTER TABLE public."DealerUsers"
  ADD CONSTRAINT "dealerusers_role_check"
  CHECK (role IN ('dealer_member', 'dealer_manager'));

-- Update default for new rows
ALTER TABLE public."DealerUsers"
  ALTER COLUMN role SET DEFAULT 'dealer_member';


-- -----------------------------------------------------------------------------
-- 3) SQL functions
-- -----------------------------------------------------------------------------

-- is_dealer_portal_user_with_write: check dealer_manager (was member_manager)
CREATE OR REPLACE FUNCTION public.is_dealer_portal_user_with_write(p_dealer_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."DealerUsers" dpu
    WHERE dpu.dealer_id = p_dealer_id
      AND (
        dpu.user_id = auth.uid()
        OR lower(dpu.portal_user_email) = lower(auth.jwt() ->> 'email')
      )
      AND dpu.deleted = false
      AND dpu.status IN ('active', 'invited')
      AND dpu.role IN ('dealer_manager')
  );
END;
$$;

COMMENT ON FUNCTION public.is_dealer_portal_user_with_write(uuid)
  IS 'True if current user is a DealerUser with write (dealer_manager) for the given dealer.';


-- approve_quote: check dealer_manager (was member_manager)
CREATE OR REPLACE FUNCTION public.approve_quote(p_quote_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_dealer_id uuid;
  v_role text;
BEGIN
  SELECT dpu.dealer_id, dpu.role INTO v_dealer_id, v_role
  FROM public."DealerUsers" dpu
  WHERE dpu.user_id = auth.uid()
    AND dpu.deleted = false
    AND dpu.status = 'active'
  LIMIT 1;

  IF v_dealer_id IS NULL THEN
    RAISE EXCEPTION 'Not a portal user';
  END IF;

  IF v_role <> 'dealer_manager' THEN
    RAISE EXCEPTION 'Forbidden: only dealer_manager can approve quotes';
  END IF;

  UPDATE public."Quotes"
  SET status = 'approved', updated_at = now()
  WHERE id = p_quote_id AND deleted = false AND dealer_id = v_dealer_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quote not found for your dealer';
  END IF;
END;
$$;


-- approve_quote_portal: check dealer_manager (was member_manager)
-- Supports both role_code (AppUsers-based) and portal_user_role (DealerUsers-based)
CREATE OR REPLACE FUNCTION public.approve_quote_portal(p_quote_id uuid, p_action text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_portal_user record;
  v_quote record;
  v_new_status public.quote_status;
  v_result json;
  v_role text;
BEGIN
  SELECT * INTO v_portal_user FROM public.get_current_portal_user() LIMIT 1;

  IF v_portal_user.id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated as active portal user';
  END IF;

  -- Support both role_code (AppUsers) and portal_user_role (DealerUsers)
  v_role := COALESCE(v_portal_user.role_code, v_portal_user.portal_user_role);
  IF v_role IS DISTINCT FROM 'dealer_manager' THEN
    RAISE EXCEPTION 'Only dealer managers can approve/reject quotes';
  END IF;

  SELECT * INTO v_quote
  FROM public."Quotes"
  WHERE id = p_quote_id AND deleted = false;

  IF v_quote.id IS NULL THEN
    RAISE EXCEPTION 'Quote not found';
  END IF;

  IF v_quote.dealer_id != v_portal_user.dealer_id THEN
    RAISE EXCEPTION 'Quote does not belong to your dealer';
  END IF;

  IF p_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Invalid action. Must be "approve" or "reject"';
  END IF;

  IF v_quote.status NOT IN ('draft', 'sent', 'pending_approval') THEN
    RAISE EXCEPTION 'Quote status (%) does not allow approval/rejection. Must be draft, sent, or pending_approval', v_quote.status;
  END IF;

  IF p_action = 'approve' THEN
    v_new_status := 'approved';
  ELSE
    v_new_status := 'rejected';
  END IF;

  UPDATE public."Quotes"
  SET status = v_new_status, updated_at = now()
  WHERE id = p_quote_id AND deleted = false;

  SELECT json_build_object('success', true, 'status', v_new_status) INTO v_result;
  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.approve_quote_portal(uuid, text)
  IS 'Approve or reject a quote. ONLY dealer_manager role can call. Validates dealer match and quote status.';


-- get_current_portal_user: ensure DealerUsers-based version returns dpu.role (now dealer_*)
-- Creates/overwrites helper for DealerUsers path. AppUsers-based callers use role_code.
-- approve_quote_portal uses COALESCE(role_code, portal_user_role) so both paths work.
DROP FUNCTION IF EXISTS public.get_current_portal_user();
CREATE OR REPLACE FUNCTION public.get_current_portal_user()
RETURNS TABLE(id uuid, auth_user_id uuid, email text, display_name text, organization_id uuid, user_type text, dealer_id uuid, role_code text, status text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT
    dpu.id,
    dpu.user_id AS auth_user_id,
    COALESCE(dpu.portal_user_email, auth.jwt() ->> 'email') AS email,
    dpu.portal_user_name AS display_name,
    dpu.organization_id,
    'dealer'::text AS user_type,
    dpu.dealer_id,
    dpu.role::text AS role_code,
    dpu.status::text AS status
  FROM public."DealerUsers" dpu
  WHERE (
    dpu.user_id = auth.uid()
    OR lower(trim(dpu.portal_user_email)) = lower(trim(auth.jwt() ->> 'email'))
  )
    AND dpu.deleted = false
    AND dpu.status IN ('active', 'invited')
  LIMIT 1;
$$;


-- -----------------------------------------------------------------------------
-- 4) RLS policies that reference du.role = 'member_manager'
-- -----------------------------------------------------------------------------

-- ProposalLines: proposal_lines_write (legacy policy if it exists)
DROP POLICY IF EXISTS "proposal_lines_write" ON public."ProposalLines";
CREATE POLICY "proposal_lines_write" ON public."ProposalLines"
  FOR ALL
  USING (
    (EXISTS (
      SELECT 1 FROM public."OrganizationUsers" ou
      WHERE ou.organization_id = "ProposalLines".organization_id
        AND ou.user_id = auth.uid()
    ))
    OR
    (EXISTS (
      SELECT 1 FROM public."DealerUsers" du
      WHERE du.organization_id = "ProposalLines".organization_id
        AND du.dealer_id = "ProposalLines".dealer_id
        AND du.user_id = auth.uid()
        AND du.role = 'dealer_manager'
    ))
  )
  WITH CHECK (
    (EXISTS (
      SELECT 1 FROM public."OrganizationUsers" ou
      WHERE ou.organization_id = "ProposalLines".organization_id
        AND ou.user_id = auth.uid()
    ))
    OR
    (EXISTS (
      SELECT 1 FROM public."DealerUsers" du
      WHERE du.organization_id = "ProposalLines".organization_id
        AND du.dealer_id = "ProposalLines".dealer_id
        AND du.user_id = auth.uid()
        AND du.role = 'dealer_manager'
    ))
  );
