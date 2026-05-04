-- Path B: standalone proposals.
-- Allow Proposals to exist without a parent Quote (one-off cotizaciones).
-- These proposals do NOT generate Sales Orders, manufacturing or accounting
-- entries. They are pure quoting documents (PDF only).
--
-- Numbering keeps the same PR- series (per dealer) as quote-based proposals.
-- Customer/contact remain optional (already nullable).
-- "sent"/"accepted" still freezes the snapshot for PDF integrity.

SET search_path = public;

-- 1) Make quote_id nullable and switch FK to ON DELETE SET NULL,
--    so deleting a quote downgrades the proposal to standalone instead of
--    silently cascading the delete (which would lose the customer-facing PDF).

ALTER TABLE public."Proposals"
  ALTER COLUMN quote_id DROP NOT NULL;

ALTER TABLE public."Proposals"
  DROP CONSTRAINT IF EXISTS "Proposals_quote_id_fkey";

ALTER TABLE public."Proposals"
  ADD CONSTRAINT "Proposals_quote_id_fkey"
  FOREIGN KEY (quote_id)
  REFERENCES public."Quotes"(id)
  ON DELETE SET NULL;

-- 2) accept_proposal: skip Quote update + quote timeline when standalone.
CREATE OR REPLACE FUNCTION public.accept_proposal(
  p_proposal_id uuid,
  p_user_id uuid,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_proposal record;
  v_quote_id uuid;
  v_org_id uuid;
BEGIN
  SELECT * INTO v_proposal FROM "Proposals" WHERE id = p_proposal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Proposal not found'; END IF;
  IF v_proposal.status != 'sent' THEN
    RAISE EXCEPTION 'Proposal must be in "sent" status to accept (current: %)', v_proposal.status;
  END IF;

  v_quote_id := v_proposal.quote_id;
  v_org_id := v_proposal.organization_id;

  UPDATE "Proposals"
     SET status = 'accepted', updated_at = now()
   WHERE id = p_proposal_id;

  IF v_quote_id IS NOT NULL THEN
    UPDATE "Quotes"
       SET status = 'approved',
           approved_at = now(),
           approved_by = p_user_id,
           updated_at = now()
     WHERE id = v_quote_id;
  END IF;

  PERFORM _insert_timeline(
    v_org_id, 'proposal', p_proposal_id,
    'status_changed', 'Proposal accepted',
    p_user_id, p_user_name,
    '{"from":"sent","to":"accepted"}'::jsonb
  );

  IF v_quote_id IS NOT NULL THEN
    PERFORM _insert_timeline(
      v_org_id, 'quote', v_quote_id,
      'status_changed', 'Quote approved - pending order confirmation',
      p_user_id, p_user_name,
      '{"from":"draft","to":"approved"}'::jsonb
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'proposal_id', p_proposal_id,
    'quote_id', v_quote_id,
    'standalone', v_quote_id IS NULL
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_proposal(uuid, uuid, text) TO authenticated;

-- 3) decline_proposal: skip quote timeline when standalone.
CREATE OR REPLACE FUNCTION public.decline_proposal(
  p_proposal_id uuid,
  p_user_id uuid,
  p_reason text DEFAULT NULL,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_proposal record;
  v_org_id uuid;
  v_desc text;
BEGIN
  SELECT * INTO v_proposal FROM "Proposals" WHERE id = p_proposal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Proposal not found'; END IF;
  IF v_proposal.status != 'sent' THEN
    RAISE EXCEPTION 'Proposal must be in "sent" status to decline (current: %)', v_proposal.status;
  END IF;

  v_org_id := v_proposal.organization_id;
  v_desc := 'Proposal declined';
  IF p_reason IS NOT NULL AND p_reason != '' THEN
    v_desc := v_desc || ' - ' || p_reason;
  END IF;

  UPDATE "Proposals"
     SET status = 'rejected', updated_at = now()
   WHERE id = p_proposal_id;

  PERFORM _insert_timeline(
    v_org_id, 'proposal', p_proposal_id,
    'status_changed', v_desc,
    p_user_id, p_user_name,
    jsonb_build_object('from','sent','to','rejected','reason',p_reason)
  );

  IF v_proposal.quote_id IS NOT NULL THEN
    PERFORM _insert_timeline(
      v_org_id, 'quote', v_proposal.quote_id,
      'proposal_declined', 'Proposal declined',
      p_user_id, p_user_name, '{}'::jsonb
    );
  END IF;

  RETURN jsonb_build_object('ok', true, 'standalone', v_proposal.quote_id IS NULL);
END;
$$;

GRANT EXECUTE ON FUNCTION public.decline_proposal(uuid, uuid, text, text) TO authenticated;

-- 4) proposals_ensure_integrity:
-- When standalone, dealer_id MUST be provided by the caller (no fallback to a quote).
-- The existing function already raises if dealer_id is null and no quote provides it,
-- so the only change is making the message clearer and gracefully handling missing
-- quote rows (defensive: SELECT into empty record is fine).
CREATE OR REPLACE FUNCTION public.proposals_ensure_integrity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_quote RECORD;
  v_uid uuid;
BEGIN
  v_uid := auth.uid();

  IF NEW.quote_id IS NOT NULL THEN
    SELECT q.created_by_user_id, q.dealer_id
      INTO v_quote
    FROM public."Quotes" q
    WHERE q.id = NEW.quote_id;
  END IF;

  IF NEW.dealer_id IS NULL THEN
    IF v_quote.dealer_id IS NOT NULL THEN
      NEW.dealer_id := v_quote.dealer_id;
    ELSE
      RAISE EXCEPTION
        'Proposal requires dealer_id (standalone proposals must specify it directly). proposal_id=%, quote_id=%',
        COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid), NEW.quote_id;
    END IF;
  END IF;

  IF NEW.created_by_user_id IS NULL THEN
    IF v_uid IS NOT NULL THEN
      NEW.created_by_user_id := v_uid;
    ELSIF v_quote.created_by_user_id IS NOT NULL THEN
      NEW.created_by_user_id := v_quote.created_by_user_id;
    ELSE
      RAISE EXCEPTION
        'Proposal must have creator. proposal_id=%, quote_id=%',
        COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid), NEW.quote_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';
