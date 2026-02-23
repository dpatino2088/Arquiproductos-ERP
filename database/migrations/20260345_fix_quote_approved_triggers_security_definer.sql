-- ====================================================
-- Migration: Make quote-approved trigger functions SECURITY DEFINER
-- ====================================================
-- Problem: When a SuperAdmin (or any org admin without a dealer_id) approves
-- a Quote belonging to a different dealer, the trigger tries to INSERT into
-- SalesOrders. RLS blocks it because:
--   - salesorders_org_insert requires dealer_id IS NULL
--   - salesorders_dealer_insert requires dealer_id IN current_user_dealer_ids
-- A SuperAdmin acting on behalf of another dealer fails both checks.
--
-- Fix: Make the trigger functions SECURITY DEFINER so they bypass RLS.
-- This is safe because the triggers only fire on valid status transitions
-- and the functions validate the data internally.
-- ====================================================

SET search_path = public;

-- 1) on_quote_approved_create_sales_order — the original trigger
ALTER FUNCTION public.on_quote_approved_create_sales_order()
  SECURITY DEFINER
  SET search_path = public, auth;

-- 2) handle_quote_approved — the BEFORE UPDATE trigger
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'handle_quote_approved') THEN
    ALTER FUNCTION public.handle_quote_approved()
      SECURITY DEFINER
      SET search_path = public, auth;
  END IF;
END $$;

-- 3) on_quote_approved_create_operational_docs — our phase3 replacement (if applied)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'on_quote_approved_create_operational_docs') THEN
    ALTER FUNCTION public.on_quote_approved_create_operational_docs()
      SECURITY DEFINER
      SET search_path = public, auth;
  END IF;
END $$;

-- 4) Also fix RLS: allow org admins to INSERT/SELECT/UPDATE SalesOrders
--    regardless of dealer_id. This covers SuperAdmin acting on any dealer.

DROP POLICY IF EXISTS "salesorders_org_insert" ON public."SalesOrders";
CREATE POLICY "salesorders_org_insert" ON public."SalesOrders"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND public.is_internal_org_user(organization_id)
  );

DROP POLICY IF EXISTS "salesorders_org_select" ON public."SalesOrders";
CREATE POLICY "salesorders_org_select" ON public."SalesOrders"
  FOR SELECT TO authenticated
  USING (
    organization_id IS NOT NULL
    AND public.is_internal_org_user(organization_id)
  );

DROP POLICY IF EXISTS "salesorders_org_update" ON public."SalesOrders";
CREATE POLICY "salesorders_org_update" ON public."SalesOrders"
  FOR UPDATE TO authenticated
  USING (
    organization_id IS NOT NULL
    AND public.is_internal_org_user(organization_id)
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND public.is_internal_org_user(organization_id)
  );
