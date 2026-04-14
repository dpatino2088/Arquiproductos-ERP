
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
      NEW.organization_id, 'sales_order', NEW.id, 'created',
      'Sales Order ' || COALESCE(NEW.sales_order_no, NEW.id::text) || ' created',
      v_user_id, v_user_name,
      jsonb_build_object('sales_order_no', NEW.sales_order_no, 'status', NEW.status)
    );
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      PERFORM _insert_timeline(
        NEW.organization_id, 'sales_order', NEW.id, 'status_changed',
        'Status changed from ' || COALESCE(OLD.status::text, 'unknown') || ' to ' || COALESCE(NEW.status::text, 'unknown'),
        v_user_id, v_user_name,
        jsonb_build_object('from', OLD.status, 'to', NEW.status)
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
;
