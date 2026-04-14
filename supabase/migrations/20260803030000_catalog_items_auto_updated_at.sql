-- Safety-net trigger: auto-refresh updated_at on CatalogItems rows.
-- The frontend already sends updated_at in most writes, but this prevents
-- stale timestamps if any code path omits it (dirty-field partial updates,
-- direct SQL fixes, external tools, etc.).

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_catalogitems_updated_at ON public."CatalogItems";
CREATE TRIGGER trg_catalogitems_updated_at
  BEFORE UPDATE ON public."CatalogItems"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();
