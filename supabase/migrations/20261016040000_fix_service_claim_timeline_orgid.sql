-- Ensure service claim timeline writes satisfy ActivityTimeline constraints
-- ActivityTimeline.organization_id is NOT NULL.

CREATE OR REPLACE FUNCTION public.service_claim_timeline_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public."ActivityTimeline" (
      organization_id,
      entity_type,
      entity_id,
      action,
      description,
      user_name,
      metadata
    )
    VALUES (
      NEW.organization_id,
      'service_claim',
      NEW.id,
      'status_changed',
      'Status changed from ' || OLD.status::text || ' to ' || NEW.status::text,
      COALESCE(current_setting('app.current_user_name', true), 'System'),
      jsonb_build_object('old_status', OLD.status::text, 'new_status', NEW.status::text)
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_service_claim_timeline ON public."ServiceClaims";
CREATE TRIGGER trg_service_claim_timeline
AFTER UPDATE ON public."ServiceClaims"
FOR EACH ROW
EXECUTE FUNCTION public.service_claim_timeline_trigger();
