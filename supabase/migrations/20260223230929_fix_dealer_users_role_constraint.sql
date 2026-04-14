-- Fix DealerUsers.role: allow dealer_member, dealer_manager (align with UI and create-temp-user)
-- Temporarily disable sync trigger to avoid ON CONFLICT error (AppUsers lacks the expected unique index)

ALTER TABLE public."DealerUsers" DISABLE TRIGGER trg_sync_dealeruser_appuser;

ALTER TABLE public."DealerUsers"
  DROP CONSTRAINT IF EXISTS "company_portal_role_check",
  DROP CONSTRAINT IF EXISTS "companyportalusers_portal_user_role_check",
  DROP CONSTRAINT IF EXISTS "companyportalusers_role_check",
  DROP CONSTRAINT IF EXISTS "dealerusers_role_check";

UPDATE public."DealerUsers" SET role = 'dealer_member' WHERE role = 'member';
UPDATE public."DealerUsers" SET role = 'dealer_manager' WHERE role = 'member_manager';

ALTER TABLE public."DealerUsers"
  ADD CONSTRAINT "dealerusers_role_check"
  CHECK (role IN ('dealer_member', 'dealer_manager'));

ALTER TABLE public."DealerUsers"
  ALTER COLUMN role SET DEFAULT 'dealer_member';

ALTER TABLE public."DealerUsers" ENABLE TRIGGER trg_sync_dealeruser_appuser;;
