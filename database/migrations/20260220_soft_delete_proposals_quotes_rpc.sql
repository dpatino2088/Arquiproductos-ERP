-- ============================================================
-- RPC para soft-delete de Proposals y Quotes
-- Permite a Dealer Member/Manager borrar aunque RLS UPDATE falle
-- (p. ej. si la migración 20260219 no está aplicada).
-- Las funciones comprueban permiso con is_org_user_member / current_dealer_id.
-- ============================================================

BEGIN;

-- Soft-delete Proposals por IDs (solo filas que el usuario puede ver)
CREATE OR REPLACE FUNCTION public.soft_delete_proposals(p_proposal_ids uuid[])
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public."Proposals" p
  SET deleted = true, updated_at = now()
  WHERE p.id = ANY(p_proposal_ids)
    AND (p.deleted IS NULL OR p.deleted = false)
    AND p.organization_id IS NOT NULL
    AND (
      public.is_org_user_member(p.organization_id)
      OR (public.current_dealer_id(p.organization_id) IS NOT NULL AND p.dealer_id = public.current_dealer_id(p.organization_id))
    );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION public.soft_delete_proposals(uuid[]) IS 'Soft-delete proposals by ID. Only rows the current user can access (org member or same dealer).';

GRANT EXECUTE ON FUNCTION public.soft_delete_proposals(uuid[]) TO authenticated;

-- Soft-delete Quotes por IDs (solo filas que el usuario puede ver)
CREATE OR REPLACE FUNCTION public.soft_delete_quotes(p_quote_ids uuid[])
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public."Quotes" q
  SET deleted = true, updated_at = now()
  WHERE q.id = ANY(p_quote_ids)
    AND (q.deleted IS NULL OR q.deleted = false)
    AND q.organization_id IS NOT NULL
    AND (
      public.is_org_user_member(q.organization_id)
      OR (public.current_dealer_id(q.organization_id) IS NOT NULL AND q.dealer_id = public.current_dealer_id(q.organization_id))
    );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION public.soft_delete_quotes(uuid[]) IS 'Soft-delete quotes by ID. Only rows the current user can access (org member or same dealer).';

GRANT EXECUTE ON FUNCTION public.soft_delete_quotes(uuid[]) TO authenticated;

COMMIT;
