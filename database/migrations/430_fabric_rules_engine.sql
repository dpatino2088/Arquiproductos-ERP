-- =====================================================
-- Migration: FabricRules engine — rule-based fabric pricing
-- =====================================================
-- 1) round_up_to_increment
-- 2) select_fabric_rule(org, product_type_id, style_code) -> FabricRules
-- 3) compute_fabric_pricing_from_rule(...) -> qty, pricing_uom, unit_price, area_base_m2, drops, waste_pct
-- 4) Patch populate_bom_line_base_pricing_fields: for fabric use rule when available, else fallback
-- No tocar: QuoteLine, ConfiguredProducts, CatalogItemsMSRP (solo lectura).
-- =====================================================

-- 1) Helper: round value up to nearest increment
CREATE OR REPLACE FUNCTION public.round_up_to_increment(
    p_value numeric,
    p_increment numeric
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_increment IS NULL OR p_increment <= 0 THEN
        RETURN p_value;
    END IF;
    RETURN CEIL(p_value / p_increment) * p_increment;
END;
$$;

COMMENT ON FUNCTION public.round_up_to_increment(numeric, numeric) IS
    'Rounds value up to the nearest multiple of increment. If increment is null or <=0 returns value unchanged.';

-- 2) Select active FabricRule: org_id, product_type_id, style_code (null = any)
-- Prefer exact style_code match; then rule with style_code IS NULL.
DROP FUNCTION IF EXISTS public.select_fabric_rule(uuid, uuid, text);
CREATE OR REPLACE FUNCTION public.select_fabric_rule(
    p_org_id uuid,
    p_product_type_id uuid,
    p_style_code text
)
RETURNS SETOF public."FabricRules"
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT r.*
    FROM public."FabricRules" r
    WHERE r.organization_id = p_org_id
      AND r.product_type_id = p_product_type_id
      AND (r.style_code IS NULL OR r.style_code = p_style_code OR (p_style_code IS NULL AND r.style_code IS NULL))
      AND COALESCE(r.is_active, true) = true
    ORDER BY (r.style_code IS NULL) ASC, r.style_code ASC  -- exact match first
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.select_fabric_rule(uuid, uuid, text) IS
    'Returns the active FabricRule for org/product_type and optional style_code. One row or none.';

-- 3) Compute fabric pricing from rule: area base, qty, uom, unit_price
-- ROLLER_DROPS: area = (H_eff * ceil(W_eff/RW)) * RW
-- AREA_BASED: area = H_eff * (W_eff * fullness_factor)
-- pricing_output_uom: m -> qty=area/RW, unit_price=msrp_per_m; m2 -> qty=area, unit_price=msrp_per_m/RW
-- Then: qty *= (1+waste_pct), round_up_to_increment(qty), max(qty, min_qty)
DROP FUNCTION IF EXISTS public.compute_fabric_pricing_from_rule(uuid, uuid, text, numeric, numeric, numeric, numeric);
CREATE OR REPLACE FUNCTION public.compute_fabric_pricing_from_rule(
    p_org_id uuid,
    p_product_type_id uuid,
    p_style_code text,
    p_height_m numeric,
    p_width_m numeric,
    p_roll_width_m numeric,
    p_msrp_per_m numeric
)
RETURNS TABLE(
    qty numeric,
    pricing_uom text,
    unit_price numeric,
    area_base_m2 numeric,
    drops numeric,
    waste_pct numeric
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_r RECORD;
    v_heff numeric;
    v_weff numeric;
    v_area numeric;
    v_drops numeric;
    v_qty numeric;
    v_uom text;
    v_unit_price numeric;
BEGIN
    qty := NULL;
    pricing_uom := NULL;
    unit_price := NULL;
    area_base_m2 := NULL;
    drops := NULL;
    waste_pct := NULL;

    SELECT * INTO v_r FROM public.select_fabric_rule(p_org_id, p_product_type_id, p_style_code) LIMIT 1;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    waste_pct := COALESCE(v_r.waste_pct, 0);

    -- GOLDEN RULE: NEVER apply waste to dimensions. H_eff/W_eff and area_base are NET.
    -- Waste is applied only once, to final qty: qty := qty * (1 + waste_pct) — see below.
    v_heff := COALESCE(p_height_m, 0) * COALESCE(v_r.height_multiplier, 1) + COALESCE(v_r.extra_height_m, 0);
    v_weff := COALESCE(p_width_m, 0) * COALESCE(v_r.width_multiplier, 1) + COALESCE(v_r.extra_width_m, 0);

    IF COALESCE(v_r.formula_code, '') = 'ROLLER_DROPS' THEN
        IF p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN
            v_area := v_heff * v_weff;
            v_drops := NULL;
        ELSE
            v_drops := CEIL(v_weff / p_roll_width_m);
            v_area := v_heff * v_drops * p_roll_width_m;
        END IF;
    ELSIF COALESCE(v_r.formula_code, '') = 'AREA_BASED' THEN
        v_area := v_heff * (v_weff * COALESCE(v_r.fullness_factor, 1));
        v_drops := NULL;
    ELSE
        v_area := v_heff * v_weff;
        v_drops := NULL;
    END IF;

    area_base_m2 := v_area;

    IF COALESCE(v_r.pricing_output_uom, 'm2') = 'm' THEN
        IF p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN
            v_qty := v_area;
            v_uom := 'm2';
            v_unit_price := p_msrp_per_m;
        ELSE
            v_qty := v_area / p_roll_width_m;
            v_uom := 'm';
            v_unit_price := COALESCE(p_msrp_per_m, 0);
        END IF;
    ELSE
        v_qty := v_area;
        v_uom := 'm2';
        v_unit_price := CASE WHEN p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN COALESCE(p_msrp_per_m, 0)
                             ELSE COALESCE(p_msrp_per_m, 0) / p_roll_width_m END;
    END IF;

    -- Merma: SIEMPRE aumenta consumo final. NUNCA restar ni aplicar a ancho/alto/área base.
    v_qty := v_qty * (1 + waste_pct);
    v_qty := public.round_up_to_increment(v_qty, COALESCE(v_r.round_to_increment, 0));
    IF v_r.min_qty IS NOT NULL AND v_r.min_qty > 0 AND v_qty < v_r.min_qty THEN
        v_qty := v_r.min_qty;
    END IF;

    qty := v_qty;
    pricing_uom := v_uom;
    unit_price := v_unit_price;
    drops := v_drops;
    RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION public.compute_fabric_pricing_from_rule(uuid, uuid, text, numeric, numeric, numeric, numeric) IS
    'Computes fabric qty, pricing_uom, unit_price from FabricRules. ROLLER_DROPS / AREA_BASED area, then m vs m2, waste, round_up, min_qty.';

-- 4) Patch populate_bom_line_base_pricing_fields: for fabric try rule first, else fallback to calculate_fabric_pricing_qty
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

    -- Base UOM and quantity (unchanged)
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

    -- Pricing path: FABRIC + rule available -> compute_fabric_pricing_from_rule; else legacy
    IF v_catalog_item.is_fabric THEN
        v_roll_width_m := v_catalog_item.roll_width_m;
        -- Resolve quote line context from BOM instance (for product_type_id, width_m, height_m)
        SELECT ql.product_type_id, ql.width_m, ql.height_m
        INTO v_quote_line
        FROM "BomInstanceLines" bil
        JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
        LEFT JOIN "QuoteLines" ql ON ql.id = bi.quote_line_id AND ql.deleted = false
        WHERE bil.id = p_bom_instance_line_id;

        -- MSRP: get per-m equivalent from CatalogItemsMSRP (source of truth)
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

        -- Try rule: need org, product_type_id, height_m, width_m, roll_width_m, msrp_per_m
        IF v_quote_line.product_type_id IS NOT NULL AND v_roll_width_m IS NOT NULL AND v_roll_width_m > 0 AND v_msrp_per_m IS NOT NULL THEN
            SELECT * INTO v_rule_result
            FROM public.compute_fabric_pricing_from_rule(
                p_organization_id,
                v_quote_line.product_type_id,
                NULL,
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
                    format(' FabricRule: area_base=%s m2, qty=%s %s, waste_pct=%s',
                        COALESCE(v_rule_result.area_base_m2::text, '?'),
                        v_qty_pricing::text, v_uom_pricing,
                        COALESCE(v_rule_result.waste_pct::text, '0'));
                -- Skip legacy path below
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

        -- Fallback: legacy calculate_fabric_pricing_qty
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

    -- Costs (unchanged)
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

COMMENT ON FUNCTION public.populate_bom_line_base_pricing_fields(uuid, uuid, numeric, text, text, uuid) IS
    'Populates base and pricing qty/UOM/costs in BomInstanceLines. For fabric: uses FabricRules via compute_fabric_pricing_from_rule when rule exists (org+product_type+quote line dimensions); else falls back to calculate_fabric_pricing_qty.';

DO $$
BEGIN
    RAISE NOTICE '✅ Migration 430: FabricRules engine installed (round_up_to_increment, select_fabric_rule, compute_fabric_pricing_from_rule, populate_bom_line_base_pricing_fields patched).';
END $$;
