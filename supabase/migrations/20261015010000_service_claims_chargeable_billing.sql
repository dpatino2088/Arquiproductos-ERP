-- ============================================================================
-- Service Claims: Chargeable billing flag + claim invoice support
-- 
-- Warranty claims (default): skip delivery gate on service MOs
-- Chargeable claims: generate DealerInvoice linked to claim, enforce payment
-- ============================================================================

SET search_path = public;

-- 1) Add chargeable flag to ServiceClaims
ALTER TABLE public."ServiceClaims"
  ADD COLUMN IF NOT EXISTS chargeable boolean NOT NULL DEFAULT false;

-- 2) Add claim_id FK to DealerInvoices
ALTER TABLE public."DealerInvoices"
  ADD COLUMN IF NOT EXISTS claim_id uuid REFERENCES public."ServiceClaims"(id);

CREATE INDEX IF NOT EXISTS idx_dealer_invoices_claim_id
  ON public."DealerInvoices"(claim_id) WHERE claim_id IS NOT NULL;

-- 3) Update transition_mo_status to handle service MO delivery gate
CREATE OR REPLACE FUNCTION public.transition_mo_status(
  p_mo_id uuid,
  p_new_status text,
  p_user_id uuid,
  p_user_name text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_mo record;
  v_from text;
  v_to text;
  v_allowed text[];
  v_readiness jsonb;
  v_has_shortage boolean;
  v_gate record;
  v_actor_name text;
  v_use_delivery_override boolean := false;
  v_active_override_id uuid := NULL;
  v_unallocated_count int;
  v_claim_chargeable boolean;
  v_claim_invoice_paid boolean;
BEGIN
  SELECT * INTO v_mo
  FROM "ManufacturingOrders"
  WHERE id = p_mo_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  v_from := COALESCE(v_mo.status::text, 'draft');
  v_to := lower(trim(p_new_status));
  v_actor_name := COALESCE(NULLIF(trim(p_user_name), ''), 'System');

  IF v_to = 'planned' THEN
    v_to := 'confirmed';
  END IF;

  v_allowed := CASE v_from
    WHEN 'draft' THEN ARRAY['confirmed', 'cancelled']
    WHEN 'confirmed' THEN ARRAY['procurement', 'materials_ready', 'cancelled', 'draft']
    WHEN 'procurement' THEN ARRAY['materials_ready', 'cancelled', 'confirmed']
    WHEN 'materials_ready' THEN ARRAY['in_production', 'cancelled']
    WHEN 'planned' THEN ARRAY['in_production', 'materials_ready', 'confirmed', 'cancelled']
    WHEN 'in_production' THEN ARRAY['quality_check', 'cancelled']
    WHEN 'quality_check' THEN ARRAY['ready_for_pickup']
    WHEN 'ready_for_pickup' THEN ARRAY['delivered']
    WHEN 'delivered' THEN ARRAY['completed']
    WHEN 'completed' THEN ARRAY[]::text[]
    WHEN 'cancelled' THEN ARRAY['draft']
    ELSE ARRAY[]::text[]
  END;

  IF NOT (v_to = ANY(v_allowed)) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('Invalid transition: %s -> %s. Allowed: %s', v_from, v_to, array_to_string(v_allowed, ', ')),
      'from', v_from,
      'to', v_to
    );
  END IF;

  IF v_to = 'materials_ready' THEN
    SELECT COUNT(*) INTO v_unallocated_count
    FROM manufacturing_order_material_demand md
    LEFT JOIN (
      SELECT catalog_item_id, SUM(allocated_qty) AS total_alloc
      FROM "InventoryAllocations"
      WHERE manufacturing_order_id = p_mo_id AND status = 'reserved'
      GROUP BY catalog_item_id
    ) ia ON ia.catalog_item_id = md.catalog_item_id
    WHERE md.manufacturing_order_id = p_mo_id
      AND COALESCE(ia.total_alloc, 0) < md.required_qty - 0.0001;

    IF v_unallocated_count > 0 THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', format('%s material(s) not fully allocated. Allocate all before marking material ready.', v_unallocated_count),
        'from', v_from,
        'to', v_to
      );
    END IF;
  END IF;

  IF v_to = 'in_production' THEN
    v_readiness := public.get_mo_material_readiness(p_mo_id);
    v_has_shortage := COALESCE((v_readiness->>'has_shortage')::boolean, false);
    IF v_has_shortage THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Materials incomplete. All materials must be on hand or on order before starting production.',
        'from', v_from,
        'to', v_to,
        'material_readiness', v_readiness
      );
    END IF;
  END IF;

  -- Delivery gate: differentiate service MOs from regular MOs
  IF v_to = 'delivered' THEN
    IF v_mo.claim_id IS NOT NULL THEN
      -- Service MO: check claim chargeable flag
      SELECT COALESCE(sc.chargeable, false) INTO v_claim_chargeable
      FROM "ServiceClaims" sc
      WHERE sc.id = v_mo.claim_id AND sc.deleted = false;

      IF v_claim_chargeable THEN
        -- Chargeable claim: check if claim invoice is paid
        SELECT EXISTS (
          SELECT 1 FROM "DealerInvoices" di
          WHERE di.claim_id = v_mo.claim_id
            AND di.deleted = false
            AND di.status <> 'void'
            AND di.status IN ('paid')
        ) INTO v_claim_invoice_paid;

        IF NOT v_claim_invoice_paid THEN
          RETURN jsonb_build_object(
            'ok', false,
            'error', 'Delivery blocked: claim invoice is not fully paid.',
            'from', v_from,
            'to', v_to
          );
        END IF;
      END IF;
      -- Warranty (chargeable=false): no payment check, delivery allowed
    ELSIF v_mo.sales_order_id IS NOT NULL THEN
      -- Regular MO: existing SO delivery gate
      SELECT * INTO v_gate
      FROM public.get_sales_order_delivery_gate(v_mo.sales_order_id);

      IF NOT COALESCE(v_gate.delivery_allowed, false) THEN
        RETURN jsonb_build_object(
          'ok', false,
          'error', format('Delivery blocked: balance due is $%s.', to_char(COALESCE(v_gate.balance_due, 0), 'FM999999990.00')),
          'from', v_from,
          'to', v_to,
          'balance_due', COALESCE(v_gate.balance_due, 0)
        );
      END IF;

      v_use_delivery_override := COALESCE(v_gate.payment_complete, false) = false
        AND v_gate.active_override_id IS NOT NULL;
      v_active_override_id := v_gate.active_override_id;
    END IF;
  END IF;

  UPDATE "ManufacturingOrders"
  SET status = v_to::manufacturing_order_status,
      updated_at = now(),
      production_started_at = CASE
        WHEN v_to = 'in_production' AND production_started_at IS NULL THEN now()
        ELSE production_started_at
      END,
      completed_at = CASE
        WHEN v_to IN ('delivered', 'completed') AND completed_at IS NULL THEN now()
        ELSE completed_at
      END,
      delivered_at = CASE
        WHEN v_to = 'delivered' AND delivered_at IS NULL THEN now()
        ELSE delivered_at
      END
  WHERE id = p_mo_id
    AND deleted = false;

  INSERT INTO public."ActivityTimeline" (
    organization_id,
    entity_type,
    entity_id,
    action,
    description,
    user_id,
    user_name,
    metadata
  ) VALUES (
    v_mo.organization_id,
    'manufacturing_order',
    p_mo_id,
    'status_changed',
    format('MO status changed: %s -> %s', replace(v_from, '_', ' '), replace(v_to, '_', ' ')),
    p_user_id,
    v_actor_name,
    jsonb_build_object('from', v_from, 'to', v_to, 'source', 'transition_mo_status')
  );

  IF v_use_delivery_override AND v_active_override_id IS NOT NULL THEN
    UPDATE public."SalesOrderDeliveryOverrides"
    SET status = 'used',
        used_by = p_user_id,
        used_by_name = v_actor_name,
        used_source = 'mo_transition',
        used_at = now(),
        updated_at = now()
    WHERE id = v_active_override_id
      AND status = 'active'
      AND deleted = false;
  END IF;

  RETURN jsonb_build_object('ok', true, 'from', v_from, 'to', v_to);
END;
$function$;

-- 4) RPC to create a claim invoice from BOM materials
CREATE OR REPLACE FUNCTION public.create_claim_invoice(p_claim_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_claim record;
  v_mo record;
  v_invoice_id uuid;
  v_invoice_no text;
  v_subtotal numeric(12,2) := 0;
  v_tax_pct numeric(7,4) := 7.0;
  v_tax_total numeric(12,2) := 0;
  v_total numeric(12,2) := 0;
  v_line record;
  v_sort int := 0;
  v_line_count int := 0;
BEGIN
  SELECT * INTO v_claim
  FROM "ServiceClaims"
  WHERE id = p_claim_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Claim not found');
  END IF;

  IF NOT v_claim.chargeable THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Claim is not marked as chargeable');
  END IF;

  IF EXISTS (
    SELECT 1 FROM "DealerInvoices"
    WHERE claim_id = p_claim_id AND deleted = false AND status <> 'void'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invoice already exists for this claim');
  END IF;

  SELECT * INTO v_mo
  FROM "ManufacturingOrders"
  WHERE claim_id = p_claim_id AND deleted = false
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No manufacturing order found for this claim');
  END IF;

  -- Generate invoice number: SVC-INV-NNNNN
  SELECT 'SVC-INV-' || LPAD((COALESCE(MAX(
    CASE WHEN invoice_number ~ '^SVC-INV-\d+$'
         THEN CAST(SUBSTRING(invoice_number FROM 'SVC-INV-(\d+)') AS integer)
         ELSE 0 END
  ), 0) + 1)::text, 5, '0')
  INTO v_invoice_no
  FROM "DealerInvoices"
  WHERE organization_id = v_claim.organization_id;

  -- Calculate subtotal from non-excluded BOM lines
  FOR v_line IN
    SELECT
      ci.sku,
      ci.name AS item_name,
      bil.part_role,
      SUM(bil.qty) AS total_qty,
      bil.uom,
      COALESCE(MAX(bil.unit_cost_exw), 0) AS unit_cost
    FROM "BOMInstanceLines" bil
    JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
    LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
    WHERE bi.manufacturing_order_id = v_mo.id
      AND bi.deleted = false
      AND bil.deleted = false
      AND bil.excluded = false
      AND bil.resolved_part_id IS NOT NULL
    GROUP BY ci.sku, ci.name, bil.part_role, bil.uom
    ORDER BY ci.sku
  LOOP
    v_subtotal := v_subtotal + ROUND(v_line.total_qty * v_line.unit_cost, 2);
    v_line_count := v_line_count + 1;
  END LOOP;

  IF v_line_count = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No materials to invoice (all excluded or empty BOM)');
  END IF;

  v_tax_total := ROUND(v_subtotal * v_tax_pct / 100, 2);
  v_total := v_subtotal + v_tax_total;

  INSERT INTO "DealerInvoices" (
    organization_id, dealer_id, sales_order_id, claim_id,
    invoice_number, status, issue_date, currency_code,
    subtotal, tax_total, total, notes
  ) VALUES (
    v_claim.organization_id,
    v_claim.dealer_id,
    v_claim.sales_order_id,
    p_claim_id,
    v_invoice_no,
    'draft',
    CURRENT_DATE,
    'USD',
    v_subtotal,
    v_tax_total,
    v_total,
    'Service claim invoice for ' || v_claim.claim_no
  ) RETURNING id INTO v_invoice_id;

  -- Insert invoice lines
  v_sort := 0;
  FOR v_line IN
    SELECT
      ci.sku,
      ci.name AS item_name,
      bil.part_role,
      SUM(bil.qty) AS total_qty,
      bil.uom,
      COALESCE(MAX(bil.unit_cost_exw), 0) AS unit_cost
    FROM "BOMInstanceLines" bil
    JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
    LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
    WHERE bi.manufacturing_order_id = v_mo.id
      AND bi.deleted = false
      AND bil.deleted = false
      AND bil.excluded = false
      AND bil.resolved_part_id IS NOT NULL
    GROUP BY ci.sku, ci.name, bil.part_role, bil.uom
    ORDER BY ci.sku
  LOOP
    v_sort := v_sort + 1;
    INSERT INTO "DealerInvoiceLines" (
      invoice_id, sort_order, description,
      qty, unit_price, tax_pct,
      line_subtotal, line_tax, line_total
    ) VALUES (
      v_invoice_id,
      v_sort,
      COALESCE(v_line.sku, '') || ' - ' || COALESCE(v_line.item_name, 'Material'),
      v_line.total_qty,
      v_line.unit_cost,
      v_tax_pct,
      ROUND(v_line.total_qty * v_line.unit_cost, 2),
      ROUND(v_line.total_qty * v_line.unit_cost * v_tax_pct / 100, 2),
      ROUND(v_line.total_qty * v_line.unit_cost * (1 + v_tax_pct / 100), 2)
    );
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'invoice_id', v_invoice_id,
    'invoice_number', v_invoice_no,
    'subtotal', v_subtotal,
    'tax_total', v_tax_total,
    'total', v_total,
    'line_count', v_line_count
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_claim_invoice(uuid) TO authenticated;
