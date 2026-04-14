-- Ensure SO numbers are always >= 100 (display as 00100, 00101, ...)
CREATE OR REPLACE FUNCTION public.generate_sales_order_no()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_seq int;
  v_max int;
BEGIN
  IF NEW.sales_order_no IS NULL OR NEW.sales_order_no = '' THEN
    SELECT COALESCE(MAX(
      CASE WHEN sales_order_no ~ '^SO-[0-9]+$'
           THEN CAST(SUBSTRING(sales_order_no FROM 4) AS integer)
           ELSE 0
      END
    ), 0) INTO v_max
    FROM "SalesOrders"
    WHERE organization_id = NEW.organization_id;
    v_seq := GREATEST(100, v_max + 1);
    NEW.sales_order_no := 'SO-' || LPAD(v_seq::text, 5, '0');
  END IF;
  RETURN NEW;
END;
$function$;;
