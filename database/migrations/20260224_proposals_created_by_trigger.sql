-- Ensure Proposals always satisfies proposals_created_by_exactly_one_chk.
-- On INSERT, if both created_by_user_id and created_by_portal_user_id are NULL,
-- set created_by_user_id = auth.uid() so the row is valid.
CREATE OR REPLACE FUNCTION public.proposals_ensure_created_by()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NEW.created_by_user_id IS NULL AND NEW.created_by_portal_user_id IS NULL THEN
    NEW.created_by_user_id := auth.uid();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proposals_ensure_created_by ON public."Proposals";
CREATE TRIGGER trg_proposals_ensure_created_by
  BEFORE INSERT ON public."Proposals"
  FOR EACH ROW
  EXECUTE FUNCTION public.proposals_ensure_created_by();

COMMENT ON FUNCTION public.proposals_ensure_created_by() IS 'Ensures exactly one of created_by_user_id or created_by_portal_user_id is set on insert (defaults to auth.uid() if both null).';
