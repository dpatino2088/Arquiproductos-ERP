-- ====================================================
-- Migration: Make OrganizationUsers hybrid (contact_id/customer_id optional)
-- ====================================================
-- OBJETIVO: Permitir crear OrganizationUsers solo con email + role
-- contact_id y customer_id son opcionales
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Confirm contact_id and customer_id are NULLABLE
-- ====================================================
-- They should already be NULLABLE from add_contact_customer_to_organization_users.sql
-- But we'll ensure they are NULLABLE explicitly
DO $$
BEGIN
  -- Check if contact_id is NOT NULL and make it nullable
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'OrganizationUsers' 
      AND column_name = 'contact_id'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public."OrganizationUsers" 
    ALTER COLUMN contact_id DROP NOT NULL;
    RAISE NOTICE '✅ Made contact_id nullable';
  ELSE
    RAISE NOTICE '✅ contact_id is already nullable';
  END IF;

  -- Check if customer_id is NOT NULL and make it nullable
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'OrganizationUsers' 
      AND column_name = 'customer_id'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public."OrganizationUsers" 
    ALTER COLUMN customer_id DROP NOT NULL;
    RAISE NOTICE '✅ Made customer_id nullable';
  ELSE
    RAISE NOTICE '✅ customer_id is already nullable';
  END IF;
END $$;

-- ====================================================
-- STEP 2: Add CHECK constraint
-- ====================================================
-- If contact_id is not null, then customer_id cannot be null
DROP CONSTRAINT IF EXISTS organization_users_contact_requires_customer ON public."OrganizationUsers";

ALTER TABLE public."OrganizationUsers"
ADD CONSTRAINT organization_users_contact_requires_customer 
CHECK (
  (contact_id IS NULL) OR (customer_id IS NOT NULL)
);

COMMENT ON CONSTRAINT organization_users_contact_requires_customer ON public."OrganizationUsers" IS 
  'If contact_id is provided, customer_id must also be provided';

-- ====================================================
-- STEP 3: Update trigger function to allow NULL contact_id/customer_id
-- ====================================================
CREATE OR REPLACE FUNCTION validate_organization_user_customer_contact()
RETURNS TRIGGER AS $$
BEGIN
  -- Only validate if both contact_id and customer_id are provided
  IF NEW.contact_id IS NOT NULL AND NEW.customer_id IS NOT NULL THEN
    -- Validate that the contact belongs to the customer
    IF NOT EXISTS (
      SELECT 1 
      FROM public."DirectoryContacts" dc
      WHERE dc.id = NEW.contact_id
        AND dc.customer_id = NEW.customer_id
        AND dc.organization_id = NEW.organization_id
        AND dc.deleted = false
    ) THEN
      RAISE EXCEPTION 'The selected Contact must belong to the selected Customer (via customer_id)';
    END IF;
  END IF;
  
  -- If contact_id is provided but customer_id is null, use the contact's customer_id
  IF NEW.contact_id IS NOT NULL AND NEW.customer_id IS NULL THEN
    SELECT customer_id INTO NEW.customer_id
    FROM public."DirectoryContacts"
    WHERE id = NEW.contact_id
      AND organization_id = NEW.organization_id
      AND deleted = false;
    
    IF NEW.customer_id IS NULL THEN
      RAISE EXCEPTION 'The selected Contact must belong to a Customer';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ====================================================
-- STEP 4: Update RPC function to be STABLE (not VOLATILE) and remove SET
-- ====================================================
DROP FUNCTION IF EXISTS public.get_organization_users(uuid);

CREATE OR REPLACE FUNCTION public.get_organization_users(
    p_organization_id uuid
)
RETURNS TABLE (
    id uuid,
    role text,
    created_at timestamptz,
    user_id uuid,
    email text,
    invited_by uuid,
    contact_id uuid,
    customer_id uuid,
    customer_name text,
    user_name text,
    organization_id uuid
)
LANGUAGE plpgsql
STABLE  -- ✅ STABLE (no VOLATILE) - no side effects, no SET needed
SECURITY DEFINER  -- ✅ Ejecuta con permisos del creador
-- ✅ NO SET search_path - not needed for STABLE functions
AS $$
BEGIN
    -- Return organization users with related data
    RETURN QUERY
    SELECT 
        ou.id,
        ou.role,
        ou.created_at,
        ou.user_id,
        ou.email,
        ou.invited_by,
        ou.contact_id,
        ou.customer_id,
        COALESCE(dc.customer_name, NULL)::text AS customer_name,
        COALESCE(dct.contact_name, NULL)::text AS user_name,
        ou.organization_id
    FROM public."OrganizationUsers" ou
    LEFT JOIN public."DirectoryCustomers" dc ON dc.id = ou.customer_id AND dc.deleted = false
    LEFT JOIN public."DirectoryContacts" dct ON dct.id = ou.contact_id AND dct.deleted = false
    WHERE ou.organization_id = p_organization_id
      AND ou.deleted = false
      AND ou.is_system = false
    ORDER BY ou.created_at DESC;
END;
$$;

-- ====================================================
-- STEP 5: Grant execute permissions
-- ====================================================
GRANT EXECUTE ON FUNCTION public.get_organization_users(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.get_organization_users(uuid) TO authenticated;

-- ====================================================
-- STEP 6: Add comment
-- ====================================================
COMMENT ON FUNCTION public.get_organization_users(uuid) IS 
    'Returns organization users for a given organization_id. Includes related customer and contact names. STABLE function (no SET needed).';

-- ====================================================
-- STEP 7: Notify PostgREST to reload schema
-- ====================================================
NOTIFY pgrst, 'reload schema';

COMMIT;

