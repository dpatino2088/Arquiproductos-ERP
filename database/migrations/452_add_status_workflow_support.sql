-- ====================================================
-- Migration 452: Add status workflow support for Authorize/Invite pattern
-- ====================================================
-- GOAL: Support 'draft', 'authorized', 'invited' status values
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Update CustomerPortalUsers status column
-- ====================================================
-- Check if status column exists and update CHECK constraint
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 
    FROM pg_constraint 
    WHERE conname = 'customer_portal_users_status_check'
    AND conrelid = 'public."CustomerPortalUsers"'::regclass
  ) THEN
    ALTER TABLE public."CustomerPortalUsers" 
    DROP CONSTRAINT customer_portal_users_status_check;
    RAISE NOTICE '✅ Dropped existing status constraint';
  END IF;

  -- Add new constraint with all supported status values
  ALTER TABLE public."CustomerPortalUsers"
  ADD CONSTRAINT customer_portal_users_status_check 
  CHECK (status IN ('draft', 'authorized', 'invited', 'active', 'inactive', 'disabled', 'pending', 'suspended'));

  RAISE NOTICE '✅ Added status constraint with workflow values';
END $$;

-- Set default status to 'authorized' for new records
ALTER TABLE public."CustomerPortalUsers"
ALTER COLUMN status SET DEFAULT 'authorized';

COMMENT ON COLUMN public."CustomerPortalUsers".status IS 
  'Status: draft (created), authorized (ready to invite), invited (auth user created), active (active), inactive/disabled (disabled)';

-- ====================================================
-- STEP 2: Update OrganizationUsers status column
-- ====================================================
-- Check if status column exists, add it if not, then update CHECK constraint
DO $$
BEGIN
  -- First, check if status column exists and add it if it doesn't
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'OrganizationUsers' 
      AND column_name = 'status'
  ) THEN
    ALTER TABLE public."OrganizationUsers"
    ADD COLUMN status text DEFAULT 'active';
    RAISE NOTICE '✅ Added status column to OrganizationUsers';
  ELSE
    RAISE NOTICE '✅ status column already exists in OrganizationUsers';
  END IF;

  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 
    FROM pg_constraint 
    WHERE conname = 'organization_users_status_check'
    AND conrelid = 'public."OrganizationUsers"'::regclass
  ) THEN
    ALTER TABLE public."OrganizationUsers" 
    DROP CONSTRAINT organization_users_status_check;
    RAISE NOTICE '✅ Dropped existing OrganizationUsers status constraint';
  END IF;

  -- Add new constraint with all supported status values
  ALTER TABLE public."OrganizationUsers"
  ADD CONSTRAINT organization_users_status_check 
  CHECK (status IN ('draft', 'authorized', 'invited', 'active', 'disabled'));

  RAISE NOTICE '✅ Added OrganizationUsers status constraint with workflow values';
END $$;

-- Set default status to 'authorized' for new records
ALTER TABLE public."OrganizationUsers"
ALTER COLUMN status SET DEFAULT 'authorized';

COMMENT ON COLUMN public."OrganizationUsers".status IS 
  'Status: draft (created), authorized (ready to invite), invited (auth user created), active (active), disabled (disabled)';

-- ====================================================
-- STEP 3: Ensure user_id is nullable in CustomerPortalUsers
-- ====================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'CustomerPortalUsers' 
      AND column_name = 'user_id'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public."CustomerPortalUsers" 
    ALTER COLUMN user_id DROP NOT NULL;
    RAISE NOTICE '✅ Made CustomerPortalUsers.user_id nullable';
  ELSE
    RAISE NOTICE '✅ CustomerPortalUsers.user_id is already nullable';
  END IF;
END $$;

-- ====================================================
-- STEP 4: Ensure user_id is nullable in OrganizationUsers
-- ====================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'OrganizationUsers' 
      AND column_name = 'user_id'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public."OrganizationUsers" 
    ALTER COLUMN user_id DROP NOT NULL;
    RAISE NOTICE '✅ Made OrganizationUsers.user_id nullable';
  ELSE
    RAISE NOTICE '✅ OrganizationUsers.user_id is already nullable';
  END IF;
END $$;

-- ====================================================
-- STEP 5: Update v_customer_portal_users to include user_id
-- ====================================================
-- (Already handled in migration 451, but ensure it's there)
-- No changes needed if migration 451 was applied

COMMIT;

