-- =============================================================
-- Accounting Phase 5: Reporting RPCs
--   - rpc_trial_balance(p_org_id, p_as_of)
--   - rpc_general_ledger(p_org_id, p_account_id, p_from, p_to)
--   - rpc_profit_loss(p_org_id, p_from, p_to)
--   - rpc_balance_sheet(p_org_id, p_as_of)
-- All read from posted JournalEntries / JournalLines using debit_base/credit_base.
-- =============================================================
SET search_path = public;

-- =============================================================
-- Trial Balance: snapshot of all accounts with non-zero activity
-- as of a given date (default = today).
-- Sign convention:
--   ASSET / EXPENSE / COGS  → debit-positive
--   LIABILITY / EQUITY / INCOME → credit-positive
-- =============================================================
CREATE OR REPLACE FUNCTION public.rpc_trial_balance(
  p_org_id uuid,
  p_as_of date DEFAULT current_date
)
RETURNS TABLE(
  account_id uuid,
  code text,
  name text,
  account_type account_type,
  total_debit numeric,
  total_credit numeric,
  balance numeric
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH posted AS (
    SELECT jl.account_id, jl.debit_base, jl.credit_base
    FROM "JournalLines" jl
    JOIN "JournalEntries" je ON je.id = jl.journal_entry_id
    WHERE je.organization_id = p_org_id
      AND je.status = 'posted'
      AND je.deleted = false
      AND je.entry_date <= p_as_of
  )
  SELECT
    a.id,
    a.code,
    a.name,
    a.account_type,
    COALESCE(SUM(p.debit_base), 0)::numeric,
    COALESCE(SUM(p.credit_base), 0)::numeric,
    CASE
      WHEN a.account_type IN ('ASSET','EXPENSE','COGS')
        THEN COALESCE(SUM(p.debit_base), 0) - COALESCE(SUM(p.credit_base), 0)
      ELSE COALESCE(SUM(p.credit_base), 0) - COALESCE(SUM(p.debit_base), 0)
    END::numeric
  FROM "Accounts" a
  LEFT JOIN posted p ON p.account_id = a.id
  WHERE a.organization_id = p_org_id
  GROUP BY a.id, a.code, a.name, a.account_type
  HAVING COALESCE(SUM(p.debit_base), 0) <> 0 OR COALESCE(SUM(p.credit_base), 0) <> 0
  ORDER BY a.code;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_trial_balance(uuid, date) TO authenticated;

-- =============================================================
-- General Ledger: line-level detail with running balance per account
-- Optionally filter by account and date range.
-- =============================================================
CREATE OR REPLACE FUNCTION public.rpc_general_ledger(
  p_org_id uuid,
  p_account_id uuid DEFAULT NULL,
  p_from date DEFAULT NULL,
  p_to date DEFAULT current_date
)
RETURNS TABLE(
  account_id uuid,
  account_code text,
  account_name text,
  account_type account_type,
  journal_entry_id uuid,
  entry_no text,
  entry_date date,
  source_type text,
  source_id uuid,
  description text,
  line_no int,
  line_description text,
  debit numeric,
  credit numeric,
  running_balance numeric,
  entity_type text,
  entity_id uuid
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH lines AS (
    SELECT
      a.id AS account_id,
      a.code AS account_code,
      a.name AS account_name,
      a.account_type,
      je.id AS journal_entry_id,
      je.entry_no,
      je.entry_date,
      je.source_type,
      je.source_id,
      je.description,
      jl.line_no,
      jl.description AS line_description,
      jl.debit_base AS debit,
      jl.credit_base AS credit,
      jl.entity_type,
      jl.entity_id,
      CASE
        WHEN a.account_type IN ('ASSET','EXPENSE','COGS')
          THEN jl.debit_base - jl.credit_base
        ELSE jl.credit_base - jl.debit_base
      END AS signed_delta
    FROM "JournalLines" jl
    JOIN "JournalEntries" je ON je.id = jl.journal_entry_id
    JOIN "Accounts" a ON a.id = jl.account_id
    WHERE je.organization_id = p_org_id
      AND je.status = 'posted'
      AND je.deleted = false
      AND (p_account_id IS NULL OR a.id = p_account_id)
      AND (p_from IS NULL OR je.entry_date >= p_from)
      AND je.entry_date <= p_to
  )
  SELECT
    account_id, account_code, account_name, account_type,
    journal_entry_id, entry_no, entry_date, source_type, source_id, description,
    line_no, line_description, debit, credit,
    SUM(signed_delta) OVER (
      PARTITION BY account_id
      ORDER BY entry_date, entry_no, line_no
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::numeric,
    entity_type, entity_id
  FROM lines
  ORDER BY account_code, entry_date, entry_no, line_no;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_general_ledger(uuid, uuid, date, date) TO authenticated;

-- =============================================================
-- Profit & Loss: revenue - cogs - expenses for a period.
-- INCOME amount is presented as positive when there's a net credit.
-- =============================================================
CREATE OR REPLACE FUNCTION public.rpc_profit_loss(
  p_org_id uuid,
  p_from date,
  p_to date
)
RETURNS TABLE(
  section text,
  account_id uuid,
  code text,
  name text,
  account_type account_type,
  amount numeric
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH posted AS (
    SELECT jl.account_id, jl.debit_base, jl.credit_base
    FROM "JournalLines" jl
    JOIN "JournalEntries" je ON je.id = jl.journal_entry_id
    WHERE je.organization_id = p_org_id
      AND je.status = 'posted'
      AND je.deleted = false
      AND je.entry_date >= p_from
      AND je.entry_date <= p_to
  )
  SELECT
    CASE
      WHEN a.account_type = 'INCOME' THEN '1_INCOME'
      WHEN a.account_type = 'COGS' THEN '2_COGS'
      WHEN a.account_type = 'EXPENSE' THEN '3_EXPENSE'
    END,
    a.id, a.code, a.name, a.account_type,
    CASE
      WHEN a.account_type = 'INCOME' THEN COALESCE(SUM(p.credit_base), 0) - COALESCE(SUM(p.debit_base), 0)
      ELSE COALESCE(SUM(p.debit_base), 0) - COALESCE(SUM(p.credit_base), 0)
    END::numeric
  FROM "Accounts" a
  LEFT JOIN posted p ON p.account_id = a.id
  WHERE a.organization_id = p_org_id
    AND a.account_type IN ('INCOME','COGS','EXPENSE')
  GROUP BY a.id, a.code, a.name, a.account_type
  HAVING COALESCE(SUM(p.debit_base), 0) <> 0 OR COALESCE(SUM(p.credit_base), 0) <> 0
  ORDER BY 1, a.code;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_profit_loss(uuid, date, date) TO authenticated;

-- =============================================================
-- Balance Sheet: assets / liabilities / equity at a point in time.
-- Synthetic line "3999 Net Income (Period)" rolls up cumulative
-- INCOME-COGS-EXPENSE up to as_of, since we don't auto-close periods yet.
-- =============================================================
CREATE OR REPLACE FUNCTION public.rpc_balance_sheet(
  p_org_id uuid,
  p_as_of date DEFAULT current_date
)
RETURNS TABLE(
  section text,
  account_id uuid,
  code text,
  name text,
  account_type account_type,
  amount numeric
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH posted AS (
    SELECT jl.account_id, jl.debit_base, jl.credit_base
    FROM "JournalLines" jl
    JOIN "JournalEntries" je ON je.id = jl.journal_entry_id
    WHERE je.organization_id = p_org_id
      AND je.status = 'posted'
      AND je.deleted = false
      AND je.entry_date <= p_as_of
  ),
  per_account AS (
    SELECT
      a.id, a.code, a.name, a.account_type,
      CASE
        WHEN a.account_type = 'ASSET' THEN COALESCE(SUM(p.debit_base), 0) - COALESCE(SUM(p.credit_base), 0)
        ELSE COALESCE(SUM(p.credit_base), 0) - COALESCE(SUM(p.debit_base), 0)
      END AS amount
    FROM "Accounts" a
    LEFT JOIN posted p ON p.account_id = a.id
    WHERE a.organization_id = p_org_id
      AND a.account_type IN ('ASSET','LIABILITY','EQUITY')
    GROUP BY a.id, a.code, a.name, a.account_type
  ),
  net_income AS (
    SELECT COALESCE(SUM(
      CASE
        WHEN a.account_type = 'INCOME' THEN jl.credit_base - jl.debit_base
        ELSE -(jl.debit_base - jl.credit_base)
      END
    ), 0) AS amt
    FROM "JournalLines" jl
    JOIN "JournalEntries" je ON je.id = jl.journal_entry_id
    JOIN "Accounts" a ON a.id = jl.account_id
    WHERE je.organization_id = p_org_id
      AND je.status = 'posted'
      AND je.deleted = false
      AND je.entry_date <= p_as_of
      AND a.account_type IN ('INCOME','COGS','EXPENSE')
  )
  SELECT
    CASE
      WHEN account_type = 'ASSET' THEN '1_ASSET'
      WHEN account_type = 'LIABILITY' THEN '2_LIABILITY'
      ELSE '3_EQUITY'
    END,
    id, code, name, account_type, amount
  FROM per_account
  WHERE amount <> 0
  UNION ALL
  SELECT '3_EQUITY', NULL::uuid, '3999', 'Net Income (Period)', 'EQUITY'::account_type,
         (SELECT amt FROM net_income)
  WHERE (SELECT amt FROM net_income) <> 0
  ORDER BY 1, 3;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_balance_sheet(uuid, date) TO authenticated;
