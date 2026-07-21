-- Fix: recording a payment fails with "Cannot resolve account for line 1 ... DEFAULT_CASH"
-- when an organization has no chart of accounts / account roles seeded.
--
-- Root cause: trg_post_payment_journal -> fn_post_payment_journal -> post_journal_entry
-- resolves roles (DEFAULT_CASH, ACCOUNTS_RECEIVABLE, ...) against AccountRoles. Orgs without
-- seeded accounting (e.g. "AP Sandbox") have 0 Accounts / 0 AccountRoles, so posting raises
-- and rolls back the payment insert.
--
-- This migration:
--   1) Adds ensure_org_accounting_setup(org) wrapping the existing idempotent seeds.
--   2) Makes post_journal_entry self-heal (seed once + retry) before failing.
--   3) Auto-seeds accounting on Organizations insert.
--   4) Backfills existing orgs missing a chart of accounts.

SET search_path = public;

-- 1) Idempotent one-call accounting setup ------------------------------------
CREATE OR REPLACE FUNCTION public.ensure_org_accounting_setup(p_org_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_accounts jsonb;
  v_roles jsonb;
BEGIN
  IF p_org_id IS NULL THEN
    RAISE EXCEPTION 'organization_id is required';
  END IF;

  v_accounts := public.seed_chart_of_accounts(p_org_id);
  v_roles := public.seed_account_roles(p_org_id);

  RETURN jsonb_build_object(
    'ok', true,
    'accounts', v_accounts,
    'roles', v_roles
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_org_accounting_setup(uuid) TO authenticated;

-- 2) Self-healing account resolution in the single posting chokepoint --------
CREATE OR REPLACE FUNCTION public.post_journal_entry(
  p_org_id uuid,
  p_entry_date date,
  p_source_type text,
  p_source_id uuid,
  p_description text,
  p_lines jsonb,
  p_currency text DEFAULT 'USD'::text,
  p_exchange_rate numeric DEFAULT NULL::numeric,
  p_created_by uuid DEFAULT NULL::uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_je_id uuid;
  v_line jsonb;
  v_idx int := 1;
  v_account_id uuid;
  v_role text;
  v_debit numeric;
  v_credit numeric;
  v_healed boolean := false;
BEGIN
  IF p_org_id IS NULL THEN
    RAISE EXCEPTION 'organization_id required';
  END IF;

  IF p_lines IS NULL OR jsonb_array_length(p_lines) < 2 THEN
    RAISE EXCEPTION 'journal entry must have at least 2 lines';
  END IF;

  -- Skip duplicate posting for same source
  IF p_source_id IS NOT NULL AND p_source_type IS NOT NULL THEN
    SELECT id INTO v_je_id
    FROM "JournalEntries"
    WHERE organization_id = p_org_id
      AND source_type = p_source_type
      AND source_id = p_source_id
      AND status = 'posted'
      AND deleted = false
    LIMIT 1;
    IF v_je_id IS NOT NULL THEN
      RETURN v_je_id;
    END IF;
  END IF;

  INSERT INTO "JournalEntries" (
    organization_id, entry_date, source_type, source_id, description,
    base_currency, status, posted_at, posted_by, created_by
  ) VALUES (
    p_org_id, COALESCE(p_entry_date, current_date), p_source_type, p_source_id,
    p_description, COALESCE(p_currency, 'USD'), 'draft', NULL, NULL, p_created_by
  )
  RETURNING id INTO v_je_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines)
  LOOP
    v_account_id := NULLIF(v_line->>'account_id', '')::uuid;
    v_role := v_line->>'role';
    v_debit := COALESCE((v_line->>'debit')::numeric, 0);
    v_credit := COALESCE((v_line->>'credit')::numeric, 0);

    IF v_account_id IS NULL AND v_role IS NOT NULL THEN
      SELECT account_id INTO v_account_id
      FROM "AccountRoles"
      WHERE organization_id = p_org_id
        AND role_code = v_role
      ORDER BY currency = COALESCE(p_currency, 'USD') DESC
      LIMIT 1;

      -- Self-heal: org may not have accounting seeded yet. Seed once and retry.
      IF v_account_id IS NULL AND NOT v_healed THEN
        PERFORM public.ensure_org_accounting_setup(p_org_id);
        v_healed := true;
        SELECT account_id INTO v_account_id
        FROM "AccountRoles"
        WHERE organization_id = p_org_id
          AND role_code = v_role
        ORDER BY currency = COALESCE(p_currency, 'USD') DESC
        LIMIT 1;
      END IF;
    END IF;

    IF v_account_id IS NULL THEN
      RAISE EXCEPTION 'Cannot resolve account for line %: %', v_idx, v_line;
    END IF;

    INSERT INTO "JournalLines" (
      journal_entry_id, line_no, account_id, description,
      debit, credit, currency, exchange_rate, entity_type, entity_id
    ) VALUES (
      v_je_id, v_idx, v_account_id,
      v_line->>'description',
      v_debit, v_credit,
      COALESCE(v_line->>'currency', p_currency, 'USD'),
      COALESCE((v_line->>'exchange_rate')::numeric, p_exchange_rate, 1),
      v_line->>'entity_type',
      NULLIF(v_line->>'entity_id', '')::uuid
    );

    v_idx := v_idx + 1;
  END LOOP;

  -- Now flip to posted (triggers will validate balance)
  UPDATE "JournalEntries"
  SET status = 'posted', posted_at = now()
  WHERE id = v_je_id;

  RETURN v_je_id;
END;
$$;

-- 3) Auto-seed accounting when an organization is created --------------------
CREATE OR REPLACE FUNCTION public.fn_seed_org_accounting()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM public.ensure_org_accounting_setup(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_seed_org_accounting ON public."Organizations";
CREATE TRIGGER trg_seed_org_accounting
AFTER INSERT ON public."Organizations"
FOR EACH ROW
EXECUTE FUNCTION public.fn_seed_org_accounting();

-- 4) Backfill existing organizations missing a chart of accounts -------------
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT o.id
    FROM public."Organizations" o
    WHERE NOT EXISTS (
      SELECT 1 FROM public."Accounts" a
      WHERE a.organization_id = o.id AND a.deleted = false
    )
  LOOP
    PERFORM public.ensure_org_accounting_setup(r.id);
  END LOOP;
END $$;
