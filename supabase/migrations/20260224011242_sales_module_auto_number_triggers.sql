
-- Auto-generate sales_order_no if not provided
CREATE OR REPLACE FUNCTION generate_sales_order_no()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_seq int;
BEGIN
  IF NEW.sales_order_no IS NULL OR NEW.sales_order_no = '' THEN
    SELECT COALESCE(MAX(
      CASE WHEN sales_order_no ~ '^SO-[0-9]+$'
           THEN CAST(SUBSTRING(sales_order_no FROM 4) AS integer)
           ELSE 0
      END
    ), 0) + 1
    INTO v_seq
    FROM "SalesOrders"
    WHERE organization_id = NEW.organization_id;
    NEW.sales_order_no := 'SO-' || LPAD(v_seq::text, 6, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_generate_so_number ON "SalesOrders";
CREATE TRIGGER trg_generate_so_number
  BEFORE INSERT ON "SalesOrders"
  FOR EACH ROW EXECUTE FUNCTION generate_sales_order_no();

-- Auto-generate manufacturing_order_no if not provided
CREATE OR REPLACE FUNCTION generate_manufacturing_order_no()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_seq int;
BEGIN
  IF NEW.manufacturing_order_no IS NULL OR NEW.manufacturing_order_no = '' THEN
    SELECT COALESCE(MAX(
      CASE WHEN manufacturing_order_no ~ '^MO-[0-9]+$'
           THEN CAST(SUBSTRING(manufacturing_order_no FROM 4) AS integer)
           ELSE 0
      END
    ), 0) + 1
    INTO v_seq
    FROM "ManufacturingOrders"
    WHERE organization_id = NEW.organization_id;
    NEW.manufacturing_order_no := 'MO-' || LPAD(v_seq::text, 6, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_generate_mo_number ON "ManufacturingOrders";
CREATE TRIGGER trg_generate_mo_number
  BEFORE INSERT ON "ManufacturingOrders"
  FOR EACH ROW EXECUTE FUNCTION generate_manufacturing_order_no();
;
