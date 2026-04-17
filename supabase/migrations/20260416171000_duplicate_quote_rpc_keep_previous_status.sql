-- Keep previous quote status unchanged when creating a new version.
-- This migration redefines duplicate_quote removing the status mutation on source quote.

CREATE OR REPLACE FUNCTION public.duplicate_quote(
  p_quote_id uuid,
  p_mode text DEFAULT 'copy',
  p_recalculate boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $function$
DECLARE
  v_source public."Quotes"%ROWTYPE;
  v_user_id uuid;
  v_new_id uuid;
  v_new_quote_no text;
  v_new_version int;
  v_root_id uuid;
  v_base_quote_no text;
  v_max_num int;
  v_cp record;
  v_new_cp_id uuid;
  v_ql record;
  v_new_ql_id uuid;
  v_mapped_cp_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_mode NOT IN ('copy','version') THEN
    RAISE EXCEPTION 'Invalid mode %: must be copy or version', p_mode;
  END IF;

  SELECT * INTO v_source
  FROM public."Quotes"
  WHERE id = p_quote_id AND deleted IS NOT TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quote not found or not accessible';
  END IF;

  IF NOT (
    v_source.created_by_user_id = v_user_id
    OR (public.session_is_org_user(v_source.organization_id) AND public.can_read_sales_org(v_source.organization_id))
    OR (v_source.dealer_id IS NOT NULL AND public.is_dealer_portal_user(v_source.dealer_id))
  ) THEN
    RAISE EXCEPTION 'Not authorized to duplicate this quote';
  END IF;

  IF p_mode = 'version' AND v_source.status = 'converted' THEN
    RAISE EXCEPTION 'Cannot create a new version of a quote already converted to a sales order';
  END IF;

  IF p_mode = 'version' THEN
    v_root_id := COALESCE(v_source.root_quote_id, v_source.id);

    SELECT COALESCE(MAX(version_no), 0) + 1
    INTO v_new_version
    FROM public."Quotes"
    WHERE deleted IS NOT TRUE
      AND (id = v_root_id OR root_quote_id = v_root_id);

    SELECT regexp_replace(COALESCE(quote_no, ''), '_V\d+$', '')
    INTO v_base_quote_no
    FROM public."Quotes" WHERE id = v_root_id;

    IF v_base_quote_no IS NULL OR v_base_quote_no = '' THEN
      v_base_quote_no := 'QT-' || LPAD(((EXTRACT(EPOCH FROM now()))::bigint % 100000)::text, 5, '0');
    END IF;

    v_new_quote_no := v_base_quote_no || '_V' || v_new_version::text;
  ELSE
    SELECT COALESCE(MAX(
      CASE WHEN quote_no ~ '^QT-\d{5}$' THEN (substring(quote_no from 4))::int ELSE 0 END
    ), 99) + 1
    INTO v_max_num
    FROM public."Quotes"
    WHERE organization_id = v_source.organization_id AND deleted IS NOT TRUE;

    v_new_quote_no := 'QT-' || LPAD(GREATEST(100, v_max_num)::text, 5, '0');
    v_new_version := 1;
    v_root_id := NULL;
  END IF;

  INSERT INTO public."Quotes" (
    organization_id, dealer_id, quote_no, status,
    customer_id, contact_id, created_by_user_id, currency,
    description, po_number, exempt_tax,
    terms_title, terms_content, terms_source_template_id,
    notes, priority, subtotal, tax_amount, total_amount,
    expires_at, internal_notes, project_address,
    parent_quote_id, root_quote_id, version_no, is_version
  )
  VALUES (
    v_source.organization_id, v_source.dealer_id, v_new_quote_no, 'draft'::quote_status,
    v_source.customer_id, v_source.contact_id, v_user_id, v_source.currency,
    v_source.description, v_source.po_number, v_source.exempt_tax,
    v_source.terms_title, v_source.terms_content, v_source.terms_source_template_id,
    v_source.notes, v_source.priority, v_source.subtotal, v_source.tax_amount, v_source.total_amount,
    v_source.expires_at, v_source.internal_notes, v_source.project_address,
    CASE WHEN p_mode = 'version' THEN v_source.id ELSE NULL END,
    CASE WHEN p_mode = 'version' THEN v_root_id ELSE NULL END,
    v_new_version,
    (p_mode = 'version')
  )
  RETURNING id INTO v_new_id;

  IF p_mode = 'copy' THEN
    UPDATE public."Quotes" SET root_quote_id = v_new_id WHERE id = v_new_id;
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS tmp_cp_map (old_id uuid PRIMARY KEY, new_id uuid NOT NULL) ON COMMIT DROP;
  TRUNCATE TABLE tmp_cp_map;

  FOR v_cp IN
    SELECT * FROM public."ConfiguredProducts"
    WHERE quote_id = p_quote_id AND COALESCE(deleted, false) = false
  LOOP
    INSERT INTO public."ConfiguredProducts" (
      organization_id, quote_id, bom_template_id, product_type_id,
      width_mm, height_mm, quantity, hardware_color, bom_total, labor_pct,
      accessories_total, total_msrp, config_snapshot,
      roll_catalog_item_id, roll_sku, roll_collection_name, roll_variant_name,
      roll_width, roll_msrp_total, labor_amount, bom_preview_snapshot,
      msrp_product_subtotal, roll_total_cost, bom_total_cost, labor_msrp,
      unit_labor_cost, unit_msrp_total, unit_product_cost,
      accessories_total_cost, total_cost, dimension_outputs
    ) VALUES (
      v_cp.organization_id, v_new_id, v_cp.bom_template_id, v_cp.product_type_id,
      v_cp.width_mm, v_cp.height_mm, v_cp.quantity, v_cp.hardware_color, v_cp.bom_total, v_cp.labor_pct,
      v_cp.accessories_total, v_cp.total_msrp, v_cp.config_snapshot,
      v_cp.roll_catalog_item_id, v_cp.roll_sku, v_cp.roll_collection_name, v_cp.roll_variant_name,
      v_cp.roll_width, v_cp.roll_msrp_total, v_cp.labor_amount, v_cp.bom_preview_snapshot,
      v_cp.msrp_product_subtotal, v_cp.roll_total_cost, v_cp.bom_total_cost, v_cp.labor_msrp,
      v_cp.unit_labor_cost, v_cp.unit_msrp_total, v_cp.unit_product_cost,
      v_cp.accessories_total_cost, v_cp.total_cost, v_cp.dimension_outputs
    ) RETURNING id INTO v_new_cp_id;

    INSERT INTO tmp_cp_map(old_id, new_id) VALUES (v_cp.id, v_new_cp_id);
  END LOOP;

  CREATE TEMP TABLE IF NOT EXISTS tmp_ql_map (old_id uuid PRIMARY KEY, new_id uuid NOT NULL) ON COMMIT DROP;
  TRUNCATE TABLE tmp_ql_map;

  FOR v_ql IN
    SELECT * FROM public."QuoteLines"
    WHERE quote_id = p_quote_id
    ORDER BY sort_order NULLS LAST, created_at
  LOOP
    v_mapped_cp_id := NULL;
    IF v_ql.configured_product_id IS NOT NULL THEN
      SELECT new_id INTO v_mapped_cp_id FROM tmp_cp_map WHERE old_id = v_ql.configured_product_id;
    END IF;

    INSERT INTO public."QuoteLines" (
      organization_id, dealer_id, quote_id, catalog_item_id, category_id, sku, name,
      manufacturer_id, manufacturer, quantity, width_m, height_m, is_roll, roll_type,
      collection_name, variant_name, roll_width_m, msrp, pricing_version, pricing_locked,
      last_priced_at, product_type, area, position, hardware_color, cassette,
      side_channel, drive_type, bom_template_id, roll_cost_snapshot, bom_cost_snapshot,
      roll_msrp_snapshot, bom_msrp_snapshot, configured_product_id, product_type_id,
      fabric_drop, installation_type, installation_location, sort_order, metadata,
      unit_msrp_product_subtotal, accessories_msrp_snapshot, labor_msrp_snapshot,
      accessories_cost_snapshot, labor_cost_snapshot, unit_msrp_total_snapshot,
      unit_cost_total_snapshot, total_cost, unit_dealer_price_snapshot,
      dealer_price_total, dealer_discount_pct, dealer_tier_id_snapshot,
      dealer_tier_code_snapshot, catalog_dealer_unit_snapshot, dealer_price_source,
      unit_msrp, net_price, config_snapshot
    ) VALUES (
      v_ql.organization_id, v_ql.dealer_id, v_new_id, v_ql.catalog_item_id, v_ql.category_id, v_ql.sku, v_ql.name,
      v_ql.manufacturer_id, v_ql.manufacturer, v_ql.quantity, v_ql.width_m, v_ql.height_m, v_ql.is_roll, v_ql.roll_type,
      v_ql.collection_name, v_ql.variant_name, v_ql.roll_width_m, v_ql.msrp, v_ql.pricing_version,
      CASE WHEN p_recalculate THEN false ELSE v_ql.pricing_locked END,
      CASE WHEN p_recalculate THEN NULL ELSE v_ql.last_priced_at END,
      v_ql.product_type, v_ql.area, v_ql.position, v_ql.hardware_color, v_ql.cassette,
      v_ql.side_channel, v_ql.drive_type, v_ql.bom_template_id, v_ql.roll_cost_snapshot, v_ql.bom_cost_snapshot,
      v_ql.roll_msrp_snapshot, v_ql.bom_msrp_snapshot, v_mapped_cp_id, v_ql.product_type_id,
      v_ql.fabric_drop, v_ql.installation_type, v_ql.installation_location, v_ql.sort_order, v_ql.metadata,
      v_ql.unit_msrp_product_subtotal, v_ql.accessories_msrp_snapshot, v_ql.labor_msrp_snapshot,
      v_ql.accessories_cost_snapshot, v_ql.labor_cost_snapshot, v_ql.unit_msrp_total_snapshot,
      v_ql.unit_cost_total_snapshot, v_ql.total_cost, v_ql.unit_dealer_price_snapshot,
      v_ql.dealer_price_total, v_ql.dealer_discount_pct, v_ql.dealer_tier_id_snapshot,
      v_ql.dealer_tier_code_snapshot, v_ql.catalog_dealer_unit_snapshot, v_ql.dealer_price_source,
      v_ql.unit_msrp, v_ql.net_price, v_ql.config_snapshot
    ) RETURNING id INTO v_new_ql_id;

    INSERT INTO tmp_ql_map(old_id, new_id) VALUES (v_ql.id, v_new_ql_id);
  END LOOP;

  INSERT INTO public."QuoteLineComponents" (
    organization_id, quote_line_id, component_role, kind, source, catalog_item_id,
    qty, unit_cost_exw, payload, deleted, archived
  )
  SELECT
    qlc.organization_id, m.new_id, qlc.component_role, qlc.kind, qlc.source, qlc.catalog_item_id,
    qlc.qty, qlc.unit_cost_exw, qlc.payload, false, false
  FROM public."QuoteLineComponents" qlc
  JOIN tmp_ql_map m ON m.old_id = qlc.quote_line_id
  WHERE COALESCE(qlc.deleted, false) = false;

  RETURN v_new_id;
END;
$function$;

COMMENT ON FUNCTION public.duplicate_quote(uuid, text, boolean) IS
  'Duplicate a Quote. mode=copy -> brand new QT number. mode=version -> appends _V2, _V3, ... and links parent_quote_id/root_quote_id. Keeps source quote status unchanged. When p_recalculate=true, cloned lines are marked with pricing_locked=false and last_priced_at=NULL.';
