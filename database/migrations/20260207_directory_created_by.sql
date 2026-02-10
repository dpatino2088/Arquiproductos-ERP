-- Directory: quién creó el contact/customer
-- Añade created_by_user_id y created_by_portal_user_id a DirectoryContacts y DirectoryCustomers
-- (misma lógica que Quotes: org user -> created_by_user_id, dealer user -> created_by_portal_user_id)

-- DirectoryContacts
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'created_by_user_id'
  ) THEN
    ALTER TABLE public."DirectoryContacts"
      ADD COLUMN created_by_user_id uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_directory_contacts_created_by_user
      ON public."DirectoryContacts"(created_by_user_id) WHERE deleted = false AND created_by_user_id IS NOT NULL;
    RAISE NOTICE 'Added created_by_user_id to DirectoryContacts';
  ELSE
    RAISE NOTICE 'Column created_by_user_id already exists in DirectoryContacts';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'created_by_portal_user_id'
  ) THEN
    ALTER TABLE public."DirectoryContacts"
      ADD COLUMN created_by_portal_user_id uuid NULL REFERENCES public."DealerUsers"(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_directory_contacts_created_by_portal_user
      ON public."DirectoryContacts"(created_by_portal_user_id) WHERE deleted = false AND created_by_portal_user_id IS NOT NULL;
    RAISE NOTICE 'Added created_by_portal_user_id to DirectoryContacts';
  ELSE
    RAISE NOTICE 'Column created_by_portal_user_id already exists in DirectoryContacts';
  END IF;
END $$;

-- DirectoryCustomers
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'created_by_user_id'
  ) THEN
    ALTER TABLE public."DirectoryCustomers"
      ADD COLUMN created_by_user_id uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_directory_customers_created_by_user
      ON public."DirectoryCustomers"(created_by_user_id) WHERE deleted = false AND created_by_user_id IS NOT NULL;
    RAISE NOTICE 'Added created_by_user_id to DirectoryCustomers';
  ELSE
    RAISE NOTICE 'Column created_by_user_id already exists in DirectoryCustomers';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'created_by_portal_user_id'
  ) THEN
    ALTER TABLE public."DirectoryCustomers"
      ADD COLUMN created_by_portal_user_id uuid NULL REFERENCES public."DealerUsers"(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_directory_customers_created_by_portal_user
      ON public."DirectoryCustomers"(created_by_portal_user_id) WHERE deleted = false AND created_by_portal_user_id IS NOT NULL;
    RAISE NOTICE 'Added created_by_portal_user_id to DirectoryCustomers';
  ELSE
    RAISE NOTICE 'Column created_by_portal_user_id already exists in DirectoryCustomers';
  END IF;
END $$;
