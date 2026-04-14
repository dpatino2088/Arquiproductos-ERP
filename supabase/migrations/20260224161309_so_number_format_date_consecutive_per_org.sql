-- SO number format: SO-YYYYMMDD-NNNNNN (e.g. SO-20260224-000100).
-- Consecutive is per organization per day (resets each day). QT and PR remain per dealer in app.
SET search_path = public;

CREATE OR REPLACE FUNCTION public.generate_sales_order_no()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_date_prefix text;
  v_max_seq int;
  v_next_seq int;
  v_last_no text;
BEGIN
  IF NEW.sales_order_no IS NOT NULL AND NEW.sales_order_no <> '' THEN
    RETURN NEW;
  END IF;

  v_date_prefix := 'SO-' || to_char(NOW(), 'YYYYMMDD') || '-';

  SELECT COALESCE(MAX(
    CASE
      WHEN sales_order_no LIKE v_date_prefix || '%'
           AND substring(sales_order_no from length(v_date_prefix) + 1) ~ '^\d+$'
      THEN (substring(sales_order_no from length(v_date_prefix) + 1))::integer
      ELSE 0
    END
  ), 0) INTO v_max_seq
  FROM "SalesOrders"
  WHERE organization_id = NEW.organization_id;

  v_next_seq := GREATEST(100, v_max_seq + 1);
  NEW.sales_order_no := v_date_prefix || lpad(v_next_seq::text, 6, '0');

  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.generate_sales_order_no() IS 'SO format: SO-YYYYMMDD-NNNNNN. Consecutive per organization per day (min 100).';;
