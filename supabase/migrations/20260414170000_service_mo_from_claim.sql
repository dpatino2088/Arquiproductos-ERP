-- ============================================================
-- Service MO from Claim
-- Relaxes the 1:1 SO→MO unique index to allow service MOs,
-- and creates an RPC to generate rework/replacement MOs from claims.
-- ============================================================

-- 1. Relax the unique index: only enforce 1 active PRIMARY MO per SO
DROP INDEX IF EXISTS uq_one_active_mo_per_so;
CREATE UNIQUE INDEX uq_one_active_mo_per_so
  ON public."ManufacturingOrders" (sales_order_id)
  WHERE deleted = false AND status != 'cancelled' AND mo_type = 'primary';

-- 2. Add claim_id reference to ManufacturingOrders for traceability
ALTER TABLE public."ManufacturingOrders"
  ADD COLUMN IF NOT EXISTS claim_id uuid REFERENCES public."ServiceClaims"(id);

CREATE INDEX IF NOT EXISTS idx_mo_claim_id ON public."ManufacturingOrders"(claim_id) WHERE claim_id IS NOT NULL;

-- 3. RPC: create_service_mo
CREATE OR REPLACE FUNCTION public.create_service_mo(
  p_claim_id uuid,
  p_mo_type  text,       -- 'rework' or 'replacement'
  p_user_id  uuid,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_claim        record;
  v_so           record;
  v_original_mo  record;
  v_mo_id        uuid;
  v_mo_number    text;
  v_bom_result   jsonb;
  v_bom_ok       boolean;
  v_bom_errors   text[];
  v_sol_ids      uuid[];
  v_product_name text;
  v_total_qty    int;
  v_line_count   int := 0;
BEGIN
  IF p_mo_type NOT IN ('rework', 'replacement') THEN
    RAISE EXCEPTION 'mo_type must be rework or replacement, got: %', p_mo_type;
  END IF;

  SELECT * INTO v_claim
  FROM public."ServiceClaims"
  WHERE id = p_claim_id AND deleted = false;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Claim not found';
  END IF;

  IF v_claim.sales_order_id IS NULL THEN
    RAISE EXCEPTION 'Claim has no linked Sales Order';
  END IF;

  IF v_claim.resolution_mo_id IS NOT NULL THEN
    RAISE EXCEPTION 'Claim already has a resolution MO assigned';
  END IF;

  SELECT * INTO v_so
  FROM public."SalesOrders"
  WHERE id = v_claim.sales_order_id AND deleted = false;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sales Order not found';
  END IF;

  -- Find the original primary MO (for parent_mo_id linkage)
  SELECT id INTO v_original_mo
  FROM public."ManufacturingOrders"
  WHERE sales_order_id = v_claim.sales_order_id
    AND deleted = false
    AND mo_type = 'primary'
  ORDER BY created_at ASC
  LIMIT 1;

  -- Collect the affected SOL ids from claim lines
  SELECT ARRAY_AGG(DISTINCT scl.sale_order_line_id)
  INTO v_sol_ids
  FROM public."ServiceClaimLines" scl
  WHERE scl.claim_id = p_claim_id
    AND scl.deleted = false
    AND scl.sale_order_line_id IS NOT NULL;

  IF v_sol_ids IS NULL OR array_length(v_sol_ids, 1) = 0 THEN
    RAISE EXCEPTION 'No affected product lines found in this claim';
  END IF;

  -- Get a product name and total qty for the MO header
  SELECT COALESCE(sol.description, sol.collection_name, 'Service Product'),
         COALESCE(SUM(scl.qty_affected)::int, 1)
  INTO v_product_name, v_total_qty
  FROM public."ServiceClaimLines" scl
  JOIN public."SaleOrderLines" sol ON sol.id = scl.sale_order_line_id
  WHERE scl.claim_id = p_claim_id
    AND scl.deleted = false
    AND scl.sale_order_line_id IS NOT NULL
  GROUP BY sol.description, sol.collection_name
  LIMIT 1;

  -- Create the service MO
  INSERT INTO public."ManufacturingOrders" (
    organization_id,
    sales_order_id,
    sales_order_line_id,
    status,
    mo_type,
    priority,
    dealer_id,
    product_name,
    quantity,
    created_by,
    parent_mo_id,
    claim_id,
    notes
  ) VALUES (
    v_so.organization_id,
    v_claim.sales_order_id,
    NULL,
    'draft',
    p_mo_type,
    COALESCE(v_so.priority, 'normal'),
    v_so.dealer_id,
    v_product_name,
    v_total_qty,
    p_user_id,
    v_original_mo.id,
    p_claim_id,
    'Service ' || INITCAP(p_mo_type) || ' — Claim ' || COALESCE(v_claim.claim_no, v_claim.id::text)
  )
  RETURNING id, manufacturing_order_no
  INTO v_mo_id, v_mo_number;

  -- Create MO Lines only for the affected SOLs
  INSERT INTO public."ManufacturingOrderLines" (
    manufacturing_order_id,
    sales_order_line_id,
    organization_id,
    status
  )
  SELECT v_mo_id, sol_id, v_so.organization_id, 'draft'
  FROM unnest(v_sol_ids) AS sol_id
  WHERE NOT EXISTS (
    SELECT 1 FROM public."ManufacturingOrderLines" mol
    WHERE mol.manufacturing_order_id = v_mo_id
      AND mol.sales_order_line_id = sol_id
  );
  GET DIAGNOSTICS v_line_count = ROW_COUNT;

  -- Generate BOM from the configured product snapshots
  SELECT public.generate_bom_for_manufacturing_order(v_mo_id) INTO v_bom_result;

  v_bom_ok := COALESCE((v_bom_result ->> 'ok')::boolean, false);
  IF jsonb_typeof(v_bom_result -> 'errors') = 'array' THEN
    SELECT COALESCE(array_agg(value), ARRAY[]::text[])
    INTO v_bom_errors
    FROM jsonb_array_elements_text(v_bom_result -> 'errors');
  ELSE
    v_bom_errors := ARRAY[]::text[];
  END IF;

  IF v_bom_ok = false OR COALESCE(array_length(v_bom_errors, 1), 0) > 0 THEN
    RAISE EXCEPTION 'Failed to generate BOM for Service MO %: %',
      v_mo_number,
      COALESCE(array_to_string(v_bom_errors, '; '), 'unknown error');
  END IF;

  -- Link the MO back to the claim
  UPDATE public."ServiceClaims"
  SET resolution_mo_id = v_mo_id,
      resolution_type  = CASE WHEN p_mo_type = 'rework' THEN 'repair' ELSE 'replace' END::claim_resolution_enum,
      updated_at = now()
  WHERE id = p_claim_id;

  -- Timeline entries
  PERFORM _insert_timeline(
    v_so.organization_id,
    'manufacturing_order',
    v_mo_id,
    'created',
    'Service ' || INITCAP(p_mo_type) || ' MO created from Claim ' || COALESCE(v_claim.claim_no, ''),
    p_user_id,
    p_user_name,
    jsonb_build_object(
      'claim_id', p_claim_id,
      'claim_no', v_claim.claim_no,
      'so_id', v_claim.sales_order_id,
      'so_number', v_so.sales_order_no,
      'mo_type', p_mo_type
    )
  );

  PERFORM _insert_timeline(
    v_so.organization_id,
    'service_claim',
    p_claim_id,
    'mo_created',
    INITCAP(p_mo_type) || ' MO ' || v_mo_number || ' created',
    p_user_id,
    p_user_name,
    jsonb_build_object('mo_id', v_mo_id, 'mo_number', v_mo_number, 'mo_type', p_mo_type)
  );

  RETURN jsonb_build_object(
    'ok', true,
    'mo_id', v_mo_id,
    'mo_number', v_mo_number,
    'mo_type', p_mo_type,
    'lines_created', v_line_count,
    'bom', v_bom_result
  );
END;
$$;
