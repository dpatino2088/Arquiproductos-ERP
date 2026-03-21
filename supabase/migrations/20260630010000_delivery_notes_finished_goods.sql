-- ============================================================
-- Delivery Notes & Finished Goods System
-- ============================================================
-- 1. Add delivery_status and delivery columns to ManufacturingOrderLines
-- 2. Add delivered_at, released_at to ManufacturingOrders (if missing)
-- 3. Create DeliveryNotes table
-- 4. Create DeliveryNoteLines table
-- 5. Trigger: QC -> ready_for_pickup sets MOLines delivery_status = 'ready'
-- 6. View: finished_goods_stock
-- 7. Function: complete_delivery_note
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. ManufacturingOrderLines — delivery columns
-- ────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'ManufacturingOrderLines'
      AND column_name = 'delivery_status'
  ) THEN
    ALTER TABLE public."ManufacturingOrderLines"
      ADD COLUMN delivery_status text NOT NULL DEFAULT 'pending';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'ManufacturingOrderLines'
      AND column_name = 'delivered_at'
  ) THEN
    ALTER TABLE public."ManufacturingOrderLines"
      ADD COLUMN delivered_at timestamptz;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'ManufacturingOrderLines'
      AND column_name = 'delivered_qty'
  ) THEN
    ALTER TABLE public."ManufacturingOrderLines"
      ADD COLUMN delivered_qty numeric(12,4) DEFAULT 0;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'ManufacturingOrderLines'
      AND column_name = 'delivery_notes'
  ) THEN
    ALTER TABLE public."ManufacturingOrderLines"
      ADD COLUMN delivery_notes text;
  END IF;
END $$;

-- ────────────────────────────────────────────────────────────
-- 2. ManufacturingOrders — delivered_at / released_at
-- ────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'ManufacturingOrders'
      AND column_name = 'delivered_at'
  ) THEN
    ALTER TABLE public."ManufacturingOrders"
      ADD COLUMN delivered_at timestamptz;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'ManufacturingOrders'
      AND column_name = 'released_at'
  ) THEN
    ALTER TABLE public."ManufacturingOrders"
      ADD COLUMN released_at timestamptz;
  END IF;
END $$;

-- ────────────────────────────────────────────────────────────
-- 3. DeliveryNotes table
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public."DeliveryNotes" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  manufacturing_order_id uuid NOT NULL REFERENCES public."ManufacturingOrders"(id),
  delivery_number text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  delivered_by_user_id uuid,
  delivered_by_name text,
  received_by_name text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  deleted boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_delivery_notes_org
  ON public."DeliveryNotes"(organization_id);
CREATE INDEX IF NOT EXISTS idx_delivery_notes_mo
  ON public."DeliveryNotes"(manufacturing_order_id);

-- RLS
ALTER TABLE public."DeliveryNotes" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "delivery_notes_org_access" ON public."DeliveryNotes";
CREATE POLICY "delivery_notes_org_access" ON public."DeliveryNotes"
  FOR ALL USING (
    organization_id IN (
      SELECT organization_id FROM public."AppUsers"
      WHERE auth_user_id = auth.uid()
        AND deleted = false
        AND status = 'active'
    )
  );

-- ────────────────────────────────────────────────────────────
-- 4. DeliveryNoteLines table
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public."DeliveryNoteLines" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_note_id uuid NOT NULL REFERENCES public."DeliveryNotes"(id) ON DELETE CASCADE,
  mo_line_id uuid NOT NULL REFERENCES public."ManufacturingOrderLines"(id),
  quantity_delivered numeric(12,4) NOT NULL DEFAULT 0,
  checked boolean NOT NULL DEFAULT false,
  checked_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_delivery_note_lines_note
  ON public."DeliveryNoteLines"(delivery_note_id);
CREATE INDEX IF NOT EXISTS idx_delivery_note_lines_mol
  ON public."DeliveryNoteLines"(mo_line_id);

-- RLS (inherits via delivery_note_id -> DeliveryNotes)
ALTER TABLE public."DeliveryNoteLines" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "delivery_note_lines_access" ON public."DeliveryNoteLines";
CREATE POLICY "delivery_note_lines_access" ON public."DeliveryNoteLines"
  FOR ALL USING (
    delivery_note_id IN (
      SELECT id FROM public."DeliveryNotes"
      WHERE organization_id IN (
        SELECT organization_id FROM public."AppUsers"
        WHERE auth_user_id = auth.uid()
          AND deleted = false
          AND status = 'active'
      )
    )
  );

-- ────────────────────────────────────────────────────────────
-- 5. Trigger: when MO transitions to ready_for_pickup,
--    set all MOLines delivery_status = 'ready'
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_mo_ready_set_delivery_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
BEGIN
  IF NEW.status = 'ready_for_pickup'
     AND (OLD.status IS NULL OR OLD.status <> 'ready_for_pickup') THEN
    UPDATE public."ManufacturingOrderLines"
    SET delivery_status = 'ready', updated_at = now()
    WHERE manufacturing_order_id = NEW.id
      AND deleted = false
      AND delivery_status = 'pending';

    NEW.released_at = COALESCE(NEW.released_at, now());
  END IF;

  IF NEW.status = 'delivered'
     AND (OLD.status IS NULL OR OLD.status <> 'delivered') THEN
    NEW.delivered_at = COALESCE(NEW.delivered_at, now());
  END IF;

  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_mo_ready_set_delivery_status ON public."ManufacturingOrders";
CREATE TRIGGER trg_mo_ready_set_delivery_status
  BEFORE UPDATE ON public."ManufacturingOrders"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_mo_ready_set_delivery_status();

-- ────────────────────────────────────────────────────────────
-- 6. View: finished_goods_stock
--    Shows MOLines ready for delivery with MO + SO context
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.finished_goods_stock AS
SELECT
  mol.id AS mo_line_id,
  mol.manufacturing_order_id,
  mol.sales_order_line_id,
  mol.quantity,
  mol.delivery_status,
  mol.delivered_qty,
  mol.delivered_at,
  mo.organization_id,
  mo.manufacturing_order_no,
  mo.status AS mo_status,
  mo.sales_order_id,
  mo.product_name,
  mo.released_at,
  so.sales_order_no,
  dc.customer_name,
  sol.description AS line_description,
  sol.product_type,
  sol.area,
  sol.position,
  ci.name AS catalog_item_name,
  ci.sku AS catalog_item_sku
FROM public."ManufacturingOrderLines" mol
JOIN public."ManufacturingOrders" mo ON mo.id = mol.manufacturing_order_id
LEFT JOIN public."SalesOrders" so ON so.id = mo.sales_order_id
LEFT JOIN public."DirectoryCustomers" dc ON dc.id = so.customer_id
LEFT JOIN public."SaleOrderLines" sol ON sol.id = mol.sales_order_line_id
LEFT JOIN public."CatalogItems" ci ON ci.id = sol.catalog_item_id
WHERE mol.deleted = false
  AND mo.deleted = false
  AND mo.status IN ('ready_for_pickup', 'delivered')
  AND mol.delivery_status IN ('ready', 'delivered');

-- ────────────────────────────────────────────────────────────
-- 7. Function: complete_delivery_note
--    Marks checked lines as delivered, updates MO status
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.complete_delivery_note(p_delivery_note_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
  v_dn        record;
  v_total     integer;
  v_checked   integer;
  v_mo_id     uuid;
  v_new_dn_status text;
  v_all_mol_delivered boolean;
  v_so_id     uuid;
  v_all_mo_delivered boolean;
  v_org_id    uuid;
  v_mo_no     text;
BEGIN
  SELECT * INTO v_dn FROM public."DeliveryNotes"
  WHERE id = p_delivery_note_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Delivery note not found');
  END IF;

  v_mo_id := v_dn.manufacturing_order_id;
  v_org_id := v_dn.organization_id;

  SELECT manufacturing_order_no INTO v_mo_no
  FROM public."ManufacturingOrders" WHERE id = v_mo_id;

  SELECT count(*), count(*) FILTER (WHERE checked = true)
  INTO v_total, v_checked
  FROM public."DeliveryNoteLines"
  WHERE delivery_note_id = p_delivery_note_id;

  IF v_total = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No lines in delivery note');
  END IF;

  IF v_checked = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No lines checked for delivery');
  END IF;

  -- Determine delivery note status
  v_new_dn_status := CASE WHEN v_checked >= v_total THEN 'completed' ELSE 'partial' END;

  UPDATE public."DeliveryNotes"
  SET status = v_new_dn_status,
      completed_at = CASE WHEN v_new_dn_status = 'completed' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_delivery_note_id;

  -- Update MOLines that were checked
  UPDATE public."ManufacturingOrderLines" mol
  SET delivery_status = 'delivered',
      delivered_at = now(),
      delivered_qty = mol.quantity,
      updated_at = now()
  FROM public."DeliveryNoteLines" dnl
  WHERE dnl.delivery_note_id = p_delivery_note_id
    AND dnl.mo_line_id = mol.id
    AND dnl.checked = true;

  -- Check if ALL MOLines for this MO are now delivered
  SELECT NOT EXISTS (
    SELECT 1 FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = v_mo_id
      AND deleted = false
      AND delivery_status <> 'delivered'
  ) INTO v_all_mol_delivered;

  IF v_all_mol_delivered THEN
    UPDATE public."ManufacturingOrders"
    SET status = 'delivered', delivered_at = now(), updated_at = now()
    WHERE id = v_mo_id AND status <> 'delivered';

    -- Check if ALL MOs for the SO are delivered
    SELECT sales_order_id INTO v_so_id
    FROM public."ManufacturingOrders" WHERE id = v_mo_id;

    IF v_so_id IS NOT NULL THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM public."ManufacturingOrders"
        WHERE sales_order_id = v_so_id
          AND deleted = false
          AND status <> 'delivered'
          AND status <> 'cancelled'
      ) INTO v_all_mo_delivered;

      IF v_all_mo_delivered THEN
        UPDATE public."SalesOrders"
        SET status = 'fulfilled', updated_at = now()
        WHERE id = v_so_id AND status <> 'fulfilled';
      END IF;
    END IF;
  END IF;

  -- Record timeline entry for the delivery
  INSERT INTO public."ActivityTimeline" (
    entity_type, entity_id, action, description, user_name, organization_id
  ) VALUES (
    'manufacturing_order', v_mo_id,
    CASE WHEN v_new_dn_status = 'completed' THEN 'delivery_completed' ELSE 'delivery_partial' END,
    format('%s: %s/%s lines delivered%s',
      v_dn.delivery_number, v_checked, v_total,
      CASE WHEN v_dn.received_by_name IS NOT NULL
        THEN format(' — received by %s', v_dn.received_by_name) ELSE '' END
    ),
    COALESCE(v_dn.delivered_by_name, 'System'),
    v_org_id
  );

  -- Timeline for MO delivered (all lines done)
  IF v_all_mol_delivered THEN
    INSERT INTO public."ActivityTimeline" (
      entity_type, entity_id, action, description, user_name, organization_id
    ) VALUES (
      'manufacturing_order', v_mo_id,
      'status_change',
      'Manufacturing order marked as Delivered — all lines delivered',
      COALESCE(v_dn.delivered_by_name, 'System'),
      v_org_id
    );
  END IF;

  -- Timeline for SO fulfilled
  IF v_all_mo_delivered AND v_so_id IS NOT NULL THEN
    INSERT INTO public."ActivityTimeline" (
      entity_type, entity_id, action, description, user_name, organization_id
    ) VALUES (
      'sales_order', v_so_id,
      'status_change',
      'Sales order fulfilled — all manufacturing orders delivered',
      'System (auto)',
      v_org_id
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'delivery_note_status', v_new_dn_status,
    'checked_count', v_checked,
    'total_count', v_total,
    'mo_delivered', v_all_mol_delivered
  );
END;
$fn$;

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
