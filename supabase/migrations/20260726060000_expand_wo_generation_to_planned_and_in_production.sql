-- Expand WO generation to work in confirmed, planned, AND in_production.
-- Previously only 'confirmed' was allowed, creating dead-ends when MOs
-- moved to in_production without WOs.

CREATE OR REPLACE FUNCTION public.enforce_workorder_insert_on_confirmed_mo()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_status text;
BEGIN
  SELECT mo.status::text
  INTO v_status
  FROM public."ManufacturingOrders" mo
  WHERE mo.id = NEW.manufacturing_order_id
    AND mo.deleted = false;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Manufacturing Order not found for Work Order task.';
  END IF;

  IF v_status NOT IN ('confirmed', 'planned', 'in_production') THEN
    RAISE EXCEPTION 'Work Orders can only be generated when MO status is Reviewed, Planned, or In Production (current: %).', v_status;
  END IF;

  RETURN NEW;
END;
$$;
