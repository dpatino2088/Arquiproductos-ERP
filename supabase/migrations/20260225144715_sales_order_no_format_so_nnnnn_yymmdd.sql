-- SO number format: SO-00100-YYMMDD (5-digit sequence + date).
-- 1) Backfill existing SalesOrders to SO-NNNNN-YYMMDD using created_at for date.
-- 2) Trigger for new rows: same pattern using CURRENT_DATE.

SET search_path = public;

-- ========== 1. Backfill: SO-00100-YYMMDD per org by created_at, date from created_at ==========
WITH so_rank AS (
  SELECT id,
    created_at,
    'SO-' || LPAD((99 + ROW_NUMBER() OVER (PARTITION BY organization_id ORDER BY created_at, id))::text, 5, '0')
      || '-' || to_char(created_at, 'YYMMDD') AS new_so_no
  FROM "SalesOrders"
  WHERE deleted = false
)
UPDATE "SalesOrders" so
SET sales_order_no = so_rank.new_so_no
FROM so_rank
WHERE so.id = so_rank.id;

-- ========== 2. Trigger: new Sales Orders get SO-NNNNN-YYMMDD (sequence per org, date = today) ==========
CREATE OR REPLACE FUNCTION public.generate_sales_order_no()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_max_num int;
  v_date_suffix text;
BEGIN
  IF NEW.sales_order_no IS NOT NULL AND NEW.sales_order_no <> '' THEN
    RETURN NEW;
  END IF;

  v_date_suffix := to_char(CURRENT_DATE, 'YYMMDD');

  -- Max sequence from SO-NNNNN or SO-NNNNN-YYMMDD (same org, same date so we get next seq for today)
  SELECT COALESCE(MAX(
    CASE
      WHEN sales_order_no ~ '^SO-\d{5}-' || v_date_suffix || '$'
        THEN (substring(sales_order_no from 4 for 5))::integer
      WHEN sales_order_no ~ '^SO-\d{5}$'
        THEN (substring(sales_order_no from 4 for 5))::integer
      ELSE 0
    END
  ), 0) INTO v_max_num
  FROM "SalesOrders"
  WHERE organization_id = NEW.organization_id
    AND deleted = false;

  NEW.sales_order_no := 'SO-' || LPAD(GREATEST(100, v_max_num + 1)::text, 5, '0') || '-' || v_date_suffix;
  RETURN NEW;
END;
$$;;
