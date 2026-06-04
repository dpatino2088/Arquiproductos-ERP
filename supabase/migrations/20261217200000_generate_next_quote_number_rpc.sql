-- generate_next_quote_number(p_org_id)
--
-- Atomically returns the next available QT-NNNNN number for an organisation.
-- Uses an advisory lock keyed on the org so concurrent calls serialise and
-- never return the same number.  Format: QT-00100, QT-00101 … (5 digits, starts at 100).
--
-- Why not a Postgres SEQUENCE?  Quotes are multi-tenant; one sequence per org
-- would require dynamic DDL.  An advisory lock + MAX query is the standard
-- Supabase/PG pattern for this case and is safe under SERIALIZABLE or the
-- default READ COMMITTED isolation.
--
-- The frontend still inserts the returned number; if somehow a collision
-- occurs (row already committed between lock-release and INSERT) Postgres
-- enforces the UNIQUE constraint and the frontend retries.

CREATE OR REPLACE FUNCTION public.generate_next_quote_number(
  p_org_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_max    int;
  v_next   int;
  v_lock   bigint;
BEGIN
  -- Derive a stable advisory-lock key from the org UUID (lower 64 bits).
  v_lock := ('x' || right(replace(p_org_id::text, '-', ''), 16))::bit(64)::bigint;
  PERFORM pg_advisory_xact_lock(v_lock);

  SELECT COALESCE(
    MAX(
      CASE
        WHEN quote_no ~ '^QT-[0-9]{5}$'
        THEN substring(quote_no FROM 4)::int
        ELSE NULL
      END
    ),
    99  -- so first generated number is 100
  )
  INTO v_max
  FROM public."Quotes"
  WHERE organization_id = p_org_id
    AND deleted = false
    AND quote_no IS NOT NULL;

  v_next := GREATEST(v_max + 1, 100);
  RETURN 'QT-' || lpad(v_next::text, 5, '0');
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_next_quote_number(uuid) TO authenticated, service_role;
