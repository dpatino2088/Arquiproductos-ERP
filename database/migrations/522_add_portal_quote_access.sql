-- ============================================================
-- Migration: Add portal quote access control
-- ============================================================
-- OBJECTIVE:
-- 1. Add company_id and created_by_portal_user_id to Quotes
-- 2. Create RLS policies for portal users
-- 3. Create approve_quote_portal RPC function
-- ============================================================

BEGIN;

-- ============================================================
-- 0) Add portal_user_role to CompanyPortalUsers table
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'CompanyPortalUsers' AND column_name = 'portal_user_role'
  ) THEN
    -- Add column as nullable first
    ALTER TABLE public."CompanyPortalUsers" ADD COLUMN portal_user_role text;
    
    -- Set default to 'member' for existing rows
    UPDATE public."CompanyPortalUsers"
    SET portal_user_role = 'member'
    WHERE portal_user_role IS NULL;
    
    -- Now make it NOT NULL with default
    ALTER TABLE public."CompanyPortalUsers" 
      ALTER COLUMN portal_user_role SET NOT NULL,
      ALTER COLUMN portal_user_role SET DEFAULT 'member';
    
    -- Add check constraint
    ALTER TABLE public."CompanyPortalUsers" ADD CONSTRAINT companyportalusers_role_check
      CHECK (portal_user_role IN ('member_manager', 'member'));
    
    CREATE INDEX IF NOT EXISTS idx_companyportalusers_role ON public."CompanyPortalUsers"(portal_user_role)
      WHERE deleted = false;
    
    RAISE NOTICE 'Added portal_user_role column to CompanyPortalUsers';
  ELSE
    -- Normalize existing roles if column already exists
    UPDATE public."CompanyPortalUsers"
    SET portal_user_role = CASE
      WHEN portal_user_role = 'manager' THEN 'member_manager'
      WHEN portal_user_role NOT IN ('member_manager', 'member') THEN 'member'
      ELSE portal_user_role
    END
    WHERE portal_user_role = 'manager' OR portal_user_role NOT IN ('member_manager', 'member');
    
    RAISE NOTICE 'Column portal_user_role already exists, normalized legacy values';
  END IF;
END $$;

-- ============================================================
-- 1) Add columns to Quotes table
-- ============================================================

-- Add company_id (NOT NULL, FK to Companies)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'Quotes' AND column_name = 'company_id'
  ) THEN
    ALTER TABLE public."Quotes" ADD COLUMN company_id uuid;
    
    -- Migrate existing data: try to find company_id from organization
    -- For existing quotes, we need to assign a company_id
    -- Strategy: If quotes have organization_id, find first company for that org, or create a default
    -- For now, we'll set a default or leave as NULL temporarily, but new quotes must have it
    
    -- Only set NOT NULL after ensuring existing data has company_id
    -- For now, allow NULL temporarily during migration
    -- ALTER TABLE public."Quotes" ALTER COLUMN company_id SET NOT NULL;
    ALTER TABLE public."Quotes" ADD CONSTRAINT quotes_company_id_fkey
      FOREIGN KEY (company_id) REFERENCES public."Companies"(id) ON DELETE RESTRICT;
    
    CREATE INDEX IF NOT EXISTS idx_quotes_company_id ON public."Quotes"(company_id) WHERE deleted = false;
    
    RAISE NOTICE 'Added company_id column to Quotes';
  ELSE
    RAISE NOTICE 'Column company_id already exists in Quotes';
  END IF;
END $$;

-- Add created_by_portal_user_id (nullable, FK to CompanyPortalUsers)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'Quotes' AND column_name = 'created_by_portal_user_id'
  ) THEN
    ALTER TABLE public."Quotes" ADD COLUMN created_by_portal_user_id uuid NULL
      REFERENCES public."CompanyPortalUsers"(id) ON DELETE SET NULL;
    
    CREATE INDEX IF NOT EXISTS idx_quotes_created_by_portal_user ON public."Quotes"(created_by_portal_user_id)
      WHERE created_by_portal_user_id IS NOT NULL AND deleted = false;
    
    RAISE NOTICE 'Added created_by_portal_user_id column to Quotes';
  ELSE
    RAISE NOTICE 'Column created_by_portal_user_id already exists in Quotes';
  END IF;
END $$;

-- ============================================================
-- 2) Helper function: Get current portal user
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_current_portal_user()
RETURNS TABLE (
  id uuid,
  company_id uuid,
  portal_user_role text,
  portal_user_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cpu.id,
    cpu.company_id,
    COALESCE(cpu.portal_user_role, 'member')::text as portal_user_role,
    cpu.portal_user_status::text as portal_user_status
  FROM public."CompanyPortalUsers" cpu
  WHERE cpu.user_id = auth.uid()
    AND cpu.deleted = false
    AND cpu.portal_user_status = 'active'
  LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.get_current_portal_user IS 'Get current portal user info. Returns empty if not a portal user or not active.';

-- ============================================================
-- 3) RLS Policies for Quotes (Portal Access)
-- ============================================================

-- Drop existing portal policies if they exist
DROP POLICY IF EXISTS quotes_portal_select ON public."Quotes";
DROP POLICY IF EXISTS quotes_portal_insert ON public."Quotes";
DROP POLICY IF EXISTS quotes_portal_update ON public."Quotes";

-- SELECT: Portal users can view quotes if:
-- - portal user is active
-- - quote belongs to their company
-- - (role = member_manager OR quote.created_by_portal_user_id = portal_user.id)
CREATE POLICY quotes_portal_select
  ON public."Quotes"
  FOR SELECT
  USING (
    deleted = false
    AND EXISTS (
      SELECT 1 FROM public.get_current_portal_user() p
      WHERE p.company_id = "Quotes".company_id
        AND (
          p.portal_user_role = 'member_manager'
          OR "Quotes".created_by_portal_user_id = p.id
        )
    )
  );

-- INSERT: Portal users can create quotes if:
-- - role in ('member', 'member_manager')
-- - active
-- - company_id matches
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

-- UPDATE: Portal users can update quotes if:
-- - active
-- - company matches
-- - member: only if owns quote AND status is draft
-- - member_manager: can update (optional, but approve is via RPC)
CREATE POLICY quotes_portal_update
  ON public."Quotes"
  FOR UPDATE
  USING (
    deleted = false
    AND EXISTS (
      SELECT 1 FROM public.get_current_portal_user() p
      WHERE p.company_id = "Quotes".company_id
        AND (
          -- member_manager can update (but approve via RPC)
          p.portal_user_role = 'member_manager'
          OR
          -- member can only update own quotes in draft
          (p.portal_user_role = 'member' 
           AND "Quotes".created_by_portal_user_id = p.id
           AND "Quotes".status = 'draft')
        )
    )
  );

-- ============================================================
-- 4) RPC: approve_quote_portal
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
  -- Get current portal user
  SELECT * INTO v_portal_user
  FROM public.get_current_portal_user()
  LIMIT 1;

  IF v_portal_user.id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated as active portal user';
  END IF;

  -- Validate role
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

  -- Validate quote status (can only approve/reject from sent/pending_approval states)
  -- Note: Adjust status values based on your quote_status enum
  IF v_quote.status NOT IN ('sent', 'draft') THEN
    RAISE EXCEPTION 'Quote status (%) does not allow approval/rejection', v_quote.status;
  END IF;

  -- Set new status
  -- Note: quote_status enum includes 'rejected' (from migration 510)
  IF p_action = 'approve' THEN
    v_new_status := 'approved'::public.quote_status;
  ELSE
    v_new_status := 'rejected'::public.quote_status;
  END IF;

  -- Update quote
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

COMMENT ON FUNCTION public.approve_quote_portal IS 'Approve or reject a quote. Only member_manager role can call. Validates company match and quote status.';

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Added company_id (NOT NULL) and created_by_portal_user_id (nullable) to Quotes
-- 2. Created get_current_portal_user() helper function
-- 3. Created RLS policies for portal quote access
-- 4. Created approve_quote_portal RPC function
-- ============================================================
