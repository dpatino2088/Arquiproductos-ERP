-- SO numbers start at 00100 (5 digits): SO-00100, SO-00101, ...
CREATE OR REPLACE FUNCTION public.generate_sales_order_no()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_seq int;
BEGIN
  IF NEW.sales_order_no IS NULL OR NEW.sales_order_no = '' THEN
    SELECT COALESCE(MAX(
      CASE WHEN sales_order_no ~ '^SO-[0-9]+$'
           THEN CAST(SUBSTRING(sales_order_no FROM 4) AS integer)
           ELSE 0
      END
    ), 99) + 1
    INTO v_seq
    FROM "SalesOrders"
    WHERE organization_id = NEW.organization_id;
    NEW.sales_order_no := 'SO-' || LPAD(v_seq::text, 5, '0');
  END IF;
  RETURN NEW;
END;
$function$;;
