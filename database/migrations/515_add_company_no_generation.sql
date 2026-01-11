-- ============================================================
-- Migration: Add company number generation system
-- ============================================================
-- OBJECTIVE:
-- 1) Add next_company_no to Organizations (for sequential numbering)
-- 2) Add company_no to Companies with unique constraint
-- 3) Create function to atomically generate next company number (sequential)
-- 4) Create trigger to auto-assign company_no on insert
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Add column to Organizations for sequential numbering
-- ============================================================

-- Add next_company_no (default 1) - simple sequential number
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'Organizations' AND column_name = 'next_company_no'
  ) THEN
    ALTER TABLE public."Organizations" 
    ADD COLUMN next_company_no integer NOT NULL DEFAULT 1;
    
    COMMENT ON COLUMN public."Organizations".next_company_no IS 'Next sequence number for company_no generation. Auto-incremented atomically. Generates sequential numbers (1, 2, 3, etc.).';
  END IF;
END $$;

-- ============================================================
-- 2) Add company_no to Companies
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'Companies' AND column_name = 'company_no'
  ) THEN
    ALTER TABLE public."Companies" 
    ADD COLUMN company_no text;
    
    COMMENT ON COLUMN public."Companies".company_no IS 'Sequential company number (e.g., 1, 2, 3). Auto-generated on insert.';
  END IF;
END $$;

-- Add unique constraint on (organization_id, company_no)
-- Only enforce uniqueness when company_no is not null
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'companies_org_company_no_unique'
  ) THEN
    CREATE UNIQUE INDEX companies_org_company_no_unique 
    ON public."Companies"(organization_id, company_no) 
    WHERE company_no IS NOT NULL;
    
    COMMENT ON INDEX companies_org_company_no_unique IS 'Ensure unique company_no per organization (only when company_no is set)';
  END IF;
END $$;

-- ============================================================
-- 3) Create function to generate next company number
-- ============================================================

CREATE OR REPLACE FUNCTION public.next_company_no(p_org_id uuid)
RETURNS text
LANGUAGE plpgsql
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

COMMENT ON FUNCTION public.next_company_no IS 'Atomically increments Organizations.next_company_no and returns sequential company number as text. Used by trigger on Companies insert.';

-- ============================================================
-- 4) Create trigger to auto-assign company_no on insert
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_company_no()
RETURNS TRIGGER
LANGUAGE plpgsql
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

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS trg_companies_set_company_no ON public."Companies";

CREATE TRIGGER trg_companies_set_company_no
BEFORE INSERT ON public."Companies"
FOR EACH ROW
EXECUTE FUNCTION public.set_company_no();

COMMENT ON TRIGGER trg_companies_set_company_no ON public."Companies" IS 'Auto-assigns company_no on insert using next_company_no() function. Only sets if company_no is null/empty.';

-- ============================================================
-- 5) Initialize existing Organizations with defaults if needed
-- ============================================================

-- This is safe to run multiple times (idempotent)
-- Set next_company_no to 1 if null, or keep existing value
UPDATE public."Organizations"
SET next_company_no = COALESCE(next_company_no, 1)
WHERE next_company_no IS NULL;

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Organizations.next_company_no (default 1) - sequential counter
-- 2. Companies.company_no (text, nullable) - sequential number
-- 3. Unique constraint: (organization_id, company_no)
-- 4. Function: next_company_no(p_org_id) - atomic increment, returns sequential number
-- 5. Trigger: trg_companies_set_company_no - auto-assign on insert
-- ============================================================
