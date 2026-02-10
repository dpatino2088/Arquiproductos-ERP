-- Directory RLS: permitir INSERT a usuarios portal (DealerUsers)
-- ============================================================
-- Las políticas dircontacts_insert y dircustomers_insert usaban is_org_member(),
-- que solo considera OrganizationUsers. Los usuarios portal (DealerUsers) fallaban
-- con "new row violates row-level security policy".
-- Usamos is_org_user_member(organization_id) en la rama de "org member" para que
-- tanto OrganizationUsers como DealerUsers puedan insertar. El trigger
-- trg_dircontacts_set_dealer / trg_directorycustomers_set_dealer sigue rellenando
-- dealer_id para portal users en BEFORE INSERT.
-- ============================================================

SET search_path = public;

-- DirectoryContacts INSERT
DROP POLICY IF EXISTS "dircontacts_insert" ON public."DirectoryContacts";
CREATE POLICY "dircontacts_insert"
  ON public."DirectoryContacts"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_user_member(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  );

-- DirectoryCustomers INSERT
DROP POLICY IF EXISTS "dircustomers_insert" ON public."DirectoryCustomers";
CREATE POLICY "dircustomers_insert"
  ON public."DirectoryCustomers"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_user_member(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  );
