-- Sequential QT / SO / PR format: PREFIX-00100 (5 digits, start 100).
-- 1) Backfill existing Quotes, SalesOrders, Proposals (two-phase where unique constraints exist).
-- 2) Update generate_sales_order_no() to emit SO-00100, SO-00101, ... per org.

SET search_path = public;

-- ========== 1. QUOTES: two-phase (quotes_org_dealer_quote_no_unique) ==========
UPDATE "Quotes"
SET quote_no = 'QT-TMP-' || id::text
WHERE deleted = false;

WITH q_rank AS (
  SELECT id,
    'QT-' || LPAD((99 + ROW_NUMBER() OVER (PARTITION BY organization_id, dealer_id ORDER BY created_at, id))::text, 5, '0') AS new_quote_no
  FROM "Quotes"
  WHERE deleted = false AND quote_no LIKE 'QT-TMP-%'
)
UPDATE "Quotes" q
SET quote_no = q_rank.new_quote_no
FROM q_rank
WHERE q.id = q_rank.id;

-- ========== 2. SALES ORDERS: SO-00100, SO-00101, ... per organization_id by created_at ==========
WITH so_rank AS (
  SELECT id,
    'SO-' || LPAD((99 + ROW_NUMBER() OVER (PARTITION BY organization_id ORDER BY created_at, id))::text, 5, '0') AS new_so_no
  FROM "SalesOrders"
  WHERE deleted = false
)
UPDATE "SalesOrders" so
SET sales_order_no = so_rank.new_so_no
FROM so_rank
WHERE so.id = so_rank.id;

-- ========== 3. PROPOSALS: two-phase (uq_proposals_org_dealer_proposal_no) ==========
UPDATE "Proposals"
SET proposal_no = 'PR-TMP-' || id::text
WHERE deleted = false AND proposal_no IS NOT NULL AND proposal_no <> '';

WITH p_rank AS (
  SELECT id,
    'PR-' || LPAD((99 + ROW_NUMBER() OVER (PARTITION BY organization_id, dealer_id ORDER BY created_at, id))::text, 5, '0') AS new_proposal_no
  FROM "Proposals"
  WHERE deleted = false
)
UPDATE "Proposals" p
SET proposal_no = p_rank.new_proposal_no
FROM p_rank
WHERE p.id = p_rank.id;

-- ========== 4. TRIGGER: new Sales Orders get SO-00100, SO-00101, ... per org ==========
CREATE OR REPLACE FUNCTION public.generate_sales_order_no()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_max_num int;
BEGIN
  IF NEW.sales_order_no IS NOT NULL AND NEW.sales_order_no <> '' THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(MAX(
    CASE
      WHEN sales_order_no ~ '^SO-\d{5}$'
      THEN (substring(sales_order_no from 4))::integer
      ELSE 0
    END
  ), 0) INTO v_max_num
  FROM "SalesOrders"
  WHERE organization_id = NEW.organization_id
    AND deleted = false;

  NEW.sales_order_no := 'SO-' || LPAD(GREATEST(100, v_max_num + 1)::text, 5, '0');
  RETURN NEW;
END;
$$;
