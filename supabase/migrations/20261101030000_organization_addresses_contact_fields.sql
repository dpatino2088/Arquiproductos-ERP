-- Add contact fields to organization address directory

ALTER TABLE public."OrganizationAddresses"
  ADD COLUMN IF NOT EXISTS contact_person text NULL;

ALTER TABLE public."OrganizationAddresses"
  ADD COLUMN IF NOT EXISTS contact_phone text NULL;

ALTER TABLE public."OrganizationAddresses"
  ADD COLUMN IF NOT EXISTS contact_email text NULL;

COMMENT ON COLUMN public."OrganizationAddresses".contact_person IS
  'Primary contact person for this destination address (receiving/contact at site).';

COMMENT ON COLUMN public."OrganizationAddresses".contact_phone IS
  'Primary phone number for the destination address contact.';

COMMENT ON COLUMN public."OrganizationAddresses".contact_email IS
  'Primary email for the destination address contact.';

NOTIFY pgrst, 'reload schema';
