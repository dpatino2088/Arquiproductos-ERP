BEGIN;

-- ============================================================
-- Fix: Make next_company_no SECURITY DEFINER to avoid RLS issues
-- ============================================================

CREATE OR REPLACE FUNCTION public.next_company_no(p_org_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER -- Add SECURITY DEFINER to bypass RLS
SET search_path = public
AS $$
DECLARE
  v_next_no integer;
BEGIN
  -- Atomically increment next_company_no and get the new value
  UPDATE public."Organizations"
  SET next_company_no = next_company_no + 1
  WHERE id = p_org_id
  RETURNING next_company_no INTO v_next_no;
  
  -- If organization not found, raise error
  IF v_next_no IS NULL THEN
    RAISE EXCEPTION 'Organization % not found', p_org_id;
  END IF;
  
  -- Return sequential number as text (e.g., "1", "2", "3")
  RETURN v_next_no::text;
END;
$$;

COMMENT ON FUNCTION public.next_company_no IS 'Atomically increments Organizations.next_company_no and returns sequential company number as text. Used by trigger on Companies insert. SECURITY DEFINER to avoid RLS recursion.';

-- ============================================================
-- Also ensure set_company_no trigger function has correct search_path
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_company_no()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- Only set company_no if it's null or empty
  IF NEW.company_no IS NULL OR TRIM(NEW.company_no) = '' THEN
    NEW.company_no := public.next_company_no(NEW.organization_id);
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_company_no IS 'Trigger function to auto-assign company_no on Companies insert if not provided. Never recalculates existing company_no.';

COMMIT;
