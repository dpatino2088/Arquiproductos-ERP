-- ============================================================================
-- Phase 1: Manufacturer + Product Line on BOMTemplates,
--          display_name/image_url on FabricRules,
--          product_line on FabricRules,
--          update save_bom_template_batch RPC,
--          fix style_code NULL in populate_bom_line_base_pricing_fields
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1A. BOMTemplates: add manufacturer and product_line columns
-- ---------------------------------------------------------------------------
ALTER TABLE "public"."BOMTemplates"
  ADD COLUMN IF NOT EXISTS "manufacturer" text,
  ADD COLUMN IF NOT EXISTS "product_line" text;

COMMENT ON COLUMN "public"."BOMTemplates"."manufacturer" IS 'System manufacturer (Coulisse, Lutron, Vertilux, etc.). NULL = template applies to all manufacturers.';
COMMENT ON COLUMN "public"."BOMTemplates"."product_line" IS 'Product line within manufacturer/product type (Ripple Fold, Wave, Pinch Pleat for Drapery). NULL = applies to all lines.';

-- ---------------------------------------------------------------------------
-- 1B. FabricRules: add display_name, image_url, product_line columns
-- ---------------------------------------------------------------------------
ALTER TABLE "public"."FabricRules"
  ADD COLUMN IF NOT EXISTS "display_name" text,
  ADD COLUMN IF NOT EXISTS "image_url" text,
  ADD COLUMN IF NOT EXISTS "product_line" text;

COMMENT ON COLUMN "public"."FabricRules"."display_name" IS 'Human-readable label shown in configurator cards (e.g. Wave 2.3, Ripple Fold 1 7/8)';
COMMENT ON COLUMN "public"."FabricRules"."image_url" IS 'Optional image URL for configurator card display';
COMMENT ON COLUMN "public"."FabricRules"."product_line" IS 'Groups style variants under a product line (e.g. wave, ripple_fold, pinch_pleat)';

-- Backfill display_name for existing drapery rules
UPDATE "public"."FabricRules"
SET display_name = CASE style_code
  WHEN 'wave_2.3' THEN 'Wave 2.3'
  WHEN 'wave_2.8' THEN 'Wave 2.8'
  WHEN 'pinch_pleat' THEN 'Pinch Pleat'
  ELSE style_code
END,
product_line = CASE
  WHEN style_code LIKE 'wave%' THEN 'wave'
  WHEN style_code LIKE 'ripple%' THEN 'ripple_fold'
  WHEN style_code = 'pinch_pleat' THEN 'pinch_pleat'
  ELSE NULL
END
WHERE style_code IS NOT NULL
  AND display_name IS NULL;

-- ---------------------------------------------------------------------------
-- 1C. Update save_bom_template_batch RPC to include manufacturer + product_line
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_bom_template_batch(
  p_organization_id uuid,
  p_template jsonb,
  p_components_upsert jsonb DEFAULT '[]'::jsonb,
  p_component_ids_delete uuid[] DEFAULT '{}'::uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_template_id uuid;
  v_is_new_template boolean := false;
  v_comp jsonb;
  v_comp_id uuid;
  v_temp_id text;
  v_parent_temp_id text;
  v_real_parent_id uuid;
  v_id_map jsonb := '{}'::jsonb;
  v_result_components jsonb;
  v_now timestamptz := now();
BEGIN
  v_template_id := (p_template ->> 'id')::uuid;

  IF v_template_id IS NOT NULL THEN
    UPDATE "BOMTemplates" SET
      product_type_id    = (p_template ->> 'product_type_id')::uuid,
      code               = p_template ->> 'code',
      name               = COALESCE(p_template ->> 'name', p_template ->> 'code'),
      description        = p_template ->> 'description',
      hardware_color     = p_template ->> 'hardware_color',
      panel_count_min    = COALESCE((p_template ->> 'panel_count_min')::int, 1),
      panel_count_max    = COALESCE((p_template ->> 'panel_count_max')::int, 1),
      drive_side         = p_template ->> 'drive_side',
      opening_direction  = p_template ->> 'opening_direction',
      manufacturer       = p_template ->> 'manufacturer',
      product_line       = p_template ->> 'product_line',
      metadata           = COALESCE((p_template -> 'metadata')::jsonb, '{}'::jsonb),
      is_active          = COALESCE((p_template ->> 'is_active')::boolean, true),
      updated_at         = v_now
    WHERE id = v_template_id
      AND organization_id = p_organization_id;
  ELSE
    v_is_new_template := true;
    INSERT INTO "BOMTemplates" (
      organization_id, product_type_id, code, name, description,
      hardware_color, panel_count_min, panel_count_max,
      drive_side, opening_direction,
      manufacturer, product_line,
      metadata, is_active, archived, created_at, updated_at
    ) VALUES (
      p_organization_id,
      (p_template ->> 'product_type_id')::uuid,
      p_template ->> 'code',
      COALESCE(p_template ->> 'name', p_template ->> 'code'),
      p_template ->> 'description',
      p_template ->> 'hardware_color',
      COALESCE((p_template ->> 'panel_count_min')::int, 1),
      COALESCE((p_template ->> 'panel_count_max')::int, 1),
      p_template ->> 'drive_side',
      p_template ->> 'opening_direction',
      p_template ->> 'manufacturer',
      p_template ->> 'product_line',
      COALESCE((p_template -> 'metadata')::jsonb, '{}'::jsonb),
      true, false, v_now, v_now
    )
    RETURNING id INTO v_template_id;
  END IF;

  -- 2. Soft-delete requested components
  IF array_length(p_component_ids_delete, 1) > 0 THEN
    UPDATE "BOMComponents"
    SET deleted = true, updated_at = v_now
    WHERE id = ANY(p_component_ids_delete)
      AND organization_id = p_organization_id
      AND bom_template_id = v_template_id;
  END IF;

  -- 3. Upsert components (parents first, then children)
  FOR v_comp IN SELECT jsonb_array_elements(p_components_upsert)
  LOOP
    v_temp_id := v_comp ->> 'temp_id';
    v_comp_id := CASE
      WHEN (v_comp ->> 'id') IS NOT NULL
        AND (v_comp ->> 'id') NOT LIKE 'temp-%'
      THEN (v_comp ->> 'id')::uuid
      ELSE NULL
    END;

    v_parent_temp_id := v_comp ->> 'parent_temp_id';
    IF v_parent_temp_id IS NOT NULL AND v_parent_temp_id != '' THEN
      CONTINUE;
    END IF;
    IF (v_comp ->> 'parent_component_id') IS NOT NULL
       AND (v_comp ->> 'parent_component_id') != ''
       AND (v_comp ->> 'parent_component_id') NOT LIKE 'temp-%' THEN
      CONTINUE;
    END IF;

    IF v_comp_id IS NOT NULL THEN
      UPDATE "BOMComponents" SET
        component_item_id   = (v_comp ->> 'component_item_id')::uuid,
        component_role      = COALESCE(v_comp ->> 'component_role', 'hardware'),
        qty_type            = COALESCE(v_comp ->> 'qty_type', 'fixed'),
        qty_value           = COALESCE((v_comp ->> 'qty_value')::numeric, 1),
        qty_delta_mm        = COALESCE((v_comp ->> 'qty_delta_mm')::numeric, 0),
        qty_spacing_mm      = (v_comp ->> 'qty_spacing_mm')::integer,
        qty_min             = (v_comp ->> 'qty_min')::numeric,
        uom                 = COALESCE(v_comp ->> 'uom', 'ea'),
        waste_pct           = COALESCE((v_comp ->> 'waste_pct')::numeric, 0),
        depends_on_role     = v_comp ->> 'depends_on_role',
        affects_role        = v_comp ->> 'affects_role',
        cut_axis            = v_comp ->> 'cut_axis',
        cut_delta_mm        = COALESCE((v_comp ->> 'cut_delta_mm')::numeric, 0),
        sort_order          = COALESCE((v_comp ->> 'sort_order')::int, 0),
        is_required         = COALESCE((v_comp ->> 'is_required')::boolean, false),
        auto_select         = false,
        parent_component_id = NULL,
        updated_at          = v_now
      WHERE id = v_comp_id
        AND organization_id = p_organization_id
        AND bom_template_id = v_template_id;
    ELSE
      INSERT INTO "BOMComponents" (
        organization_id, bom_template_id, parent_component_id,
        component_item_id, component_role, qty_type, qty_value,
        qty_delta_mm, qty_spacing_mm, qty_min,
        uom, waste_pct, depends_on_role, affects_role, cut_axis,
        cut_delta_mm, sort_order, is_required, auto_select,
        deleted, archived, created_at, updated_at
      ) VALUES (
        p_organization_id, v_template_id, NULL,
        (v_comp ->> 'component_item_id')::uuid,
        COALESCE(v_comp ->> 'component_role', 'hardware'),
        COALESCE(v_comp ->> 'qty_type', 'fixed'),
        COALESCE((v_comp ->> 'qty_value')::numeric, 1),
        COALESCE((v_comp ->> 'qty_delta_mm')::numeric, 0),
        (v_comp ->> 'qty_spacing_mm')::integer,
        (v_comp ->> 'qty_min')::numeric,
        COALESCE(v_comp ->> 'uom', 'ea'),
        COALESCE((v_comp ->> 'waste_pct')::numeric, 0),
        v_comp ->> 'depends_on_role',
        v_comp ->> 'affects_role',
        v_comp ->> 'cut_axis',
        COALESCE((v_comp ->> 'cut_delta_mm')::numeric, 0),
        COALESCE((v_comp ->> 'sort_order')::int, 0),
        COALESCE((v_comp ->> 'is_required')::boolean, false),
        false,
        false, false, v_now, v_now
      )
      RETURNING id INTO v_comp_id;
    END IF;

    IF v_temp_id IS NOT NULL AND v_temp_id != '' THEN
      v_id_map := v_id_map || jsonb_build_object(v_temp_id, v_comp_id::text);
    END IF;
  END LOOP;

  -- Second pass: children
  FOR v_comp IN SELECT jsonb_array_elements(p_components_upsert)
  LOOP
    v_temp_id := v_comp ->> 'temp_id';
    v_comp_id := CASE
      WHEN (v_comp ->> 'id') IS NOT NULL
        AND (v_comp ->> 'id') NOT LIKE 'temp-%'
      THEN (v_comp ->> 'id')::uuid
      ELSE NULL
    END;

    v_parent_temp_id := v_comp ->> 'parent_temp_id';
    v_real_parent_id := NULL;

    IF v_parent_temp_id IS NOT NULL AND v_parent_temp_id != '' THEN
      v_real_parent_id := (v_id_map ->> v_parent_temp_id)::uuid;
      IF v_real_parent_id IS NULL THEN
        CONTINUE;
      END IF;
    ELSIF (v_comp ->> 'parent_component_id') IS NOT NULL
          AND (v_comp ->> 'parent_component_id') != ''
          AND (v_comp ->> 'parent_component_id') NOT LIKE 'temp-%' THEN
      v_real_parent_id := (v_comp ->> 'parent_component_id')::uuid;
    ELSE
      CONTINUE;
    END IF;

    IF v_comp_id IS NOT NULL THEN
      UPDATE "BOMComponents" SET
        parent_component_id = v_real_parent_id,
        component_item_id   = (v_comp ->> 'component_item_id')::uuid,
        component_role      = COALESCE(v_comp ->> 'component_role', 'hardware'),
        qty_type            = COALESCE(v_comp ->> 'qty_type', 'fixed'),
        qty_value           = COALESCE((v_comp ->> 'qty_value')::numeric, 1),
        qty_delta_mm        = COALESCE((v_comp ->> 'qty_delta_mm')::numeric, 0),
        qty_spacing_mm      = (v_comp ->> 'qty_spacing_mm')::integer,
        qty_min             = (v_comp ->> 'qty_min')::numeric,
        uom                 = COALESCE(v_comp ->> 'uom', 'ea'),
        waste_pct           = COALESCE((v_comp ->> 'waste_pct')::numeric, 0),
        depends_on_role     = v_comp ->> 'depends_on_role',
        affects_role        = v_comp ->> 'affects_role',
        cut_axis            = v_comp ->> 'cut_axis',
        cut_delta_mm        = COALESCE((v_comp ->> 'cut_delta_mm')::numeric, 0),
        sort_order          = COALESCE((v_comp ->> 'sort_order')::int, 0),
        is_required         = COALESCE((v_comp ->> 'is_required')::boolean, false),
        auto_select         = false,
        updated_at          = v_now
      WHERE id = v_comp_id
        AND organization_id = p_organization_id
        AND bom_template_id = v_template_id;
    ELSE
      INSERT INTO "BOMComponents" (
        organization_id, bom_template_id, parent_component_id,
        component_item_id, component_role, qty_type, qty_value,
        qty_delta_mm, qty_spacing_mm, qty_min,
        uom, waste_pct, depends_on_role, affects_role, cut_axis,
        cut_delta_mm, sort_order, is_required, auto_select,
        deleted, archived, created_at, updated_at
      ) VALUES (
        p_organization_id, v_template_id, v_real_parent_id,
        (v_comp ->> 'component_item_id')::uuid,
        COALESCE(v_comp ->> 'component_role', 'hardware'),
        COALESCE(v_comp ->> 'qty_type', 'fixed'),
        COALESCE((v_comp ->> 'qty_value')::numeric, 1),
        COALESCE((v_comp ->> 'qty_delta_mm')::numeric, 0),
        (v_comp ->> 'qty_spacing_mm')::integer,
        (v_comp ->> 'qty_min')::numeric,
        COALESCE(v_comp ->> 'uom', 'ea'),
        COALESCE((v_comp ->> 'waste_pct')::numeric, 0),
        v_comp ->> 'depends_on_role',
        v_comp ->> 'affects_role',
        v_comp ->> 'cut_axis',
        COALESCE((v_comp ->> 'cut_delta_mm')::numeric, 0),
        COALESCE((v_comp ->> 'sort_order')::int, 0),
        COALESCE((v_comp ->> 'is_required')::boolean, false),
        false,
        false, false, v_now, v_now
      )
      RETURNING id INTO v_comp_id;
    END IF;

    IF v_temp_id IS NOT NULL AND v_temp_id != '' THEN
      v_id_map := v_id_map || jsonb_build_object(v_temp_id, v_comp_id::text);
    END IF;
  END LOOP;

  -- 4. Fetch refreshed components
  SELECT jsonb_agg(row_to_json(c.*)::jsonb ORDER BY c.parent_component_id NULLS FIRST, c.sort_order, c.created_at)
  INTO v_result_components
  FROM "BOMComponents" c
  WHERE c.bom_template_id = v_template_id
    AND c.organization_id = p_organization_id
    AND c.deleted = false
    AND c.archived = false;

  RETURN jsonb_build_object(
    'template_id', v_template_id,
    'is_new', v_is_new_template,
    'id_map', v_id_map,
    'components', COALESCE(v_result_components, '[]'::jsonb)
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 1D. Fix populate_bom_line_base_pricing_fields: pass style_code from config_snapshot
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.populate_bom_line_base_pricing_fields(
    p_bom_instance_line_id uuid,
    p_catalog_item_id uuid,
    p_component_qty numeric,
    p_component_uom text,
    p_component_role text,
    p_organization_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_catalog_item RECORD;
    v_qty_base numeric;
    v_uom_base text;
    v_qty_pricing numeric;
    v_uom_pricing text;
    v_unit_cost_base numeric;
    v_unit_cost_pricing numeric;
    v_total_cost_base numeric;
    v_total_cost_pricing numeric;
    v_calc_notes text;
    v_pricing_result RECORD;
    v_rule_result RECORD;
    v_quote_line RECORD;
    v_msrp_rec RECORD;
    v_roll_width_m numeric;
    v_msrp_per_m numeric;
    v_style_code text;
    v_config_snapshot jsonb;
BEGIN
    SELECT ci.is_fabric, ci.roll_width_m, ci.fabric_pricing_mode::text, ci.measure_basis, ci.uom
    INTO v_catalog_item
    FROM "CatalogItems" ci
    WHERE ci.id = p_catalog_item_id
      AND ci.organization_id = p_organization_id
      AND ci.deleted = false;

    IF NOT FOUND THEN
        RAISE WARNING 'CatalogItem % not found for BOM line %', p_catalog_item_id, p_bom_instance_line_id;
        RETURN;
    END IF;

    IF v_catalog_item.is_fabric THEN
        v_uom_base := 'm2';
        IF UPPER(TRIM(COALESCE(p_component_uom, ''))) IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
            v_qty_base := p_component_qty;
        ELSIF UPPER(TRIM(COALESCE(p_component_uom, ''))) IN ('M', 'MTS', 'METER', 'METERS') THEN
            IF v_catalog_item.roll_width_m IS NOT NULL AND v_catalog_item.roll_width_m > 0 THEN
                v_qty_base := p_component_qty * v_catalog_item.roll_width_m;
            ELSE
                v_qty_base := p_component_qty;
                v_calc_notes := 'WARNING: No roll_width_m for fabric, cannot convert linear m to m2';
            END IF;
        ELSE
            v_qty_base := p_component_qty;
            v_calc_notes := 'WARNING: Unknown fabric UOM, using component qty as base';
        END IF;
    ELSE
        v_uom_base := public.normalize_uom_to_canonical(p_component_uom);
        v_qty_base := p_component_qty;
    END IF;

    IF v_catalog_item.is_fabric THEN
        v_roll_width_m := v_catalog_item.roll_width_m;

        SELECT ql.product_type_id, ql.width_m, ql.height_m
        INTO v_quote_line
        FROM "BomInstanceLines" bil
        JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
        LEFT JOIN "QuoteLines" ql ON ql.id = bi.quote_line_id AND ql.deleted = false
        WHERE bil.id = p_bom_instance_line_id;

        -- Resolve style_code from ConfiguredProduct.config_snapshot
        v_style_code := NULL;
        BEGIN
            SELECT cp.config_snapshot INTO v_config_snapshot
            FROM "BomInstanceLines" bil
            JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
            LEFT JOIN "QuoteLines" ql ON ql.id = bi.quote_line_id AND ql.deleted = false
            LEFT JOIN "ConfiguredProducts" cp ON cp.id = ql.configured_product_id
            WHERE bil.id = p_bom_instance_line_id
            LIMIT 1;

            IF v_config_snapshot IS NOT NULL THEN
                v_style_code := COALESCE(
                    v_config_snapshot ->> 'styleCode',
                    v_config_snapshot ->> 'style_code',
                    NULL
                );
            END IF;
        EXCEPTION WHEN OTHERS THEN
            v_style_code := NULL;
        END;

        SELECT cim.msrp, cim.pricing_uom
        INTO v_msrp_rec
        FROM "CatalogItemsMSRP" cim
        WHERE cim.catalog_item_id = p_catalog_item_id
          AND cim.organization_id = p_organization_id
        LIMIT 1;

        IF FOUND AND v_msrp_rec.msrp IS NOT NULL AND v_roll_width_m IS NOT NULL AND v_roll_width_m > 0 THEN
            IF UPPER(TRIM(COALESCE(v_msrp_rec.pricing_uom, ''))) = 'M' THEN
                v_msrp_per_m := v_msrp_rec.msrp;
            ELSE
                v_msrp_per_m := v_msrp_rec.msrp / v_roll_width_m;
            END IF;
        ELSE
            v_msrp_per_m := NULL;
        END IF;

        IF v_quote_line.product_type_id IS NOT NULL AND v_roll_width_m IS NOT NULL AND v_roll_width_m > 0 AND v_msrp_per_m IS NOT NULL THEN
            SELECT * INTO v_rule_result
            FROM public.compute_fabric_pricing_from_rule(
                p_organization_id,
                v_quote_line.product_type_id,
                v_style_code,
                v_quote_line.height_m,
                v_quote_line.width_m,
                v_roll_width_m,
                v_msrp_per_m
            ) LIMIT 1;

            IF FOUND AND v_rule_result.qty IS NOT NULL THEN
                v_qty_pricing := v_rule_result.qty;
                v_uom_pricing := COALESCE(v_rule_result.pricing_uom, 'm2');
                v_unit_cost_pricing := v_rule_result.unit_price;
                v_total_cost_pricing := v_qty_pricing * COALESCE(v_rule_result.unit_price, 0);
                v_calc_notes := COALESCE(v_calc_notes, '') ||
                    format(' FabricRule: area_base=%s m2, qty=%s %s, waste_pct=%s, style_code=%s',
                        COALESCE(v_rule_result.area_base_m2::text, '?'),
                        v_qty_pricing::text, v_uom_pricing,
                        COALESCE(v_rule_result.waste_pct::text, '0'),
                        COALESCE(v_style_code, 'NULL'));
                v_unit_cost_base := public.get_unit_cost_in_uom(p_catalog_item_id, v_uom_base, p_organization_id);
                IF (v_unit_cost_base IS NULL OR v_unit_cost_base = 0) THEN
                    SELECT unit_cost_exw INTO v_unit_cost_base FROM "BomInstanceLines" WHERE id = p_bom_instance_line_id;
                END IF;
                v_total_cost_base := v_qty_base * COALESCE(v_unit_cost_base, 0);
                UPDATE "BomInstanceLines"
                SET qty_base = v_qty_base, uom_base = v_uom_base,
                    qty_pricing = v_qty_pricing, uom_pricing = v_uom_pricing,
                    unit_cost_base = v_unit_cost_base, unit_cost_pricing = v_unit_cost_pricing,
                    total_cost_base = v_total_cost_base, total_cost_pricing = v_total_cost_pricing,
                    calc_notes = COALESCE(calc_notes, '') || CASE WHEN calc_notes IS NOT NULL AND calc_notes <> '' THEN '; ' ELSE '' END || v_calc_notes
                WHERE id = p_bom_instance_line_id;
                RETURN;
            END IF;
        END IF;

        IF v_catalog_item.fabric_pricing_mode IS NOT NULL THEN
            SELECT * INTO v_pricing_result
            FROM public.calculate_fabric_pricing_qty(
                v_qty_base,
                v_catalog_item.fabric_pricing_mode,
                v_catalog_item.roll_width_m
            );
            v_qty_pricing := v_pricing_result.qty_pricing;
            v_uom_pricing := v_pricing_result.uom_pricing;
        ELSE
            v_qty_pricing := v_qty_base;
            v_uom_pricing := v_uom_base;
        END IF;
    ELSE
        v_qty_pricing := v_qty_base;
        v_uom_pricing := v_uom_base;
    END IF;

    v_unit_cost_base := public.get_unit_cost_in_uom(p_catalog_item_id, v_uom_base, p_organization_id);
    v_unit_cost_pricing := public.get_unit_cost_in_pricing_uom(p_catalog_item_id, v_uom_pricing, p_organization_id);
    IF (v_unit_cost_base IS NULL OR v_unit_cost_base = 0) THEN
        SELECT unit_cost_exw INTO v_unit_cost_base FROM "BomInstanceLines" WHERE id = p_bom_instance_line_id;
    END IF;
    IF (v_unit_cost_pricing IS NULL OR v_unit_cost_pricing = 0) THEN
        v_unit_cost_pricing := v_unit_cost_base;
    END IF;
    v_total_cost_base := v_qty_base * COALESCE(v_unit_cost_base, 0);
    v_total_cost_pricing := v_qty_pricing * COALESCE(v_unit_cost_pricing, 0);

    IF v_calc_notes IS NULL THEN v_calc_notes := ''; END IF;
    IF v_catalog_item.is_fabric THEN
        v_calc_notes := v_calc_notes || format(' Fabric: base=%s %s, pricing=%s %s (mode=%s, roll_width=%s m)',
            v_qty_base::text, v_uom_base, v_qty_pricing::text, v_uom_pricing,
            COALESCE(v_catalog_item.fabric_pricing_mode::text, 'none'),
            ROUND(COALESCE(v_catalog_item.roll_width_m, 0), 4)::text);
    ELSE
        v_calc_notes := v_calc_notes || format(' Base=%s %s, pricing=%s %s', v_qty_base::text, v_uom_base, v_qty_pricing::text, v_uom_pricing);
    END IF;

    UPDATE "BomInstanceLines"
    SET qty_base = v_qty_base, uom_base = v_uom_base,
        qty_pricing = v_qty_pricing, uom_pricing = v_uom_pricing,
        unit_cost_base = v_unit_cost_base, unit_cost_pricing = v_unit_cost_pricing,
        total_cost_base = v_total_cost_base, total_cost_pricing = v_total_cost_pricing,
        calc_notes = COALESCE(calc_notes, '') || CASE WHEN calc_notes IS NOT NULL AND calc_notes <> '' THEN '; ' ELSE '' END || v_calc_notes
    WHERE id = p_bom_instance_line_id;
END;
$$;

NOTIFY pgrst, 'reload schema';
