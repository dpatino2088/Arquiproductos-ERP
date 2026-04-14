
-- Función trigger para escribir eventos de Quote en ActivityTimeline
CREATE OR REPLACE FUNCTION trg_quotes_write_timeline()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_user_name text;
BEGIN
  -- Obtener el usuario actual de la sesión (puede ser null en operaciones internas)
  v_user_id := (SELECT au.id FROM "AppUsers" au WHERE au.auth_user_id = auth.uid() LIMIT 1);
  SELECT display_name INTO v_user_name FROM "AppUsers" WHERE id = v_user_id;

  IF TG_OP = 'INSERT' THEN
    PERFORM _insert_timeline(
      NEW.organization_id,
      'quote',
      NEW.id,
      'created',
      'Quote ' || COALESCE(NEW.quote_no, NEW.id::text) || ' created',
      v_user_id,
      v_user_name,
      jsonb_build_object('quote_no', NEW.quote_no, 'status', NEW.status)
    );

  ELSIF TG_OP = 'UPDATE' THEN
    -- Cambio de estado
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      PERFORM _insert_timeline(
        NEW.organization_id,
        'quote',
        NEW.id,
        'status_changed',
        'Status changed from ' || COALESCE(OLD.status, 'unknown') || ' to ' || COALESCE(NEW.status, 'unknown'),
        v_user_id,
        v_user_name,
        jsonb_build_object('from', OLD.status, 'to', NEW.status)
      );
    END IF;

    -- Aprobación
    IF OLD.approved_at IS NULL AND NEW.approved_at IS NOT NULL THEN
      PERFORM _insert_timeline(
        NEW.organization_id,
        'quote',
        NEW.id,
        'approved',
        'Quote ' || COALESCE(NEW.quote_no, NEW.id::text) || ' approved',
        v_user_id,
        v_user_name,
        jsonb_build_object('quote_no', NEW.quote_no)
      );
    END IF;

    -- Conversión a Sales Order
    IF OLD.converted_at IS NULL AND NEW.converted_at IS NOT NULL THEN
      PERFORM _insert_timeline(
        NEW.organization_id,
        'quote',
        NEW.id,
        'converted',
        'Quote converted to Sales Order',
        v_user_id,
        v_user_name,
        jsonb_build_object('quote_no', NEW.quote_no)
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger en INSERT y UPDATE sobre Quotes
DROP TRIGGER IF EXISTS trg_quotes_activity_timeline ON "Quotes";
CREATE TRIGGER trg_quotes_activity_timeline
  AFTER INSERT OR UPDATE ON "Quotes"
  FOR EACH ROW
  EXECUTE FUNCTION trg_quotes_write_timeline();

-- Backfill: insertar evento 'created' para quotes existentes que no tengan entrada en ActivityTimeline
INSERT INTO "ActivityTimeline" (organization_id, entity_type, entity_id, action, description, user_name, created_at, metadata)
SELECT
  q.organization_id,
  'quote',
  q.id,
  'created',
  'Quote ' || COALESCE(q.quote_no, q.id::text) || ' created',
  NULL,
  q.created_at,
  jsonb_build_object('quote_no', q.quote_no, 'status', q.status)
FROM "Quotes" q
WHERE NOT EXISTS (
  SELECT 1 FROM "ActivityTimeline" at2
  WHERE at2.entity_type = 'quote' AND at2.entity_id = q.id
)
AND q.deleted = false;

-- Backfill: insertar evento 'status_changed' → approved para quotes con approved_at
INSERT INTO "ActivityTimeline" (organization_id, entity_type, entity_id, action, description, user_name, created_at, metadata)
SELECT
  q.organization_id,
  'quote',
  q.id,
  'approved',
  'Quote ' || COALESCE(q.quote_no, q.id::text) || ' approved',
  NULL,
  q.approved_at,
  jsonb_build_object('quote_no', q.quote_no)
FROM "Quotes" q
WHERE q.approved_at IS NOT NULL
  AND q.deleted = false
  AND NOT EXISTS (
    SELECT 1 FROM "ActivityTimeline" at2
    WHERE at2.entity_type = 'quote' AND at2.entity_id = q.id AND at2.action = 'approved'
  );

-- Backfill: insertar evento 'converted' para quotes convertidas
INSERT INTO "ActivityTimeline" (organization_id, entity_type, entity_id, action, description, user_name, created_at, metadata)
SELECT
  q.organization_id,
  'quote',
  q.id,
  'converted',
  'Quote converted to Sales Order',
  NULL,
  q.converted_at,
  jsonb_build_object('quote_no', q.quote_no)
FROM "Quotes" q
WHERE q.converted_at IS NOT NULL
  AND q.deleted = false
  AND NOT EXISTS (
    SELECT 1 FROM "ActivityTimeline" at2
    WHERE at2.entity_type = 'quote' AND at2.entity_id = q.id AND at2.action = 'converted'
  );
;
