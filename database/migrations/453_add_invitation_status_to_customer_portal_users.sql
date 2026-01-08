-- ====================================================
-- Migration 453: Add invitation_status and invited_at to CustomerPortalUsers
-- ====================================================
-- GOAL: Separate invitation workflow from account status
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Add invitation_status column
-- ====================================================
ALTER TABLE public."CustomerPortalUsers"
ADD COLUMN IF NOT EXISTS invitation_status text DEFAULT 'pending' 
CHECK (invitation_status IN ('pending', 'sent', 'accepted', 'expired'));

-- ====================================================
-- STEP 2: Add invited_at column
-- ====================================================
ALTER TABLE public."CustomerPortalUsers"
ADD COLUMN IF NOT EXISTS invited_at timestamptz;

-- ====================================================
-- STEP 3: Add index for invitation_status
-- ====================================================
CREATE INDEX IF NOT EXISTS idx_customer_portal_users_invitation_status 
ON public."CustomerPortalUsers"(invitation_status) 
WHERE deleted = false;

-- ====================================================
-- STEP 4: Add comments
-- ====================================================
COMMENT ON COLUMN public."CustomerPortalUsers".invitation_status IS 
  'Invitation workflow status: pending (not invited), sent (invite sent), accepted (user accepted), expired (invite expired)';

COMMENT ON COLUMN public."CustomerPortalUsers".invited_at IS 
  'Timestamp when invitation was sent';

COMMENT ON COLUMN public."CustomerPortalUsers".status IS 
  'Account status: active (enabled), inactive/disabled (disabled), draft/authorized/invited (workflow states)';

COMMIT;

