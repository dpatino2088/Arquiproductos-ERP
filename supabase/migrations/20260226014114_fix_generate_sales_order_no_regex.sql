
CREATE OR REPLACE FUNCTION public.generate_sales_order_no()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_max_num int;
  v_date_suffix text;
  v_pattern text;
BEGIN
  IF NEW.sales_order_no IS NOT NULL AND NEW.sales_order_no <> '' THEN
    RETURN NEW;
  END IF;

  v_date_suffix := to_char(CURRENT_DATE, 'YYMMDD');
  v_pattern := '^SO-\d{5}-' || v_date_suffix || '$';

  SELECT COALESCE(MAX(
    CASE
      WHEN sales_order_no ~ v_pattern
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
$function$;
;
