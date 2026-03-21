-- Adjustments Module Improvements
-- Applied via Supabase MCP.

-- 1. Adjustment reason enum
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'adjustment_reason') THEN
    CREATE TYPE public.adjustment_reason AS ENUM (
      'physical_count', 'damaged', 'theft_shrinkage', 'write_off',
      'opening_stock', 'correction', 'return_to_stock', 'other'
    );
  END IF;
END $$;

-- 2. Add adjustment_reason column
ALTER TABLE public."InventoryMovements"
  ADD COLUMN IF NOT EXISTS adjustment_reason public.adjustment_reason DEFAULT NULL;

-- 3. Auto-generate movement_no trigger
CREATE OR REPLACE FUNCTION public.trg_inventory_movement_no()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_prefix text;
  v_next_no integer;
BEGIN
  IF NEW.movement_no IS NOT NULL THEN
    RETURN NEW;
  END IF;

  v_prefix := CASE NEW.movement_type
    WHEN 'adjustment' THEN 'ADJ'
    WHEN 'receipt' THEN 'REC'
    WHEN 'transfer' THEN 'TRF'
    WHEN 'return' THEN 'RTN'
    WHEN 'issue_to_production' THEN 'ISS'
    ELSE 'MOV'
  END;

  SELECT COALESCE(MAX(
    CASE WHEN movement_no ~ ('^' || v_prefix || '-\d+$')
         THEN CAST(SUBSTRING(movement_no FROM v_prefix || '-(\d+)') AS integer)
         ELSE 0
    END
  ), 0) + 1
  INTO v_next_no
  FROM "InventoryMovements"
  WHERE organization_id = NEW.organization_id;

  NEW.movement_no := v_prefix || '-' || LPAD(v_next_no::text, 6, '0');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inventory_movement_no_bi ON public."InventoryMovements";
CREATE TRIGGER trg_inventory_movement_no_bi
  BEFORE INSERT ON public."InventoryMovements"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_inventory_movement_no();

-- 4. Fix confirm_inventory_movement to handle negative adjustments
CREATE OR REPLACE FUNCTION public.confirm_inventory_movement(p_movement_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_mov RECORD;
  v_line RECORD;
  v_line_count integer := 0;
  v_existing_qty numeric;
  v_new_qty numeric;
BEGIN
  SELECT id, organization_id, warehouse_id, movement_type, status
  INTO v_mov
  FROM "InventoryMovements"
  WHERE id = p_movement_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Movement not found or deleted.');
  END IF;

  IF v_mov.status = 'confirmed' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Movement is already confirmed.');
  END IF;

  FOR v_line IN
    SELECT catalog_item_id, quantity, unit
    FROM "InventoryMovementLines"
    WHERE inventory_movement_id = p_movement_id
  LOOP
    SELECT quantity INTO v_existing_qty
    FROM "InventoryBalances"
    WHERE organization_id = v_mov.organization_id
      AND warehouse_id = v_mov.warehouse_id
      AND catalog_item_id = v_line.catalog_item_id;

    IF FOUND THEN
      v_new_qty := v_existing_qty + v_line.quantity;
      IF v_new_qty < 0 THEN
        RETURN jsonb_build_object(
          'ok', false,
          'error', format('Insufficient stock for item %s. Current: %s, Adjustment: %s, Would result in: %s',
            v_line.catalog_item_id, v_existing_qty, v_line.quantity, v_new_qty)
        );
      END IF;
      UPDATE "InventoryBalances"
      SET quantity = v_new_qty, updated_at = now()
      WHERE organization_id = v_mov.organization_id
        AND warehouse_id = v_mov.warehouse_id
        AND catalog_item_id = v_line.catalog_item_id;
    ELSE
      IF v_line.quantity < 0 THEN
        RETURN jsonb_build_object(
          'ok', false,
          'error', format('Cannot create negative balance for item %s. No existing stock.', v_line.catalog_item_id)
        );
      END IF;
      INSERT INTO "InventoryBalances" (organization_id, warehouse_id, catalog_item_id, quantity, updated_at)
      VALUES (v_mov.organization_id, v_mov.warehouse_id, v_line.catalog_item_id, v_line.quantity, now());
    END IF;

    v_line_count := v_line_count + 1;
  END LOOP;

  UPDATE "InventoryMovements"
  SET status = 'confirmed', confirmed_at = now(), updated_at = now()
  WHERE id = p_movement_id;

  RETURN jsonb_build_object('ok', true, 'movement_id', p_movement_id, 'lines_confirmed', v_line_count);
END;
$function$;

NOTIFY pgrst, 'reload schema';
