-- Sales Order numbers: SO-YYYYMM-NNNN
-- - YYYYMM = year+month of creation (label)
-- - NNNN   = consecutive sequence per organization + calendar year (resets Jan 1)
-- - Dealer does not participate
-- - Applies to NEW SalesOrders only (legacy SO-00100-YYMMDD left untouched)
-- - Room left to migrate legacy numbers later without colliding (different pattern)

CREATE TABLE IF NOT EXISTS public.sales_order_year_counters (
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
  year integer NOT NULL,
  last_seq integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, year),
  CONSTRAINT sales_order_year_counters_year_chk CHECK (year >= 2000 AND year <= 2100),
  CONSTRAINT sales_order_year_counters_seq_chk CHECK (last_seq >= 0)
);

COMMENT ON TABLE public.sales_order_year_counters IS
  'Per-org yearly sequence for SalesOrders numbers (SO-YYYYMM-NNNN).';

ALTER TABLE public.sales_order_year_counters ENABLE ROW LEVEL SECURITY;

-- No direct client access; allocated only via SECURITY DEFINER helper.
REVOKE ALL ON TABLE public.sales_order_year_counters FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.sales_order_year_counters TO service_role;

CREATE OR REPLACE FUNCTION public.allocate_next_sales_order_seq(
  p_organization_id uuid,
  p_year integer
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_seq integer;
BEGIN
  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION 'organization_id is required to allocate sales order sequence';
  END IF;
  IF p_year IS NULL OR p_year < 2000 OR p_year > 2100 THEN
    RAISE EXCEPTION 'invalid year for sales order sequence: %', p_year;
  END IF;

  INSERT INTO public.sales_order_year_counters AS c (organization_id, year, last_seq, updated_at)
  VALUES (p_organization_id, p_year, 1, now())
  ON CONFLICT (organization_id, year)
  DO UPDATE SET
    last_seq = c.last_seq + 1,
    updated_at = now()
  RETURNING last_seq INTO v_seq;

  RETURN v_seq;
END;
$fn$;

REVOKE ALL ON FUNCTION public.allocate_next_sales_order_seq(uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.allocate_next_sales_order_seq(uuid, integer) TO service_role;
-- Trigger runs as inserting role; allow authenticated to call via trigger path.
GRANT EXECUTE ON FUNCTION public.allocate_next_sales_order_seq(uuid, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.generate_sales_order_no()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ts timestamptz;
  v_year integer;
  v_yyyymm text;
  v_seq integer;
BEGIN
  IF NEW.sales_order_no IS NOT NULL AND NEW.sales_order_no <> '' THEN
    RETURN NEW;
  END IF;

  IF NEW.organization_id IS NULL THEN
    RAISE EXCEPTION 'Cannot generate sales_order_no without organization_id';
  END IF;

  v_ts := COALESCE(NEW.created_at, now());
  v_year := EXTRACT(YEAR FROM v_ts)::integer;
  v_yyyymm := to_char(v_ts, 'YYYYMM');
  v_seq := public.allocate_next_sales_order_seq(NEW.organization_id, v_year);

  -- SO-202605-0001
  NEW.sales_order_no := 'SO-' || v_yyyymm || '-' || LPAD(v_seq::text, 4, '0');
  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.generate_sales_order_no() IS
  'SO format: SO-YYYYMM-NNNN. Sequence per organization per calendar year; month is label only.';

-- Ensure trigger still points at this function (idempotent).
DROP TRIGGER IF EXISTS trg_generate_so_number ON public."SalesOrders";
CREATE TRIGGER trg_generate_so_number
  BEFORE INSERT ON public."SalesOrders"
  FOR EACH ROW
  EXECUTE FUNCTION public.generate_sales_order_no();
