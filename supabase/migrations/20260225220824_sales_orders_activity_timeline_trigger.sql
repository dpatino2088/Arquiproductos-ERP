
-- Trigger function for SalesOrders → ActivityTimeline
CREATE OR REPLACE FUNCTION trg_sales_orders_write_timeline()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_user_name text;
BEGIN
  v_user_id := (SELECT au.id FROM "AppUsers" au WHERE au.auth_user_id = auth.uid() LIMIT 1);
  SELECT display_name INTO v_user_name FROM "AppUsers" WHERE id = v_user_id;

  IF TG_OP = 'INSERT' THEN
    PERFORM _insert_timeline(
      NEW.organization_id,
      'sales_order',
      NEW.id,
      'created',
      'Sales Order ' || COALESCE(NEW.sales_order_no, NEW.id::text) || ' created',
      v_user_id,
      v_user_name,
      jsonb_build_object('sales_order_no', NEW.sales_order_no, 'status', NEW.status)
    );

  ELSIF TG_OP = 'UPDATE' THEN
    -- Status change
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      PERFORM _insert_timeline(
        NEW.organization_id,
        'sales_order',
        NEW.id,
        'status_changed',
        'Status changed from ' || COALESCE(OLD.status, 'unknown') || ' to ' || COALESCE(NEW.status, 'unknown'),
        v_user_id,
        v_user_name,
        jsonb_build_object('from', OLD.status, 'to', NEW.status)
      );
    END IF;

    -- Payment recorded (amount_paid increased)
    IF (NEW.amount_paid IS NOT NULL AND OLD.amount_paid IS NOT NULL)
       AND NEW.amount_paid > OLD.amount_paid THEN
      PERFORM _insert_timeline(
        NEW.organization_id,
        'sales_order',
        NEW.id,
        'payment_recorded',
        'Payment recorded: ' || COALESCE(NEW.sales_order_no, NEW.id::text),
        v_user_id,
        v_user_name,
        jsonb_build_object(
          'amount_paid', NEW.amount_paid,
          'previous', OLD.amount_paid
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trg_sales_orders_activity_timeline ON "SalesOrders";
CREATE TRIGGER trg_sales_orders_activity_timeline
  AFTER INSERT OR UPDATE ON "SalesOrders"
  FOR EACH ROW
  EXECUTE FUNCTION trg_sales_orders_write_timeline();

-- Backfill: created events for existing SalesOrders with no timeline entry
INSERT INTO "ActivityTimeline" (organization_id, entity_type, entity_id, action, description, user_name, created_at, metadata)
SELECT
  so.organization_id,
  'sales_order',
  so.id,
  'created',
  'Sales Order ' || COALESCE(so.sales_order_no, so.id::text) || ' created',
  NULL,
  so.created_at,
  jsonb_build_object('sales_order_no', so.sales_order_no, 'status', so.status)
FROM "SalesOrders" so
WHERE so.deleted = false
  AND NOT EXISTS (
    SELECT 1 FROM "ActivityTimeline" at2
    WHERE at2.entity_type = 'sales_order'
      AND at2.entity_id = so.id
      AND at2.action = 'created'
  );
;
