-- Allow dealer_manager role to pass write checks for dealer portal users.
-- This unblocks Terms & Conditions actions (set default / edit templates)
-- that rely on public.is_dealer_portal_user_with_write(p_dealer_id).

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
      AND lower(coalesce(dpu.role, '')) IN ('member_manager', 'dealer_manager', 'manager')
  );
END;
$$;

COMMENT ON FUNCTION public.is_dealer_portal_user_with_write(uuid)
  IS 'True if current user is a DealerUser with write role (member_manager/dealer_manager/manager) for the given dealer.';
