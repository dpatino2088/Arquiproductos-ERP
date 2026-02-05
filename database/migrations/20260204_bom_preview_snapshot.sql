-- ============================================================================
-- Migration: BOM Preview Snapshot for ConfiguredProducts
-- Date: 2026-02-04
-- Description: Adds bom_preview_snapshot JSONB column to ConfiguredProducts
--              and modifies RPCs to populate it during preview creation.
-- ============================================================================

-- ============================================================================
-- 1) ADD COLUMN: bom_preview_snapshot
-- ============================================================================
-- JSONB CONTRACT (product-agnostic):
-- {
--   "version": "1",                    -- Schema version for future compatibility
--   "product_type_id": "uuid",         -- Product type
--   "bom_template_id": "uuid|null",    -- Matched BOM template
--   "price_basis": "msrp|dealer",      -- Price basis used (msrp for now)
--   "currency": "USD",                 -- Currency code
--   "totals": {                        -- Summary totals
--     "roll_msrp_total": number,
--     "bom_total": number,
--     "accessories_total": number,
--     "labor_pct": number,
--     "labor_amount": number,
--     "total_msrp": number,
--     "roll_total_cost": number,
--     "bom_total_cost": number
--   },
--   "items": [                         -- Array of breakdown items
--     {
--       "id": "string",                -- Stable ID (uuid or "role:sku")
--       "kind": "roll|parent|child|accessory|labor|other",
--       "role": "text",                -- Component role (fabric, tube, motor, etc)
--       "level": 0|1,                  -- 0=parent, 1=child
--       "selected": boolean,           -- User-selected vs template default
--       "catalog_item_id": "uuid|null",
--       "sku": "string|null",
--       "name": "string|null",
--       "qty": number,
--       "uom": "string",
--       "unit_price": number,          -- MSRP unit price
--       "line_total": number,          -- qty * unit_price
--       "children": [],                -- Nested children (same shape)
--       "meta": {}                     -- Optional product-specific data
--     }
--   ]
-- }

ALTER TABLE public."ConfiguredProducts"
  ADD COLUMN IF NOT EXISTS bom_preview_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public."ConfiguredProducts".bom_preview_snapshot IS 
'JSONB snapshot of BOM breakdown for UI preview. Contains version, totals, and items array with pricing details. Generated during create_configured_product_and_bom_preview.';

-- Optional GIN index for debugging/searching (can be removed if not needed)
CREATE INDEX IF NOT EXISTS idx_configuredproducts_bom_preview_gin 
  ON public."ConfiguredProducts" USING gin (bom_preview_snapshot);

-- ============================================================================
-- 2) CREATE OR REPLACE: Helper function to build preview snapshot
-- ============================================================================
CREATE OR REPLACE FUNCTION public.build_bom_preview_snapshot(
  p_org_id uuid,
  p_configured_product_id uuid,
  p_bom_template_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_items jsonb := '[]'::jsonb;
  v_totals jsonb;
  v_comp RECORD;
  v_child RECORD;
  v_item_info RECORD;
  v_msrp_info RECORD;
  v_qty numeric;
  v_unit_price numeric;
  v_line_total numeric;
  v_width_mm numeric;
  v_height_mm numeric;
  v_width_m numeric;
  v_height_m numeric;
  v_area_m2 numeric;
  v_roll_item jsonb;
  v_parent_items jsonb := '[]'::jsonb;
  v_children jsonb;
  v_item_id text;
  v_selected boolean;
  -- ✅ Variables for totals calculation
  v_roll_msrp_total numeric;
  v_bom_sum numeric;
  v_labor_amount numeric;
  v_accessories_total numeric;
  v_total_msrp numeric;
  v_child_unit_price numeric;
  v_child_line_total numeric;
BEGIN
  -- Get ConfiguredProduct
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  -- Calculate dimensions
  v_width_mm := COALESCE(v_cp.width_mm, 0);
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_width_m := v_width_mm / 1000.0;
  v_height_m := v_height_mm / 1000.0;
  v_area_m2 := v_width_m * v_height_m;

  -- 1) Add ROLL/FABRIC item if exists
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.name, ci.unit_of_measure
      INTO v_item_info
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;

    SELECT msrp, total_cost INTO v_msrp_info
    FROM public."CatalogItemsMSRP"
    WHERE catalog_item_id = v_cp.roll_catalog_item_id
      AND organization_id = p_org_id
    LIMIT 1;

    v_qty := v_area_m2 * COALESCE(v_cp.quantity, 1);
    v_unit_price := COALESCE(v_msrp_info.msrp, 0);
    v_line_total := ROUND(v_qty * v_unit_price, 2);

    v_roll_item := jsonb_build_object(
      'id', COALESCE(v_cp.roll_catalog_item_id::text, 'roll:' || COALESCE(v_cp.roll_sku, 'unknown')),
      'kind', 'roll',
      'role', 'fabric',
      'level', 0,
      'selected', true,
      'catalog_item_id', v_cp.roll_catalog_item_id,
      'sku', v_cp.roll_sku,
      'name', COALESCE(v_cp.roll_variant_name, v_item_info.name, v_cp.roll_sku),
      'qty', ROUND(v_qty, 3),
      'uom', 'm²',
      'unit_price', v_unit_price,
      'line_total', v_line_total,
      'children', '[]'::jsonb,
      'meta', jsonb_build_object(
        'collection_name', v_cp.roll_collection_name,
        'variant_name', v_cp.roll_variant_name,
        'roll_width', v_cp.roll_width
      )
    );
    v_items := v_items || v_roll_item;
  END IF;

  -- 2) Process BOM Components from template
  IF p_bom_template_id IS NOT NULL THEN
    FOR v_comp IN
      SELECT 
        bc.id,
        bc.component_role,
        bc.component_item_id,
        bc.qty_type,
        bc.qty_value,
        bc.qty_delta_mm,
        bc.uom,
        bc.parent_component_id,
        bc.sort_order
      FROM public."BOMComponents" bc
      WHERE bc.bom_template_id = p_bom_template_id
        AND bc.organization_id = p_org_id
        AND bc.deleted = false
        AND bc.archived = false
        AND bc.parent_component_id IS NULL  -- Only parents first
      ORDER BY bc.sort_order ASC
    LOOP
      -- Check if user selected a different item for this role
      v_selected := false;
      DECLARE
        v_role_lower text := lower(v_comp.component_role);
        v_selected_id uuid;
      BEGIN
        -- Map role to ConfiguredProduct columns
        CASE v_role_lower
          WHEN 'bottom_bar' THEN v_selected_id := v_cp.bottom_bar_item_id;
          WHEN 'headbox' THEN v_selected_id := v_cp.headbox_item_id;
          WHEN 'side_channel' THEN v_selected_id := v_cp.side_channel_item_id;
          WHEN 'bottom_channel' THEN v_selected_id := v_cp.bottom_channel_item_id;
          WHEN 'motor' THEN v_selected_id := v_cp.motor_item_id;
          WHEN 'drive' THEN v_selected_id := v_cp.drive_item_id;
          WHEN 'tube' THEN v_selected_id := v_cp.tube_item_id;
          ELSE v_selected_id := NULL;
        END CASE;

        -- Use selected item if exists, otherwise template default
        IF v_selected_id IS NOT NULL THEN
          v_comp.component_item_id := v_selected_id;
          v_selected := true;
        END IF;
      END;

      -- Skip if no item
      IF v_comp.component_item_id IS NULL THEN
        CONTINUE;
      END IF;

      -- Get item info
      SELECT ci.sku, ci.name, ci.unit_of_measure
        INTO v_item_info
      FROM public."CatalogItems" ci
      WHERE ci.id = v_comp.component_item_id
        AND ci.organization_id = p_org_id
      LIMIT 1;

      -- Get MSRP
      SELECT msrp, total_cost INTO v_msrp_info
      FROM public."CatalogItemsMSRP"
      WHERE catalog_item_id = v_comp.component_item_id
        AND organization_id = p_org_id
      LIMIT 1;

      -- Calculate quantity based on qty_type
      v_qty := COALESCE(v_comp.qty_value, 1);
      CASE COALESCE(v_comp.qty_type, 'fixed')
        WHEN 'per_width', 'width' THEN
          v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_height', 'height' THEN
          v_qty := GREATEST(0, (v_height_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_m2', 'area' THEN
          v_qty := GREATEST(0, v_area_m2);
        ELSE
          v_qty := COALESCE(v_comp.qty_value, 1);
      END CASE;

      v_unit_price := COALESCE(v_msrp_info.msrp, 0);
      v_line_total := ROUND(v_qty * v_unit_price, 2);

      -- Process children for this parent
      v_children := '[]'::jsonb;
      FOR v_child IN
        SELECT 
          bc.id,
          bc.component_role,
          bc.component_item_id,
          bc.qty_type,
          bc.qty_value,
          bc.qty_delta_mm,
          bc.uom
        FROM public."BOMComponents" bc
        WHERE bc.parent_component_id = v_comp.id
          AND bc.organization_id = p_org_id
          AND bc.deleted = false
          AND bc.archived = false
        ORDER BY bc.sort_order ASC
      LOOP
        IF v_child.component_item_id IS NULL THEN
          CONTINUE;
        END IF;

        -- Get child item info
        SELECT ci.sku, ci.name, ci.unit_of_measure
          INTO v_item_info
        FROM public."CatalogItems" ci
        WHERE ci.id = v_child.component_item_id
          AND ci.organization_id = p_org_id
        LIMIT 1;

        -- Get child MSRP
        SELECT msrp, total_cost INTO v_msrp_info
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_child.component_item_id
          AND organization_id = p_org_id
        LIMIT 1;

        -- Calculate child quantity
        DECLARE
          v_child_qty numeric;
          v_child_unit_price numeric;
          v_child_line_total numeric;
        BEGIN
          v_child_qty := COALESCE(v_child.qty_value, 1);
          CASE COALESCE(v_child.qty_type, 'fixed')
            WHEN 'per_width', 'width' THEN
              v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
            WHEN 'per_height', 'height' THEN
              v_child_qty := GREATEST(0, (v_height_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
            WHEN 'per_m2', 'area' THEN
              v_child_qty := GREATEST(0, v_area_m2);
            ELSE
              v_child_qty := COALESCE(v_child.qty_value, 1);
          END CASE;

          v_child_unit_price := COALESCE(v_msrp_info.msrp, 0);
          v_child_line_total := ROUND(v_child_qty * v_child_unit_price, 2);

          v_children := v_children || jsonb_build_object(
            'id', v_child.id::text,
            'kind', 'child',
            'role', COALESCE(v_child.component_role, 'child'),
            'level', 1,
            'selected', false,
            'catalog_item_id', v_child.component_item_id,
            'sku', v_item_info.sku,
            'name', v_item_info.name,
            'qty', ROUND(v_child_qty, 3),
            'uom', COALESCE(v_child.uom, v_item_info.unit_of_measure, 'ea'),
            'unit_price', v_child_unit_price,
            'line_total', v_child_line_total,
            'children', '[]'::jsonb,
            'meta', '{}'::jsonb
          );
        END;
      END LOOP;

      -- Add parent with its children
      v_items := v_items || jsonb_build_object(
        'id', v_comp.id::text,
        'kind', 'parent',
        'role', COALESCE(v_comp.component_role, 'component'),
        'level', 0,
        'selected', v_selected,
        'catalog_item_id', v_comp.component_item_id,
        'sku', v_item_info.sku,
        'name', v_item_info.name,
        'qty', ROUND(v_qty, 3),
        'uom', COALESCE(v_comp.uom, v_item_info.unit_of_measure, 'ea'),
        'unit_price', v_unit_price,
        'line_total', v_line_total,
        'children', v_children,
        'meta', '{}'::jsonb
      );
    END LOOP;
  END IF;

  -- ✅ RE-FETCH ConfiguredProduct to get updated totals
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id;

  -- ═══════════════════════════════════════════════════════════════════════
  -- ✅ CALCULAR TOTALES DESDE v_items (más preciso que columnas)
  -- Las columnas de ConfiguredProducts pueden ser 0 si no hay BOMInstance
  -- ═══════════════════════════════════════════════════════════════════════
  
  -- Calcular roll_msrp_total desde items kind='roll'
  SELECT COALESCE(SUM((item->>'line_total')::numeric), 0)
  INTO v_roll_msrp_total
  FROM jsonb_array_elements(v_items) AS item
  WHERE item->>'kind' = 'roll';
  
  -- Si no hay roll en items, usar columna de ConfiguredProducts
  IF v_roll_msrp_total = 0 THEN
    v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0);
  END IF;
  
  -- Calcular bom_total sumando parents + children
  SELECT COALESCE(SUM(
    (item->>'line_total')::numeric + 
    COALESCE((
      SELECT SUM((c->>'line_total')::numeric) 
      FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c
    ), 0)
  ), 0)
  INTO v_bom_sum
  FROM jsonb_array_elements(v_items) AS item
  WHERE item->>'kind' = 'parent';
  
  -- Si v_bom_sum es 0, intentar con columna de ConfiguredProducts
  IF v_bom_sum = 0 THEN
    v_bom_sum := COALESCE(v_cp.bom_total, 0);
  END IF;
  
  -- Labor y accessories desde ConfiguredProducts
  v_labor_amount := COALESCE(v_cp.labor_amount, 0);
  v_accessories_total := COALESCE(v_cp.accessories_total, 0);
  
  -- Calcular labor si es 0 pero hay labor_pct
  IF v_labor_amount = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_amount := (v_roll_msrp_total + v_bom_sum) * (v_cp.labor_pct / 100.0);
  END IF;
  
  -- ✅ SIEMPRE calcular total_msrp desde las partes
  v_total_msrp := v_roll_msrp_total + v_bom_sum + v_labor_amount + v_accessories_total;
  
  v_totals := jsonb_build_object(
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_sum,
    'accessories_total', v_accessories_total,
    'labor_pct', COALESCE(v_cp.labor_pct, 0),
    'labor_amount', v_labor_amount,
    'total_msrp', v_total_msrp,
    'roll_total_cost', COALESCE(v_cp.roll_total_cost, 0),
    'bom_total_cost', COALESCE(v_cp.bom_total_cost, 0)
  );

  RETURN jsonb_build_object(
    'version', '1',
    'product_type_id', v_cp.product_type_id,
    'bom_template_id', p_bom_template_id,
    'price_basis', 'msrp',
    'currency', 'USD',
    'totals', v_totals,
    'items', v_items
  );
END;
$$;

COMMENT ON FUNCTION public.build_bom_preview_snapshot(uuid, uuid, uuid) IS 
'Builds the bom_preview_snapshot JSONB for a ConfiguredProduct. Called after totals are calculated.';

-- ============================================================================
-- 3) MODIFY: create_configured_product_and_bom_preview to populate snapshot
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_configured_product_and_bom_preview(
  p_org_id uuid,
  p_product_type_id uuid,
  p_config_snapshot jsonb,
  p_quote_id uuid DEFAULT NULL,
  p_quote_line_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_configured_product_id uuid;
  v_bom_template_id uuid;
  v_bom_instance_id uuid;
  v_totals jsonb;
  v_preview_snapshot jsonb;
  v_hardware_color text;
  v_fabric_item_id uuid;
  v_width_mm numeric(12,4);
  v_height_mm numeric(12,4);
  v_quantity numeric(12,4);
  v_roll_sku text;
  v_roll_collection_name text;
  v_roll_variant_name text;
  v_roll_width numeric(12,4);
BEGIN
  -- 1) Match BOM Template
  v_bom_template_id := public.select_best_bom_template_for_configured_product(
    p_org_id,
    p_product_type_id,
    p_config_snapshot
  );

  IF v_bom_template_id IS NULL THEN
    RAISE EXCEPTION 'No matching BOMTemplate found for product_type_id=% with config=%',
      p_product_type_id, p_config_snapshot::text;
  END IF;

  -- 2) Extract values from config
  v_hardware_color := COALESCE(
    p_config_snapshot->>'hardware_color',
    p_config_snapshot->>'hardwareColor'
  );
  v_fabric_item_id := (p_config_snapshot->>'variantId')::uuid;
  IF v_fabric_item_id IS NULL THEN
    v_fabric_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid;
  END IF;
  v_width_mm := (p_config_snapshot->>'width_mm')::numeric(12,4);
  v_height_mm := (p_config_snapshot->>'height_mm')::numeric(12,4);
  v_quantity := COALESCE((p_config_snapshot->>'quantity')::numeric(12,4), 1);

  -- Get roll info from CatalogItems if fabric_item_id exists
  IF v_fabric_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.collection_name, ci.variant_name, ci.roll_width
      INTO v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width
    FROM public."CatalogItems" ci
    WHERE ci.id = v_fabric_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;
  END IF;

  -- 3) Insert ConfiguredProduct
  INSERT INTO public."ConfiguredProducts" (
    organization_id,
    quote_id,
    bom_template_id,
    product_type_id,
    width_mm,
    height_mm,
    quantity,
    hardware_color,
    roll_catalog_item_id,
    roll_sku,
    roll_collection_name,
    roll_variant_name,
    roll_width,
    bottom_bar_item_id,
    bottom_bar_sku,
    headbox_item_id,
    headbox_sku,
    side_channel_item_id,
    side_channel_sku,
    bottom_channel_item_id,
    bottom_channel_sku,
    motor_item_id,
    motor_sku,
    drive_item_id,
    drive_sku,
    tube_item_id,
    tube_sku,
    operating_type,
    config_snapshot
  )
  VALUES (
    p_org_id,
    p_quote_id,
    v_bom_template_id,
    p_product_type_id,
    v_width_mm,
    v_height_mm,
    v_quantity,
    v_hardware_color,
    v_fabric_item_id,
    v_roll_sku,
    v_roll_collection_name,
    v_roll_variant_name,
    v_roll_width,
    (p_config_snapshot->>'bottom_bar_item_id')::uuid,
    p_config_snapshot->>'bottom_bar_sku',
    (p_config_snapshot->>'headbox_item_id')::uuid,
    p_config_snapshot->>'headbox_sku',
    (p_config_snapshot->>'side_channel_item_id')::uuid,
    p_config_snapshot->>'side_channel_sku',
    (p_config_snapshot->>'bottom_channel_item_id')::uuid,
    p_config_snapshot->>'bottom_channel_sku',
    (p_config_snapshot->>'motor_item_id')::uuid,
    p_config_snapshot->>'motor_sku',
    (p_config_snapshot->>'drive_item_id')::uuid,
    p_config_snapshot->>'drive_sku',
    (p_config_snapshot->>'tube_item_id')::uuid,
    p_config_snapshot->>'tube_sku',
    COALESCE(
      p_config_snapshot->>'operating_type',
      p_config_snapshot->>'operation_type',
      p_config_snapshot->>'drive_type'
    ),
    p_config_snapshot
  )
  RETURNING id INTO v_configured_product_id;

  -- 4) Calculate totals (this updates ConfiguredProducts with pricing)
  v_bom_instance_id := NULL;
  v_totals := public.calculate_configured_product_totals(v_configured_product_id);

  -- 5) Build and persist the preview snapshot
  v_preview_snapshot := public.build_bom_preview_snapshot(
    p_org_id,
    v_configured_product_id,
    v_bom_template_id
  );

  UPDATE public."ConfiguredProducts"
  SET bom_preview_snapshot = v_preview_snapshot,
      updated_at = now()
  WHERE id = v_configured_product_id
    AND organization_id = p_org_id;

  -- 6) Return result
  RETURN jsonb_build_object(
    'configured_product_id', v_configured_product_id,
    'bom_instance_id', v_bom_instance_id,
    'bom_template_id', v_bom_template_id,
    'totals', v_totals,
    'bom_preview_snapshot', v_preview_snapshot
  );
END;
$$;

COMMENT ON FUNCTION public.create_configured_product_and_bom_preview(uuid, uuid, jsonb, uuid, uuid) IS 
'Creates ConfiguredProduct with pricing totals and bom_preview_snapshot.
✅ CAMBIO: Now populates bom_preview_snapshot JSONB for UI breakdown.
Solo crea BOMInstance si se proporciona quote_line_id.';

-- ============================================================================
-- 4) MODIFY: Trigger to skip if configured_product_id is present
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_quote_lines_generate_bom_instance_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_product_type_id uuid;
  v_exists boolean;
BEGIN
  -- ✅ NEW GUARD: If QuoteLine has configured_product_id, skip trigger entirely
  -- The BOMInstance should be created by commit_configured_product_to_quote_line RPC
  IF NEW.configured_product_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- 0) If BOMInstance already exists, do nothing
  SELECT EXISTS (
    SELECT 1
    FROM public."BOMInstances" bi
    WHERE bi.organization_id = NEW.organization_id
      AND bi.quote_line_id = NEW.id
  )
  INTO v_exists;

  IF v_exists THEN
    RETURN NEW;
  END IF;

  -- 1) If QuoteLine already has bom_template_id, don't auto-generate
  IF NEW.bom_template_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- 2) Resolve product_type_id (legacy fallback)
  v_product_type_id := NEW.product_type_id;

  -- 3) If still null, don't generate (better to fail gracefully)
  IF v_product_type_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- 4) Legacy: generate BOM for QuoteLines without configured_product_id
  PERFORM public.generate_bom_instance_for_quote_line(NEW.organization_id, NEW.id, v_product_type_id);

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_quote_lines_generate_bom_instance_fn() IS 
'Trigger function for QuoteLines BOM generation.
✅ CAMBIO: Skips entirely if configured_product_id IS NOT NULL.
Legacy fallback: generates BOM only for QuoteLines without configured_product_id.';

-- ============================================================================
-- 5) Verify grants
-- ============================================================================
GRANT EXECUTE ON FUNCTION public.build_bom_preview_snapshot(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.build_bom_preview_snapshot(uuid, uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.build_bom_preview_snapshot(uuid, uuid, uuid) TO anon;

-- ============================================================================
-- Done!
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '✅ Migration 20260204_bom_preview_snapshot completed successfully.';
  RAISE NOTICE '   - Added bom_preview_snapshot column to ConfiguredProducts';
  RAISE NOTICE '   - Created build_bom_preview_snapshot helper function';
  RAISE NOTICE '   - Modified create_configured_product_and_bom_preview to populate snapshot';
  RAISE NOTICE '   - Modified trigger to skip when configured_product_id is present';
END $$;
