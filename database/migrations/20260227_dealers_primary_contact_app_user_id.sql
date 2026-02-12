-- Primary Contact as AppUser (Dealer Manager)
-- Dealers.primary_contact_id remains FK to DirectoryContacts (legacy).
-- New column: primary_contact_app_user_id = AppUser (user_type=dealer, role_code=dealer_manager) for this dealer.

ALTER TABLE public."Dealers"
  ADD COLUMN IF NOT EXISTS primary_contact_app_user_id uuid NULL;

COMMENT ON COLUMN public."Dealers".primary_contact_app_user_id IS 'Primary contact: AppUser (dealer) with role Dealer Manager for this dealer.';

ALTER TABLE public."Dealers"
  DROP CONSTRAINT IF EXISTS dealers_primary_contact_app_user_id_fkey;

ALTER TABLE public."Dealers"
  ADD CONSTRAINT dealers_primary_contact_app_user_id_fkey
  FOREIGN KEY (primary_contact_app_user_id)
  REFERENCES public."AppUsers"(id)
  ON DELETE SET NULL;
