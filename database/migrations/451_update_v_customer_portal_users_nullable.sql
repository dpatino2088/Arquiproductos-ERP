-- ====================================================
-- Migration 451: Update v_customer_portal_users to handle nullable customer_id/contact_id
-- ====================================================
-- PROBLEMA: View assumes customer_id and contact_id always exist
-- SOLUCIÓN: Use LEFT JOINs and COALESCE to handle nullable fields
-- ====================================================

BEGIN;

-- Drop existing view if it exists
DROP VIEW IF EXISTS public.v_customer_portal_users;

-- Recreate view with nullable customer/contact support
CREATE OR REPLACE VIEW public.v_customer_portal_users AS
SELECT 
  cpu.id,
  cpu.organization_id,
  cpu.user_id,
  cpu.user_name,
  cpu.user_email,
  cpu.customer_id,
  cpu.contact_id,
  cpu.status,
  cpu.invited_by_user_id,
  cpu.created_at,
  cpu.updated_at,
  cpu.deleted,
  -- Customer fields (nullable)
  dc.customer_name,
  -- Contact fields (nullable)
  dct.contact_name,
  dct.email AS contact_email,
  dct.primary_phone AS contact_phone
FROM public."CustomerPortalUsers" cpu
LEFT JOIN public."DirectoryCustomers" dc 
  ON dc.id = cpu.customer_id 
  AND dc.deleted = false
LEFT JOIN public."DirectoryContacts" dct 
  ON dct.id = cpu.contact_id 
  AND dct.deleted = false
WHERE cpu.deleted = false;

-- Grant permissions
GRANT SELECT ON public.v_customer_portal_users TO anon;
GRANT SELECT ON public.v_customer_portal_users TO authenticated;

-- Add comment
COMMENT ON VIEW public.v_customer_portal_users IS 
  'View for listing customer portal users with optional customer and contact information. Supports nullable customer_id and contact_id.';

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

COMMIT;

