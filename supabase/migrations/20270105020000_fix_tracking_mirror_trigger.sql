-- Fix: the Quote mirror trigger must fire whenever tracking_status actually
-- changes, including when it is set by the BEFORE trigger during a status
-- UPDATE. A "AFTER UPDATE OF tracking_status" trigger only fires when
-- tracking_status is in the UPDATE's SET list, NOT when a BEFORE trigger
-- mutates it. So we listen to any INSERT/UPDATE and compare OLD/NEW instead.

SET search_path = public;

DROP TRIGGER IF EXISTS trg_so_mirror_tracking_to_quote ON public."SalesOrders";
CREATE TRIGGER trg_so_mirror_tracking_to_quote
AFTER INSERT OR UPDATE ON public."SalesOrders"
FOR EACH ROW
EXECUTE FUNCTION public.trg_so_mirror_tracking_to_quote();
