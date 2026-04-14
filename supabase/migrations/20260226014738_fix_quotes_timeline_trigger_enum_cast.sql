
CREATE OR REPLACE FUNCTION public.trg_quotes_write_timeline()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid;
  v_user_name text;
BEGIN
  v_user_id := (SELECT au.id FROM "AppUsers" au WHERE au.auth_user_id = auth.uid() LIMIT 1);
  SELECT display_name INTO v_user_name FROM "AppUsers" WHERE id = v_user_id;

  IF TG_OP = 'INSERT' THEN
    PERFORM _insert_timeline(
      NEW.organization_id, 'quote', NEW.id, 'created',
      'Quote ' || COALESCE(NEW.quote_no, NEW.id::text) || ' created',
      v_user_id, v_user_name,
      jsonb_build_object('quote_no', NEW.quote_no, 'status', NEW.status::text)
    );

  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      PERFORM _insert_timeline(
        NEW.organization_id, 'quote', NEW.id, 'status_changed',
        'Status changed from ' || COALESCE(OLD.status::text, 'none') || ' to ' || COALESCE(NEW.status::text, 'none'),
        v_user_id, v_user_name,
        jsonb_build_object('from', OLD.status::text, 'to', NEW.status::text)
      );
    END IF;

    IF OLD.approved_at IS NULL AND NEW.approved_at IS NOT NULL THEN
      PERFORM _insert_timeline(
        NEW.organization_id, 'quote', NEW.id, 'approved',
        'Quote ' || COALESCE(NEW.quote_no, NEW.id::text) || ' approved',
        v_user_id, v_user_name,
        jsonb_build_object('quote_no', NEW.quote_no)
      );
    END IF;

    IF OLD.converted_at IS NULL AND NEW.converted_at IS NOT NULL THEN
      PERFORM _insert_timeline(
        NEW.organization_id, 'quote', NEW.id, 'converted',
        'Quote converted to Sales Order',
        v_user_id, v_user_name,
        jsonb_build_object('quote_no', NEW.quote_no)
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;
;
