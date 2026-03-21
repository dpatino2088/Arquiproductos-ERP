-- Fix receive_purchase_order: multiply received qty by units_per_purchase_unit
-- when purchase_unit differs from stock unit (e.g., box→ea).
-- Normalizes ea/each/unit/pc synonyms so they compare equal.
-- Also corrects historically wrong inventory balances and movement lines.

BEGIN;

-- ============================================================
-- 1. Replace the RPC with the corrected version
-- ============================================================
CREATE OR REPLACE FUNCTION public.receive_purchase_order(
  p_purchase_order_id uuid,
  p_lines jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_po RECORD;
  v_movement_id uuid;
  v_movement_no text;
  v_line_count integer := 0;
  v_line jsonb;
  v_pol RECORD;
  v_remaining numeric;
  v_new_received numeric;
  v_inventory_delta numeric;
  v_inventory_unit text;
  v_roll_length_value numeric;
  v_roll_length_uom text;
  v_length_m_per_purchase numeric;
  v_uppu numeric;
  v_po_unit_norm text;
  v_stock_unit_norm text;
BEGIN
  SELECT id, organization_id, warehouse_id, status, po_number
  INTO v_po
  FROM "PurchaseOrders"
  WHERE id = p_purchase_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Purchase order not found.');
  END IF;

  IF v_po.status NOT IN ('OPEN', 'PARTIAL') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Purchase order is closed. Cannot receive.');
  END IF;

  SELECT 'REC-' || LPAD((COALESCE(MAX(
    CASE WHEN movement_no ~ '^REC-\d+$' THEN CAST(SUBSTRING(movement_no FROM 'REC-(\d+)') AS integer) ELSE 0 END
  ), 0) + 1)::text, 6, '0')
  INTO v_movement_no
  FROM "InventoryMovements"
  WHERE organization_id = v_po.organization_id;

  INSERT INTO "InventoryMovements" (
    organization_id, warehouse_id, movement_type, reference_type, reference_id,
    movement_no, movement_date, status, confirmed_at, notes, deleted, created_at, updated_at
  ) VALUES (
    v_po.organization_id, v_po.warehouse_id, 'receipt',
    'purchase_order', p_purchase_order_id,
    v_movement_no, CURRENT_DATE, 'confirmed', now(),
    'Receipt for PO ' || COALESCE(v_po.po_number, v_po.id::text),
    false, now(), now()
  ) RETURNING id INTO v_movement_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines)
  LOOP
    SELECT
      pol.id,
      pol.catalog_item_id,
      pol.ordered_qty,
      pol.received_qty,
      pol.unit,
      pol.is_one_off,
      COALESCE(pol.unit_of_measure_snapshot, ci.unit_of_measure, pol.unit, 'ea') AS unit_of_measure_snapshot,
      COALESCE(pol.is_roll_snapshot, ci.is_roll, false) AS is_roll_snapshot,
      COALESCE(pol.roll_length_value_snapshot, ci.roll_length_value) AS roll_length_value_snapshot,
      COALESCE(pol.roll_length_uom_snapshot, ci.roll_length_uom) AS roll_length_uom_snapshot,
      COALESCE(pol.units_per_purchase_unit_snapshot, ci.units_per_purchase_unit, 1) AS units_per_purchase_unit
    INTO v_pol
    FROM "PurchaseOrderLines" pol
    LEFT JOIN "CatalogItems" ci ON ci.id = pol.catalog_item_id
    WHERE pol.id = (v_line->>'purchase_order_line_id')::uuid
      AND pol.purchase_order_id = p_purchase_order_id;

    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    v_remaining := v_pol.ordered_qty - COALESCE(v_pol.received_qty, 0);
    v_new_received := LEAST((v_line->>'received_qty')::numeric, v_remaining);

    IF v_new_received <= 0 THEN
      CONTINUE;
    END IF;

    v_inventory_delta := v_new_received;
    v_inventory_unit := COALESCE(v_pol.unit_of_measure_snapshot, v_pol.unit, 'ea');
    v_uppu := COALESCE(v_pol.units_per_purchase_unit, 1);

    -- Normalize ea/each/unit synonyms for comparison
    v_po_unit_norm := CASE
      WHEN LOWER(COALESCE(v_pol.unit, '')) IN ('each','ea','unit','units','pc','pcs') THEN 'ea'
      ELSE LOWER(COALESCE(v_pol.unit, ''))
    END;
    v_stock_unit_norm := CASE
      WHEN LOWER(v_inventory_unit) IN ('each','ea','unit','units','pc','pcs') THEN 'ea'
      ELSE LOWER(v_inventory_unit)
    END;

    -- Roll handling (fabric): convert rolls to linear meters
    IF v_pol.catalog_item_id IS NOT NULL AND COALESCE(v_pol.is_roll_snapshot, false) = true THEN
      v_roll_length_value := COALESCE(v_pol.roll_length_value_snapshot, 0);
      v_roll_length_uom := LOWER(COALESCE(v_pol.roll_length_uom_snapshot, ''));
      v_length_m_per_purchase := CASE
        WHEN v_roll_length_value <= 0 THEN NULL
        WHEN v_roll_length_uom IN ('m', 'meter', 'meters', 'metre', 'metres') THEN v_roll_length_value
        WHEN v_roll_length_uom IN ('yd', 'yard', 'yards') THEN v_roll_length_value * 0.9144
        WHEN v_roll_length_uom IN ('ft', 'foot', 'feet') THEN v_roll_length_value * 0.3048
        WHEN v_roll_length_uom IN ('in', 'inch', 'inches') THEN v_roll_length_value * 0.0254
        WHEN v_roll_length_uom IN ('cm', 'centimeter', 'centimeters', 'centimetre', 'centimetres') THEN v_roll_length_value / 100.0
        WHEN v_roll_length_uom IN ('mm', 'millimeter', 'millimeters', 'millimetre', 'millimetres') THEN v_roll_length_value / 1000.0
        ELSE NULL
      END;
      IF v_length_m_per_purchase IS NOT NULL AND v_length_m_per_purchase > 0 THEN
        v_inventory_delta := v_new_received * v_length_m_per_purchase;
        v_inventory_unit := 'm';
      END IF;

    -- Non-roll: apply units_per_purchase_unit when purchase unit differs from stock unit
    ELSIF v_pol.catalog_item_id IS NOT NULL
      AND v_uppu > 1
      AND v_po_unit_norm != v_stock_unit_norm
    THEN
      v_inventory_delta := v_new_received * v_uppu;

      -- If both are length units, also convert between unit systems (e.g., ft→m)
      IF v_po_unit_norm IN ('ft', 'foot', 'feet') AND v_stock_unit_norm = 'm' THEN
        v_inventory_delta := v_inventory_delta * 0.3048;
      ELSIF v_po_unit_norm IN ('yd', 'yard', 'yards') AND v_stock_unit_norm = 'm' THEN
        v_inventory_delta := v_inventory_delta * 0.9144;
      ELSIF v_po_unit_norm IN ('in', 'inch', 'inches') AND v_stock_unit_norm = 'm' THEN
        v_inventory_delta := v_inventory_delta * 0.0254;
      END IF;
    END IF;

    IF v_pol.catalog_item_id IS NOT NULL THEN
      INSERT INTO "InventoryMovementLines" (
        inventory_movement_id, catalog_item_id, quantity, unit, notes, created_at, updated_at
      ) VALUES (
        v_movement_id,
        v_pol.catalog_item_id,
        v_inventory_delta,
        v_inventory_unit,
        CASE
          WHEN COALESCE(v_pol.is_roll_snapshot, false) = true
            THEN format('Received %s %s (normalized to %s m)',
                        v_new_received,
                        COALESCE(v_pol.unit, 'roll'),
                        ROUND(v_inventory_delta, 6))
          WHEN v_uppu > 1 AND v_po_unit_norm != v_stock_unit_norm
            THEN format('Received %s %s x %s units/%s = %s %s',
                        v_new_received,
                        COALESCE(v_pol.unit, 'unit'),
                        v_uppu,
                        COALESCE(v_pol.unit, 'unit'),
                        ROUND(v_inventory_delta, 4),
                        v_inventory_unit)
          ELSE NULL
        END,
        now(),
        now()
      );
    END IF;
    v_line_count := v_line_count + 1;

    UPDATE "PurchaseOrderLines"
    SET received_qty = received_qty + v_new_received, updated_at = now()
    WHERE id = v_pol.id;

    IF v_pol.catalog_item_id IS NOT NULL THEN
      INSERT INTO "InventoryBalances" (organization_id, warehouse_id, catalog_item_id, quantity, updated_at)
      VALUES (v_po.organization_id, v_po.warehouse_id, v_pol.catalog_item_id, v_inventory_delta, now())
      ON CONFLICT (organization_id, warehouse_id, catalog_item_id)
      DO UPDATE SET quantity = "InventoryBalances".quantity + v_inventory_delta, updated_at = now();
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM "PurchaseOrderLines"
    WHERE purchase_order_id = p_purchase_order_id
      AND (ordered_qty - received_qty) > 0
  ) THEN
    UPDATE "PurchaseOrders" SET status = 'CLOSED', updated_at = now() WHERE id = p_purchase_order_id;
  ELSE
    UPDATE "PurchaseOrders" SET status = 'PARTIAL', updated_at = now() WHERE id = p_purchase_order_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'movement_id', v_movement_id,
    'movement_no', v_movement_no,
    'lines_count', v_line_count,
    'po_number', v_po.po_number
  );
END;
$$;


-- ============================================================
-- 2. Correct historical inventory data
-- ============================================================
-- For each receipt movement line where purchase unit (box/pack/set)
-- differs from stock unit (ea), the recorded qty was the raw purchase
-- qty (e.g., 1 box) but should have been multiplied by uppu (e.g., 50 ea).

DO $$
DECLARE
  v_rec RECORD;
  v_correction numeric;
BEGIN
  FOR v_rec IN
    SELECT
      iml.id AS iml_id,
      iml.catalog_item_id,
      iml.quantity AS old_qty,
      ci.units_per_purchase_unit::numeric AS uppu,
      im.organization_id,
      im.warehouse_id
    FROM "InventoryMovementLines" iml
    JOIN "InventoryMovements" im ON im.id = iml.inventory_movement_id
      AND im.movement_type = 'receipt'
      AND im.reference_type = 'purchase_order'
    JOIN "PurchaseOrders" po ON po.id = im.reference_id
    JOIN "PurchaseOrderLines" pol ON pol.purchase_order_id = po.id
      AND pol.catalog_item_id = iml.catalog_item_id
    JOIN "CatalogItems" ci ON ci.id = iml.catalog_item_id
    WHERE COALESCE(ci.is_roll, false) = false
      AND ci.units_per_purchase_unit IS NOT NULL
      AND ci.units_per_purchase_unit > 1
      AND CASE WHEN LOWER(pol.unit) IN ('each','ea','unit','units','pc','pcs') THEN 'ea'
               ELSE LOWER(pol.unit) END
        != CASE WHEN LOWER(COALESCE(ci.unit_of_measure,'ea')) IN ('each','ea','unit','units','pc','pcs') THEN 'ea'
                ELSE LOWER(COALESCE(ci.unit_of_measure,'ea')) END
    ORDER BY iml.catalog_item_id, im.created_at
  LOOP
    v_correction := v_rec.old_qty * (v_rec.uppu - 1);

    UPDATE "InventoryMovementLines"
    SET quantity = v_rec.old_qty * v_rec.uppu,
        notes = format('Corrected: was %s, now %s (x%s uppu)',
                       ROUND(v_rec.old_qty, 4),
                       ROUND(v_rec.old_qty * v_rec.uppu, 4),
                       v_rec.uppu),
        updated_at = now()
    WHERE id = v_rec.iml_id;

    UPDATE "InventoryBalances"
    SET quantity = quantity + v_correction,
        updated_at = now()
    WHERE organization_id = v_rec.organization_id
      AND warehouse_id = v_rec.warehouse_id
      AND catalog_item_id = v_rec.catalog_item_id;
  END LOOP;
END;
$$;

COMMIT;
