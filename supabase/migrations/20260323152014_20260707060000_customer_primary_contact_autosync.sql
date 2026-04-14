BEGIN;

CREATE OR REPLACE FUNCTION public.directorycustomers_ensure_primary_contact(p_customer_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_primary_contact_id uuid;
  v_candidate_contact_id uuid;
BEGIN
  IF p_customer_id IS NULL THEN
    RETURN;
  END IF;

  SELECT dc.primary_contact_id
    INTO v_primary_contact_id
  FROM public."DirectoryCustomers" dc
  WHERE dc.id = p_customer_id
    AND COALESCE(dc.deleted, false) = false;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_primary_contact_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public."DirectoryContacts" c
    WHERE c.id = v_primary_contact_id
      AND c.customer_id = p_customer_id
      AND COALESCE(c.deleted, false) = false
  ) THEN
    RETURN;
  END IF;

  SELECT c.id
    INTO v_candidate_contact_id
  FROM public."DirectoryContacts" c
  WHERE c.customer_id = p_customer_id
    AND COALESCE(c.deleted, false) = false
  ORDER BY c.created_at ASC NULLS LAST, c.id ASC
  LIMIT 1;

  UPDATE public."DirectoryCustomers"
  SET
    primary_contact_id = v_candidate_contact_id,
    updated_at = now()
  WHERE id = p_customer_id
    AND primary_contact_id IS DISTINCT FROM v_candidate_contact_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.tg_directorycontacts_sync_customer_primary_contact()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.directorycustomers_ensure_primary_contact(NEW.customer_id);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.customer_id IS DISTINCT FROM NEW.customer_id THEN
      PERFORM public.directorycustomers_ensure_primary_contact(OLD.customer_id);
      PERFORM public.directorycustomers_ensure_primary_contact(NEW.customer_id);
    ELSIF OLD.deleted IS DISTINCT FROM NEW.deleted THEN
      PERFORM public.directorycustomers_ensure_primary_contact(NEW.customer_id);
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM public.directorycustomers_ensure_primary_contact(OLD.customer_id);
    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_directorycontacts_sync_customer_primary_contact ON public."DirectoryContacts";

CREATE TRIGGER trg_directorycontacts_sync_customer_primary_contact
AFTER INSERT OR UPDATE OF customer_id, deleted OR DELETE
ON public."DirectoryContacts"
FOR EACH ROW
EXECUTE FUNCTION public.tg_directorycontacts_sync_customer_primary_contact();

DO $$
DECLARE
  v_customer_id uuid;
BEGIN
  FOR v_customer_id IN
    SELECT dc.id
    FROM public."DirectoryCustomers" dc
    WHERE COALESCE(dc.deleted, false) = false
  LOOP
    PERFORM public.directorycustomers_ensure_primary_contact(v_customer_id);
  END LOOP;
END;
$$;

COMMIT;;
