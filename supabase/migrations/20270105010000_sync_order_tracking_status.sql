-- Keep the dealer-facing order status (SalesOrders.tracking_status and the
-- mirrored Quotes.tracking_status) in sync with the internal SalesOrders.status.
--
-- Model (single source of truth = SalesOrders.status):
--   internal status        -> dealer tracking_status
--   draft                  -> pending_confirmation
--   confirmed              -> confirmed
--   in_production          -> in_production
--   ready_for_delivery     -> ready_for_delivery
--   delivered / closed     -> delivered
--   cancelled              -> canceled
--   on_hold / other        -> (unchanged; dealer keeps last milestone)
--
-- The dealer never sees factory-internal MO states (procurement, materials,
-- quality_check, completed). Those collapse into the milestones above via the
-- MO->SO propagation trigger.

SET search_path = public;

-- ---------------------------------------------------------------------------
-- 1) MO -> SO propagation: fix "completed" so it no longer marks the SO as
--    delivered. Delivered must only happen through an actual delivery note.
--    completed / quality_check now keep the dealer at "In Production".
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_mo_status_propagate_to_so()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_so_id     uuid;
  v_so_status text;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  v_so_id := NEW.sales_order_id;
  IF v_so_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT status INTO v_so_status
  FROM "SalesOrders"
  WHERE id = v_so_id AND deleted = false;

  IF v_so_status IS NULL THEN
    RETURN NEW;
  END IF;

  -- Fabrication in progress / done (but not yet ready for pickup) -> In Production
  IF NEW.status IN ('in_production', 'completed', 'quality_check')
     AND v_so_status IN ('draft', 'confirmed', 'on_hold') THEN
    UPDATE "SalesOrders"
    SET status = 'in_production', updated_at = now()
    WHERE id = v_so_id AND deleted = false;
    RETURN NEW;
  END IF;

  IF NEW.status = 'ready_for_pickup'
     AND v_so_status NOT IN ('delivered', 'closed') THEN
    UPDATE "SalesOrders"
    SET status = 'ready_for_delivery', updated_at = now()
    WHERE id = v_so_id AND deleted = false;
    RETURN NEW;
  END IF;

  IF NEW.status = 'delivered'
     AND v_so_status <> 'delivered' THEN
    UPDATE "SalesOrders"
    SET status = 'delivered', updated_at = now()
    WHERE id = v_so_id AND deleted = false;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2) SalesOrders.status -> SalesOrders.tracking_status (dealer-facing).
--    BEFORE trigger so we mutate the same row without recursion.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_so_sync_tracking_status()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_track text;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  v_track := CASE NEW.status::text
    WHEN 'draft'              THEN 'pending_confirmation'
    WHEN 'confirmed'          THEN 'confirmed'
    WHEN 'in_production'      THEN 'in_production'
    WHEN 'ready_for_delivery' THEN 'ready_for_delivery'
    WHEN 'delivered'          THEN 'delivered'
    WHEN 'closed'             THEN 'delivered'
    WHEN 'cancelled'          THEN 'canceled'
    ELSE NULL  -- on_hold and anything unmapped: keep current tracking
  END;

  IF v_track IS NOT NULL THEN
    NEW.tracking_status := v_track::sales_order_tracking_status;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_so_sync_tracking_status ON public."SalesOrders";
CREATE TRIGGER trg_so_sync_tracking_status
BEFORE INSERT OR UPDATE OF status ON public."SalesOrders"
FOR EACH ROW
EXECUTE FUNCTION public.trg_so_sync_tracking_status();

-- ---------------------------------------------------------------------------
-- 3) Mirror SalesOrders.tracking_status -> Quotes.tracking_status so the
--    dealer's approved-quote/order view reflects live progress.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_so_mirror_tracking_to_quote()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.quote_id IS NOT NULL
     AND NEW.tracking_status IS DISTINCT FROM OLD.tracking_status THEN
    UPDATE "Quotes"
    SET tracking_status = NEW.tracking_status, updated_at = now()
    WHERE id = NEW.quote_id
      AND tracking_status IS DISTINCT FROM NEW.tracking_status;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_so_mirror_tracking_to_quote ON public."SalesOrders";
CREATE TRIGGER trg_so_mirror_tracking_to_quote
AFTER UPDATE OF tracking_status ON public."SalesOrders"
FOR EACH ROW
EXECUTE FUNCTION public.trg_so_mirror_tracking_to_quote();

-- ---------------------------------------------------------------------------
-- 4) Backfill existing rows so what is already delivered/in production shows
--    correctly for the dealer.
-- ---------------------------------------------------------------------------
UPDATE public."SalesOrders" so
SET tracking_status = (CASE so.status::text
      WHEN 'draft'              THEN 'pending_confirmation'
      WHEN 'confirmed'          THEN 'confirmed'
      WHEN 'in_production'      THEN 'in_production'
      WHEN 'ready_for_delivery' THEN 'ready_for_delivery'
      WHEN 'delivered'          THEN 'delivered'
      WHEN 'closed'             THEN 'delivered'
      WHEN 'cancelled'          THEN 'canceled'
      ELSE so.tracking_status::text
    END)::sales_order_tracking_status,
    updated_at = now()
WHERE so.deleted = false
  AND so.tracking_status::text IS DISTINCT FROM (CASE so.status::text
      WHEN 'draft'              THEN 'pending_confirmation'
      WHEN 'confirmed'          THEN 'confirmed'
      WHEN 'in_production'      THEN 'in_production'
      WHEN 'ready_for_delivery' THEN 'ready_for_delivery'
      WHEN 'delivered'          THEN 'delivered'
      WHEN 'closed'             THEN 'delivered'
      WHEN 'cancelled'          THEN 'canceled'
      ELSE so.tracking_status::text
    END);

-- Mirror the backfilled tracking to the originating quotes.
UPDATE public."Quotes" q
SET tracking_status = so.tracking_status, updated_at = now()
FROM public."SalesOrders" so
WHERE so.quote_id = q.id
  AND so.deleted = false
  AND q.tracking_status IS DISTINCT FROM so.tracking_status;
