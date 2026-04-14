
-- Helper to insert timeline entries (used by all RPCs)
CREATE OR REPLACE FUNCTION _insert_timeline(
  p_org_id uuid, p_entity_type text, p_entity_id uuid,
  p_action text, p_description text, p_user_id uuid,
  p_user_name text DEFAULT NULL, p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO "ActivityTimeline" (organization_id, entity_type, entity_id, action, description, user_id, user_name, metadata)
  VALUES (p_org_id, p_entity_type, p_entity_id, p_action, p_description, p_user_id, p_user_name, p_metadata);
END;
$$;

-- accept_proposal: proposal sent -> accepted, quote -> approved
CREATE OR REPLACE FUNCTION accept_proposal(p_proposal_id uuid, p_user_id uuid, p_user_name text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_proposal record;
  v_quote_id uuid;
  v_org_id uuid;
BEGIN
  SELECT * INTO v_proposal FROM "Proposals" WHERE id = p_proposal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Proposal not found'; END IF;
  IF v_proposal.status != 'sent' THEN RAISE EXCEPTION 'Proposal must be in "sent" status to accept (current: %)', v_proposal.status; END IF;

  v_quote_id := v_proposal.quote_id;
  v_org_id := v_proposal.organization_id;

  UPDATE "Proposals" SET status = 'accepted', updated_at = now() WHERE id = p_proposal_id;
  UPDATE "Quotes" SET status = 'approved', approved_at = now(), approved_by = p_user_id, updated_at = now() WHERE id = v_quote_id;

  PERFORM _insert_timeline(v_org_id, 'proposal', p_proposal_id, 'status_changed', 'Proposal accepted', p_user_id, p_user_name, '{"from":"sent","to":"accepted"}'::jsonb);
  PERFORM _insert_timeline(v_org_id, 'quote', v_quote_id, 'status_changed', 'Quote approved - pending order confirmation', p_user_id, p_user_name, '{"from":"draft","to":"approved"}'::jsonb);

  RETURN jsonb_build_object('ok', true, 'proposal_id', p_proposal_id, 'quote_id', v_quote_id);
END;
$$;

GRANT EXECUTE ON FUNCTION accept_proposal(uuid, uuid, text) TO authenticated;

-- decline_proposal: proposal sent -> rejected
CREATE OR REPLACE FUNCTION decline_proposal(p_proposal_id uuid, p_user_id uuid, p_reason text DEFAULT NULL, p_user_name text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_proposal record;
  v_org_id uuid;
  v_desc text;
BEGIN
  SELECT * INTO v_proposal FROM "Proposals" WHERE id = p_proposal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Proposal not found'; END IF;
  IF v_proposal.status != 'sent' THEN RAISE EXCEPTION 'Proposal must be in "sent" status to decline (current: %)', v_proposal.status; END IF;

  v_org_id := v_proposal.organization_id;
  v_desc := 'Proposal declined';
  IF p_reason IS NOT NULL AND p_reason != '' THEN v_desc := v_desc || ' - ' || p_reason; END IF;

  UPDATE "Proposals" SET status = 'rejected', updated_at = now() WHERE id = p_proposal_id;

  PERFORM _insert_timeline(v_org_id, 'proposal', p_proposal_id, 'status_changed', v_desc, p_user_id, p_user_name, jsonb_build_object('from','sent','to','rejected','reason',p_reason));
  PERFORM _insert_timeline(v_org_id, 'quote', v_proposal.quote_id, 'proposal_declined', 'Proposal declined', p_user_id, p_user_name, '{}'::jsonb);

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION decline_proposal(uuid, uuid, text, text) TO authenticated;
;
