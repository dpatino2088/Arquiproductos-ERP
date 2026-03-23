


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;




ALTER SCHEMA "public" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."bom_component_mode" AS ENUM (
    'select',
    'fixed',
    'auto',
    'optional'
);


ALTER TYPE "public"."bom_component_mode" OWNER TO "postgres";


CREATE TYPE "public"."contact_type" AS ENUM (
    'architect',
    'interior_designer',
    'engineer',
    'project_manager',
    'end_customer'
);


ALTER TYPE "public"."contact_type" OWNER TO "postgres";


CREATE TYPE "public"."customer_type" AS ENUM (
    'distributor',
    'reseller',
    'partner',
    'vip'
);


ALTER TYPE "public"."customer_type" OWNER TO "postgres";


CREATE TYPE "public"."directory_customer_type_name" AS ENUM (
    'contractor',
    'architecture_studio',
    'design_studio',
    'end_user'
);


ALTER TYPE "public"."directory_customer_type_name" OWNER TO "postgres";


CREATE TYPE "public"."headbox_type" AS ENUM (
    'none',
    'cassette'
);


ALTER TYPE "public"."headbox_type" OWNER TO "postgres";


CREATE TYPE "public"."manufacturing_order_status" AS ENUM (
    'draft',
    'planned',
    'in_production',
    'completed',
    'cancelled'
);


ALTER TYPE "public"."manufacturing_order_status" OWNER TO "postgres";


CREATE TYPE "public"."material_type_enum" AS ENUM (
    'fabric',
    'film',
    'mesh',
    'vinyl',
    'other'
);


ALTER TYPE "public"."material_type_enum" OWNER TO "postgres";


CREATE TYPE "public"."measure_basis_enum" AS ENUM (
    'unit',
    'linear',
    'area'
);


ALTER TYPE "public"."measure_basis_enum" OWNER TO "postgres";


CREATE TYPE "public"."operating_system" AS ENUM (
    'manual',
    'motor'
);


ALTER TYPE "public"."operating_system" OWNER TO "postgres";


CREATE TYPE "public"."org_role" AS ENUM (
    'owner',
    'admin',
    'member',
    'viewer',
    'superadmin',
    'operator',
    'procurement',
    'finance'
);


ALTER TYPE "public"."org_role" OWNER TO "postgres";


CREATE TYPE "public"."org_user_status" AS ENUM (
    'invited',
    'active',
    'disabled'
);


ALTER TYPE "public"."org_user_status" OWNER TO "postgres";


CREATE TYPE "public"."pack_uom_enum" AS ENUM (
    'ea',
    'm',
    'm2'
);


ALTER TYPE "public"."pack_uom_enum" OWNER TO "postgres";


CREATE TYPE "public"."portal_user_status" AS ENUM (
    'draft',
    'invited',
    'active',
    'disabled'
);


ALTER TYPE "public"."portal_user_status" OWNER TO "postgres";


CREATE TYPE "public"."pricing_basis" AS ENUM (
    'unit',
    'linear',
    'area'
);


ALTER TYPE "public"."pricing_basis" OWNER TO "postgres";


CREATE TYPE "public"."proposal_custom_category" AS ENUM (
    'installation',
    'delivery',
    'service',
    'other'
);


ALTER TYPE "public"."proposal_custom_category" OWNER TO "postgres";


CREATE TYPE "public"."proposal_line_type" AS ENUM (
    'from_quote',
    'custom'
);


ALTER TYPE "public"."proposal_line_type" OWNER TO "postgres";


CREATE TYPE "public"."proposal_override_mode" AS ENUM (
    'inherit',
    'discount_pct',
    'markup_pct',
    'fixed_unit_price',
    'fixed_line_total'
);


ALTER TYPE "public"."proposal_override_mode" OWNER TO "postgres";


CREATE TYPE "public"."proposal_status" AS ENUM (
    'draft',
    'sent',
    'accepted',
    'rejected',
    'cancelled'
);


ALTER TYPE "public"."proposal_status" OWNER TO "postgres";


CREATE TYPE "public"."purchase_uom_enum" AS ENUM (
    'm',
    'm2',
    'yd',
    'ft',
    'ea',
    'set',
    'pack'
);


ALTER TYPE "public"."purchase_uom_enum" OWNER TO "postgres";


CREATE TYPE "public"."quote_status" AS ENUM (
    'draft',
    'sent',
    'approved',
    'canceled'
);


ALTER TYPE "public"."quote_status" OWNER TO "postgres";


CREATE TYPE "public"."roll_kind" AS ENUM (
    'fabric',
    'window_film',
    'vinyl',
    'other'
);


ALTER TYPE "public"."roll_kind" OWNER TO "postgres";


CREATE TYPE "public"."roll_type" AS ENUM (
    'fabric',
    'window_film',
    'vinyl',
    'mesh',
    'paper',
    'other'
);


ALTER TYPE "public"."roll_type" OWNER TO "postgres";


CREATE TYPE "public"."sales_order_status" AS ENUM (
    'draft',
    'confirmed',
    'in_production',
    'ready_for_delivery',
    'delivered',
    'cancelled'
);


ALTER TYPE "public"."sales_order_status" OWNER TO "postgres";


CREATE TYPE "public"."sales_order_tracking_status" AS ENUM (
    'pending_confirmation',
    'confirmed',
    'in_production',
    'ready_for_delivery',
    'delivered',
    'canceled'
);


ALTER TYPE "public"."sales_order_tracking_status" OWNER TO "postgres";


CREATE TYPE "public"."side_channel_mode" AS ENUM (
    'none',
    'side_only',
    'side_plus_bottom'
);


ALTER TYPE "public"."side_channel_mode" OWNER TO "postgres";


CREATE TYPE "public"."supply_form_enum" AS ENUM (
    'each',
    'linear',
    'roll'
);


ALTER TYPE "public"."supply_form_enum" OWNER TO "postgres";


CREATE TYPE "public"."system_size" AS ENUM (
    's',
    'm',
    'l',
    'xl'
);


ALTER TYPE "public"."system_size" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_trg_categorymargins_recompute_itemsmsrp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  perform public.recompute_catalogitems_msrp_for_category(new.organization_id, new.category_id);
  return new;
end;
$$;


ALTER FUNCTION "public"."_trg_categorymargins_recompute_itemsmsrp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_trg_costsettings_recompute_itemsmsrp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  perform public.recompute_catalogitems_msrp_for_org(new.organization_id);
  return new;
end;
$$;


ALTER FUNCTION "public"."_trg_costsettings_recompute_itemsmsrp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_trg_importtaxrules_recompute_itemsmsrp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  perform public.recompute_catalogitems_msrp_for_category(new.organization_id, new.category_id);
  return new;
end;
$$;


ALTER FUNCTION "public"."_trg_importtaxrules_recompute_itemsmsrp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."approve_quote"("p_quote_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_dealer_id uuid;
  v_role text;
BEGIN
  SELECT dpu.dealer_id, dpu.role INTO v_dealer_id, v_role
  FROM public."DealerUsers" dpu
  WHERE dpu.user_id = auth.uid()
    AND dpu.deleted = false
    AND dpu.status = 'active'
  LIMIT 1;

  IF v_dealer_id IS NULL THEN
    RAISE EXCEPTION 'Not a portal user';
  END IF;

  IF v_role <> 'member_manager' THEN
    RAISE EXCEPTION 'Forbidden: only member_manager can approve quotes';
  END IF;

  UPDATE public."Quotes"
  SET status = 'approved', updated_at = now()
  WHERE id = p_quote_id AND deleted = false AND dealer_id = v_dealer_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quote not found for your dealer';
  END IF;
END;
$$;


ALTER FUNCTION "public"."approve_quote"("p_quote_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_portal_user record;
  v_quote record;
  v_new_status public.quote_status;
  v_result json;
BEGIN
  SELECT * INTO v_portal_user FROM public.get_current_portal_user() LIMIT 1;

  IF v_portal_user.id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated as active portal user';
  END IF;

  IF v_portal_user.portal_user_role != 'member_manager' THEN
    RAISE EXCEPTION 'Only member managers can approve/reject quotes';
  END IF;

  SELECT * INTO v_quote
  FROM public."Quotes"
  WHERE id = p_quote_id AND deleted = false;

  IF v_quote.id IS NULL THEN
    RAISE EXCEPTION 'Quote not found';
  END IF;

  IF v_quote.dealer_id != v_portal_user.dealer_id THEN
    RAISE EXCEPTION 'Quote does not belong to your dealer';
  END IF;

  IF p_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Invalid action. Must be "approve" or "reject"';
  END IF;

  IF v_quote.status NOT IN ('draft', 'sent', 'pending_approval') THEN
    RAISE EXCEPTION 'Quote status (%) does not allow approval/rejection. Must be draft, sent, or pending_approval', v_quote.status;
  END IF;

  IF p_action = 'approve' THEN
    v_new_status := 'approved';
  ELSE
    v_new_status := 'rejected';
  END IF;

  UPDATE public."Quotes"
  SET status = v_new_status, updated_at = now()
  WHERE id = p_quote_id AND deleted = false;

  SELECT json_build_object('success', true, 'status', v_new_status) INTO v_result;
  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") IS 'Approve or reject a quote. ONLY member_manager role can call. Validates company match and quote status. Uses status column.';



CREATE OR REPLACE FUNCTION "public"."build_bom_preview_snapshot"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_bom_template_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_cp RECORD;
  v_config jsonb;
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
  v_roll_msrp_total numeric := 0;
  v_bom_sum numeric := 0;
  v_labor_amount numeric := 0;
  v_accessories_total numeric := 0;
  v_total_msrp numeric := 0;
  v_child_unit_price numeric;
  v_child_line_total numeric;
  v_selected_id uuid;
  v_labor_pct numeric(12,4);
  v_panel_count int := 1;  -- 1, 2 or 3 paños (para dimensiones; tubo/bottom bar = per_width)
  v_role_lower text;
  v_by_total_width boolean;  -- headbox/bottom_channel: qty por ancho total (suma paños)
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  SELECT COALESCE(cs.labor_pct, 0) INTO v_labor_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_org_id
  LIMIT 1;
  IF v_labor_pct IS NULL THEN
    v_labor_pct := COALESCE(v_cp.labor_pct, 0);
  END IF;

  v_config := COALESCE(v_cp.config_snapshot, '{}'::jsonb);

  -- Paños: use total width and panel count from measurements (default 1)
  v_panel_count := LEAST(3, GREATEST(1, COALESCE((v_config->'measurements'->>'panel_count')::int, 1)));
  v_width_mm := COALESCE(
    (v_config->'measurements'->>'width_total_mm')::numeric,
    v_cp.width_mm,
    0
  );
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_width_m := v_width_mm / 1000.0;
  v_height_m := v_height_mm / 1000.0;
  v_area_m2 := v_width_m * v_height_m;

  IF jsonb_typeof(v_config->'accessories') = 'array' THEN
    SELECT COALESCE(SUM(
      (elem->>'price')::numeric * GREATEST(COALESCE((elem->>'qty')::numeric, 0), 0)
    ), 0) INTO v_accessories_total
    FROM jsonb_array_elements(v_config->'accessories') AS elem;
  END IF;
  v_accessories_total := ROUND(COALESCE(v_accessories_total, 0), 2);

  -- 1) ROLL/FABRIC
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
    v_roll_msrp_total := v_line_total;

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

  -- 2) BOM Components
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
        AND bc.parent_component_id IS NULL
      ORDER BY bc.sort_order ASC
    LOOP
      v_selected := false;
      v_selected_id := NULL;
      v_role_lower := lower(COALESCE(v_comp.component_role, ''));

      CASE v_role_lower
        WHEN 'bottom_bar' THEN v_selected_id := (v_config->>'bottom_bar_item_id')::uuid;
        WHEN 'headbox' THEN v_selected_id := (v_config->>'headbox_item_id')::uuid;
        WHEN 'side_channel' THEN v_selected_id := (v_config->>'side_channel_item_id')::uuid;
        WHEN 'bottom_channel' THEN v_selected_id := (v_config->>'bottom_channel_item_id')::uuid;
        WHEN 'motor' THEN v_selected_id := (v_config->>'motor_item_id')::uuid;
        WHEN 'drive' THEN v_selected_id := (v_config->>'drive_item_id')::uuid;
        WHEN 'tube' THEN v_selected_id := (v_config->>'tube_item_id')::uuid;
        ELSE v_selected_id := NULL;
      END CASE;

      IF v_selected_id IS NOT NULL THEN
        v_comp.component_item_id := v_selected_id;
        v_selected := true;
      END IF;

      IF v_comp.component_item_id IS NULL THEN
        CONTINUE;
      END IF;

      SELECT ci.sku, ci.name, ci.unit_of_measure
        INTO v_item_info
      FROM public."CatalogItems" ci
      WHERE ci.id = v_comp.component_item_id
        AND ci.organization_id = p_org_id
      LIMIT 1;

      SELECT msrp, total_cost INTO v_msrp_info
      FROM public."CatalogItemsMSRP"
      WHERE catalog_item_id = v_comp.component_item_id
        AND organization_id = p_org_id
      LIMIT 1;

      -- Tubo = per_width per each panel (longitud = width_total). Headbox/bottom channel = por ancho total
      v_qty := COALESCE(v_comp.qty_value, 1);
      v_by_total_width := v_role_lower IN ('headbox', 'bottom_channel');

      -- Tube (tubo) siempre per_width: longitud = ancho total (suma anchos por paño)
      IF v_role_lower = 'tube' THEN
        v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
      ELSE
        CASE COALESCE(v_comp.qty_type, 'fixed')
          WHEN 'per_width', 'width' THEN
            v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
          WHEN 'per_height', 'height' THEN
            v_qty := GREATEST(0, (v_height_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
          WHEN 'per_m2', 'area' THEN
            v_qty := GREATEST(0, v_area_m2);
          ELSE
            IF v_by_total_width THEN
              v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
            ELSE
              v_qty := COALESCE(v_comp.qty_value, 1);
            END IF;
        END CASE;
      END IF;

      v_unit_price := COALESCE(v_msrp_info.msrp, 0);
      v_line_total := ROUND(v_qty * v_unit_price, 2);

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

        SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
        FROM public."CatalogItems" ci
        WHERE ci.id = v_child.component_item_id AND ci.organization_id = p_org_id
        LIMIT 1;

        SELECT msrp INTO v_child_unit_price
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_child.component_item_id AND organization_id = p_org_id
        LIMIT 1;

        DECLARE v_child_qty numeric;
              v_child_role_lower text;
        BEGIN
          v_child_qty := COALESCE(v_child.qty_value, 1);
          v_child_role_lower := lower(COALESCE(v_child.component_role, ''));
          IF v_child_role_lower = 'tube' THEN
            v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
          ELSE
            CASE COALESCE(v_child.qty_type, 'fixed')
              WHEN 'per_width', 'width' THEN
                v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
              WHEN 'per_height', 'height' THEN
                v_child_qty := GREATEST(0, (v_height_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
              ELSE
                IF v_child_role_lower IN ('headbox', 'bottom_channel') THEN
                  v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
                ELSE
                  v_child_qty := COALESCE(v_child.qty_value, 1);
                END IF;
            END CASE;
          END IF;
          v_child_line_total := ROUND(v_child_qty * COALESCE(v_child_unit_price, 0), 2);
          v_bom_sum := v_bom_sum + v_child_line_total;

          v_children := v_children || jsonb_build_object(
            'id', v_child.component_item_id::text,
            'kind', 'child',
            'role', v_child.component_role,
            'level', 1,
            'selected', false,
            'catalog_item_id', v_child.component_item_id,
            'sku', v_item_info.sku,
            'name', v_item_info.name,
            'qty', ROUND(v_child_qty, 3),
            'uom', COALESCE(v_child.uom, v_item_info.unit_of_measure, 'ea'),
            'unit_price', COALESCE(v_child_unit_price, 0),
            'line_total', v_child_line_total,
            'children', '[]'::jsonb,
            'meta', '{}'::jsonb
          );
        END;
      END LOOP;

      v_bom_sum := v_bom_sum + v_line_total;
      v_items := v_items || jsonb_build_object(
        'id', v_comp.component_item_id::text,
        'kind', 'parent',
        'role', v_comp.component_role,
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

  v_labor_amount := ROUND((v_roll_msrp_total + v_bom_sum) * v_labor_pct, 2);
  v_total_msrp := v_roll_msrp_total + v_bom_sum + v_labor_amount + v_accessories_total;

  v_totals := jsonb_build_object(
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_sum,
    'accessories_total', v_accessories_total,
    'labor_pct', v_labor_pct,
    'labor_amount', v_labor_amount,
    'total_msrp', v_total_msrp,
    'roll_total_cost', 0,
    'bom_total_cost', 0
  );

  UPDATE public."ConfiguredProducts"
  SET roll_msrp_total = v_roll_msrp_total,
      bom_total = v_bom_sum,
      labor_pct = v_labor_pct,
      labor_amount = v_labor_amount,
      roll_plus_bom_total = v_roll_msrp_total + v_bom_sum,
      accessories_total = v_accessories_total,
      total_msrp = v_total_msrp,
      updated_at = now()
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id;

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


ALTER FUNCTION "public"."build_bom_preview_snapshot"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_bom_template_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."build_bom_preview_snapshot"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_bom_template_id" "uuid") IS 'BOM breakdown: Roll=area width_total×height. Tubo=per_width per each panel (qty=width_total). Bottom bar/Headbox/Bottom channel=ancho total (qty=width_total).';



CREATE OR REPLACE FUNCTION "public"."build_quote_line_config"("p_org_id" "uuid", "p_quote_line_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    AS $$
  select '{}'::jsonb;
$$;


ALTER FUNCTION "public"."build_quote_line_config"("p_org_id" "uuid", "p_quote_line_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_bom_price"("p_parent_item_id" "uuid", "p_organization_id" "uuid", "p_width_m" numeric, "p_height_m" numeric, "p_area_sqm" numeric) RETURNS TABLE("component_item_id" "uuid", "category_id" "uuid", "basis" "text", "unit_cost" numeric, "qty" numeric, "extended_cost" numeric)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  r RECORD;
  j jsonb;

  v_component_item_id uuid;
  v_qty_value numeric;
  v_qty_type text;

  v_basis text;
  v_unit_cost numeric(12,4);

  v_multiplier numeric := 1;
  v_qty numeric(12,4);
BEGIN
  FOR r IN
    SELECT to_jsonb(b) AS j
    FROM public."BOMComponents" b
    WHERE b.organization_id = p_organization_id
      AND b.deleted = false
      AND (
        (to_jsonb(b)->>'parent_item_id')::uuid = p_parent_item_id
        OR (to_jsonb(b)->>'parent_catalog_item_id')::uuid = p_parent_item_id
      )
  LOOP
    j := r.j;

    -- soporta nombres alternos para el componente hijo
    v_component_item_id :=
      COALESCE(
        NULLIF(j->>'child_item_id','')::uuid,
        NULLIF(j->>'component_item_id','')::uuid,
        NULLIF(j->>'catalog_item_id','')::uuid
      );

    IF v_component_item_id IS NULL THEN
      CONTINUE;
    END IF;

    -- soporta qty_value / qty / quantity
    v_qty_value :=
      COALESCE(
        NULLIF(j->>'qty_value','')::numeric,
        NULLIF(j->>'qty','')::numeric,
        NULLIF(j->>'quantity','')::numeric,
        1
      );

    -- soporta qty_type / qty_basis
    v_qty_type :=
      COALESCE(
        NULLIF(j->>'qty_type',''),
        NULLIF(j->>'qty_basis',''),
        'per_unit'
      );

    -- unit cost normalizado (tu función)
    SELECT u.basis, u.unit_cost
    INTO v_basis, v_unit_cost
    FROM public.get_catalog_item_unit_cost_norm(v_component_item_id, p_organization_id) u
    LIMIT 1;

    v_unit_cost := COALESCE(v_unit_cost, 0);

    -- multipliers segun qty_type
    v_multiplier := 1;

    IF v_qty_type IN ('per_width','per_linear_width','per_m_width','per_linear') THEN
      v_multiplier := COALESCE(p_width_m, 0);
    ELSIF v_qty_type IN ('per_height','per_m_height') THEN
      v_multiplier := COALESCE(p_height_m, 0);
    ELSIF v_qty_type IN ('per_area','per_sqm','per_m2') THEN
      v_multiplier := COALESCE(p_area_sqm, COALESCE(p_width_m,0) * COALESCE(p_height_m,0));
    ELSE
      v_multiplier := 1;
    END IF;

    v_qty := round(COALESCE(v_qty_value,1) * COALESCE(v_multiplier,1), 4);

    component_item_id := v_component_item_id;

    -- category_id (si CatalogItems la tiene como item_category_id)
    SELECT ci.item_category_id
    INTO category_id
    FROM public."CatalogItems" ci
    WHERE ci.id = v_component_item_id
    LIMIT 1;

    basis := v_basis;
    unit_cost := v_unit_cost;
    qty := v_qty;
    extended_cost := round(v_unit_cost * v_qty, 4);

    RETURN NEXT;
  END LOOP;

  RETURN;
END;
$$;


ALTER FUNCTION "public"."calculate_bom_price"("p_parent_item_id" "uuid", "p_organization_id" "uuid", "p_width_m" numeric, "p_height_m" numeric, "p_area_sqm" numeric) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."calculate_bom_price"("p_parent_item_id" "uuid", "p_organization_id" "uuid", "p_width_m" numeric, "p_height_m" numeric, "p_area_sqm" numeric) IS 'Explode BOMComponents for a parent item and compute extended costs using get_catalog_item_unit_cost_norm(). Supports qty_type (per_width/per_height/per_area/per_unit).';



CREATE OR REPLACE FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_cp RECORD;
  v_bom_instance_id uuid;
  v_part RECORD;
  v_config jsonb;

  v_roll_msrp_unit numeric := 0;
  v_roll_cost_unit numeric := 0;
  v_roll_factor numeric := 0;
  v_roll_msrp_total numeric := 0;
  v_roll_total_cost numeric := 0;

  v_roll_pricing_mode text;
  v_roll_measure_basis text;
  v_roll_width_m numeric := 0;
  v_height_m numeric := 0;
  v_qty numeric := 1;

  v_bom_msrp numeric := 0;
  v_bom_total_cost numeric := 0;
  v_part_msrp numeric;
  v_part_total_cost numeric;

  v_roll_plus_bom_total numeric := 0;
  v_labor_amount numeric := 0;
  v_accessories_total numeric := 0;
  v_total_msrp numeric := 0;
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  v_config := COALESCE(v_cp.config_snapshot, '{}'::jsonb);

  -- Compute accessories_total from config_snapshot->'accessories' (array of { id, name, qty, price })
  IF jsonb_typeof(v_config->'accessories') = 'array' THEN
    SELECT COALESCE(SUM(
      (elem->>'price')::numeric * GREATEST(COALESCE((elem->>'qty')::numeric, 0), 0)
    ), 0) INTO v_accessories_total
    FROM jsonb_array_elements(v_config->'accessories') AS elem;
  ELSE
    v_accessories_total := COALESCE(v_cp.accessories_total, 0);
  END IF;
  v_accessories_total := ROUND(v_accessories_total, 2);

  -- Locate latest BOMInstance for this configured product (may be NULL for previews)
  SELECT bi.id INTO v_bom_instance_id
  FROM public."BOMInstances" bi
  WHERE bi.configured_product_id = p_configured_product_id
    AND bi.organization_id = v_cp.organization_id
    AND bi.deleted = false
    AND bi.archived = false
  ORDER BY bi.created_at DESC
  LIMIT 1;

  -- Roll totals
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT msrp, total_cost
      INTO v_roll_msrp_unit, v_roll_cost_unit
    FROM public."CatalogItemsMSRP"
    WHERE catalog_item_id = v_cp.roll_catalog_item_id
      AND organization_id = v_cp.organization_id
    LIMIT 1;

    IF v_roll_msrp_unit IS NULL THEN
      SELECT msrp, total_cost
        INTO v_roll_msrp_unit, v_roll_cost_unit
      FROM public."CatalogItemsMSRP"
      WHERE catalog_item_id = v_cp.roll_catalog_item_id
      LIMIT 1;
    END IF;

    SELECT ci.roll_pricing_mode, ci.measure_basis
      INTO v_roll_pricing_mode, v_roll_measure_basis
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
    LIMIT 1;

    v_roll_width_m := COALESCE(v_cp.roll_width, 0);
    v_height_m := COALESCE(v_cp.height_mm, 0) / 1000.0;
    v_qty := COALESCE(v_cp.quantity, 1);

    IF v_roll_pricing_mode = 'per_unit' THEN
      v_roll_factor := v_qty;
    ELSIF v_roll_pricing_mode = 'per_linear_meter' OR v_roll_measure_basis = 'linear' THEN
      v_roll_factor := v_height_m * v_qty;
    ELSE
      v_roll_factor := (v_roll_width_m * v_height_m) * v_qty;
    END IF;

    v_roll_msrp_total := COALESCE(v_roll_msrp_unit, 0) * v_roll_factor;
    v_roll_total_cost := COALESCE(v_roll_cost_unit, 0) * v_roll_factor;
  END IF;

  -- BOM totals (components)
  IF v_bom_instance_id IS NOT NULL THEN
    FOR v_part IN
      SELECT bil.resolved_part_id, bil.qty
      FROM public."BOMInstanceLines" bil
      WHERE bil.bom_instance_id = v_bom_instance_id
        AND bil.deleted = false
        AND bil.archived = false
        AND bil.resolved_part_id IS NOT NULL
    LOOP
      SELECT msrp, total_cost
        INTO v_part_msrp, v_part_total_cost
      FROM public."CatalogItemsMSRP"
      WHERE catalog_item_id = v_part.resolved_part_id
        AND organization_id = v_cp.organization_id
      LIMIT 1;

      IF v_part_msrp IS NULL THEN
        SELECT msrp, total_cost
          INTO v_part_msrp, v_part_total_cost
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_part.resolved_part_id
        LIMIT 1;
      END IF;

      v_bom_msrp := v_bom_msrp + (COALESCE(v_part_msrp, 0) * COALESCE(v_part.qty, 0));
      v_bom_total_cost := v_bom_total_cost + (COALESCE(v_part_total_cost, 0) * COALESCE(v_part.qty, 0));
    END LOOP;
  END IF;

  v_roll_plus_bom_total := v_roll_msrp_total + v_bom_msrp;
  v_labor_amount := v_roll_plus_bom_total * (COALESCE(v_cp.labor_pct, 0) / 100.0);
  v_total_msrp := v_roll_plus_bom_total + v_accessories_total + v_labor_amount;

  -- Persist back to ConfiguredProducts (including accessories_total from config_snapshot)
  UPDATE public."ConfiguredProducts"
  SET
    roll_msrp_total = v_roll_msrp_total,
    roll_total_cost = v_roll_total_cost,
    bom_total = v_bom_msrp,
    bom_total_cost = v_bom_total_cost,
    roll_plus_bom_total = v_roll_plus_bom_total,
    labor_amount = v_labor_amount,
    accessories_total = v_accessories_total,
    total_msrp = v_total_msrp,
    updated_at = now()
  WHERE id = p_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id', p_configured_product_id,
    'bom_instance_id', v_bom_instance_id,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_msrp,
    'roll_plus_bom_total', v_roll_plus_bom_total,
    'labor_amount', v_labor_amount,
    'accessories_total', v_accessories_total,
    'total_msrp', v_total_msrp,
    'roll_total_cost', v_roll_total_cost,
    'bom_total_cost', v_bom_total_cost,
    'total_cost', (v_roll_total_cost + v_bom_total_cost)
  );
END;
$$;


ALTER FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") IS 'Recalculates ConfiguredProduct totals (roll, BOM, labor, accessories, total_msrp) and persists them. accessories_total is computed from config_snapshot->accessories (array of { id, name, qty, price }) when present.';



CREATE OR REPLACE FUNCTION "public"."catalogitems_set_to_base_factor"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.sku := btrim(NEW.sku);

  IF NEW.measure_basis = 'linear' AND NEW.purchase_uom IN ('m','yd','ft') THEN
    IF NEW.purchase_uom = 'm'  THEN NEW.to_base_m_factor := 1.0; END IF;
    IF NEW.purchase_uom = 'yd' THEN NEW.to_base_m_factor := 0.9144; END IF;
    IF NEW.purchase_uom = 'ft' THEN NEW.to_base_m_factor := 0.3048; END IF;
  ELSE
    NEW.to_base_m_factor := NULL;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."catalogitems_set_to_base_factor"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."catalogitems_sync_roll_dimensions"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- ---- WIDTH -> meters ----
  IF NEW.roll_width_value IS NOT NULL AND NEW.roll_width_uom IS NOT NULL THEN
    NEW.roll_width_m :=
      CASE NEW.roll_width_uom
        WHEN 'm'  THEN NEW.roll_width_value
        WHEN 'yd' THEN NEW.roll_width_value * 0.9144
        WHEN 'ft' THEN NEW.roll_width_value * 0.3048
        WHEN 'in' THEN NEW.roll_width_value * 0.0254
      END;
  END IF;

  -- ---- LENGTH -> meters ----
  IF NEW.roll_length_value IS NOT NULL AND NEW.roll_length_uom IS NOT NULL THEN
    NEW.roll_length_m :=
      CASE NEW.roll_length_uom
        WHEN 'm'  THEN NEW.roll_length_value
        WHEN 'yd' THEN NEW.roll_length_value * 0.9144
        WHEN 'ft' THEN NEW.roll_length_value * 0.3048
        WHEN 'in' THEN NEW.roll_length_value * 0.0254
      END;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."catalogitems_sync_roll_dimensions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."catalogitemsmsrp_guard_not_null"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.dealer_price := COALESCE(NEW.dealer_price, 0);
  NEW.msrp         := COALESCE(NEW.msrp, 0);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."catalogitemsmsrp_guard_not_null"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."clear_my_must_change_password"() RETURNS TABLE("org_updated" integer, "portal_updated" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_org integer := 0;
  v_portal integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT 0, 0;
    RETURN;
  END IF;

  UPDATE public."OrganizationUsers"
  SET must_change_password = false,
      updated_at = now()
  WHERE user_id = v_uid
    AND deleted = false
    AND must_change_password = true;

  GET DIAGNOSTICS v_org = ROW_COUNT;

  UPDATE public."CompanyPortalUsers"
  SET must_change_password = false,
      updated_at = now()
  WHERE user_id = v_uid
    AND deleted = false
    AND must_change_password = true;

  GET DIAGNOSTICS v_portal = ROW_COUNT;

  RETURN QUERY SELECT v_org, v_portal;
END;
$$;


ALTER FUNCTION "public"."clear_my_must_change_password"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."commit_configured_product_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_configured_product_id" "uuid", "p_dealer_id" "uuid" DEFAULT NULL::"uuid", "p_position" "text" DEFAULT NULL::"text", "p_area" "text" DEFAULT NULL::"text", "p_fabric_drop" "text" DEFAULT NULL::"text", "p_installation_type" "text" DEFAULT NULL::"text", "p_installation_location" "text" DEFAULT NULL::"text") RETURNS TABLE("quote_line_id" "uuid", "bom_instance_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_cp RECORD;
  v_quote_line_id uuid;
  v_bom_instance_id uuid;
  v_width_m numeric(12,4);
  v_height_m numeric(12,4);
  v_roll_item RECORD;
  v_operating_type text;
  v_fabric_drop text;
  v_installation_type text;
  v_installation_location text;
  v_roll_msrp_total numeric(12,4);
  v_bom_total numeric(12,4);
  v_total_msrp numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_roll_total_cost numeric(12,4);
  v_bom_total_cost numeric(12,4);
  v_labor_amount numeric(12,4);
  v_accessories_total numeric(12,4);
  v_snapshot jsonb;
  v_snapshot_totals jsonb;
  v_recalc jsonb;
BEGIN
  IF p_org_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_org_id is required'; END IF;
  IF p_quote_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_quote_id is required'; END IF;
  IF p_configured_product_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_configured_product_id is required'; END IF;

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id AND organization_id = p_org_id AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found or does not belong to org %', p_configured_product_id, p_org_id;
  END IF;
  IF v_cp.bom_template_id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % has no bom_template_id', p_configured_product_id;
  END IF;

  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := v_snapshot->'totals';
  v_roll_msrp_total := 0; v_bom_total := 0; v_roll_total_cost := 0; v_bom_total_cost := 0;
  v_labor_amount := 0; v_accessories_total := 0; v_total_msrp := 0;

  IF v_snapshot->>'version' = '1' AND jsonb_array_length(v_snapshot->'items') > 0 THEN
    SELECT COALESCE(SUM((item->>'line_total')::numeric), 0) INTO v_roll_msrp_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item WHERE item->>'kind' = 'roll';
    SELECT COALESCE(SUM(
      (item->>'line_total')::numeric + COALESCE((SELECT SUM((c->>'line_total')::numeric) FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c), 0)
    ), 0) INTO v_bom_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item WHERE item->>'kind' = 'parent';
    v_labor_amount := COALESCE((v_snapshot_totals->>'labor_amount')::numeric, 0);
    v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, 0);
    v_roll_total_cost := COALESCE((v_snapshot_totals->>'roll_total_cost')::numeric, 0);
    v_bom_total_cost := COALESCE((v_snapshot_totals->>'bom_total_cost')::numeric, 0);
  ELSIF v_snapshot->>'version' = '1' AND v_snapshot_totals IS NOT NULL THEN
    v_roll_msrp_total := COALESCE((v_snapshot_totals->>'roll_msrp_total')::numeric, 0);
    v_bom_total := COALESCE((v_snapshot_totals->>'bom_total')::numeric, 0);
    v_roll_total_cost := COALESCE((v_snapshot_totals->>'roll_total_cost')::numeric, 0);
    v_bom_total_cost := COALESCE((v_snapshot_totals->>'bom_total_cost')::numeric, 0);
    v_labor_amount := COALESCE((v_snapshot_totals->>'labor_amount')::numeric, 0);
    v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, 0);
    v_total_msrp := COALESCE((v_snapshot_totals->>'total_msrp')::numeric, 0);
  ELSE
    v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0);
    v_bom_total := COALESCE(v_cp.bom_total, 0);
    v_roll_total_cost := COALESCE(v_cp.roll_total_cost, 0);
    v_bom_total_cost := COALESCE(v_cp.bom_total_cost, 0);
    v_labor_amount := COALESCE(v_cp.labor_amount, 0);
    v_accessories_total := COALESCE(v_cp.accessories_total, 0);
    v_total_msrp := COALESCE(v_cp.total_msrp, 0);
  END IF;

  v_total_msrp := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total;

  IF (v_total_msrp IS NULL OR v_total_msrp = 0) THEN
    BEGIN
      v_recalc := public.calculate_configured_product_totals(p_configured_product_id);
      IF v_recalc IS NOT NULL AND NOT (v_recalc ? 'error') THEN
        v_roll_msrp_total := COALESCE((v_recalc->>'roll_msrp_total')::numeric, 0);
        v_bom_total := COALESCE((v_recalc->>'bom_total')::numeric, 0);
        v_roll_total_cost := COALESCE((v_recalc->>'roll_total_cost')::numeric, 0);
        v_bom_total_cost := COALESCE((v_recalc->>'bom_total_cost')::numeric, 0);
        v_labor_amount := COALESCE((v_recalc->>'labor_amount')::numeric, 0);
        v_accessories_total := COALESCE((v_recalc->>'accessories_total')::numeric, 0);
        v_total_msrp := COALESCE((v_recalc->>'total_msrp')::numeric, 0);
        IF v_total_msrp = 0 THEN v_total_msrp := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total; END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;

  v_unit_msrp := v_total_msrp / NULLIF(COALESCE(v_cp.quantity, 1), 0);

  v_width_m := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m := COALESCE(v_cp.height_mm / 1000.0, 0);
  v_operating_type := COALESCE(
    v_cp.config_snapshot->>'operating_type',
    v_cp.config_snapshot->>'drive_type',
    v_cp.config_snapshot->>'operation_type'
  );
  IF v_operating_type IS NOT NULL THEN
    v_operating_type := lower(trim(v_operating_type));
    IF v_operating_type IN ('motorized', 'motorised') THEN v_operating_type := 'motor'; END IF;
  END IF;

  v_fabric_drop := COALESCE(p_fabric_drop, v_cp.config_snapshot->>'fabricDrop', v_cp.config_snapshot->>'drop_type');
  v_installation_type := COALESCE(p_installation_type, v_cp.config_snapshot->>'installationType');
  v_installation_location := COALESCE(p_installation_location, v_cp.config_snapshot->>'installationLocation');

  SELECT ci.sku, ci.name, ci.category_id, ci.manufacturer_id, m.name as manufacturer_name,
         ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width) as roll_width_m
  INTO v_roll_item
  FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id AND ci.is_active = true LIMIT 1;

  INSERT INTO public."QuoteLines" (
    organization_id, dealer_id, quote_id,
    product_type_id, configured_product_id, bom_template_id,
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer, collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity,
    hardware_color, drive_type,
    position, area,
    fabric_drop, installation_type, installation_location,
    roll_msrp_snapshot, bom_msrp_snapshot, roll_cost_snapshot, bom_cost_snapshot, unit_msrp, msrp, total_cost,
    pricing_locked, last_priced_at, pricing_version
  )
  VALUES (
    p_org_id, COALESCE(p_dealer_id, (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)), p_quote_id,
    v_cp.product_type_id, v_cp.id, v_cp.bom_template_id,
    v_cp.roll_catalog_item_id, COALESCE(v_cp.roll_sku, v_roll_item.sku), v_roll_item.name, v_roll_item.category_id, v_roll_item.manufacturer_id, v_roll_item.manufacturer_name,
    COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name), COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name),
    v_cp.roll_catalog_item_id IS NOT NULL, CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END, COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    v_width_m, v_height_m, COALESCE(v_cp.quantity, 1),
    v_cp.hardware_color, v_operating_type,
    p_position, p_area,
    v_fabric_drop, v_installation_type, v_installation_location,
    v_roll_msrp_total, v_bom_total, v_roll_total_cost, v_bom_total_cost, v_unit_msrp, v_total_msrp, v_roll_total_cost + v_bom_total_cost + v_labor_amount,
    true, now(), 1
  )
  RETURNING id INTO v_quote_line_id;

  IF v_quote_line_id IS NULL THEN RAISE EXCEPTION 'Failed to insert QuoteLine for ConfiguredProduct %', p_configured_product_id; END IF;
  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;


ALTER FUNCTION "public"."commit_configured_product_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_configured_product_id" "uuid", "p_dealer_id" "uuid", "p_position" "text", "p_area" "text", "p_fabric_drop" "text", "p_installation_type" "text", "p_installation_location" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."commit_configured_product_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_configured_product_id" "uuid", "p_dealer_id" "uuid", "p_position" "text", "p_area" "text", "p_fabric_drop" "text", "p_installation_type" "text", "p_installation_location" "text") IS 'Creates QuoteLine from ConfiguredProduct. Uses p_dealer_id.';



CREATE OR REPLACE FUNCTION "public"."compute_quote_line_cost"("p_quote_line_id" "uuid", "p_options" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_quote_line_record RECORD;
    v_cost_settings_record RECORD;
    v_catalog_item_record RECORD;
    v_conversions_record RECORD;
    v_existing_cost_record RECORD;
    v_component_record RECORD;
    v_bom_component_record RECORD;
    v_category_tax_record RECORD;
    v_base_material_cost numeric(12,4) := 0;
    v_labor_cost numeric(12,4) := 0;
    v_shipping_cost numeric(12,4) := 0;
    v_import_tax_cost numeric(12,4) := 0;
    v_total_cost numeric(12,4) := 0;
    v_quote_line_cost_id uuid;
    v_reset_labor boolean := COALESCE((p_options->>'reset_labor')::boolean, false);
    v_reset_shipping boolean := COALESCE((p_options->>'reset_shipping')::boolean, false);
    v_reset_import_tax boolean := COALESCE((p_options->>'reset_import_tax')::boolean, false);
    v_labor_percentage numeric(8,4) := 10.0000;
    v_shipping_percentage numeric(8,4) := 15.0000;
    v_global_import_tax_percentage numeric(8,4) := 0;
    v_labor_source text := 'auto';
    v_shipping_source text := 'auto';
    v_import_tax_source text := 'auto';
    v_unit_cost numeric(12,4);
    v_extended_cost numeric(12,4);
    v_category_tax_percentage numeric(8,4);
    v_category_tax_amount numeric(12,4);
    v_has_bom boolean := false;
    v_category_cost_map jsonb := '{}'::jsonb;
    v_category_id uuid;
    v_category_extended_cost numeric(12,4);
    v_area_sqm numeric;
    v_category_key text;
    v_category_value text;
    v_breakdown_key text;
    v_breakdown_value text;
    v_import_tax_pct_raw numeric(8,4);
BEGIN
    -- Step 1: Load QuoteLine + organization_id + dimensions
    SELECT 
        ql.id,
        ql.organization_id,
        ql.quote_id,
        ql.catalog_item_id,
        ql.qty,
        ql.computed_qty,
        ql.width_m,
        ql.height_m,
        q.currency
    INTO v_quote_line_record
    FROM "QuoteLines" ql
    INNER JOIN "Quotes" q ON q.id = ql.quote_id
    WHERE ql.id = p_quote_line_id
    AND ql.deleted = false
    AND q.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'QuoteLine with id % not found or deleted', p_quote_line_id;
    END IF;
    
    -- Step 2: Check if catalog_item_id has a BOM
    SELECT EXISTS (
        SELECT 1
        FROM "BOMComponents" bom
        WHERE bom.parent_item_id = v_quote_line_record.catalog_item_id
        AND bom.organization_id = v_quote_line_record.organization_id
        AND bom.deleted = false
    ) INTO v_has_bom;
    
    -- Step 3: Calculate base_material_cost (unchanged - keep existing logic from dump)
    IF v_has_bom THEN
        v_area_sqm := CASE 
            WHEN v_quote_line_record.width_m IS NOT NULL 
                 AND v_quote_line_record.height_m IS NOT NULL 
            THEN v_quote_line_record.width_m * v_quote_line_record.height_m
            ELSE NULL
        END;
        
        FOR v_bom_component_record IN
            SELECT * FROM calculate_bom_price(
                v_quote_line_record.catalog_item_id,
                v_quote_line_record.organization_id,
                v_quote_line_record.width_m,
                v_quote_line_record.height_m,
                v_area_sqm
            )
        LOOP
            v_base_material_cost := v_base_material_cost + v_bom_component_record.extended_cost;
            IF v_bom_component_record.category_id IS NOT NULL THEN
                v_category_id := v_bom_component_record.category_id;
                v_category_extended_cost := COALESCE((v_category_cost_map->>v_category_id::text)::numeric, 0);
                v_category_extended_cost := v_category_extended_cost + v_bom_component_record.extended_cost;
                v_category_cost_map := jsonb_set(
                    v_category_cost_map,
                    ARRAY[v_category_id::text],
                    to_jsonb(v_category_extended_cost)
                );
            END IF;
        END LOOP;
        
        v_base_material_cost := v_base_material_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
        v_category_cost_map := (
            SELECT jsonb_object_agg(key, value::numeric * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1))
            FROM jsonb_each_text(v_category_cost_map)
        );
        
    ELSE
        SELECT SUM(COALESCE(qlc.unit_cost_exw, ci.cost_exw, 0) * qlc.qty)
        INTO v_base_material_cost
        FROM "QuoteLineComponents" qlc
        LEFT JOIN "CatalogItems" ci ON qlc.catalog_item_id = ci.id
        WHERE qlc.quote_line_id = p_quote_line_id
        AND qlc.deleted = false;
        
        IF v_base_material_cost IS NULL OR v_base_material_cost = 0 THEN
            SELECT 
                ci.id,
                ci.cost_exw,
                ci.is_roll,
                ci.roll_pricing_mode,
                ci.measure_basis,
                ci.unit_of_measure,
                ci.category_id,
                conv.cost_exw_per_m,
                conv.cost_exw_per_m2,
                conv.cost_exw_per_ea
            INTO v_catalog_item_record
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemConversions" conv 
                ON conv.catalog_item_id = ci.id 
                AND conv.organization_id = ci.organization_id
            WHERE ci.id = v_quote_line_record.catalog_item_id
            AND ci.is_active = true;
            
            IF FOUND THEN
                IF v_catalog_item_record.is_roll = true AND v_catalog_item_record.roll_pricing_mode IS NOT NULL THEN
                    IF v_catalog_item_record.roll_pricing_mode = 'per_linear_meter' THEN
                        v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_m, v_catalog_item_record.cost_exw, 0);
                        v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                    ELSIF v_catalog_item_record.roll_pricing_mode = 'per_square_meter' THEN
                        v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_m2, v_catalog_item_record.cost_exw, 0);
                        v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                    ELSIF v_catalog_item_record.roll_pricing_mode = 'per_unit' THEN
                        v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_ea, v_catalog_item_record.cost_exw, 0);
                        v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.qty, 1);
                    ELSE
                        v_base_material_cost := COALESCE(v_catalog_item_record.cost_exw, 0) * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                    END IF;
                ELSIF v_catalog_item_record.measure_basis = 'linear' THEN
                    v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_m, v_catalog_item_record.cost_exw, 0);
                    v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                ELSIF v_catalog_item_record.measure_basis = 'area' THEN
                    v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_m2, v_catalog_item_record.cost_exw, 0);
                    v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                ELSIF v_catalog_item_record.measure_basis = 'unit' THEN
                    v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_ea, v_catalog_item_record.cost_exw, 0);
                    v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.qty, 1);
                ELSE
                    v_base_material_cost := COALESCE(v_catalog_item_record.cost_exw, 0) * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                END IF;
            ELSE
                v_base_material_cost := 0;
            END IF;
        END IF;
        
        FOR v_component_record IN
            SELECT 
                qlc.catalog_item_id,
                COALESCE(qlc.unit_cost_exw, ci.cost_exw, 0) as unit_cost,
                qlc.qty,
                ci.item_category_id,
                ic.name as category_name
            FROM "QuoteLineComponents" qlc
            LEFT JOIN "CatalogItems" ci ON qlc.catalog_item_id = ci.id
            LEFT JOIN "ItemCategories" ic ON ci.item_category_id = ic.id
            WHERE qlc.quote_line_id = p_quote_line_id
            AND qlc.deleted = false
        LOOP
            IF v_component_record.item_category_id IS NOT NULL THEN
                v_category_id := v_component_record.item_category_id;
                v_category_extended_cost := COALESCE((v_category_cost_map->>v_category_id::text)::numeric, 0);
                v_category_extended_cost := v_category_extended_cost + (v_component_record.unit_cost * v_component_record.qty);
                v_category_cost_map := jsonb_set(
                    v_category_cost_map,
                    ARRAY[v_category_id::text],
                    to_jsonb(v_category_extended_cost)
                );
            END IF;
        END LOOP;
    END IF;
    
    -- Step 4: Load CostSettings (actual columns: labor_pct, shipping_pct, global_import_tax_pct; no id, no currency_code, no deleted)
    SELECT 
        labor_pct,
        shipping_pct,
        global_import_tax_pct
    INTO v_cost_settings_record
    FROM "CostSettings"
    WHERE organization_id = v_quote_line_record.organization_id
    AND is_active = true
    LIMIT 1;
    
    IF FOUND THEN
        -- DB stores 0-1 (e.g. 0.10); formula expects 0-100
        v_labor_percentage := COALESCE(v_cost_settings_record.labor_pct, 0.10) * 100.0;
        v_shipping_percentage := COALESCE(v_cost_settings_record.shipping_pct, 0.15) * 100.0;
        v_global_import_tax_percentage := COALESCE(v_cost_settings_record.global_import_tax_pct, 0) * 100.0;
    END IF;
    
    -- Step 5: Check for existing QuoteLineCosts to preserve manual overrides
    SELECT * INTO v_existing_cost_record
    FROM "QuoteLineCosts"
    WHERE quote_line_id = p_quote_line_id
    AND deleted = false
    LIMIT 1;
    
    -- Step 6: Calculate labor and shipping costs
    IF v_existing_cost_record.id IS NOT NULL THEN
        IF v_existing_cost_record.labor_source = 'manual' AND NOT v_reset_labor THEN
            v_labor_cost := v_existing_cost_record.labor_cost;
            v_labor_source := 'manual';
        ELSE
            v_labor_cost := v_base_material_cost * (v_labor_percentage / 100.0);
            v_labor_source := 'auto';
        END IF;
        
        IF v_existing_cost_record.shipping_source = 'manual' AND NOT v_reset_shipping THEN
            v_shipping_cost := v_existing_cost_record.shipping_cost;
            v_shipping_source := 'manual';
        ELSE
            v_shipping_cost := v_base_material_cost * (v_shipping_percentage / 100.0);
            v_shipping_source := 'auto';
        END IF;
    ELSE
        v_labor_cost := v_base_material_cost * (v_labor_percentage / 100.0);
        v_shipping_cost := v_base_material_cost * (v_shipping_percentage / 100.0);
    END IF;
    
    -- Step 7: Calculate Import Tax by category (ImportTaxRules uses import_tax_pct 0-1, no deleted)
    IF v_existing_cost_record.id IS NOT NULL 
       AND v_existing_cost_record.import_tax_source = 'manual' 
       AND NOT v_reset_import_tax THEN
        v_import_tax_cost := v_existing_cost_record.import_tax_cost;
        v_import_tax_source := 'manual';
    ELSE
        v_import_tax_cost := 0;
        
        FOR v_category_key, v_category_value IN
            SELECT key, value
            FROM jsonb_each_text(v_category_cost_map)
        LOOP
            v_category_id := v_category_key::uuid;
            v_category_extended_cost := v_category_value::numeric;
            
            v_category_tax_percentage := NULL;
            SELECT import_tax_pct INTO v_import_tax_pct_raw
            FROM "ImportTaxRules"
            WHERE organization_id = v_quote_line_record.organization_id
            AND category_id = v_category_id
            AND is_active = true
            LIMIT 1;
            
            IF v_import_tax_pct_raw IS NOT NULL THEN
                v_category_tax_percentage := v_import_tax_pct_raw * 100.0;
            ELSE
                v_category_tax_percentage := v_global_import_tax_percentage;
            END IF;
            
            v_category_tax_amount := v_category_extended_cost * (v_category_tax_percentage / 100.0);
            v_import_tax_cost := v_import_tax_cost + v_category_tax_amount;
        END LOOP;
        
        v_import_tax_source := 'auto';
    END IF;
    
    -- Step 8: Calculate total_cost
    v_total_cost := v_base_material_cost + v_labor_cost + v_shipping_cost + v_import_tax_cost;
    
    -- Step 9: Upsert into QuoteLineCosts (currency from Quotes)
    INSERT INTO "QuoteLineCosts" (
        organization_id,
        quote_id,
        quote_line_id,
        currency_code,
        base_material_cost,
        labor_cost,
        shipping_cost,
        import_tax_cost,
        labor_source,
        shipping_source,
        import_tax_source,
        total_cost
    )
    VALUES (
        v_quote_line_record.organization_id,
        v_quote_line_record.quote_id,
        p_quote_line_id,
        v_quote_line_record.currency,
        v_base_material_cost,
        v_labor_cost,
        v_shipping_cost,
        v_import_tax_cost,
        v_labor_source,
        v_shipping_source,
        v_import_tax_source,
        v_total_cost
    )
    ON CONFLICT (quote_line_id) 
    DO UPDATE SET
        base_material_cost = EXCLUDED.base_material_cost,
        labor_cost = EXCLUDED.labor_cost,
        shipping_cost = EXCLUDED.shipping_cost,
        import_tax_cost = EXCLUDED.import_tax_cost,
        labor_source = EXCLUDED.labor_source,
        shipping_source = EXCLUDED.shipping_source,
        import_tax_source = EXCLUDED.import_tax_source,
        total_cost = EXCLUDED.total_cost,
        updated_at = now()
    RETURNING id INTO v_quote_line_cost_id;
    
    -- Step 10: Update QuoteLineImportTaxBreakdown (if using BOM) - use import_tax_pct * 100 for percentage
    IF v_has_bom THEN
        DELETE FROM "QuoteLineImportTaxBreakdown"
        WHERE quote_line_id = p_quote_line_id
        AND deleted = false;
        
        FOR v_breakdown_key, v_breakdown_value IN
            SELECT key, value
            FROM jsonb_each_text(v_category_cost_map)
        LOOP
            v_category_id := v_breakdown_key::uuid;
            v_category_extended_cost := v_breakdown_value::numeric;
            
            SELECT name INTO v_category_tax_record.category_name
            FROM "ItemCategories"
            WHERE id = v_category_id
            AND deleted = false
            LIMIT 1;
            
            v_category_tax_percentage := NULL;
            SELECT import_tax_pct INTO v_import_tax_pct_raw
            FROM "ImportTaxRules"
            WHERE organization_id = v_quote_line_record.organization_id
            AND category_id = v_category_id
            AND is_active = true
            LIMIT 1;
            
            IF v_import_tax_pct_raw IS NOT NULL THEN
                v_category_tax_percentage := v_import_tax_pct_raw * 100.0;
            ELSE
                v_category_tax_percentage := v_global_import_tax_percentage;
            END IF;
            
            INSERT INTO "QuoteLineImportTaxBreakdown" (
                organization_id,
                quote_line_id,
                category_id,
                category_name,
                extended_cost,
                import_tax_percentage,
                import_tax_amount
            )
            VALUES (
                v_quote_line_record.organization_id,
                p_quote_line_id,
                v_category_id,
                COALESCE(v_category_tax_record.category_name, 'Unknown'),
                v_category_extended_cost,
                v_category_tax_percentage,
                v_category_extended_cost * (v_category_tax_percentage / 100.0)
            );
        END LOOP;
    END IF;
    
    RETURN v_quote_line_cost_id;
END;
$$;


ALTER FUNCTION "public"."compute_quote_line_cost"("p_quote_line_id" "uuid", "p_options" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."compute_quote_line_cost"("p_quote_line_id" "uuid", "p_options" "jsonb") IS 'Calculates quote line costs. Uses CostSettings.labor_pct, shipping_pct, global_import_tax_pct (0-1) and ImportTaxRules.import_tax_pct (0-1).';



CREATE OR REPLACE FUNCTION "public"."compute_roll_conversions"("p_cost_exw" numeric, "p_uom" "text", "p_roll_width" numeric) RETURNS TABLE("cost_exw_per_m" numeric, "cost_exw_per_m2" numeric)
    LANGUAGE "sql" IMMUTABLE
    AS $$
  with base as (
    select public.cost_to_per_m(p_cost_exw, p_uom) as per_m
  )
  select
    per_m,
    case
      when per_m is null then null
      when p_roll_width is null or p_roll_width <= 0 then null
      else (per_m / p_roll_width)
    end
  from base;
$$;


ALTER FUNCTION "public"."compute_roll_conversions"("p_cost_exw" numeric, "p_uom" "text", "p_roll_width" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cost_to_per_m"("p_cost" numeric, "p_uom" "text") RETURNS numeric
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select
    case
      when p_cost is null then null
      when lower(coalesce(p_uom,'')) in ('yd','yard','yards') then (p_cost / 0.9144)
      when lower(coalesce(p_uom,'')) in ('m','meter','meters','mt') then p_cost
      else null
    end;
$$;


ALTER FUNCTION "public"."cost_to_per_m"("p_cost" numeric, "p_uom" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid" DEFAULT NULL::"uuid", "p_quote_line_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
  v_labor_pct numeric(12,4);
BEGIN
  SELECT COALESCE(cs.labor_pct, 0) INTO v_labor_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_org_id
  LIMIT 1;
  IF v_labor_pct IS NULL THEN
    v_labor_pct := 0;
  END IF;

  v_bom_template_id := (p_config_snapshot->>'bom_template_id')::uuid;

  IF v_bom_template_id IS NULL THEN
    BEGIN
      SELECT public.select_best_bom_template_v2_strict(
        p_org_id,
        p_product_type_id,
        p_config_snapshot
      ) INTO v_bom_template_id;
    EXCEPTION WHEN OTHERS THEN
      v_bom_template_id := NULL;
    END;
  END IF;

  IF v_bom_template_id IS NULL THEN
    RAISE EXCEPTION 'No matching BOMTemplate found for product_type_id=% with config=%',
      p_product_type_id, p_config_snapshot::text;
  END IF;

  v_hardware_color := COALESCE(
    p_config_snapshot->>'hardware_color',
    p_config_snapshot->>'hardwareColor'
  );
  v_fabric_item_id := (p_config_snapshot->>'variantId')::uuid;
  IF v_fabric_item_id IS NULL THEN
    v_fabric_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid;
  END IF;

  -- Use total width when multi-panel (config_snapshot.measurements.width_total_mm)
  v_width_mm := COALESCE(
    (p_config_snapshot->'measurements'->>'width_total_mm')::numeric(12,4),
    (p_config_snapshot->>'width_mm')::numeric(12,4)
  );
  v_height_mm := (p_config_snapshot->>'height_mm')::numeric(12,4);
  v_quantity := COALESCE((p_config_snapshot->>'quantity')::numeric(12,4), 1);

  IF v_fabric_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.collection_name, ci.variant_name, ci.roll_width
      INTO v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width
    FROM public."CatalogItems" ci
    WHERE ci.id = v_fabric_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;
  END IF;

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
    config_snapshot,
    roll_msrp_total,
    bom_total,
    roll_plus_bom_total,
    labor_pct,
    accessories_total,
    total_msrp
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
    p_config_snapshot,
    0, 0, 0,
    v_labor_pct,
    0, 0
  )
  RETURNING id INTO v_configured_product_id;

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

  v_totals := v_preview_snapshot->'totals';
  v_bom_instance_id := NULL;

  RETURN jsonb_build_object(
    'configured_product_id', v_configured_product_id,
    'bom_instance_id', v_bom_instance_id,
    'bom_template_id', v_bom_template_id,
    'totals', v_totals,
    'bom_preview_snapshot', v_preview_snapshot
  );
END;
$$;


ALTER FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") IS 'Creates ConfiguredProduct; width_mm from measurements.width_total_mm when present (multi-panel).';



CREATE OR REPLACE FUNCTION "public"."create_quote_line_cost_snapshot"("p_quote_line_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
declare
  v_org_id uuid;
  v_quote_id uuid;
  v_configured_product_id uuid;
  v_inserted int := 0;
begin
  select ql.organization_id, ql.quote_id, ql.configured_product_id
    into v_org_id, v_quote_id, v_configured_product_id
  from public."QuoteLines" ql
  where ql.id = p_quote_line_id;

  if v_org_id is null then
    raise exception 'QuoteLine not found: %', p_quote_line_id;
  end if;

  if v_configured_product_id is null then
    raise exception 'QuoteLine % has no configured_product_id set', p_quote_line_id;
  end if;

  delete from public."QuoteLineCostLines"
  where quote_line_id = p_quote_line_id;

  insert into public."QuoteLineCostLines" (
    organization_id,
    quote_id,
    quote_line_id,
    "group",
    role,
    sort_order,
    catalog_item_id,
    sku,
    name,
    uom,
    qty,
    unit_cost_exw,
    shipping_unit_cost,
    import_tax_unit_cost,
    landed_unit_cost,
    msrp_unit,
    msrp_line,
    rule_note
  )
  select
    cpl.organization_id,
    v_quote_id,
    p_quote_line_id,
    cpl."group",
    cpl.role,
    cpl.sort_order,
    cpl.catalog_item_id,
    cpl.sku,
    cpl.name,
    cpl.uom,
    cpl.qty,
    cpl.unit_cost_exw,
    cpl.shipping_unit_cost,
    cpl.import_tax_unit_cost,
    cpl.landed_unit_cost,
    cpl.msrp_unit,
    cpl.msrp_line,
    cpl.rule_note
  from public."ConfiguredProductLines" cpl
  where cpl.organization_id = v_org_id
    and cpl.configured_product_id = v_configured_product_id;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;


ALTER FUNCTION "public"."create_quote_line_cost_snapshot"("p_quote_line_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_auth_email"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT lower(nullif(trim(auth.jwt() ->> 'email'), ''));
$$;


ALTER FUNCTION "public"."current_auth_email"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_dealer_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_deleted_count int;
BEGIN
  UPDATE public."DealerUsers"
  SET deleted = true,
      status = 'disabled',
      updated_at = now()
  WHERE id = p_portal_user_id
    AND organization_id = p_organization_id
    AND deleted = false;

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  IF v_deleted_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Portal user not found or already deleted');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;


ALTER FUNCTION "public"."delete_dealer_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."delete_dealer_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") IS 'Soft delete a dealer portal user. Replaces delete_company_portal_user.';



CREATE OR REPLACE FUNCTION "public"."delete_organization_user"("p_org_user_id" "uuid", "p_organization_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_user_role text;
  v_result json;
BEGIN
  -- 1) Verify user is authenticated
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 2) Check if user is superadmin or admin in the organization
  SELECT ou.role::text INTO v_user_role
  FROM public."OrganizationUsers" ou
  WHERE ou.user_id = auth.uid()
    AND ou.organization_id = p_organization_id
    AND ou.deleted = false
    AND ou.status = 'active'
  LIMIT 1;

  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'User not found in organization or not active';
  END IF;

  IF v_user_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Only superadmins and admins can delete users';
  END IF;

  -- 3) Verify the user to delete exists and belongs to the organization
  IF NOT EXISTS (
    SELECT 1
    FROM public."OrganizationUsers"
    WHERE id = p_org_user_id
      AND organization_id = p_organization_id
      AND deleted = false
  ) THEN
    RAISE EXCEPTION 'User not found in organization or already deleted';
  END IF;

  -- 4) Prevent self-deletion
  IF EXISTS (
    SELECT 1
    FROM public."OrganizationUsers"
    WHERE id = p_org_user_id
      AND user_id = auth.uid()
      AND organization_id = p_organization_id
  ) THEN
    RAISE EXCEPTION 'Cannot delete your own account';
  END IF;

  -- 4.5) Prevent deleting the last active superadmin
  IF EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" target
    WHERE target.id = p_org_user_id
      AND target.organization_id = p_organization_id
      AND target.deleted = false
      AND target.status = 'active'
      AND target.role::text = 'superadmin'
  ) THEN
    IF (
      SELECT count(*)
      FROM public."OrganizationUsers" su
      WHERE su.organization_id = p_organization_id
        AND su.deleted = false
        AND su.status = 'active'
        AND su.role::text = 'superadmin'
    ) <= 1 THEN
      RAISE EXCEPTION 'Cannot delete the last active superadmin';
    END IF;
  END IF;

  -- 5) Perform soft delete
  UPDATE public."OrganizationUsers"
  SET 
    deleted = true,
    updated_at = NOW()
  WHERE id = p_org_user_id
    AND organization_id = p_organization_id
    AND deleted = false;

  -- 6) Return success
  SELECT json_build_object(
    'success', true,
    'message', 'User deleted successfully',
    'id', p_org_user_id
  ) INTO v_result;

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'id', p_org_user_id
    );
END;
$$;


ALTER FUNCTION "public"."delete_organization_user"("p_org_user_id" "uuid", "p_organization_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."delete_organization_user"("p_org_user_id" "uuid", "p_organization_id" "uuid") IS 'Soft delete an organization user. Only superadmins/admins can call. Uses SECURITY DEFINER to bypass RLS. Prevents self-deletion and last-superadmin deletion.';



CREATE OR REPLACE FUNCTION "public"."directorycontacts_fill_org_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.organization_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.dealer_id IS NOT NULL THEN
    SELECT d.organization_id INTO NEW.organization_id
    FROM public."Dealers" d
    WHERE d.id = NEW.dealer_id AND d.deleted = false
    LIMIT 1;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."directorycontacts_fill_org_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_active_item_role"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.item_role IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public."CatalogItemRoles" r
      WHERE r.role_code = NEW.item_role
        AND r.active = true
    ) THEN
      RAISE EXCEPTION 'item_role "%" no está activo en CatalogItemRoles', NEW.item_role;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."enforce_active_item_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_mo_dealer_matches_salesorder"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_so_dealer uuid;
BEGIN
  IF NEW.sales_order_id IS NULL THEN
    RAISE EXCEPTION 'ManufacturingOrders.sales_order_id is required';
  END IF;

  SELECT so.dealer_id INTO v_so_dealer FROM public."SalesOrders" so WHERE so.id = NEW.sales_order_id;

  IF v_so_dealer IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.dealer_id IS NULL THEN
    NEW.dealer_id := v_so_dealer;
  END IF;

  IF NEW.dealer_id <> v_so_dealer THEN
    RAISE EXCEPTION 'ManufacturingOrders.dealer_id must match SalesOrders.dealer_id';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."enforce_mo_dealer_matches_salesorder"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_orderlist_dealer_matches_salesorder"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_so_dealer uuid;
BEGIN
  IF NEW.sales_order_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT so.dealer_id INTO v_so_dealer FROM public."SalesOrders" so WHERE so.id = NEW.sales_order_id;

  IF v_so_dealer IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.dealer_id IS NULL THEN
    NEW.dealer_id := v_so_dealer;
  END IF;

  IF NEW.dealer_id <> v_so_dealer THEN
    RAISE EXCEPTION 'OrderList.dealer_id must match SalesOrders.dealer_id';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."enforce_orderlist_dealer_matches_salesorder"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_salesorders_dealer_matches_quote"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_quote_dealer uuid;
BEGIN
  IF NEW.quote_id IS NULL THEN
    RAISE EXCEPTION 'SalesOrders.quote_id is required';
  END IF;

  SELECT q.dealer_id INTO v_quote_dealer FROM public."Quotes" q WHERE q.id = NEW.quote_id;

  IF v_quote_dealer IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.dealer_id IS NULL THEN
    NEW.dealer_id := v_quote_dealer;
  END IF;

  IF NEW.dealer_id <> v_quote_dealer THEN
    RAISE EXCEPTION 'SalesOrders.dealer_id must match Quotes.dealer_id';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."enforce_salesorders_dealer_matches_quote"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fill_msrp_item_identity"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_sku text;
  v_name text;
  v_collection_name text;
  v_variant_name text;
  v_unit_of_measure text;
BEGIN
  IF NEW.sku IS NULL OR NEW.name IS NULL OR NEW.collection_name IS NULL OR NEW.variant_name IS NULL OR NEW.unit_of_measure IS NULL
  THEN
    SELECT ci.sku, ci.name, ci.collection_name, ci.variant_name, ci.unit_of_measure
      INTO v_sku, v_name, v_collection_name, v_variant_name, v_unit_of_measure
      FROM public."CatalogItems" ci
      WHERE ci.id = NEW.catalog_item_id;

    IF NEW.sku IS NULL THEN NEW.sku := v_sku; END IF;
    IF NEW.name IS NULL THEN NEW.name := v_name; END IF;
    IF NEW.collection_name IS NULL THEN NEW.collection_name := v_collection_name; END IF;
    IF NEW.variant_name IS NULL THEN NEW.variant_name := v_variant_name; END IF;
    IF NEW.unit_of_measure IS NULL THEN NEW.unit_of_measure := v_unit_of_measure; END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fill_msrp_item_identity"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fill_msrp_sku_name"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_sku text;
  v_name text;
begin
  -- If already present, keep it (but we can also force overwrite; here we fill if null)
  if new.sku is null or new.name is null then
    select ci.sku, ci.name
      into v_sku, v_name
    from public."CatalogItems" ci
    where ci.id = new.catalog_item_id;

    if new.sku is null then new.sku := v_sku; end if;
    if new.name is null then new.name := v_name; end if;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."fill_msrp_sku_name"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_bom_from_slots"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_template_id uuid;
    v_instance_id uuid;
    v_ql RECORD;
    v_slot RECORD;
    v_component RECORD;
    v_resolved_item uuid;
    v_qty numeric(12,4);
    v_width_mm numeric(12,4);
    v_height_mm numeric(12,4);
    v_unit_cost numeric(12,4);
    v_unit_uom text;
    v_child RECORD;
    v_has_component_rules boolean;
    v_config jsonb;
BEGIN
    SELECT * INTO v_ql
    FROM public."QuoteLines"
    WHERE id = p_quote_line_id
        AND organization_id = p_org_id
        AND deleted = false;

    IF v_ql.id IS NULL THEN
        RAISE EXCEPTION 'QuoteLine not found %', p_quote_line_id;
    END IF;

    v_config := public.build_quote_line_config(p_org_id, p_quote_line_id);
    v_template_id := public.select_best_bom_template(p_org_id, p_product_type_id, v_config);

    IF v_template_id IS NULL THEN
        RAISE EXCEPTION 'No matching BOMTemplate found for org %, product_type %', 
            p_org_id, p_product_type_id;
    END IF;

    UPDATE public."BOMInstances"
        SET deleted = true
    WHERE organization_id = p_org_id
        AND quote_line_id = p_quote_line_id
        AND deleted = false;

    INSERT INTO public."BOMInstances"(
        organization_id, 
        quote_line_id, 
        bom_template_id,
        configured_product_id
    )
    VALUES (p_org_id, p_quote_line_id, v_template_id, NULL)
    RETURNING id INTO v_instance_id;

    v_width_mm := COALESCE(v_ql.width_m, 0) * 1000;
    v_height_mm := COALESCE(v_ql.height_m, 0) * 1000;

    FOR v_slot IN
        SELECT *
        FROM public."BOMTemplateSlots"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
        ORDER BY item_role ASC
    LOOP
        v_resolved_item := v_slot.catalog_item_id;

        SELECT * INTO v_component
        FROM public."BOMComponents"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
            AND component_role = v_slot.item_role
            AND deleted = false
        LIMIT 1;

        v_has_component_rules := (v_component.id IS NOT NULL);

        IF v_has_component_rules THEN
            IF v_component.qty_type = 'fixed' THEN
                v_qty := v_component.qty_value;
            ELSIF v_component.qty_type = 'per_width' THEN
                v_qty := ((v_width_mm + COALESCE(v_component.qty_delta_mm, 0)) / 1000.0) * v_component.qty_value;
            ELSIF v_component.qty_type = 'per_height' THEN
                v_qty := ((v_height_mm + COALESCE(v_component.qty_delta_mm, 0)) / 1000.0) * v_component.qty_value;
            ELSIF v_component.qty_type = 'per_area' THEN
                v_qty := ((v_width_mm/1000.0) * (v_height_mm/1000.0)) * v_component.qty_value;
            ELSE
                v_qty := v_component.qty_value;
            END IF;

            IF v_component.waste_pct IS NOT NULL AND v_component.waste_pct > 0 THEN
                v_qty := v_qty * (1 + v_component.waste_pct);
            END IF;
        ELSE
            v_qty := v_slot.qty;
        END IF;

        IF v_resolved_item IS NOT NULL THEN
            SELECT ci.cost_exw, ci.unit_of_measure INTO v_unit_cost, v_unit_uom
            FROM public."CatalogItems" ci
            WHERE ci.id = v_resolved_item;
            
            v_unit_cost := COALESCE(v_unit_cost, 0);
            v_unit_uom := COALESCE(v_unit_uom, 'ea');
        ELSE
            v_unit_cost := 0;
            v_unit_uom := 'ea';
        END IF;

        IF v_resolved_item IS NOT NULL AND v_qty > 0 THEN
            INSERT INTO public."BOMInstanceLines"(
                organization_id,
                bom_instance_id,
                resolved_part_id,
                part_role,
                qty,
                uom,
                unit_cost_exw,
                deleted
            ) VALUES (
                p_org_id,
                v_instance_id,
                v_resolved_item,
                v_slot.item_role,
                v_qty,
                v_unit_uom,
                v_unit_cost,
                false
            );
        END IF;

        IF v_resolved_item IS NOT NULL THEN
            FOR v_child IN
                WITH bom_override AS (
                    SELECT 
                        bc.component_item_id AS child_item_id,
                        bc.component_role AS child_role,
                        bc.qty_value AS qty,
                        bc.uom,
                        COALESCE(ci.cost_exw, 0) AS child_cost
                    FROM public."BOMComponents" bc
                    JOIN public."CatalogItems" ci ON ci.id = bc.component_item_id
                    WHERE bc.organization_id = p_org_id
                        AND bc.bom_template_id = v_template_id
                        AND bc.parent_item_id = v_resolved_item
                        AND bc.component_scope = 'bom'
                        AND bc.deleted = false
                        AND bc.archived = false
                ),
                global_defaults AS (
                    SELECT 
                        cic.child_item_id,
                        cic.child_role,
                        cic.qty,
                        cic.uom,
                        COALESCE(ci.cost_exw, 0) AS child_cost
                    FROM public."CatalogItemComponents" cic
                    JOIN public."CatalogItems" ci ON ci.id = cic.child_item_id
                    WHERE cic.organization_id = p_org_id
                        AND cic.parent_item_id = v_resolved_item
                        AND cic.deleted = false
                )
                SELECT * FROM bom_override
                UNION ALL
                SELECT * FROM global_defaults
                WHERE NOT EXISTS (SELECT 1 FROM bom_override)
            LOOP
                INSERT INTO public."BOMInstanceLines"(
                    organization_id,
                    bom_instance_id,
                    resolved_part_id,
                    part_role,
                    qty,
                    uom,
                    unit_cost_exw,
                    deleted
                ) VALUES (
                    p_org_id,
                    v_instance_id,
                    v_child.child_item_id,
                    v_child.child_role,
                    v_qty * v_child.qty,
                    v_child.uom,
                    v_child.child_cost,
                    false
                );
            END LOOP;
        END IF;
    END LOOP;

    RETURN v_instance_id;
END;
$$;


ALTER FUNCTION "public"."generate_bom_from_slots"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."generate_bom_from_slots"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") IS 'Genera BOMInstance desde BOMTemplateSlots para QuoteLine.
✅ CORREGIDO: Usa BOMInstances y BOMInstanceLines (mayúsculas).';



CREATE OR REPLACE FUNCTION "public"."generate_bom_from_slots_for_configured_product"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_template_id uuid;
    v_instance_id uuid;
    v_cp RECORD;
    v_slot RECORD;
    v_component RECORD;
    v_resolved_item uuid;
    v_qty numeric(12,4);
    v_width_mm numeric(12,4);
    v_height_mm numeric(12,4);
    v_unit_cost numeric(12,4);
    v_unit_uom text;
    v_child RECORD;
    v_has_component_rules boolean;
    v_config_snapshot jsonb;
    v_selected_item_id uuid;
    v_selected_sku text;
    v_mounting_clip_qty numeric(12,4);
    v_mounting_clip_rule RECORD;
BEGIN
    -- 1. Obtener ConfiguredProduct
    SELECT * INTO v_cp
    FROM public."ConfiguredProducts"
    WHERE id = p_configured_product_id 
        AND organization_id = p_org_id
        AND deleted = false;

    IF v_cp.id IS NULL THEN
        RAISE EXCEPTION 'ConfiguredProduct not found %', p_configured_product_id;
    END IF;

    v_config_snapshot := v_cp.config_snapshot;
    v_template_id := v_cp.bom_template_id;

    IF v_template_id IS NULL THEN
        RAISE EXCEPTION 'BOMTemplate not set in ConfiguredProduct %', p_configured_product_id;
    END IF;

    -- ✅ CAMBIO CRÍTICO: Solo crear BOMInstance si se proporciona quote_line_id
    IF p_quote_line_id IS NULL THEN
        -- NO crear BOMInstance sin quote_line_id
        RAISE NOTICE 'BOMInstance NO creado: quote_line_id es NULL. Retornando NULL.';
        RETURN NULL;
    END IF;

    -- 2. Soft-delete instancias previas (idempotencia)
    UPDATE public."BOMInstances"
        SET deleted = true
    WHERE organization_id = p_org_id
        AND (
            (configured_product_id = p_configured_product_id AND configured_product_id IS NOT NULL)
            OR (quote_line_id = p_quote_line_id AND quote_line_id IS NOT NULL)
        )
        AND deleted = false;

    -- 3. Crear nueva instancia con quote_line_id
    BEGIN
        INSERT INTO public."BOMInstances"(
            organization_id, 
            quote_line_id,  -- ✅ REQUERIDO
            configured_product_id, 
            bom_template_id
        )
        VALUES (p_org_id, p_quote_line_id, p_configured_product_id, v_template_id)
        RETURNING id INTO v_instance_id;

        IF v_instance_id IS NULL THEN
            RAISE EXCEPTION 'Failed to create BOMInstance: RETURNING id returned NULL. QuoteLine: %, ConfiguredProduct: %, Template: %', 
                p_quote_line_id, p_configured_product_id, v_template_id;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Failed to create BOMInstance for QuoteLine % and ConfiguredProduct %: %. Check constraints and schema.', 
                p_quote_line_id, p_configured_product_id, SQLERRM;
    END;

    v_width_mm := COALESCE(v_cp.width_mm, 0);
    v_height_mm := COALESCE(v_cp.height_mm, 0);

    -- 4. Iterar BOMTemplateSlots (PADRES) - misma lógica que antes
    FOR v_slot IN
        SELECT *
        FROM public."BOMTemplateSlots"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
        ORDER BY item_role ASC
    LOOP
        -- PASO 1: Resolver SKU PADRE desde config_snapshot
        v_selected_item_id := NULL;
        v_selected_sku := NULL;
        
        CASE v_slot.item_role
            WHEN 'bottom_bar' THEN
                v_selected_item_id := (v_config_snapshot->>'bottom_bar_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'bottom_bar_sku';
            WHEN 'headbox' THEN
                v_selected_item_id := (v_config_snapshot->>'headbox_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'headbox_sku';
            WHEN 'side_channel' THEN
                v_selected_item_id := (v_config_snapshot->>'side_channel_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'side_channel_sku';
            WHEN 'bottom_channel' THEN
                v_selected_item_id := (v_config_snapshot->>'bottom_channel_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'bottom_channel_sku';
            WHEN 'motor' THEN
                v_selected_item_id := (v_config_snapshot->>'motor_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'motor_sku';
            WHEN 'drive' THEN
                v_selected_item_id := (v_config_snapshot->>'drive_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'drive_sku';
            WHEN 'tube' THEN
                v_selected_item_id := (v_config_snapshot->>'tube_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'tube_sku';
            ELSE
                v_selected_item_id := (v_config_snapshot->>(v_slot.item_role || '_item_id'))::uuid;
                v_selected_sku := v_config_snapshot->>(v_slot.item_role || '_sku');
        END CASE;

        -- Resolver item
        IF v_selected_sku IS NOT NULL AND v_slot.catalog_item_id IS NOT NULL THEN
            SELECT ci.sku INTO v_resolved_item
            FROM public."CatalogItems" ci
            WHERE ci.id = v_slot.catalog_item_id
                AND TRIM(ci.sku) = TRIM(v_selected_sku);
                
            IF v_resolved_item IS NOT NULL THEN
                v_resolved_item := v_slot.catalog_item_id;
            END IF;
        ELSIF v_selected_item_id IS NOT NULL THEN
            v_resolved_item := v_selected_item_id;
        ELSE
            v_resolved_item := v_slot.catalog_item_id;
        END IF;

        -- PASO 2: Obtener reglas de qty/corte desde BOMComponents
        SELECT * INTO v_component
        FROM public."BOMComponents"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
            AND component_role = v_slot.item_role
            AND deleted = false
        LIMIT 1;

        v_has_component_rules := (v_component.id IS NOT NULL);

        -- PASO 3: Calcular cantidad
        IF v_has_component_rules THEN
            IF v_component.qty_type = 'fixed' THEN
                v_qty := v_component.qty_value;
            ELSIF v_component.qty_type = 'per_width' THEN
                v_qty := ((v_width_mm + COALESCE(v_component.qty_delta_mm, 0)) / 1000.0) * v_component.qty_value;
            ELSIF v_component.qty_type = 'per_height' THEN
                v_qty := ((v_height_mm + COALESCE(v_component.qty_delta_mm, 0)) / 1000.0) * v_component.qty_value;
            ELSIF v_component.qty_type = 'per_area' THEN
                v_qty := ((v_width_mm/1000.0) * (v_height_mm/1000.0)) * v_component.qty_value;
            ELSE
                v_qty := v_component.qty_value;
            END IF;

            IF v_component.waste_pct IS NOT NULL AND v_component.waste_pct > 0 THEN
                v_qty := v_qty * (1 + v_component.waste_pct);
            END IF;
        ELSE
            v_qty := v_slot.qty;
        END IF;

        -- PASO 4: Obtener costo y UOM
        IF v_resolved_item IS NOT NULL THEN
            SELECT ci.cost_exw, ci.unit_of_measure INTO v_unit_cost, v_unit_uom
            FROM public."CatalogItems" ci
            WHERE ci.id = v_resolved_item;
            
            v_unit_cost := COALESCE(v_unit_cost, 0);
            v_unit_uom := COALESCE(v_unit_uom, 'ea');
        ELSE
            v_unit_cost := 0;
            v_unit_uom := 'ea';
        END IF;

        -- PASO 5: Insertar línea del BOM (PADRE)
        IF v_resolved_item IS NOT NULL AND v_qty > 0 THEN
            INSERT INTO public."BOMInstanceLines"(
                organization_id,
                bom_instance_id,
                resolved_part_id,
                part_role,
                qty,
                uom,
                unit_cost_exw,
                deleted
            ) VALUES (
                p_org_id,
                v_instance_id,
                v_resolved_item,
                v_slot.item_role,
                v_qty,
                v_unit_uom,
                v_unit_cost,
                false
            );
        ELSIF v_resolved_item IS NULL AND v_qty > 0 THEN
            RAISE WARNING 'Skipping BOM line insertion for role %: qty=% but resolved_part_id is NULL', v_slot.item_role, v_qty;
        END IF;

        -- PASO 6: Si hay SKU resuelto, agregar HIJOS desde CatalogItemComponents
        IF v_resolved_item IS NOT NULL THEN
            FOR v_child IN
                SELECT 
                    cic.child_item_id,
                    cic.child_role,
                    cic.qty,
                    cic.uom,
                    COALESCE(ci.cost_exw, 0) AS child_cost
                FROM public."CatalogItemComponents" cic
                JOIN public."CatalogItems" ci ON ci.id = cic.child_item_id
                WHERE cic.organization_id = p_org_id
                    AND cic.parent_item_id = v_resolved_item
                    AND cic.deleted = false
                ORDER BY cic.sort_order ASC
            LOOP
                -- REGLA ESPECIAL: mounting_clip con qty_type=per_width
                IF v_child.child_role = 'mounting_clip' THEN
                    SELECT * INTO v_mounting_clip_rule
                    FROM public."BOMComponents"
                    WHERE organization_id = p_org_id
                        AND bom_template_id = v_template_id
                        AND component_role = 'mounting_clip'
                        AND depends_on_role = v_slot.item_role
                        AND qty_type = 'per_width'
                        AND deleted = false
                    LIMIT 1;

                    IF v_mounting_clip_rule.id IS NOT NULL THEN
                        v_mounting_clip_qty := CEIL((v_width_mm / 1000.0) * v_mounting_clip_rule.qty_value);
                        IF v_mounting_clip_qty < 2 THEN
                            v_mounting_clip_qty := 2;
                        END IF;
                        v_child.qty := v_mounting_clip_qty * v_qty;
                        v_child.uom := 'ea';
                    END IF;
                END IF;

                INSERT INTO public."BOMInstanceLines"(
                    organization_id,
                    bom_instance_id,
                    resolved_part_id,
                    part_role,
                    qty,
                    uom,
                    unit_cost_exw,
                    deleted
                ) VALUES (
                    p_org_id,
                    v_instance_id,
                    v_child.child_item_id,
                    v_child.child_role,
                    v_qty * v_child.qty,
                    v_child.uom,
                    v_child.child_cost,
                    false
                );
            END LOOP;
        END IF;
    END LOOP;

    RETURN v_instance_id;
END;
$$;


ALTER FUNCTION "public"."generate_bom_from_slots_for_configured_product"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."generate_bom_from_slots_for_configured_product"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") IS 'Genera BOMInstance y BOMInstanceLines para un ConfiguredProduct.
✅ CAMBIO: Ahora acepta quote_line_id opcional.
- Si quote_line_id viene: crea BOMInstance con quote_line_id (requerido por constraint)
- Si quote_line_id es NULL: NO crea BOMInstance (retorna NULL)
Esto evita violar el constraint NOT NULL en BOMInstances.quote_line_id.';



CREATE OR REPLACE FUNCTION "public"."generate_bom_instance_for_quote_line"("p_quote_line_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
declare
  v_org_id uuid;
  v_product_type_code text;
  v_product_type_id uuid;

  v_template_id uuid;
  v_instance_id uuid;

  -- column/table existence flags (para no reventar si faltan)
  has_bomtemplates_archived boolean;
  has_bomtemplates_is_active boolean;
  has_bomtemplates_updated_at boolean;

  has_bomcomponents_deleted boolean;

  has_bominstances_quote_line_id boolean;
begin
  -- 0) Validaciones base
  select organization_id, product_type
    into v_org_id, v_product_type_code
  from public."QuoteLines"
  where id = p_quote_line_id;

  if v_org_id is null then
    raise exception 'QuoteLine not found %', p_quote_line_id;
  end if;

  if v_product_type_code is null or btrim(v_product_type_code) = '' then
    raise exception 'QuoteLine % has NULL/empty product_type', p_quote_line_id;
  end if;

  -- 1) Resolver ProductTypes.id usando QuoteLines.product_type (code)
  select pt.id
    into v_product_type_id
  from public."ProductTypes" pt
  where pt.organization_id = v_org_id
    and pt.code = v_product_type_code
  limit 1;

  if v_product_type_id is null then
    raise exception 'ProductTypes not found for organization_id=% and code=%', v_org_id, v_product_type_code;
  end if;

  -- 2) Detectar columnas reales en BOMTemplates / BOMComponents
  select exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='BOMTemplates' and column_name='archived'
  ) into has_bomtemplates_archived;

  select exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='BOMTemplates' and column_name='is_active'
  ) into has_bomtemplates_is_active;

  select exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='BOMTemplates' and column_name='updated_at'
  ) into has_bomtemplates_updated_at;

  select exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='BOMComponents' and column_name='deleted'
  ) into has_bomcomponents_deleted;

  select exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='BOMInstances' and column_name='quote_line_id'
  ) into has_bominstances_quote_line_id;

  -- 3) Seleccionar el BOMTemplate “mejor” (por product_type_id)
  --    (sin usar deleted porque en tu tabla NO existe)
  if has_bomtemplates_updated_at then
    execute format($q$
      select t.id
      from public."BOMTemplates" t
      where t.organization_id = $1
        and t.product_type_id = $2
        %s
        %s
      order by t.updated_at desc nulls last
      limit 1
    $q$,
      case when has_bomtemplates_is_active then 'and t.is_active = true' else '' end,
      case when has_bomtemplates_archived then 'and t.archived = false' else '' end
    )
    into v_template_id
    using v_org_id, v_product_type_id;
  else
    execute format($q$
      select t.id
      from public."BOMTemplates" t
      where t.organization_id = $1
        and t.product_type_id = $2
        %s
        %s
      order by t.created_at desc
      limit 1
    $q$,
      case when has_bomtemplates_is_active then 'and t.is_active = true' else '' end,
      case when has_bomtemplates_archived then 'and t.archived = false' else '' end
    )
    into v_template_id
    using v_org_id, v_product_type_id;
  end if;

  if v_template_id is null then
    raise exception 'No BOMTemplate found for organization_id=% product_type_id=% (code=%)',
      v_org_id, v_product_type_id, v_product_type_code;
  end if;

  -- 4) Crear BOMInstance
  v_instance_id := gen_random_uuid();

  if has_bominstances_quote_line_id then
    insert into public."BOMInstances"(id, organization_id, quote_line_id, bom_template_id, created_at)
    values (v_instance_id, v_org_id, p_quote_line_id, v_template_id, now());
  else
    -- fallback por si tu BOMInstances no tiene quote_line_id (no debería pasar, pero lo cubrimos)
    insert into public."BOMInstances"(id, organization_id, bom_template_id, created_at)
    values (v_instance_id, v_org_id, v_template_id, now());
  end if;

  -- 5) Copiar BOMComponents -> BOMInstanceLines (usando TU esquema real)
  --    BOMInstanceLines: part_role, resolved_part_id, qty, uom, etc.
  execute format($q$
    insert into public."BOMInstanceLines"(
      id,
      bom_instance_id,
      bom_component_id,
      resolved_part_id,
      part_role,
      qty,
      uom,
      unit_cost_exw,
      total_cost_exw,
      organization_id,
      created_at,
      deleted
    )
    select
      gen_random_uuid(),
      $1 as bom_instance_id,
      bc.id as bom_component_id,
      bc.component_item_id as resolved_part_id,
      bc.component_role as part_role,
      coalesce(bc.qty_value, 1)::numeric as qty,
      coalesce(bc.uom, 'ea')::text as uom,
      null::numeric as unit_cost_exw,
      null::numeric as total_cost_exw,
      bc.organization_id,
      now(),
      false
    from public."BOMComponents" bc
    where bc.organization_id = $2
      and bc.bom_template_id = $3
      %s
  $q$,
    case when has_bomcomponents_deleted then 'and bc.deleted = false' else '' end
  )
  using v_instance_id, v_org_id, v_template_id;

  return v_instance_id;
end;
$_$;


ALTER FUNCTION "public"."generate_bom_instance_for_quote_line"("p_quote_line_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_bom_instance_for_quote_line_v1"("p_org_id" "uuid", "p_quote_line_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_product_type_id uuid;
  v_template_id uuid;
  v_instance_id uuid;

  v_width_mm numeric;
  v_height_mm numeric;

  v_rules jsonb;
  v_target int;
  v_clearance int;

  v_tube_width_mm numeric;
  v_fabric_width_mm numeric;

  r record;
  v_resolved uuid;
  v_qty numeric;
  v_uom text;
BEGIN
  -- product_type_id: en tu esquema NO está en QuoteLines.
  -- Así que: asumimos roller_shade por el BOMTemplate seleccionado (por ahora).
  -- (Si luego agregas product_type_id a QuoteLines, lo conectamos.)
  -- Para V1: usa el product_type_id de tus templates de Roller Shade.
  SELECT pt.id INTO v_product_type_id
  FROM public."ProductTypes" pt
  WHERE pt.organization_id = p_org_id
    AND pt.code = 'roller_shade'
  LIMIT 1;

  IF v_product_type_id IS NULL THEN
    RAISE EXCEPTION 'ProductTypes.code=roller_shade not found for org %', p_org_id;
  END IF;

  -- medidas
  SELECT (ql.width_m * 1000), (ql.height_m * 1000)
    INTO v_width_mm, v_height_mm
  FROM public."QuoteLines" ql
  WHERE ql.organization_id = p_org_id
    AND ql.id = p_quote_line_id;

  IF v_width_mm IS NULL OR v_height_mm IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % must have width_m and height_m', p_quote_line_id;
  END IF;

  -- seleccionar template
  v_template_id := public.select_best_bom_template_for_quote_line(
    p_org_id, v_product_type_id, p_quote_line_id
  );

  IF v_template_id IS NULL THEN
    RAISE EXCEPTION 'No matching BOMTemplate for QuoteLine % (missing options?)', p_quote_line_id;
  END IF;

  -- rules
  SELECT bt.metadata->'rules' INTO v_rules
  FROM public."BOMTemplates" bt
  WHERE bt.id = v_template_id;

  v_target := COALESCE((v_rules->>'tube_total_target_mm')::int, 0);
  v_clearance := COALESCE((v_rules->>'fabric_width_clearance_total_mm')::int, 2);

  IF v_target = 0 THEN
    RAISE EXCEPTION 'Template % missing rules.tube_total_target_mm', v_template_id;
  END IF;

  v_tube_width_mm := v_width_mm - v_target;
  v_fabric_width_mm := v_tube_width_mm - v_clearance;

  -- upsert instance (hay unique index org+quote_line donde deleted=false)
  SELECT bi.id INTO v_instance_id
  FROM public."BOMInstances" bi
  WHERE bi.organization_id = p_org_id
    AND bi.quote_line_id = p_quote_line_id
    AND bi.deleted = false
  LIMIT 1;

  IF v_instance_id IS NULL THEN
    INSERT INTO public."BOMInstances"(organization_id, quote_line_id, bom_template_id, deleted)
    VALUES (p_org_id, p_quote_line_id, v_template_id, false)
    RETURNING id INTO v_instance_id;
  ELSE
    UPDATE public."BOMInstances"
    SET bom_template_id = v_template_id, updated_at = now()
    WHERE id = v_instance_id;

    DELETE FROM public."BOMInstanceLines" WHERE bom_instance_id = v_instance_id;
  END IF;

  -- generar lines desde BOMComponents
  FOR r IN
    SELECT *
    FROM public."BOMComponents" bc
    WHERE bc.organization_id = p_org_id
      AND bc.bom_template_id = v_template_id
      AND bc.deleted = false
      AND bc.archived = false
    ORDER BY bc.sort_order ASC
  LOOP
    v_resolved := public.resolve_catalog_item_for_bom_component(
      p_org_id,
      p_quote_line_id,
      r.component_role,
      r.component_item_id
    );

    -- qty por tipo (V1 simple)
    IF r.qty_type = 'fixed' THEN
      v_qty := r.qty_value;
      v_uom := r.uom;
    ELSIF r.qty_type = 'per_width' THEN
      -- qty en mm (corte)
      IF r.component_role = 'tube' THEN
        v_qty := v_tube_width_mm;
      ELSIF r.component_role IN ('fabric','bottom_bar_profile','bottom_rail_profile','side_channel_profile','track','top_rail_profile') THEN
        v_qty := v_fabric_width_mm;
      ELSE
        v_qty := v_width_mm;
      END IF;
      v_uom := 'mm';
    ELSIF r.qty_type = 'per_area' THEN
      v_qty := (v_fabric_width_mm * v_height_mm);
      v_uom := 'mm2';
    ELSE
      v_qty := r.qty_value;
      v_uom := r.uom;
    END IF;

    INSERT INTO public."BOMInstanceLines"(
      bom_instance_id, bom_component_id, resolved_part_id, part_role,
      qty, uom,
      cut_width_mm, cut_height_mm, cut_length_mm,
      unit_cost_exw, total_cost_exw
    )
    VALUES (
      v_instance_id, r.id, v_resolved, r.component_role,
      v_qty, v_uom,
      CASE WHEN r.component_role IN ('tube','fabric','bottom_bar_profile','bottom_rail_profile','side_channel_profile','track','top_rail_profile') THEN v_qty ELSE NULL END,
      CASE WHEN r.component_role = 'fabric' THEN v_height_mm ELSE NULL END,
      NULL,
      NULL, NULL
    );
  END LOOP;

  RETURN v_instance_id;
END;
$$;


ALTER FUNCTION "public"."generate_bom_instance_for_quote_line_v1"("p_org_id" "uuid", "p_quote_line_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_auth_context"() RETURNS TABLE("user_id" "uuid", "is_org_user" boolean, "is_portal_user" boolean, "organization_id" "uuid", "dealer_id" "uuid", "needs_password" boolean, "access_allowed" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid;
  v_org_user_id uuid;
  v_portal_user_id uuid;
  v_organization_id uuid;
  v_dealer_id uuid;
  v_org_status text;
  v_portal_status text;
  v_org_must_change_password boolean;
  v_portal_must_change_password boolean;
  v_is_org_user boolean := false;
  v_is_portal_user boolean := false;
  v_access_allowed boolean := false;
  v_needs_password boolean := false;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT
      NULL::uuid, false::boolean, false::boolean,
      NULL::uuid, NULL::uuid, false::boolean, false::boolean;
    RETURN;
  END IF;

  SELECT ou.id, ou.organization_id, ou.status, COALESCE(ou.must_change_password, false)
  INTO v_org_user_id, v_organization_id, v_org_status, v_org_must_change_password
  FROM public."OrganizationUsers" ou
  WHERE ou.user_id = v_user_id AND ou.deleted = false AND ou.status IN ('active', 'invited')
  LIMIT 1;

  IF v_org_user_id IS NOT NULL THEN
    v_is_org_user := true;
    v_access_allowed := true;
  END IF;

  IF v_org_user_id IS NULL THEN
    SELECT dpu.id, dpu.dealer_id, dpu.organization_id, dpu.status, COALESCE(dpu.must_change_password, false)
    INTO v_portal_user_id, v_dealer_id, v_organization_id, v_portal_status, v_portal_must_change_password
    FROM public."DealerUsers" dpu
    WHERE dpu.user_id = v_user_id AND dpu.deleted = false AND dpu.status IN ('active', 'invited')
    LIMIT 1;

    IF v_portal_user_id IS NOT NULL THEN
      v_is_portal_user := true;
      v_access_allowed := true;
    END IF;
  ELSE
    SELECT dpu.dealer_id, dpu.status, COALESCE(dpu.must_change_password, false)
    INTO v_dealer_id, v_portal_status, v_portal_must_change_password
    FROM public."DealerUsers" dpu
    WHERE dpu.user_id = v_user_id AND dpu.deleted = false AND dpu.status IN ('active', 'invited')
    LIMIT 1;
  END IF;

  v_needs_password := COALESCE(v_org_must_change_password, false) OR COALESCE(v_portal_must_change_password, false);

  RETURN QUERY SELECT
    v_user_id, v_is_org_user, v_is_portal_user,
    v_organization_id, v_dealer_id, v_needs_password, v_access_allowed;
END;
$$;


ALTER FUNCTION "public"."get_auth_context"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_auth_context"() IS 'Auth context for current user. Returns dealer_id (was company_id).';



CREATE OR REPLACE FUNCTION "public"."get_catalog_item_price_for_quote"("p_catalog_item_id" "uuid") RETURNS TABLE("measure_basis" "text", "unit_price" numeric, "unit_label" "text")
    LANGUAGE "sql" STABLE
    AS $$
  select
    ci.measure_basis,
    case
      when coalesce(ci.measure_basis,'linear') = 'linear' then conv.cost_exw_per_m
      when ci.measure_basis = 'area' then conv.cost_exw_per_m2
      when ci.measure_basis = 'unit' then ci.cost_exw
      else conv.cost_exw_per_m
    end as unit_price,
    case
      when coalesce(ci.measure_basis,'linear') = 'linear' then 'ml'
      when ci.measure_basis = 'area' then 'm2'
      when ci.measure_basis = 'unit' then 'unit'
      else 'ml'
    end as unit_label
  from public."CatalogItems" ci
  left join public."CatalogItemConversions" conv
    on conv.catalog_item_id = ci.id
  where ci.id = p_catalog_item_id;
$$;


ALTER FUNCTION "public"."get_catalog_item_price_for_quote"("p_catalog_item_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_catalog_item_unit_cost_norm"("p_catalog_item_id" "uuid", "p_organization_id" "uuid") RETURNS TABLE("basis" "text", "unit_cost" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_ci RECORD;
  v_conv RECORD;
  v_basis text;
  v_unit_cost numeric(12,4);
BEGIN
  SELECT
    ci.id,
    ci.organization_id,
    ci.is_roll,
    ci.roll_width,
    ci.unit_of_measure,
    ci.cost_exw
  INTO v_ci
  FROM public."CatalogItems" ci
  WHERE ci.id = p_catalog_item_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 'ea'::text, 0::numeric;
    RETURN;
  END IF;

  SELECT
    conv.cost_exw_per_m,
    conv.cost_exw_per_m2,
    conv.cost_exw_per_ea
  INTO v_conv
  FROM public."CatalogItemConversions" conv
  WHERE conv.catalog_item_id = p_catalog_item_id
    AND conv.organization_id = p_organization_id
  LIMIT 1;

  IF COALESCE(v_ci.is_roll,false) = true THEN
    IF v_conv.cost_exw_per_m2 IS NOT NULL THEN
      v_basis := 'm2';
      v_unit_cost := v_conv.cost_exw_per_m2;
    ELSIF v_conv.cost_exw_per_m IS NOT NULL THEN
      v_basis := 'm';
      v_unit_cost := v_conv.cost_exw_per_m;
    ELSE
      v_basis := 'ea';
      v_unit_cost := COALESCE(v_conv.cost_exw_per_ea, v_ci.cost_exw, 0);
    END IF;
  ELSE
    -- no-roll: prefer ea if available, else m if available
    IF v_conv.cost_exw_per_ea IS NOT NULL THEN
      v_basis := 'ea';
      v_unit_cost := v_conv.cost_exw_per_ea;
    ELSIF v_conv.cost_exw_per_m IS NOT NULL THEN
      v_basis := 'm';
      v_unit_cost := v_conv.cost_exw_per_m;
    ELSIF v_conv.cost_exw_per_m2 IS NOT NULL THEN
      v_basis := 'm2';
      v_unit_cost := v_conv.cost_exw_per_m2;
    ELSE
      v_basis := 'ea';
      v_unit_cost := COALESCE(v_ci.cost_exw, 0);
    END IF;
  END IF;

  RETURN QUERY SELECT v_basis, COALESCE(v_unit_cost,0)::numeric(12,4);
END;
$$;


ALTER FUNCTION "public"."get_catalog_item_unit_cost_norm"("p_catalog_item_id" "uuid", "p_organization_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_category_id_by_path"("p_org" "uuid", "p_path" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  parts text[];
  i int;
  current_id uuid;
  part_name text;
BEGIN
  IF p_path IS NULL OR btrim(p_path) = '' THEN
    RETURN NULL;
  END IF;

  parts := regexp_split_to_array(p_path, '\s*>\s*');
  current_id := NULL;

  FOR i IN 1..array_length(parts, 1) LOOP
    part_name := btrim(parts[i]);

    SELECT c.id INTO current_id
    FROM public."CatalogCategories" c
    WHERE c.organization_id = p_org
      AND (
        (current_id IS NULL AND c.parent_id IS NULL)
        OR (c.parent_id = current_id)
      )
      AND lower(c.name) = lower(part_name)
    LIMIT 1;

    IF current_id IS NULL THEN
      RETURN NULL;
    END IF;
  END LOOP;

  RETURN current_id;
END;
$$;


ALTER FUNCTION "public"."get_category_id_by_path"("p_org" "uuid", "p_path" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_category_margins_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", OUT "msrp_pct_sale_in" numeric, OUT "msrp_pct_sale_out" numeric) RETURNS "record"
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  v_current_category_id uuid;
  v_found boolean := false;
BEGIN
  msrp_pct_sale_in := 0.35;
  msrp_pct_sale_out := 0.65;

  IF p_category_id IS NULL THEN RETURN; END IF;
  v_current_category_id := p_category_id;

  WHILE v_current_category_id IS NOT NULL AND NOT v_found LOOP
    SELECT COALESCE(cm.minimum_margin_pct, 0.35), COALESCE(cm.msrp_pct, 0.65)
    INTO msrp_pct_sale_in, msrp_pct_sale_out
    FROM public."CategoryMargins" cm
    WHERE cm.organization_id = p_organization_id AND cm.category_id = v_current_category_id
      AND COALESCE(cm.is_active, true) = true
    LIMIT 1;
    IF FOUND THEN v_found := true;
    ELSE
      SELECT parent_id INTO v_current_category_id FROM public."CatalogCategories" WHERE id = v_current_category_id;
    END IF;
  END LOOP;

  IF NOT v_found THEN msrp_pct_sale_in := 0.35; msrp_pct_sale_out := 0.65; END IF;
END;
$$;


ALTER FUNCTION "public"."get_category_margins_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", OUT "msrp_pct_sale_in" numeric, OUT "msrp_pct_sale_out" numeric) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_category_margins_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", OUT "msrp_pct_sale_in" numeric, OUT "msrp_pct_sale_out" numeric) IS 'Busca márgenes (minimum_margin_pct, msrp_pct_sale_out) para una categoría. OUT msrp_pct_sale_in = minimum_margin_pct.';



CREATE OR REPLACE FUNCTION "public"."get_current_portal_user"() RETURNS TABLE("id" "uuid", "organization_id" "uuid", "dealer_id" "uuid", "portal_user_role" "text", "status" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    dpu.id,
    dpu.organization_id,
    dpu.dealer_id,
    CASE
      WHEN dpu.role IN ('member_manager', 'manager') THEN 'member_manager'::text
      ELSE 'member'::text
    END AS portal_user_role,
    dpu.status::text AS status
  FROM public."DealerUsers" dpu
  WHERE (
    dpu.user_id = auth.uid()
    OR dpu.portal_user_email = (auth.jwt() ->> 'email')
  )
    AND dpu.deleted = false
    AND dpu.status IN ('active', 'invited')
  LIMIT 1;
END;
$$;


ALTER FUNCTION "public"."get_current_portal_user"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_current_portal_user"() IS 'Get current portal user info. Returns dealer_id.';



CREATE OR REPLACE FUNCTION "public"."get_current_portal_user_dealer_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT dealer_id
  FROM public."DealerUsers"
  WHERE (user_id = auth.uid() OR portal_user_email = (auth.jwt() ->> 'email'))
    AND deleted = false
    AND status IN ('active', 'invited')
  LIMIT 1;
$$;


ALTER FUNCTION "public"."get_current_portal_user_dealer_id"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_current_portal_user_dealer_id"() IS 'Returns dealer_id for current portal user.';



CREATE OR REPLACE FUNCTION "public"."get_import_tax_pct_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", "p_fallback_pct" numeric DEFAULT 0) RETURNS numeric
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  v_tax_pct numeric;
  v_current_category_id uuid;
BEGIN
  -- Si no hay category_id, retornar fallback
  IF p_category_id IS NULL THEN
    RETURN p_fallback_pct;
  END IF;

  v_current_category_id := p_category_id;
  v_tax_pct := NULL;

  -- Buscar regla activa subiendo por la jerarquía de categorías
  WHILE v_current_category_id IS NOT NULL AND v_tax_pct IS NULL LOOP
    SELECT import_tax_pct INTO v_tax_pct
    FROM public."ImportTaxRules"
    WHERE organization_id = p_organization_id
      AND category_id = v_current_category_id
      AND COALESCE(is_active, true) = true
    LIMIT 1;

    -- Si no encontramos, intentar con la categoría padre
    IF v_tax_pct IS NULL THEN
      SELECT parent_id INTO v_current_category_id
      FROM public."CatalogCategories"
      WHERE id = v_current_category_id;
    END IF;
  END LOOP;

  -- Retornar el valor encontrado o el fallback
  RETURN COALESCE(v_tax_pct, p_fallback_pct);
END;
$$;


ALTER FUNCTION "public"."get_import_tax_pct_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", "p_fallback_pct" numeric) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_import_tax_pct_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", "p_fallback_pct" numeric) IS 'Busca import_tax_pct para una categoría, subiendo por la jerarquía (parent_category_id) hasta encontrar una regla activa. Si no encuentra, retorna el fallback.';



CREATE OR REPLACE FUNCTION "public"."get_must_change_password"() RETURNS TABLE("must_change_password" boolean, "user_type" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_org_must_change boolean;
  v_portal_must_change boolean;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'none'::text;
    RETURN;
  END IF;

  -- Check OrganizationUsers
  SELECT ou.must_change_password
  INTO v_org_must_change
  FROM public."OrganizationUsers" ou
  WHERE ou.user_id = v_user_id
    AND ou.deleted = false
  LIMIT 1;

  IF v_org_must_change IS NOT NULL THEN
    RETURN QUERY SELECT v_org_must_change, 'org'::text;
    RETURN;
  END IF;

  -- Check CompanyPortalUsers
  SELECT cpu.must_change_password
  INTO v_portal_must_change
  FROM public."CompanyPortalUsers" cpu
  WHERE cpu.user_id = v_user_id
    AND cpu.deleted = false
  LIMIT 1;

  IF v_portal_must_change IS NOT NULL THEN
    RETURN QUERY SELECT v_portal_must_change, 'portal'::text;
    RETURN;
  END IF;

  -- No membership found
  RETURN QUERY SELECT false, 'none'::text;
END;
$$;


ALTER FUNCTION "public"."get_must_change_password"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_must_change_password"() IS 'Returns must_change_password flag and user type (org/portal/none) for the current authenticated user';



CREATE OR REPLACE FUNCTION "public"."get_my_portal_access"() RETURNS TABLE("id" "uuid", "organization_id" "uuid", "portal_user_email" "text", "user_id" "uuid", "role" "text", "status" "text", "deleted" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
  SELECT
    cpu.id,
    cpu.organization_id,
    cpu.portal_user_email,
    cpu.user_id,
    cpu.role::text as role,
    cpu.status::text as status,
    cpu.deleted
  FROM public."CompanyPortalUsers" cpu
  WHERE cpu.deleted = false
    AND (cpu.status IS NULL OR cpu.status IN ('active', 'invited'))
    AND (
      cpu.user_id = auth.uid()
      OR lower(trim(cpu.portal_user_email)) = lower(trim(coalesce(auth.jwt() ->> 'email', '')))
    )
  ORDER BY cpu.created_at DESC NULLS LAST
  LIMIT 1;
$$;


ALTER FUNCTION "public"."get_my_portal_access"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_parent_sku_selections"("p_org_id" "uuid", "p_quote_line_id" "uuid") RETURNS TABLE("component_role" "text", "catalog_item_id" "uuid", "sku" "text", "item_name" "text")
    LANGUAGE "sql" STABLE
    AS $$
  SELECT 
    qlc.component_role,
    qlc.catalog_item_id,
    ci.sku,
    ci.name as item_name
  FROM public."QuoteLineComponents" qlc
  LEFT JOIN public."CatalogItems" ci ON ci.id = qlc.catalog_item_id
  WHERE qlc.organization_id = p_org_id
    AND qlc.quote_line_id = p_quote_line_id
    AND qlc.kind = 'selection'
    AND qlc.deleted = false
  ORDER BY qlc.created_at ASC;
$$;


ALTER FUNCTION "public"."get_parent_sku_selections"("p_org_id" "uuid", "p_quote_line_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_parent_sku_selections"("p_org_id" "uuid", "p_quote_line_id" "uuid") IS 'Get all parent SKU selections made by user for a quote line. Used for debugging and validation.';



CREATE OR REPLACE FUNCTION "public"."get_quote_line_option_value"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_key" "text") RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT qlc.payload->>'value'
  FROM public."QuoteLineComponents" qlc
  WHERE qlc.organization_id = p_org_id
    AND qlc.quote_line_id = p_quote_line_id
    AND qlc.deleted = false
    AND qlc.kind = 'option'
    AND qlc.component_role = p_key
  ORDER BY qlc.created_at DESC
  LIMIT 1;
$$;


ALTER FUNCTION "public"."get_quote_line_option_value"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_roll_unit_price_for_quote"("p_catalog_item_id" "uuid") RETURNS TABLE("roll_pricing_mode" "text", "unit_price" numeric, "unit_label" "text")
    LANGUAGE "sql" STABLE
    AS $$
  select
    ci.roll_pricing_mode,
    case
      when ci.roll_pricing_mode = 'per_linear_meter' then conv.cost_exw_per_m
      when ci.roll_pricing_mode = 'per_square_meter' then conv.cost_exw_per_m2
      when ci.roll_pricing_mode = 'per_unit' then ci.cost_exw
      else conv.cost_exw_per_m
    end as unit_price,
    case
      when ci.roll_pricing_mode = 'per_linear_meter' then 'ml'
      when ci.roll_pricing_mode = 'per_square_meter' then 'm2'
      when ci.roll_pricing_mode = 'per_unit' then 'unit'
      else 'ml'
    end as unit_label
  from public."CatalogItems" ci
  left join public."CatalogItemConversions" conv
    on conv.catalog_item_id = ci.id
  where ci.id = p_catalog_item_id;
$$;


ALTER FUNCTION "public"."get_roll_unit_price_for_quote"("p_catalog_item_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_auth_user_created_for_org_users"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Link OrganizationUsers where email matches and user_id is null
  UPDATE public."OrganizationUsers"
  SET
    user_id = NEW.id,
    status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
    accepted_at = COALESCE(accepted_at, now()),
    updated_at = now()
  WHERE
    lower(user_email) = lower(NEW.email)
    AND user_id IS NULL
    AND deleted = false;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_auth_user_created_for_org_users"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."handle_auth_user_created_for_org_users"() IS 'Automatically links OrganizationUsers invites when a new auth.users is created. Matches by lower(email).';



CREATE OR REPLACE FUNCTION "public"."handle_auth_user_created_for_portal_users"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  UPDATE public."DealerUsers"
  SET user_id = NEW.id,
      status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
      accepted_at = COALESCE(accepted_at, now()),
      updated_at = now()
  WHERE lower(portal_user_email) = lower(NEW.email)
    AND user_id IS NULL
    AND deleted = false;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_auth_user_created_for_portal_users"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."handle_auth_user_created_for_portal_users"() IS 'Auto-link DealerUsers invites when auth.users is created.';



CREATE OR REPLACE FUNCTION "public"."handle_quote_approved"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_sales_order_id uuid;
    v_sales_order_no text;
    v_quote_no text;
BEGIN
    -- Only process when status changes to 'approved'
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
        -- Check if SalesOrder already exists (idempotent)
        SELECT id INTO v_sales_order_id
        FROM public."SalesOrders"
        WHERE quote_id = NEW.id
        AND deleted = false
        LIMIT 1;

        -- If SalesOrder doesn't exist, create it
        IF v_sales_order_id IS NULL THEN
            -- Generate sales_order_no from quote_no
            v_quote_no := NEW.quote_no;
            v_sales_order_no := 'SO-' || v_quote_no || '-' || to_char(now(), 'YYYYMMDD-HH24MISS');

            -- Insert SalesOrder
            INSERT INTO public."SalesOrders" (
                organization_id,
                quote_id,
                sales_order_no,
                tracking_status,
                deleted,
                created_at,
                updated_at
            )
            VALUES (
                NEW.organization_id,
                NEW.id,
                v_sales_order_no,
                'pending_confirmation',
                false,
                now(),
                now()
            )
            RETURNING id INTO v_sales_order_id;

            -- Insert OrderList (mirror of SalesOrder)
            INSERT INTO public."OrderList" (
                organization_id,
                sales_order_id,
                tracking_status,
                deleted,
                created_at,
                updated_at
            )
            VALUES (
                NEW.organization_id,
                v_sales_order_id,
                'pending_confirmation',
                false,
                now(),
                now()
            );
        END IF;

        -- Update Quote.tracking_status
        NEW.tracking_status := 'pending_confirmation';
    END IF;

    -- If status is NOT 'approved', ensure tracking_status is NULL
    IF NEW.status != 'approved' THEN
        NEW.tracking_status := NULL;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_quote_approved"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."handle_quote_approved"() IS 'Trigger function: When Quote.status changes to approved, creates SalesOrder and OrderList, and sets Quote.tracking_status to pending_confirmation.';



CREATE OR REPLACE FUNCTION "public"."is_dealer_member"("p_dealer_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."Dealers" d
    JOIN public."OrganizationUsers" ou ON ou.organization_id = d.organization_id
    WHERE d.id = p_dealer_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;


ALTER FUNCTION "public"."is_dealer_member"("p_dealer_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_dealer_member"("p_dealer_id" "uuid") IS 'Check if current user is member of dealer via organization. SECURITY DEFINER.';



CREATE OR REPLACE FUNCTION "public"."is_dealer_owner_or_admin"("p_dealer_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."Dealers" d
    JOIN public."OrganizationUsers" ou ON ou.organization_id = d.organization_id
    WHERE d.id = p_dealer_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('superadmin', 'owner', 'admin')
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;


ALTER FUNCTION "public"."is_dealer_owner_or_admin"("p_dealer_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_dealer_owner_or_admin"("p_dealer_id" "uuid") IS 'Check if current user is superadmin/owner/admin of dealer. SECURITY DEFINER.';



CREATE OR REPLACE FUNCTION "public"."is_dealer_portal_user"("p_dealer_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."DealerUsers" dpu
    WHERE dpu.dealer_id = p_dealer_id
      AND (
        dpu.user_id = auth.uid()
        OR dpu.portal_user_email = (auth.jwt() ->> 'email')
      )
      AND dpu.deleted = false
      AND dpu.status IN ('active', 'invited')
  );
END;
$$;


ALTER FUNCTION "public"."is_dealer_portal_user"("p_dealer_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_dealer_portal_user"("p_dealer_id" "uuid") IS 'True if current user is a DealerUser (portal) for the given dealer.';



CREATE OR REPLACE FUNCTION "public"."is_dealer_portal_user_with_write"("p_dealer_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."DealerUsers" dpu
    WHERE dpu.dealer_id = p_dealer_id
      AND (
        dpu.user_id = auth.uid()
        OR lower(dpu.portal_user_email) = lower(auth.jwt() ->> 'email')
      )
      AND dpu.deleted = false
      AND dpu.status IN ('active', 'invited')
      AND dpu.role IN ('member_manager')
  );
END;
$$;


ALTER FUNCTION "public"."is_dealer_portal_user_with_write"("p_dealer_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_dealer_portal_user_with_write"("p_dealer_id" "uuid") IS 'True if current user is a DealerUser with write (member_manager) for the given dealer.';



CREATE OR REPLACE FUNCTION "public"."is_org_member"("p_org_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND (ou.deleted IS NULL OR ou.deleted = false)
  );
END;
$$;


ALTER FUNCTION "public"."is_org_member"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_org_member"("p_org_id" "uuid") IS 'Check if current user is an active member of organization. SECURITY DEFINER to avoid RLS recursion.';



CREATE OR REPLACE FUNCTION "public"."is_org_owner_or_admin"("p_org_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('superadmin', 'owner', 'admin') -- Added 'superadmin'
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;


ALTER FUNCTION "public"."is_org_owner_or_admin"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_org_owner_or_admin"("p_org_id" "uuid") IS 'Check if current user is superadmin/owner/admin in organization. SECURITY DEFINER to avoid RLS recursion. Updated to include superadmin role.';



CREATE OR REPLACE FUNCTION "public"."is_org_user_member"("p_org_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
      AND ou.status IN ('active', 'invited')
  );
END;
$$;


ALTER FUNCTION "public"."is_org_user_member"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_org_user_member"("p_org_id" "uuid") IS 'Returns true if current user is an active/invited OrganizationUser member (non-superadmin).';



CREATE OR REPLACE FUNCTION "public"."is_org_user_superadmin"("p_org_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('superadmin', 'admin', 'owner')
      AND ou.deleted = false
      AND ou.status IN ('active', 'invited')
  );
END;
$$;


ALTER FUNCTION "public"."is_org_user_superadmin"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_org_user_superadmin"("p_org_id" "uuid") IS 'Returns true if current user is superadmin/admin/owner in the organization. Used for RLS policies that allow full access.';



CREATE OR REPLACE FUNCTION "public"."is_pack_uom"("p_uom" "text") RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT lower(coalesce(p_uom,'')) = ANY (ARRAY[
    'pack','set','box','case','bag'
  ]);
$$;


ALTER FUNCTION "public"."is_pack_uom"("p_uom" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
  v_uid uuid;
  v_jwt_email text;
  v_row_user_id uuid;
  v_row_email text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN false;
  END IF;

  SELECT dpu.user_id, dpu.portal_user_email INTO v_row_user_id, v_row_email
  FROM public."DealerUsers" dpu
  WHERE dpu.id = p_portal_row_id AND dpu.deleted = false
  LIMIT 1;

  IF v_row_user_id IS NULL AND v_row_email IS NULL THEN
    RETURN false;
  END IF;

  IF v_row_user_id IS NOT NULL AND v_row_user_id = v_uid THEN
    RETURN true;
  END IF;

  v_jwt_email := NULLIF(lower(trim(auth.jwt() ->> 'email')), '');
  IF v_jwt_email IS NOT NULL AND v_row_email IS NOT NULL AND lower(trim(v_row_email)) = v_jwt_email THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;


ALTER FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") IS 'True if current user matches the portal record by user_id or jwt email fallback.';



CREATE OR REPLACE FUNCTION "public"."is_unit_uom"("p_uom" "text") RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT lower(coalesce(p_uom,'')) = ANY (ARRAY[
    'ea','pcs','pc','unit','piece'
  ]);
$$;


ALTER FUNCTION "public"."is_unit_uom"("p_uom" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."link_my_invites"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_email text;
  v_org_updated int := 0;
  v_portal_updated int := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_email := lower(coalesce(auth.jwt() ->> 'email', ''));

  IF v_email = '' THEN
    RAISE EXCEPTION 'Missing email in auth context';
  END IF;

  UPDATE public."OrganizationUsers"
  SET user_id = v_uid,
      status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
      updated_at = now()
  WHERE lower(user_email) = v_email AND (user_id IS NULL OR user_id = v_uid);
  GET DIAGNOSTICS v_org_updated = ROW_COUNT;

  UPDATE public."DealerUsers"
  SET user_id = v_uid,
      status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
      updated_at = now()
  WHERE lower(portal_user_email) = v_email AND (user_id IS NULL OR user_id = v_uid);
  GET DIAGNOSTICS v_portal_updated = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'org_updated', v_org_updated, 'portal_updated', v_portal_updated);
END;
$$;


ALTER FUNCTION "public"."link_my_invites"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."link_my_org_invites"() RETURNS TABLE("linked_count" integer, "updated_ids" "uuid"[])
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_user_email text;
  v_linked_count integer := 0;
  v_portal_linked_count integer := 0;
  v_updated_ids uuid[];
  v_portal_updated_ids uuid[];
BEGIN
  v_user_id := auth.uid();
  v_user_email := coalesce(auth.jwt() ->> 'email', '');

  IF v_user_id IS NULL OR btrim(v_user_email) = '' THEN
    RETURN QUERY SELECT 0, ARRAY[]::uuid[];
    RETURN;
  END IF;

  WITH updated AS (
    UPDATE public."OrganizationUsers"
    SET user_id = v_user_id,
        status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
        accepted_at = COALESCE(accepted_at, now()),
        updated_at = now()
    WHERE lower(user_email) = lower(v_user_email) AND user_id IS NULL AND deleted = false
    RETURNING id
  )
  SELECT COUNT(*)::integer, ARRAY_AGG(id)::uuid[] INTO v_linked_count, v_updated_ids FROM updated;

  WITH updated_portal AS (
    UPDATE public."DealerUsers"
    SET user_id = v_user_id,
        status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
        accepted_at = COALESCE(accepted_at, now()),
        updated_at = now()
    WHERE lower(portal_user_email) = lower(v_user_email) AND user_id IS NULL AND deleted = false
    RETURNING id
  )
  SELECT COUNT(*)::integer, ARRAY_AGG(id)::uuid[] INTO v_portal_linked_count, v_portal_updated_ids FROM updated_portal;

  RETURN QUERY
  SELECT (v_linked_count + v_portal_linked_count)::integer,
         (COALESCE(v_updated_ids, ARRAY[]::uuid[]) || COALESCE(v_portal_updated_ids, ARRAY[]::uuid[]))::uuid[];
END;
$$;


ALTER FUNCTION "public"."link_my_org_invites"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."link_my_org_invites"() IS 'Links OrganizationUsers and DealerUsers invites by email.';



CREATE OR REPLACE FUNCTION "public"."list_matching_bom_templates"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") RETURNS TABLE("id" "uuid", "code" "text", "name" "text", "metadata" "jsonb")
    LANGUAGE "sql" STABLE
    AS $$
  SELECT bt.id, bt.code, bt.name, bt.metadata
  FROM public."BOMTemplates" bt
  WHERE bt.organization_id = p_org
    AND bt.product_type_id = p_product_type
    AND bt.active = true
    AND bt.deleted = false
    AND bt.archived = false
    AND bt.metadata @> p_config
  ORDER BY bt.code;
$$;


ALTER FUNCTION "public"."list_matching_bom_templates"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."OrganizationUsers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "user_email" "text" NOT NULL,
    "user_name" "text",
    "role" "public"."org_role" DEFAULT 'member'::"public"."org_role" NOT NULL,
    "status" "public"."org_user_status" DEFAULT 'invited'::"public"."org_user_status" NOT NULL,
    "invited_by_user_id" "uuid",
    "invited_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "accepted_at" timestamp with time zone,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "must_change_password" boolean DEFAULT true NOT NULL,
    "temp_password_set_at" timestamp with time zone,
    CONSTRAINT "organizationusers_role_check" CHECK ((("role")::"text" = ANY (ARRAY['superadmin'::"text", 'admin'::"text", 'operator'::"text", 'procurement'::"text", 'finance'::"text"])))
);


ALTER TABLE "public"."OrganizationUsers" OWNER TO "postgres";


COMMENT ON TABLE "public"."OrganizationUsers" IS 'Organization users - internal users with roles (owner, admin, member, viewer)';



COMMENT ON COLUMN "public"."OrganizationUsers"."user_id" IS 'FK to auth.users. Nullable until user accepts invite.';



COMMENT ON COLUMN "public"."OrganizationUsers"."user_email" IS 'User email (lowercased). Unique per organization when not deleted.';



COMMENT ON COLUMN "public"."OrganizationUsers"."status" IS 'Status: invited (pending), active (accepted), disabled (inactive)';



CREATE OR REPLACE FUNCTION "public"."list_organization_users"("p_organization_id" "uuid") RETURNS SETOF "public"."OrganizationUsers"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_caller_user_id uuid;
  v_caller_role public.org_role;
BEGIN
  -- Obtener caller user_id
  v_caller_user_id := auth.uid();
  
  IF v_caller_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validar que caller es miembro de la organización
  SELECT ou.role INTO v_caller_role
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND ou.user_id = v_caller_user_id
    AND ou.deleted = false
    AND ou.status = 'active'
  LIMIT 1;

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Caller is not a member of organization %', p_organization_id;
  END IF;

  -- Allow superadmin, admin, and owner (legacy) roles to list users
  IF v_caller_role::text NOT IN ('superadmin', 'admin', 'owner') THEN
    RAISE EXCEPTION 'Only superadmins, admins, and owners can list organization users';
  END IF;

  -- Retornar usuarios de la organización (deleted=false)
  RETURN QUERY
  SELECT ou.*
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND ou.deleted = false
  ORDER BY ou.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."list_organization_users"("p_organization_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."list_organization_users"("p_organization_id" "uuid") IS 'List all users in an organization. Only superadmins, admins, and owners can call.';



CREATE OR REPLACE FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_org_id uuid; v_category_id uuid; v_cost_exw numeric;
  v_shipping_pct numeric; v_import_tax_pct numeric; v_min_margin_pct numeric;
  v_msrp_pct_sale_in numeric; v_msrp_pct numeric;
  v_shipping_cost numeric; v_import_tax_cost numeric; v_total_cost numeric;
  v_dealer_price numeric; v_msrp numeric;
BEGIN
  SELECT organization_id, category_id, COALESCE(cost_exw, 0) INTO v_org_id, v_category_id, v_cost_exw
  FROM public."CatalogItems" WHERE id = p_item_id;
  IF v_org_id IS NULL THEN RETURN; END IF;

  SELECT r.shipping_pct, r.import_tax_pct, r.minimum_margin_pct, r.msrp_pct_sale_in, r.msrp_pct
  INTO v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct_sale_in, v_msrp_pct
  FROM public.msrp_get_effective_rates(v_org_id, v_category_id) r;

  v_shipping_cost := round(v_cost_exw * COALESCE(v_shipping_pct, 0), 6);
  v_import_tax_cost := round((v_cost_exw + v_shipping_cost) * COALESCE(v_import_tax_pct, 0), 6);
  v_total_cost := round(v_cost_exw + v_shipping_cost + v_import_tax_cost, 6);
  v_dealer_price := round(v_total_cost / NULLIF(1 - COALESCE(v_min_margin_pct, 0), 0), 6);
  v_msrp := round(v_dealer_price / NULLIF(1 - COALESCE(v_msrp_pct, 0), 0), 6);

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id, cost_exw,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    shipping_cost, import_tax_cost, total_cost, dealer_price, msrp, updated_at
  ) VALUES (
    p_item_id, v_org_id, v_category_id, v_cost_exw,
    COALESCE(v_shipping_pct, 0), COALESCE(v_import_tax_pct, 0), COALESCE(v_min_margin_pct, 0), COALESCE(v_msrp_pct, 0),
    COALESCE(v_shipping_cost, 0), COALESCE(v_import_tax_cost, 0), COALESCE(v_total_cost, 0),
    COALESCE(v_dealer_price, 0), COALESCE(v_msrp, 0), now()
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    organization_id = EXCLUDED.organization_id, category_id = EXCLUDED.category_id, cost_exw = EXCLUDED.cost_exw,
    shipping_pct = EXCLUDED.shipping_pct, import_tax_pct = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct, msrp_pct = EXCLUDED.msrp_pct,
    shipping_cost = EXCLUDED.shipping_cost, import_tax_cost = EXCLUDED.import_tax_cost,
    total_cost = EXCLUDED.total_cost, dealer_price = EXCLUDED.dealer_price, msrp = EXCLUDED.msrp, updated_at = now();
END;
$$;


ALTER FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") IS 'Calcula MSRP para un CatalogItem.

Regla:
- total_cost = cost_exw + shipping_cost + import_tax_cost
- dealer_price = total_cost / (1 - minimum_margin_pct)
- msrp = dealer_price / (1 - msrp_pct_sale_out)

Nota: msrp_pct_sale_out es margen sobre la venta (margin-on-sale), aplicado sobre dealer_price.';



CREATE OR REPLACE FUNCTION "public"."msrp_get_effective_rates"("p_org_id" "uuid", "p_category_id" "uuid") RETURNS TABLE("shipping_pct" numeric, "import_tax_pct" numeric, "minimum_margin_pct" numeric, "msrp_pct_sale_in" numeric, "msrp_pct" numeric)
    LANGUAGE "sql" STABLE
    AS $$
  WITH RECURSIVE
  -- Categoría + ancestros (depth 0 = self, 1 = parent, ...) para heredar margen del padre
  ancestors(category_id, depth) AS (
    SELECT p_category_id, 0
    UNION ALL
    SELECT cc.parent_id, a.depth + 1
    FROM public."CatalogCategories" cc
    JOIN ancestors a ON cc.id = a.category_id
    WHERE cc.parent_id IS NOT NULL
  ),
  cs AS (
    SELECT
      COALESCE(shipping_pct, 0)::numeric AS shipping_pct,
      COALESCE(global_import_tax_pct, 0)::numeric AS global_import_tax_pct,
      COALESCE(minimum_margin_pct, 0)::numeric AS minimum_margin_pct,
      COALESCE(default_msrp_pct, 0)::numeric AS default_msrp_pct
    FROM public."CostSettings" WHERE organization_id = p_org_id LIMIT 1
  ),
  -- Primer margen encontrado subiendo por la jerarquía (igual que get_category_margins_for_category)
  cm AS (
    SELECT cm_inner.minimum_margin_pct::numeric AS msrp_pct_sale_in, cm_inner.msrp_pct::numeric AS msrp_pct
    FROM public."CategoryMargins" cm_inner
    JOIN ancestors a ON cm_inner.category_id = a.category_id
    WHERE cm_inner.organization_id = p_org_id AND cm_inner.is_active = true
    ORDER BY a.depth ASC
    LIMIT 1
  ),
  it AS (
    SELECT import_tax_pct::numeric AS import_tax_pct
    FROM public."ImportTaxRules"
    WHERE organization_id = p_org_id AND category_id = p_category_id AND is_active = true LIMIT 1
  )
  SELECT
    COALESCE((SELECT shipping_pct FROM cs), 0),
    COALESCE((SELECT import_tax_pct FROM it), (SELECT global_import_tax_pct FROM cs), 0),
    COALESCE((SELECT msrp_pct_sale_in FROM cm), (SELECT minimum_margin_pct FROM cs), 0) AS minimum_margin_pct,
    COALESCE((SELECT msrp_pct_sale_in FROM cm), (1 - COALESCE((SELECT msrp_pct FROM cm), (SELECT default_msrp_pct FROM cs), 0))) AS msrp_pct_sale_in,
    COALESCE((SELECT msrp_pct FROM cm), (SELECT default_msrp_pct FROM cs), 0) AS msrp_pct
$$;


ALTER FUNCTION "public"."msrp_get_effective_rates"("p_org_id" "uuid", "p_category_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."msrp_get_effective_rates"("p_org_id" "uuid", "p_category_id" "uuid") IS 'Rates for MSRP: CostSettings + CategoryMargins (resolved by category hierarchy) + ImportTaxRules.';



CREATE OR REPLACE FUNCTION "public"."msrp_recompute_for_category"("p_category_id" "uuid", "p_organization_id" "uuid" DEFAULT NULL::"uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
DECLARE
  v_item RECORD;
  v_count integer := 0;
  v_org_filter text;
BEGIN
  -- Construir filtro de organización si se proporciona
  IF p_organization_id IS NOT NULL THEN
    v_org_filter := format('AND organization_id = %L', p_organization_id);
  ELSE
    v_org_filter := '';
  END IF;

  -- Recalcular todos los items de la categoría (y subcategorías si aplica)
  FOR v_item IN
    EXECUTE format('
      SELECT id
      FROM public."CatalogItems"
      WHERE category_id = $1
        AND cost_exw > 0
        AND organization_id IS NOT NULL
        %s
    ', v_org_filter)
    USING p_category_id
  LOOP
    BEGIN
      PERFORM public.msrp_compute_for_item(v_item.id);
      v_count := v_count + 1;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Error recalculando item %: %', v_item.id, SQLERRM;
    END;
  END LOOP;

  RETURN v_count;
END;
$_$;


ALTER FUNCTION "public"."msrp_recompute_for_category"("p_category_id" "uuid", "p_organization_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."msrp_recompute_for_category"("p_category_id" "uuid", "p_organization_id" "uuid") IS 'Recalcula MSRP para todos los CatalogItems de una categoría. Útil cuando cambian ImportTaxRules o CategoryMargins.';



CREATE OR REPLACE FUNCTION "public"."next_dealer_no"("p_org_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_next_no integer;
BEGIN
  UPDATE public."Organizations"
  SET next_dealer_no = next_dealer_no + 1
  WHERE id = p_org_id
  RETURNING next_dealer_no INTO v_next_no;

  IF v_next_no IS NULL THEN
    RAISE EXCEPTION 'Organization % not found', p_org_id;
  END IF;

  RETURN v_next_no::text;
END;
$$;


ALTER FUNCTION "public"."next_dealer_no"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."next_dealer_no"("p_org_id" "uuid") IS 'Atomically increments Organizations.next_dealer_no. Used by trigger on Dealers insert.';



CREATE OR REPLACE FUNCTION "public"."on_quote_approved_create_sales_order"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_so_id uuid;
  v_so_no text;
begin
  if new.status = 'approved' and old.status is distinct from new.status then

    if not exists (
      select 1 from "SalesOrders"
      where quote_id = new.id and deleted = false
    ) then

      v_so_no := 'SO-' || to_char(now(),'YYMMDD') || '-' ||
                 substr(replace(gen_random_uuid()::text,'-',''),1,6);

      insert into "SalesOrders" (
        organization_id,
        quote_id,
        sales_order_no
      ) values (
        new.organization_id,
        new.id,
        v_so_no
      )
      returning id into v_so_id;

      insert into "OrderList" (
        organization_id,
        sales_order_id
      ) values (
        new.organization_id,
        v_so_id
      );

      update "Quotes"
      set tracking_status = 'pending_confirmation'
      where id = new.id;
    end if;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."on_quote_approved_create_sales_order"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."on_sales_order_status_mirror"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  update "OrderList"
  set tracking_status = new.tracking_status
  where sales_order_id = new.id
    and deleted = false;

  update "Quotes"
  set tracking_status = new.tracking_status
  where id = new.quote_id
    and status = 'approved'
    and deleted = false;

  return new;
end;
$$;


ALTER FUNCTION "public"."on_sales_order_status_mirror"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."quote_lines_set_dealer_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.dealer_id IS NULL AND NEW.quote_id IS NOT NULL THEN
    SELECT q.dealer_id INTO NEW.dealer_id
    FROM public."Quotes" q
    WHERE q.id = NEW.quote_id AND q.organization_id = NEW.organization_id
    LIMIT 1;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."quote_lines_set_dealer_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."quote_lines_validate_dealer"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_quote_dealer uuid;
BEGIN
  IF NEW.quote_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT q.dealer_id INTO v_quote_dealer
  FROM public."Quotes" q
  WHERE q.id = NEW.quote_id AND q.organization_id = NEW.organization_id
  LIMIT 1;

  IF v_quote_dealer IS NULL THEN
    RAISE EXCEPTION 'QuoteLines: quote_id % has no dealer_id (or quote not found) for org %', NEW.quote_id, NEW.organization_id;
  END IF;

  IF NEW.dealer_id IS NOT NULL AND NEW.dealer_id <> v_quote_dealer THEN
    RAISE EXCEPTION 'QuoteLines: dealer_id % does not match Quotes.dealer_id % for quote %', NEW.dealer_id, v_quote_dealer, NEW.quote_id;
  END IF;

  IF NEW.dealer_id IS NULL THEN
    NEW.dealer_id := v_quote_dealer;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."quote_lines_validate_dealer"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rebuild_catalogitem_conversions"("p_org" "uuid" DEFAULT NULL::"uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
begin
  if p_org is null then
    truncate table public."CatalogItemConversions";
  else
    delete from public."CatalogItemConversions" where organization_id = p_org;
  end if;

  insert into public."CatalogItemConversions" (
    catalog_item_id,
    organization_id,
    cost_exw_input,
    unit_of_measure_input,
    roll_width_input,
    cost_exw_per_m,
    cost_exw_per_m2,
    computed_at
  )
  select
    ci.id,
    ci.organization_id,
    ci.cost_exw,
    ci.unit_of_measure,
    ci.roll_width,
    c.cost_exw_per_m,
    c.cost_exw_per_m2,
    now()
  from public."CatalogItems" ci
  cross join lateral public.compute_roll_conversions(ci.cost_exw, ci.unit_of_measure, ci.roll_width) c
  where coalesce(ci.is_roll,false) = true
    and (p_org is null or ci.organization_id = p_org);
end;
$$;


ALTER FUNCTION "public"."rebuild_catalogitem_conversions"("p_org" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_cost_exw numeric; v_category_id uuid; v_unit_of_measure text;
  v_shipping_pct numeric := 0; v_import_tax_pct numeric := 0;
  v_min_margin_pct numeric := 0.35; v_msrp_pct numeric := 0.65;
  v_material_cost numeric := 0; v_shipping_cost numeric := 0; v_import_tax_cost numeric := 0;
  v_total_cost numeric := 0; v_dealer_price numeric := 0; v_msrp numeric := 0;
BEGIN
  SELECT cost_exw, category_id, unit_of_measure INTO v_cost_exw, v_category_id, v_unit_of_measure
  FROM public."CatalogItems" WHERE id = p_catalog_item_id;
  IF v_cost_exw IS NULL OR v_cost_exw <= 0 THEN RETURN; END IF;

  SELECT
    COALESCE(cs.shipping_pct, 0), COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
    COALESCE(cs.minimum_margin_pct, 0.35), COALESCE(cs.default_msrp_pct, 0.65)
  INTO v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct
  FROM public."CostSettings" cs WHERE cs.organization_id = p_organization_id LIMIT 1;

  SELECT COALESCE(cm.minimum_margin_pct, v_min_margin_pct), COALESCE(cm.msrp_pct, v_msrp_pct)
  INTO v_min_margin_pct, v_msrp_pct
  FROM public."CategoryMargins" cm
  WHERE cm.organization_id = p_organization_id AND cm.category_id = v_category_id AND COALESCE(cm.is_active, true) LIMIT 1;

  v_material_cost := v_cost_exw;
  v_shipping_cost := round(v_cost_exw * v_shipping_pct, 4);
  v_import_tax_cost := round((v_cost_exw + v_shipping_cost) * v_import_tax_pct, 4);
  v_total_cost := round(v_cost_exw + v_shipping_cost + v_import_tax_cost, 4);
  v_dealer_price := round(v_total_cost / NULLIF(1 - v_min_margin_pct, 0), 4);
  v_msrp := round(v_dealer_price / NULLIF(1 - v_msrp_pct, 0), 4);

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id, unit_of_measure,
    cost_exw, shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    shipping_cost, import_tax_cost, total_cost, dealer_price, msrp, updated_at
  ) VALUES (
    p_catalog_item_id, p_organization_id, v_category_id, v_unit_of_measure,
    v_cost_exw, v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct,
    v_shipping_cost, v_import_tax_cost, v_total_cost, v_dealer_price, v_msrp, now()
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    cost_exw = EXCLUDED.cost_exw, shipping_pct = EXCLUDED.shipping_pct, import_tax_pct = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct, msrp_pct = EXCLUDED.msrp_pct,
    shipping_cost = EXCLUDED.shipping_cost, import_tax_cost = EXCLUDED.import_tax_cost,
    total_cost = EXCLUDED.total_cost, dealer_price = EXCLUDED.dealer_price, msrp = EXCLUDED.msrp, updated_at = now();
END;
$$;


ALTER FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") IS 'Recompute CatalogItemsMSRP. CostSettings: minimum_margin_pct, default_msrp_pct.';



CREATE OR REPLACE FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" "uuid", "p_category_id" "uuid") RETURNS "void"
    LANGUAGE "sql"
    AS $$
  WITH RECURSIVE descendants(category_id) AS (
    SELECT id FROM public."CatalogCategories" WHERE id = p_category_id
    UNION ALL
    SELECT cc.id
    FROM public."CatalogCategories" cc
    JOIN descendants d ON cc.parent_id = d.category_id
  )
  INSERT INTO public."CatalogItemsMSRP" (
    organization_id, catalog_item_id, category_id, sku, name, collection_name, variant_name, unit_of_measure,
    cost_exw, shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    shipping_cost, import_tax_cost, total_cost, dealer_price, msrp, updated_at
  )
  SELECT
    p_org_id, ci.id, ci.category_id, ci.sku, ci.name, ci.collection_name, ci.variant_name, ci.unit_of_measure,
    COALESCE(ci.cost_exw, 0),
    COALESCE(rates.shipping_pct, 0), COALESCE(rates.import_tax_pct, 0),
    COALESCE(rates.minimum_margin_pct, 0.35), COALESCE(rates.msrp_pct, 0.65),
    round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4),
    round((COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4)) * COALESCE(rates.import_tax_pct, 0), 4),
    round(COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4) +
      round((COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4)) * COALESCE(rates.import_tax_pct, 0), 4), 4),
    round((COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4) +
      round((COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4)) * COALESCE(rates.import_tax_pct, 0), 4))
      / NULLIF(1 - COALESCE(rates.minimum_margin_pct, 0.35), 0), 4),
    round(round((COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4) +
      round((COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4)) * COALESCE(rates.import_tax_pct, 0), 4))
      / NULLIF(1 - COALESCE(rates.minimum_margin_pct, 0.35), 0), 4)
      / NULLIF(1 - COALESCE(rates.msrp_pct, 0.65), 0), 4),
    now()
  FROM public."CatalogItems" ci
  LEFT JOIN public.msrp_get_effective_rates(p_org_id, ci.category_id) rates ON true
  WHERE ci.organization_id = p_org_id
    AND ci.category_id IN (SELECT category_id FROM descendants)
    AND ci.is_active = true
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    cost_exw = EXCLUDED.cost_exw, shipping_pct = EXCLUDED.shipping_pct, import_tax_pct = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct, msrp_pct = EXCLUDED.msrp_pct,
    shipping_cost = EXCLUDED.shipping_cost, import_tax_cost = EXCLUDED.import_tax_cost,
    total_cost = EXCLUDED.total_cost, dealer_price = EXCLUDED.dealer_price, msrp = EXCLUDED.msrp, updated_at = now();
$$;


ALTER FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" "uuid", "p_category_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" "uuid", "p_category_id" "uuid") IS 'Recompute CatalogItemsMSRP for a category and all its descendant categories (trigger on CategoryMargins). Uses msrp_pct.';



CREATE OR REPLACE FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id, sku, name, collection_name, variant_name, unit_of_measure,
    cost_exw, shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    shipping_cost, import_tax_cost, total_cost, dealer_price, msrp, updated_at
  )
  SELECT
    ci.id, ci.organization_id, ci.category_id, ci.sku, ci.name, ci.collection_name, ci.variant_name, ci.unit_of_measure,
    COALESCE(ci.cost_exw, 0),
    COALESCE(cs.shipping_pct, 0), COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
    COALESCE(cm.minimum_margin_pct, cs.minimum_margin_pct, 0.35),
    COALESCE(cm.msrp_pct, cs.default_msrp_pct, 0.65),
    round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4),
    round((COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4)) * COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0), 4),
    round(COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4) +
      round((COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4)) * COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0), 4), 4),
    round((COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4) +
      round((COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4)) * COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0), 4))
      / NULLIF(1 - COALESCE(cm.minimum_margin_pct, cs.minimum_margin_pct, 0.35), 0), 4),
    round(round((COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4) +
      round((COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4)) * COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0), 4))
      / NULLIF(1 - COALESCE(cm.minimum_margin_pct, cs.minimum_margin_pct, 0.35), 0), 4)
      / NULLIF(1 - COALESCE(cm.msrp_pct, cs.default_msrp_pct, 0.65), 0), 4),
    now()
  FROM public."CatalogItems" ci
  LEFT JOIN public."CostSettings" cs ON cs.organization_id = ci.organization_id
  LEFT JOIN public."CategoryMargins" cm ON cm.organization_id = ci.organization_id AND cm.category_id = ci.category_id
  WHERE ci.organization_id = p_org AND ci.is_active = true
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    cost_exw = EXCLUDED.cost_exw, shipping_pct = EXCLUDED.shipping_pct, import_tax_pct = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct, msrp_pct = EXCLUDED.msrp_pct,
    shipping_cost = EXCLUDED.shipping_cost, import_tax_cost = EXCLUDED.import_tax_cost,
    total_cost = EXCLUDED.total_cost, dealer_price = EXCLUDED.dealer_price, msrp = EXCLUDED.msrp, updated_at = now();
END;
$$;


ALTER FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" "uuid") IS 'Recompute CatalogItemsMSRP for org. CostSettings: minimum_margin_pct, default_msrp_pct.';



CREATE OR REPLACE FUNCTION "public"."resolve_catalog_item_for_bom_component"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_component_role" "text", "p_component_item_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  v_color text := public.get_quote_line_option_value(p_org_id, p_quote_line_id, 'hardware_color');
  v_collection text;
  v_variant text;
  v_id uuid;
BEGIN
  -- 1) SKU fijo
  IF p_component_item_id IS NOT NULL THEN
    RETURN p_component_item_id;
  END IF;

  -- 2) Tela (roll) por collection+variant en QuoteLines
  IF p_component_role = 'fabric' THEN
    SELECT ql.collection_name, ql.variant_name
      INTO v_collection, v_variant
    FROM public."QuoteLines" ql
    WHERE ql.organization_id = p_org_id
      AND ql.id = p_quote_line_id;

    SELECT ci.id INTO v_id
    FROM public."CatalogItems" ci
    WHERE ci.organization_id = p_org_id
      AND ci.deleted = false
      AND ci.is_roll = true
      AND ci.collection_name = v_collection
      AND ci.variant_name = v_variant
    LIMIT 1;

    IF v_id IS NULL THEN
      RAISE EXCEPTION 'No fabric roll found for collection=% variant=% (QuoteLine %)', v_collection, v_variant, p_quote_line_id;
    END IF;

    RETURN v_id;
  END IF;

  -- 3) Hardware por role + color (si existe)
  IF v_color IS NOT NULL THEN
    SELECT ci.id INTO v_id
    FROM public."CatalogItems" ci
    WHERE ci.organization_id = p_org_id
      AND ci.deleted = false
      AND ci.item_role = p_component_role
      AND ci.color = v_color
    ORDER BY ci.updated_at DESC
    LIMIT 1;

    IF v_id IS NOT NULL THEN
      RETURN v_id;
    END IF;
  END IF;

  -- 4) Fallback por role sin color
  SELECT ci.id INTO v_id
  FROM public."CatalogItems" ci
  WHERE ci.organization_id = p_org_id
    AND ci.deleted = false
    AND ci.item_role = p_component_role
  ORDER BY ci.updated_at DESC
  LIMIT 1;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'No CatalogItem found for role=% (QuoteLine %)', p_component_role, p_quote_line_id;
  END IF;

  RETURN v_id;
END;
$$;


ALTER FUNCTION "public"."resolve_catalog_item_for_bom_component"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_component_role" "text", "p_component_item_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_component_item_id"("p_org_id" "uuid", "p_component_role" "text", "p_sku_rule" "text", "p_quote_line_id" "uuid", "p_config" "jsonb", "p_fixed_component_item_id" "uuid", "p_override_item_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  v_item_id uuid;
  v_hw_color text;
  v_ql public."QuoteLines";
BEGIN
  -- fixed or override
  IF p_override_item_id IS NOT NULL THEN
    RETURN p_override_item_id;
  END IF;

  IF p_fixed_component_item_id IS NOT NULL THEN
    RETURN p_fixed_component_item_id;
  END IF;

  SELECT * INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id
    AND organization_id = p_org_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine not found %', p_quote_line_id;
  END IF;

  IF p_sku_rule = 'FABRIC_BY_COLLECTION_VARIANT' OR p_component_role = 'fabric' THEN
    IF v_ql.collection_name IS NULL OR v_ql.variant_name IS NULL THEN
      RAISE EXCEPTION 'Missing collection_name/variant_name on QuoteLine %', p_quote_line_id;
    END IF;

    SELECT ci.id INTO v_item_id
    FROM public."CatalogItems" ci
    WHERE ci.organization_id = p_org_id
      AND ci.is_roll = true
      AND ci.collection_name = v_ql.collection_name
      AND ci.variant_name = v_ql.variant_name
      AND ci.is_active = true
    LIMIT 1;

    IF v_item_id IS NULL THEN
      RAISE EXCEPTION 'No roll CatalogItem found for collection %, variant %',
        v_ql.collection_name, v_ql.variant_name;
    END IF;

    RETURN v_item_id;
  END IF;

  -- hardware: ROLE_AND_COLOR
  v_hw_color := NULL;

  -- expect config has a row 'hardware_color': {"hardware_color":"White"}
  IF (p_config ? 'hardware_color') THEN
    v_hw_color := NULLIF(p_config#>>ARRAY['hardware_color','hardware_color'], '');
  END IF;

  IF v_hw_color IS NULL THEN
    RAISE EXCEPTION 'hardware_color is required to resolve role %', p_component_role;
  END IF;

  -- Resolve uniquely
  SELECT ci.id INTO v_item_id
  FROM public."CatalogItems" ci
  WHERE ci.organization_id = p_org_id
    AND ci.is_roll = false
    AND ci.item_role = p_component_role
    AND ci.color = v_hw_color
    AND ci.is_active = true
  LIMIT 2;

  IF v_item_id IS NULL THEN
    RAISE EXCEPTION 'No hardware CatalogItem found for role % with color %', p_component_role, v_hw_color;
  END IF;

  -- Ambiguity check (LIMIT 2 trick)
  IF (SELECT COUNT(*) FROM public."CatalogItems" ci
      WHERE ci.organization_id = p_org_id
        AND ci.is_roll = false
        AND ci.item_role = p_component_role
        AND ci.color = v_hw_color
        AND ci.is_active = true) > 1 THEN
    RAISE EXCEPTION 'Ambiguous match for role % and color %; add more filters (manufacturer/system) or normalize catalog', p_component_role, v_hw_color;
  END IF;

  RETURN v_item_id;
END $$;


ALTER FUNCTION "public"."resolve_component_item_id"("p_org_id" "uuid", "p_component_role" "text", "p_sku_rule" "text", "p_quote_line_id" "uuid", "p_config" "jsonb", "p_fixed_component_item_id" "uuid", "p_override_item_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."resolve_component_item_id"("p_org_id" "uuid", "p_component_role" "text", "p_sku_rule" "text", "p_quote_line_id" "uuid", "p_config" "jsonb", "p_fixed_component_item_id" "uuid", "p_override_item_id" "uuid") IS 'LEGACY function. Uses sku_resolution_rule heuristics (ROLE_AND_COLOR, etc). 
New BOM generation uses explicit user selections (QuoteLineComponents kind=selection). 
Kept for backward compatibility.';



CREATE OR REPLACE FUNCTION "public"."resolve_quote_line_product_type_id"("p_quote_line_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
DECLARE
  v_org_id uuid;
  v_catalog_item_id uuid;
  v_product_type_code text;
  v_product_type_id uuid;
  has_ptid boolean;
BEGIN
  -- ¿QuoteLines tiene product_type_id?
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='QuoteLines'
      AND column_name='product_type_id'
  ) INTO has_ptid;

  -- Leer QuoteLine base (siempre)
  SELECT organization_id,
         catalog_item_id,
         product_type
  INTO v_org_id, v_catalog_item_id, v_product_type_code
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine not found %', p_quote_line_id;
  END IF;

  -- 1) Si existe QuoteLines.product_type_id úsalo
  IF has_ptid THEN
    EXECUTE 'SELECT product_type_id FROM public."QuoteLines" WHERE id = $1'
      INTO v_product_type_id
      USING p_quote_line_id;

    IF v_product_type_id IS NOT NULL THEN
      RETURN v_product_type_id;
    END IF;
  END IF;

  -- 2) Intentar por ProductTypes.code = QuoteLines.product_type (texto)
  IF to_regclass('public."ProductTypes"') IS NOT NULL AND v_product_type_code IS NOT NULL AND btrim(v_product_type_code) <> '' THEN
    EXECUTE 'SELECT id FROM public."ProductTypes" WHERE organization_id = $1 AND code = $2 LIMIT 1'
      INTO v_product_type_id
      USING v_org_id, v_product_type_code;

    IF v_product_type_id IS NOT NULL THEN
      RETURN v_product_type_id;
    END IF;
  END IF;

  -- 3) Resolver por CatalogItemProductTypes (la que tú tienes)
  IF to_regclass('public."CatalogItemProductTypes"') IS NOT NULL AND v_catalog_item_id IS NOT NULL THEN
    EXECUTE 'SELECT product_type_id
             FROM public."CatalogItemProductTypes"
             WHERE organization_id = $1 AND catalog_item_id = $2
             ORDER BY created_at DESC NULLS LAST
             LIMIT 1'
      INTO v_product_type_id
      USING v_org_id, v_catalog_item_id;

    IF v_product_type_id IS NOT NULL THEN
      RETURN v_product_type_id;
    END IF;
  END IF;

  RAISE EXCEPTION 'Cannot resolve product_type_id for QuoteLine % (org %, catalog_item %, product_type "%")',
    p_quote_line_id, v_org_id, v_catalog_item_id, v_product_type_code;
END;
$_$;


ALTER FUNCTION "public"."resolve_quote_line_product_type_id"("p_quote_line_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_quote_line_cost_snapshot"("p_quote_line_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_org_id uuid;
  v_quote_id uuid;
  v_result record;
  v_snapshot_id uuid;
BEGIN
  -- 1. Obtener org y quote
  SELECT organization_id, quote_id
  INTO v_org_id, v_quote_id
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  -- 2. Calcular costo (tu función que YA funciona)
  SELECT *
  INTO v_result
  FROM public.compute_quote_line_cost(
    p_quote_line_id,
    '{}'::jsonb
  );

  -- 3. Guardar snapshot
  INSERT INTO public."QuoteLineCosts" (
    organization_id,
    quote_id,
    quote_line_id,

    quantity,
    cost_exw,
    material_cost,

    labor_pct,
    labor_cost,

    shipping_pct,
    shipping_cost,

    import_tax_pct,
    import_tax_cost,

    total_cost
  )
  VALUES (
    v_org_id,
    v_quote_id,
    p_quote_line_id,

    v_result.quantity,
    v_result.cost_exw,
    v_result.material_cost,

    v_result.labor_pct,
    v_result.labor_cost,

    v_result.shipping_pct,
    v_result.shipping_cost,

    v_result.import_tax_pct,
    v_result.import_tax_cost,

    v_result.total_cost
  )
  RETURNING id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$;


ALTER FUNCTION "public"."save_quote_line_cost_snapshot"("p_quote_line_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_quote_line_prices_snapshot"("p_quote_line_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_cost record;
  v_q  record;
  v_default_margin numeric := 0.65; -- fallback si viene null
  v_discount_pct   numeric := 0;    -- fallback si viene null
  v_margin_pct     numeric;
  v_msrp           numeric;
  v_net_price      numeric;
  v_version        int;
BEGIN
  -- 1) Tomar la QuoteLine actual
  SELECT
    ql.id,
    ql.default_margin_pct,
    ql.discount_pct,
    ql.pricing_version
  INTO v_q
  FROM public."QuoteLines" ql
  WHERE ql.id = p_quote_line_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  -- 2) Tomar el último snapshot de costo
  SELECT *
  INTO v_cost
  FROM public."QuoteLineCosts"
  WHERE quote_line_id = p_quote_line_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No QuoteLineCosts snapshot for QuoteLine %', p_quote_line_id;
  END IF;

  -- 3) Margin / discount
  v_margin_pct   := COALESCE(v_q.default_margin_pct, v_default_margin);
  v_discount_pct := COALESCE(v_q.discount_pct, v_discount_pct);

  -- 4) MSRP basado en costo total / (1 - margin)
  v_msrp := round(v_cost.total_cost / nullif(1 - v_margin_pct, 0), 4);

  -- 5) Net price = MSRP * (1 - discount)
  v_net_price := round(v_msrp * (1 - v_discount_pct), 4);

  -- 6) Bump pricing_version
  v_version := COALESCE(v_q.pricing_version, 0) + 1;

  -- 7) Guardar en QuoteLines (snapshot final de precios)
  UPDATE public."QuoteLines"
  SET
    msrp = v_msrp,
    net_price = v_net_price,
    pricing_version = v_version,
    pricing_locked = true,
    last_priced_at = now(),
    updated_at = now()
  WHERE id = p_quote_line_id;

  RETURN p_quote_line_id;
END;
$$;


ALTER FUNCTION "public"."save_quote_line_prices_snapshot"("p_quote_line_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."select_best_bom_template"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_template_id uuid;
BEGIN
  SELECT t.id
  INTO v_template_id
  FROM public."BOMTemplates" t
  WHERE t.organization_id = p_org_id
    AND t.product_type_id = p_product_type_id
    AND t.archived = false
    AND t.is_active = true
  ORDER BY
    COALESCE((t.metadata->>'priority')::int, 0) DESC,
    t.updated_at DESC
  LIMIT 1;

  IF v_template_id IS NULL THEN
    RAISE EXCEPTION
      'No BOMTemplate found for org %, product_type %',
      p_org_id, p_product_type_id;
  END IF;

  RETURN v_template_id;
END;
$$;


ALTER FUNCTION "public"."select_best_bom_template"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."select_best_bom_template_for_configured_product"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_template_id uuid;
    v_hardware_color text;
    v_selected_bottom_bar_sku text;
    v_selected_headbox_sku text;
    v_selected_side_channel_sku text;
    v_selected_bottom_channel_sku text;
    v_selected_motor_sku text;
    v_selected_drive_sku text;
    v_selected_tube_sku text;
    v_operating_type text; -- 'motor' o 'manual'
    v_matching_count integer;
    v_debug_info text;
    v_match_score integer;
BEGIN
    -- Extraer valores del config_snapshot
    v_hardware_color := p_config_snapshot->>'hardware_color';
    IF v_hardware_color IS NULL THEN
        v_hardware_color := p_config_snapshot->>'hardwareColor';
    END IF;
    IF v_hardware_color IS NULL THEN
        v_hardware_color := p_config_snapshot->>'operatingSystemColor';
    END IF;
    
    -- Normalizar hardware_color (capitalize first letter)
    IF v_hardware_color IS NOT NULL THEN
        v_hardware_color := UPPER(SUBSTRING(v_hardware_color, 1, 1)) || LOWER(SUBSTRING(v_hardware_color, 2));
    END IF;
    
    v_selected_bottom_bar_sku := p_config_snapshot->>'bottom_bar_sku';
    v_selected_headbox_sku := p_config_snapshot->>'headbox_sku';
    v_selected_side_channel_sku := p_config_snapshot->>'side_channel_sku';
    v_selected_bottom_channel_sku := p_config_snapshot->>'bottom_channel_sku';
    v_selected_motor_sku := p_config_snapshot->>'motor_sku';
    v_selected_drive_sku := p_config_snapshot->>'drive_sku';
    v_selected_tube_sku := p_config_snapshot->>'tube_sku';
    
    -- ✅ CRITICAL: Determinar Operating Type (obligatorio)
    -- Si hay motor_sku, operating_type = 'motor'
    -- Si hay drive_sku, operating_type = 'manual'
    -- NO pueden estar ambos
    IF v_selected_motor_sku IS NOT NULL AND v_selected_drive_sku IS NOT NULL THEN
        RAISE WARNING 'Invalid config: both motor_sku and drive_sku are set. Only one should be set.';
        -- Preferir motor si ambos están presentes
        v_operating_type := 'motor';
        v_selected_drive_sku := NULL;
    ELSIF v_selected_motor_sku IS NOT NULL THEN
        v_operating_type := 'motor';
    ELSIF v_selected_drive_sku IS NOT NULL THEN
        v_operating_type := 'manual';
    ELSE
        v_operating_type := NULL;
    END IF;

    -- ✅ DEBUG: Log valores extraídos
    v_debug_info := format(
        'Config snapshot: hardware_color=%s, operating_type=%s, bottom_bar_sku=%s, headbox_sku=%s, motor_sku=%s, drive_sku=%s, tube_sku=%s, side_channel_sku=%s, bottom_channel_sku=%s',
        v_hardware_color,
        v_operating_type,
        v_selected_bottom_bar_sku,
        v_selected_headbox_sku,
        v_selected_motor_sku,
        v_selected_drive_sku,
        v_selected_tube_sku,
        v_selected_side_channel_sku,
        v_selected_bottom_channel_sku
    );
    RAISE NOTICE '%', v_debug_info;

    -- ✅ FILTRADO PROGRESIVO: Buscar templates que coincidan EXACTAMENTE
    -- OBLIGATORIOS primero, luego OPCIONALES
    -- Usar subquery para calcular score y ordenar
    WITH scored_templates AS (
        SELECT bt.id,
               bt.hardware_color,
               bt.metadata,
               bt.updated_at,
               -- Calcular score: más coincidencias = mejor
               (CASE WHEN v_hardware_color IS NOT NULL 
                          AND LOWER(TRIM(COALESCE(bt.hardware_color, ''))) = LOWER(TRIM(v_hardware_color)) 
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_bottom_bar_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'bottom_bar'
                                        AND TRIM(ci.sku) = TRIM(v_selected_bottom_bar_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_tube_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'tube'
                                        AND TRIM(ci.sku) = TRIM(v_selected_tube_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_operating_type = 'motor' AND v_selected_motor_sku IS NOT NULL
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'motor'
                                        AND TRIM(ci.sku) = TRIM(v_selected_motor_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_operating_type = 'manual' AND v_selected_drive_sku IS NOT NULL
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'drive'
                                        AND TRIM(ci.sku) = TRIM(v_selected_drive_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_headbox_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'headbox'
                                        AND TRIM(ci.sku) = TRIM(v_selected_headbox_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_side_channel_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'side_channel'
                                        AND TRIM(ci.sku) = TRIM(v_selected_side_channel_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_bottom_channel_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'bottom_channel'
                                        AND TRIM(ci.sku) = TRIM(v_selected_bottom_channel_sku))
                     THEN 1 ELSE 0 END) AS match_score
        FROM "public"."BOMTemplates" bt
        WHERE bt.organization_id = p_org_id
            AND bt.product_type_id = p_product_type_id
            AND bt.deleted = false
            AND bt.archived = false
            -- ✅ OBLIGATORIO 1: hardware_color debe coincidir EXACTAMENTE
            AND (
                v_hardware_color IS NULL 
                OR LOWER(TRIM(COALESCE(bt.hardware_color, ''))) = LOWER(TRIM(v_hardware_color))
            )
            -- ✅ OBLIGATORIO 2: Bottom Bar SKU debe coincidir EXACTAMENTE
            AND (
                v_selected_bottom_bar_sku IS NULL
                OR EXISTS (
                    SELECT 1 FROM "public"."BOMTemplateSlots" bts
                    JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                    WHERE bts.bom_template_id = bt.id
                        AND bts.organization_id = p_org_id
                        AND bts.item_role = 'bottom_bar'
                        AND TRIM(ci.sku) = TRIM(v_selected_bottom_bar_sku)
                )
            )
            -- ✅ OBLIGATORIO 3: Tube SKU debe coincidir EXACTAMENTE
            AND (
                v_selected_tube_sku IS NULL
                OR EXISTS (
                    SELECT 1 FROM "public"."BOMTemplateSlots" bts
                    JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                    WHERE bts.bom_template_id = bt.id
                        AND bts.organization_id = p_org_id
                        AND bts.item_role = 'tube'
                        AND TRIM(ci.sku) = TRIM(v_selected_tube_sku)
                )
            )
            -- ✅ OBLIGATORIO 4: Operating Type (motor O drive, no ambos)
            AND (
                v_operating_type IS NULL
                OR (
                    v_operating_type = 'motor' 
                    AND v_selected_motor_sku IS NOT NULL
                    AND EXISTS (
                        SELECT 1 FROM "public"."BOMTemplateSlots" bts
                        JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                        WHERE bts.bom_template_id = bt.id
                            AND bts.organization_id = p_org_id
                            AND bts.item_role = 'motor'
                            AND TRIM(ci.sku) = TRIM(v_selected_motor_sku)
                    )
                    -- ✅ Validar que NO tenga drive_sku (no puede tener ambos)
                    AND NOT EXISTS (
                        SELECT 1 FROM "public"."BOMTemplateSlots" bts
                        JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                        WHERE bts.bom_template_id = bt.id
                            AND bts.organization_id = p_org_id
                            AND bts.item_role = 'drive'
                            AND TRIM(ci.sku) = TRIM(v_selected_drive_sku)
                    )
                )
                OR (
                    v_operating_type = 'manual' 
                    AND v_selected_drive_sku IS NOT NULL
                    AND EXISTS (
                        SELECT 1 FROM "public"."BOMTemplateSlots" bts
                        JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                        WHERE bts.bom_template_id = bt.id
                            AND bts.organization_id = p_org_id
                            AND bts.item_role = 'drive'
                            AND TRIM(ci.sku) = TRIM(v_selected_drive_sku)
                    )
                    -- ✅ Validar que NO tenga motor_sku (no puede tener ambos)
                    AND NOT EXISTS (
                        SELECT 1 FROM "public"."BOMTemplateSlots" bts
                        JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                        WHERE bts.bom_template_id = bt.id
                            AND bts.organization_id = p_org_id
                            AND bts.item_role = 'motor'
                            AND TRIM(ci.sku) = TRIM(v_selected_motor_sku)
                    )
                )
            )
            -- ✅ OPCIONAL 1: Headbox SKU (si está seleccionado, debe coincidir)
            AND (
                v_selected_headbox_sku IS NULL
                OR EXISTS (
                    SELECT 1 FROM "public"."BOMTemplateSlots" bts
                    JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                    WHERE bts.bom_template_id = bt.id
                        AND bts.organization_id = p_org_id
                        AND bts.item_role = 'headbox'
                        AND TRIM(ci.sku) = TRIM(v_selected_headbox_sku)
                )
            )
            -- ✅ OPCIONAL 2: Side Channel SKU (si está seleccionado, debe coincidir)
            AND (
                v_selected_side_channel_sku IS NULL
                OR EXISTS (
                    SELECT 1 FROM "public"."BOMTemplateSlots" bts
                    JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                    WHERE bts.bom_template_id = bt.id
                        AND bts.organization_id = p_org_id
                        AND bts.item_role = 'side_channel'
                        AND TRIM(ci.sku) = TRIM(v_selected_side_channel_sku)
                )
            )
            -- ✅ OPCIONAL 3: Bottom Channel SKU (si está seleccionado, debe coincidir)
            AND (
                v_selected_bottom_channel_sku IS NULL
                OR EXISTS (
                    SELECT 1 FROM "public"."BOMTemplateSlots" bts
                    JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                    WHERE bts.bom_template_id = bt.id
                        AND bts.organization_id = p_org_id
                        AND bts.item_role = 'bottom_channel'
                        AND TRIM(ci.sku) = TRIM(v_selected_bottom_channel_sku)
                )
            )
    )
    SELECT st.id, st.match_score
    INTO v_template_id, v_match_score
    FROM scored_templates st
    ORDER BY 
        -- 1. Priorizar por score (más coincidencias primero) - CRÍTICO para desambiguar
        st.match_score DESC,
        -- 2. Priorizar templates que coincidan con hardware_color exacto
        CASE 
            WHEN v_hardware_color IS NOT NULL 
                 AND LOWER(TRIM(COALESCE(st.hardware_color, ''))) = LOWER(TRIM(v_hardware_color)) 
            THEN 0 
            ELSE 1 
        END,
        -- 3. Luego por priority en metadata
        COALESCE((st.metadata->>'priority')::int, 0) DESC,
        -- 4. Finalmente por updated_at (más reciente primero)
        st.updated_at DESC
    LIMIT 1;

    -- ✅ DEBUG: Si no se encontró template, log información de debugging
    IF v_template_id IS NULL THEN
        -- Contar templates disponibles para este product_type_id
        SELECT COUNT(*) INTO v_matching_count
        FROM "public"."BOMTemplates" bt
        WHERE bt.organization_id = p_org_id
            AND bt.product_type_id = p_product_type_id
            AND bt.deleted = false
            AND bt.archived = false;
        
        RAISE WARNING 'No BOMTemplate found for org=%, product_type_id=%, hardware_color=%, operating_type=%. Available templates for product_type: %. Config: %',
            p_org_id, p_product_type_id, v_hardware_color, v_operating_type, v_matching_count, v_debug_info;
    ELSE
        RAISE NOTICE 'BOMTemplate found: % (score: %) for org=%, product_type_id=%, hardware_color=%, operating_type=%',
            v_template_id, v_match_score, p_org_id, p_product_type_id, v_hardware_color, v_operating_type;
    END IF;

    RETURN v_template_id;
END;
$$;


ALTER FUNCTION "public"."select_best_bom_template_for_configured_product"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."select_best_bom_template_for_configured_product"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") IS 'Selecciona el mejor BOMTemplate para una configuración con filtrado progresivo.
✅ FILTRADO PROGRESIVO:
- OBLIGATORIOS: ProductType, Color (hardware_color), Bottom Bar (bottom_bar_sku), Operating Type (motor_sku O drive_sku, no ambos), Tube (tube_sku)
- OPCIONALES: Headbox (headbox_sku), Side Channel (side_channel_sku), Bottom Channel (bottom_channel_sku)
✅ VALIDACIONES:
- SKUs deben coincidir EXACTAMENTE (trim, case-sensitive)
- hardware_color debe coincidir EXACTAMENTE (case-insensitive)
- Operating Type: motor O manual, no ambos
- No permite SKUs duplicados en el mismo template
✅ PRIORIZACIÓN:
- Ordena por score de coincidencias (más coincidencias = mejor)
- Luego por hardware_color exacto
- Luego por priority en metadata
- Finalmente por updated_at (más reciente primero)';



CREATE OR REPLACE FUNCTION "public"."select_best_bom_template_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_forced_template uuid;
  v_match_template uuid;
begin
  -- 1) Si la QuoteLine ya trae un template forzado y está activo, úsalo SIEMPRE
  select ql.bom_template_id
    into v_forced_template
  from public."QuoteLines" ql
  join public."BOMTemplates" bt
    on bt.id = ql.bom_template_id
   and bt.organization_id = ql.organization_id
   and bt.deleted = false
   and bt.archived = false
   and bt.is_active = true
  where ql.id = p_quote_line_id
    and ql.organization_id = p_org_id
    and ql.bom_template_id is not null
  limit 1;

  if v_forced_template is not null then
    return v_forced_template;
  end if;

  /*
    2) Aquí iría tu lógica “real” de matching (por cassette/motor/color/etc).
       Si hoy esa lógica te está devolviendo NULL cuando hay campos "Not selected",
       el preview muere.

    3) Fallback seguro: si NO hay match, devuelve el primer template activo para ese product_type_id
  */
  select bt.id
    into v_match_template
  from public."BOMTemplates" bt
  where bt.organization_id = p_org_id
    and bt.product_type_id = p_product_type_id
    and bt.is_active = true
    and bt.deleted = false
    and bt.archived = false
  order by bt.sort_order asc nulls last, bt.updated_at desc, bt.created_at desc
  limit 1;

  if v_match_template is not null then
    return v_match_template;
  end if;

  -- Si NO hay ninguno activo para ese product_type_id, entonces sí es error real
  raise exception 'No BOM Template found for org=% product_type_id=%', p_org_id, p_product_type_id;
end;
$$;


ALTER FUNCTION "public"."select_best_bom_template_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."select_best_bom_template_for_quote_line_match"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_template_id uuid;
begin
  /*
    1) Intento “estricto” (si tú ya tienes lógica aquí, puedes dejarla arriba).
       Por ahora lo omitimos para asegurar que el sistema no se caiga.
  */

  /*
    2) FALLBACK DURO (urgente):
       Si hay templates activos para ese product_type_id, siempre devuelve 1.
  */
  select bt.id
    into v_template_id
  from public."BOMTemplates" bt
  where bt.organization_id = p_org_id
    and bt.product_type_id = p_product_type_id
    and coalesce(bt.is_active, true) = true
    and coalesce(bt.deleted, false) = false
    and coalesce(bt.archived, false) = false
  order by bt.sort_order asc nulls last, bt.updated_at desc
  limit 1;

  return v_template_id;
end;
$$;


ALTER FUNCTION "public"."select_best_bom_template_for_quote_line_match"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."select_best_bom_template_for_quote_line_match"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") IS 'Selecciona el mejor BOMTemplate basado en:
1. ProductType (primer filtro)
2. Color (hardware_color, segundo filtro)
3. Comparación de selecciones SKU del usuario con slots del template (más coincidencias = mejor)';



CREATE OR REPLACE FUNCTION "public"."select_best_bom_template_v2"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  WITH cfg AS (
    SELECT COALESCE(p_config, '{}'::jsonb) AS c
  ),
  candidates AS (
    SELECT
      bt.id,
      bt.code,
      COALESCE(bt.metadata->'requires','{}'::jsonb) AS req
    FROM public."BOMTemplates" bt
    WHERE bt.organization_id = p_org
      AND bt.product_type_id = p_product_type
      AND bt.active = true
      AND bt.deleted = false
      AND bt.archived = false
  ),
  matched AS (
    SELECT c.id, c.code
    FROM candidates c, cfg
    WHERE
      -- config incluye todas las condiciones del requires (uuid o null)
      (cfg.c @> c.req)

      -- XOR: drive_id vs motor_id (exactamente uno existe en requires)
      AND (
        ( (c.req ? 'drive_id') AND NOT (c.req ? 'motor_id') )
        OR
        ( (c.req ? 'motor_id') AND NOT (c.req ? 'drive_id') )
      )
  )
  SELECT m.id
  FROM matched m
  ORDER BY m.code
  LIMIT 1;
$$;


ALTER FUNCTION "public"."select_best_bom_template_v2"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."select_best_bom_template_v2_strict"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  v_id uuid;
BEGIN
  -- obligatorios roller (segun lo que me dijiste)
  IF NOT (p_config ? 'tube_id') OR (p_config->>'tube_id') IS NULL THEN
    RAISE EXCEPTION 'Missing tube_id in config';
  END IF;

  IF NOT (p_config ? 'bottom_bar_id') OR (p_config->>'bottom_bar_id') IS NULL THEN
    RAISE EXCEPTION 'Missing bottom_bar_id in config';
  END IF;

  -- XOR drive/motor
  IF (p_config ? 'drive_id') AND (p_config ? 'motor_id') THEN
    RAISE EXCEPTION 'Config cannot contain both drive_id and motor_id';
  END IF;

  IF NOT (p_config ? 'drive_id') AND NOT (p_config ? 'motor_id') THEN
    RAISE EXCEPTION 'Config must contain drive_id OR motor_id';
  END IF;

  SELECT public.select_best_bom_template_v2(p_org, p_product_type, p_config)
  INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'No BOMTemplate found for org %, product_type %', p_org, p_product_type;
  END IF;

  RETURN v_id;
END;
$$;


ALTER FUNCTION "public"."select_best_bom_template_v2_strict"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."select_exact_bom_template_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- ═══════════════════════════════════════════════════════════════════════
  -- FUNCIÓN DEPRECADA
  -- ═══════════════════════════════════════════════════════════════════════
  -- Esta función hacía JOIN con BOMTemplateComponents que NO existe.
  -- Fue reemplazada por el flujo ConfiguredProducts:
  -- 1. El frontend usa create_configured_product_and_bom_preview() que 
  --    internamente llama select_best_bom_template_for_configured_product()
  -- 2. El commit a QuoteLine usa commit_configured_product_to_quote_line()
  
  RAISE EXCEPTION 
    'DEPRECATED: select_exact_bom_template_for_quote_line() is no longer supported. '
    'Use the ConfiguredProducts flow instead: '
    '1) create_configured_product_and_bom_preview() to create ConfiguredProduct, '
    '2) commit_configured_product_to_quote_line() to commit to QuoteLine. '
    'Called with: org=%, quote_line=%, product_type=%',
    p_org_id, p_quote_line_id, p_product_type_id;
END;
$$;


ALTER FUNCTION "public"."select_exact_bom_template_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."select_exact_bom_template_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") IS '⚠️ DEPRECATED - Esta función ha sido deprecada porque referenciaba BOMTemplateComponents (tabla inexistente).

ALTERNATIVA: Usar el flujo ConfiguredProducts:
1. create_configured_product_and_bom_preview() - crea ConfiguredProduct con bom_template_id resuelto
2. commit_configured_product_to_quote_line() - commit a QuoteLine + BOMInstance

El matching de templates ahora se hace en select_best_bom_template_for_configured_product() 
o select_best_bom_template_v2_strict().';



CREATE OR REPLACE FUNCTION "public"."set_dealer_no"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.dealer_no IS NULL OR TRIM(NEW.dealer_no) = '' THEN
    NEW.dealer_no := public.next_dealer_no(NEW.organization_id);
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_dealer_no"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."set_dealer_no"() IS 'Trigger: auto-assign dealer_no on Dealers insert.';



CREATE OR REPLACE FUNCTION "public"."set_quote_line_company_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  -- si no viene company_id, herédalo del Quote
  if new.company_id is null and new.quote_id is not null then
    select q.company_id
      into new.company_id
    from public."Quotes" q
    where q.id = new.quote_id
      and q.organization_id = new.organization_id
    limit 1;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."set_quote_line_company_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end $$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at_product_type_role_rules"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at_product_type_role_rules"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_bom_template_slot_sku"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_item_id uuid;
  v_sku text;
BEGIN
  v_item_id := COALESCE(NEW.fixed_catalog_item_id, NEW.catalog_item_id);
  IF v_item_id IS NULL THEN
    NEW.slot_sku := NULL;
    RETURN NEW;
  END IF;

  SELECT trim(ci.sku) INTO v_sku
  FROM public."CatalogItems" ci
  WHERE ci.id = v_item_id
    AND (ci.organization_id = NEW.organization_id OR ci.organization_id IS NULL)
  LIMIT 1;

  NEW.slot_sku := v_sku;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_bom_template_slot_sku"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_catalogitem_collection_name_from_roll_collection"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_name text;
begin
  if new.roll_collection_id is null then
    return new;
  end if;

  select name into v_name
  from public."CatalogRollCollections"
  where id = new.roll_collection_id;

  if v_name is not null then
    new.collection_name = v_name;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."sync_catalogitem_collection_name_from_roll_collection"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_catalogitems_manufacturer"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_name text;
  v_id uuid;
BEGIN
  -- Normalize
  v_name := btrim(COALESCE(NEW.manufacturer, ''));

  -- If empty, keep manufacturer_id as-is (do not null it automatically)
  IF v_name = '' THEN
    RETURN NEW;
  END IF;

  -- Upsert Manufacturer row (case-insensitive)
  INSERT INTO public."Manufacturers"(organization_id, name)
  VALUES (NEW.organization_id, v_name)
  ON CONFLICT (organization_id, lower(name)) DO NOTHING;

  -- Fetch id
  SELECT id INTO v_id
  FROM public."Manufacturers"
  WHERE organization_id = NEW.organization_id
    AND lower(name) = lower(v_name)
  LIMIT 1;

  NEW.manufacturer_id := v_id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_catalogitems_manufacturer"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_catalogitems_to_msrp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    sku, name, collection_name, variant_name, unit_of_measure,
    cost_exw, shipping_cost, import_tax_cost, total_cost,
    dealer_price, msrp
  )
  VALUES (
    NEW.id, NEW.organization_id, NEW.category_id,
    NEW.sku, NEW.name, NEW.collection_name, NEW.variant_name, NEW.unit_of_measure,
    0, 0, 0, 0,
    0, 0
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    sku = EXCLUDED.sku,
    name = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure,
    category_id = EXCLUDED.category_id,
    updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_catalogitems_to_msrp"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_catalogitems_to_msrp"() IS 'Sync identity (sku, name, collection_name, variant_name, unit_of_measure) from CatalogItems to CatalogItemsMSRP. If row does not exist, INSERT with dealer_price=0, msrp=0 to satisfy NOT NULL.';



CREATE OR REPLACE FUNCTION "public"."sync_catalogitems_to_msrp_safe"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id,
    organization_id,
    category_id,

    cost_exw,
    shipping_cost,
    import_tax_cost,
    total_cost,

    dealer_price,
    msrp,

    sku,
    name,
    collection_name,
    variant_name,
    unit_of_measure,

    updated_at
  )
  VALUES (
    NEW.id,
    NEW.organization_id,
    NEW.category_id,

    COALESCE(NEW.cost_exw, 0),
    0,
    0,
    COALESCE(NEW.cost_exw, 0),

    0,
    0,

    NEW.sku,
    NEW.name,
    NEW.collection_name,
    NEW.variant_name,
    NEW.unit_of_measure,

    now()
  )
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    sku = EXCLUDED.sku,
    name = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure,
    category_id = EXCLUDED.category_id,
    updated_at = now();

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_catalogitems_to_msrp_safe"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_catalogitems_to_msrp_safe"() IS 'Sync identity (sku, name, collection_name, variant_name, unit_of_measure) from CatalogItems to CatalogItemsMSRP. If row does not exist, INSERT with minimal values. On UPDATE only touches identity, NOT cost_exw or total_cost (handled by msrp_compute_for_item).';



CREATE OR REPLACE FUNCTION "public"."sync_order_list_tracking_status"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Update OrderList.tracking_status to match SalesOrder
    UPDATE public."OrderList"
    SET 
        tracking_status = NEW.tracking_status,
        updated_at = now()
    WHERE sales_order_id = NEW.id
    AND deleted = false;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_order_list_tracking_status"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_order_list_tracking_status"() IS 'Trigger function: Syncs OrderList.tracking_status to match SalesOrders.tracking_status (mirror).';



CREATE OR REPLACE FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_ql RECORD;
  v_cp RECORD;
  v_snapshot jsonb;
  v_snapshot_totals jsonb;
  v_recalc jsonb;
  v_roll_msrp_total numeric(12,4);
  v_bom_total numeric(12,4);
  v_total_msrp numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_roll_total_cost numeric(12,4);
  v_bom_total_cost numeric(12,4);
  v_labor_amount numeric(12,4);
  v_accessories_total numeric(12,4);
  v_line_quantity numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required';
  END IF;

  -- a) Load QuoteLine
  SELECT id, organization_id, configured_product_id, quantity
  INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;
  IF v_ql.configured_product_id IS NULL THEN
    RETURN; -- nothing to sync
  END IF;

  v_line_quantity := NULLIF(GREATEST(COALESCE(v_ql.quantity, 1), 0.001), 0);

  -- b) Load ConfiguredProducts
  SELECT
    id, organization_id, bom_preview_snapshot,
    roll_msrp_total, bom_total, roll_total_cost, bom_total_cost,
    labor_amount, accessories_total, total_msrp, quantity
  INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = v_ql.configured_product_id
    AND organization_id = v_ql.organization_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found for QuoteLine %', v_ql.configured_product_id, p_quote_line_id;
  END IF;

  -- c) Same totals logic as commit_configured_product_to_quote_line
  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := v_snapshot->'totals';
  v_roll_msrp_total := 0;
  v_bom_total := 0;
  v_roll_total_cost := 0;
  v_bom_total_cost := 0;
  v_labor_amount := 0;
  v_accessories_total := 0;
  v_total_msrp := 0;

  IF v_snapshot->>'version' = '1' AND jsonb_array_length(COALESCE(v_snapshot->'items', '[]'::jsonb)) > 0 THEN
    SELECT COALESCE(SUM((item->>'line_total')::numeric), 0) INTO v_roll_msrp_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item WHERE item->>'kind' = 'roll';
    SELECT COALESCE(SUM(
      (item->>'line_total')::numeric + COALESCE((SELECT SUM((c->>'line_total')::numeric) FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c), 0)
    ), 0) INTO v_bom_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item WHERE item->>'kind' = 'parent';
    v_labor_amount := COALESCE((v_snapshot_totals->>'labor_amount')::numeric, 0);
    v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, 0);
    v_roll_total_cost := COALESCE((v_snapshot_totals->>'roll_total_cost')::numeric, 0);
    v_bom_total_cost := COALESCE((v_snapshot_totals->>'bom_total_cost')::numeric, 0);
  ELSIF v_snapshot->>'version' = '1' AND v_snapshot_totals IS NOT NULL THEN
    v_roll_msrp_total := COALESCE((v_snapshot_totals->>'roll_msrp_total')::numeric, 0);
    v_bom_total := COALESCE((v_snapshot_totals->>'bom_total')::numeric, 0);
    v_roll_total_cost := COALESCE((v_snapshot_totals->>'roll_total_cost')::numeric, 0);
    v_bom_total_cost := COALESCE((v_snapshot_totals->>'bom_total_cost')::numeric, 0);
    v_labor_amount := COALESCE((v_snapshot_totals->>'labor_amount')::numeric, 0);
    v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, 0);
    v_total_msrp := COALESCE((v_snapshot_totals->>'total_msrp')::numeric, 0);
  ELSE
    v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0);
    v_bom_total := COALESCE(v_cp.bom_total, 0);
    v_roll_total_cost := COALESCE(v_cp.roll_total_cost, 0);
    v_bom_total_cost := COALESCE(v_cp.bom_total_cost, 0);
    v_labor_amount := COALESCE(v_cp.labor_amount, 0);
    v_accessories_total := COALESCE(v_cp.accessories_total, 0);
    v_total_msrp := COALESCE(v_cp.total_msrp, 0);
  END IF;

  v_total_msrp := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total;

  IF (v_total_msrp IS NULL OR v_total_msrp = 0) THEN
    BEGIN
      v_recalc := public.calculate_configured_product_totals(v_ql.configured_product_id);
      IF v_recalc IS NOT NULL AND NOT (v_recalc ? 'error') THEN
        v_roll_msrp_total := COALESCE((v_recalc->>'roll_msrp_total')::numeric, 0);
        v_bom_total := COALESCE((v_recalc->>'bom_total')::numeric, 0);
        v_roll_total_cost := COALESCE((v_recalc->>'roll_total_cost')::numeric, 0);
        v_bom_total_cost := COALESCE((v_recalc->>'bom_total_cost')::numeric, 0);
        v_labor_amount := COALESCE((v_recalc->>'labor_amount')::numeric, 0);
        v_accessories_total := COALESCE((v_recalc->>'accessories_total')::numeric, 0);
        v_total_msrp := COALESCE((v_recalc->>'total_msrp')::numeric, 0);
        IF v_total_msrp = 0 THEN
          v_total_msrp := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total;
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;

  -- d) unit_msrp = total per unit; msrp = unit_msrp * line quantity (line total)
  v_unit_msrp := v_total_msrp / NULLIF(COALESCE(v_cp.quantity, 1), 0);
  v_total_msrp := v_unit_msrp * v_line_quantity;

  -- e) Update QuoteLines with same fields as commit_configured_product_to_quote_line
  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot = v_roll_msrp_total,
    bom_msrp_snapshot = v_bom_total,
    roll_cost_snapshot = v_roll_total_cost,
    bom_cost_snapshot = v_bom_total_cost,
    unit_msrp = v_unit_msrp,
    msrp = v_total_msrp,
    total_cost = v_roll_total_cost + v_bom_total_cost + v_labor_amount,
    last_priced_at = now(),
    pricing_version = COALESCE(pricing_version, 0) + 1,
    pricing_locked = true
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;


ALTER FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid") IS 'Syncs QuoteLines pricing (msrp, unit_msrp, snapshots, total_cost) from its configured_product_id. Use after EDIT when QuoteLine is pointed to CP_NEW. Same source as commit_configured_product_to_quote_line.';



CREATE OR REPLACE FUNCTION "public"."tg_set_dealer_id_from_portal_user"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v record;
BEGIN
  IF NEW.dealer_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    SELECT * INTO v FROM public.get_current_portal_user() LIMIT 1;
    IF v.id IS NOT NULL THEN
      NEW.dealer_id := v.dealer_id;
    END IF;
  EXCEPTION WHEN undefined_function THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."tg_set_dealer_id_from_portal_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_catalog_items_recompute_msrp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.cost_exw is distinct from old.cost_exw then
    -- recalcula para el org del item
    perform public.recompute_catalog_item_msrp(new.organization_id, new.id);
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_catalog_items_recompute_msrp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_catalogcategories_insert_category_margin"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_min_pct numeric := 0.35;
  v_msrp_pct numeric := 0.65;
BEGIN
  SELECT COALESCE(cs.minimum_margin_pct, 0.35), COALESCE(cs.default_msrp_pct, 0.65)
  INTO v_min_pct, v_msrp_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = NEW.organization_id
  LIMIT 1;

  INSERT INTO public."CategoryMargins" (
    organization_id, category_id, minimum_margin_pct, msrp_pct, is_active, created_at, updated_at
  ) VALUES (
    NEW.organization_id, NEW.id, v_min_pct, v_msrp_pct, true, now(), now()
  )
  ON CONFLICT (organization_id, category_id) DO NOTHING;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_catalogcategories_insert_category_margin"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."trg_catalogcategories_insert_category_margin"() IS 'Crea fila en CategoryMargins con defaults de CostSettings cuando se inserta una categoría en CatalogCategories.';



CREATE OR REPLACE FUNCTION "public"."trg_catalogitems_validate_roll_pricing_mode"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  -- If it's a roll, it MUST have a pricing mode
  if coalesce(new.is_roll,false) = true then
    if new.roll_pricing_mode is null then
      new.roll_pricing_mode := 'per_linear_meter';
    end if;

    -- If priced per m2, roll_width must be present (>0)
    if new.roll_pricing_mode = 'per_square_meter' then
      if new.roll_width is null or new.roll_width <= 0 then
        raise exception 'roll_width is required (>0, meters) when roll_pricing_mode = per_square_meter';
      end if;
    end if;

  else
    -- Non-roll items should not carry roll pricing mode (keeps data clean)
    new.roll_pricing_mode := null;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."trg_catalogitems_validate_roll_pricing_mode"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_catalogitems_write_conversions"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
  v_per_m  numeric := NULL;
  v_per_m2 numeric := NULL;
  v_per_ea numeric := NULL;
  v_effective_width_m numeric := NULL;
BEGIN
  IF NEW.cost_exw IS NULL OR NEW.unit_of_measure IS NULL THEN
    RETURN NEW;
  END IF;

  -- =========================
  -- LINEAR ($/m)
  -- =========================
  IF lower(NEW.unit_of_measure) IN ('m','meter','meters') THEN
    v_per_m := NEW.cost_exw;

  ELSIF lower(NEW.unit_of_measure) = 'ft' THEN
    v_per_m := NEW.cost_exw / 0.3048;

  ELSIF lower(NEW.unit_of_measure) = 'yd' THEN
    v_per_m := NEW.cost_exw / 0.9144;
  END IF;

  -- =========================
  -- ROLL AREA ($/m2)
  -- =========================
  -- Use roll_width_m (normalized) if available, fallback to roll_width (legacy)
  IF coalesce(NEW.is_roll, false) = true AND v_per_m IS NOT NULL THEN
    v_effective_width_m := COALESCE(NEW.roll_width_m, NEW.roll_width);
    
    IF v_effective_width_m IS NOT NULL AND v_effective_width_m > 0 THEN
      v_per_m2 := v_per_m / v_effective_width_m;
    END IF;
  END IF;

  -- =========================
  -- UNIT ($/ea)
  -- =========================
  IF lower(NEW.unit_of_measure) IN ('ea','pcs','pc','unit','piece') THEN
    v_per_ea := NEW.cost_exw;

  ELSIF lower(NEW.unit_of_measure) IN ('pack','set','box','case','bag')
        AND NEW.units_per_purchase_unit IS NOT NULL
        AND NEW.units_per_purchase_unit > 0 THEN
    v_per_ea := NEW.cost_exw / NEW.units_per_purchase_unit;
  END IF;

  -- =========================
  -- UPSERT
  -- =========================
  INSERT INTO public."CatalogItemConversions" (
    catalog_item_id,
    organization_id,
    cost_exw_input,
    unit_of_measure_input,
    roll_width_input,
    cost_exw_per_m,
    cost_exw_per_m2,
    cost_exw_per_ea,
    computed_at
  )
  VALUES (
    NEW.id,
    NEW.organization_id,
    NEW.cost_exw,
    NEW.unit_of_measure,
    v_effective_width_m, -- Use normalized width for consistency
    v_per_m,
    v_per_m2,
    v_per_ea,
    now()
  )
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    cost_exw_input = EXCLUDED.cost_exw_input,
    unit_of_measure_input = EXCLUDED.unit_of_measure_input,
    roll_width_input = EXCLUDED.roll_width_input,
    cost_exw_per_m = EXCLUDED.cost_exw_per_m,
    cost_exw_per_m2 = EXCLUDED.cost_exw_per_m2,
    cost_exw_per_ea = EXCLUDED.cost_exw_per_ea,
    computed_at = EXCLUDED.computed_at;

  RETURN NEW;
END;
$_$;


ALTER FUNCTION "public"."trg_catalogitems_write_conversions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_companies_set_company_no"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.company_no is null or btrim(new.company_no) = '' then
    new.company_no := public.next_company_no(new.organization_id);
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_companies_set_company_no"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trig_catmargins_msrp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE v_item_id uuid;
BEGIN
  IF TG_OP = 'UPDATE' AND (OLD.minimum_margin_pct = NEW.minimum_margin_pct) AND (OLD.msrp_pct = NEW.msrp_pct) THEN
    RETURN NEW;
  END IF;
  FOR v_item_id IN
    SELECT id FROM public."CatalogItems"
    WHERE organization_id = NEW.organization_id AND category_id = NEW.category_id
      AND cost_exw IS NOT NULL AND cost_exw > 0 AND is_active = true
  LOOP
    PERFORM "public"."msrp_compute_for_item"(v_item_id);
  END LOOP;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trig_catmargins_msrp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trig_enforce_msrp_sources"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE v_org uuid; v_cat uuid; r record;
BEGIN
  v_org := NEW.organization_id; v_cat := NEW.category_id;
  IF v_org IS NULL OR v_cat IS NULL THEN
    SELECT organization_id, category_id INTO v_org, v_cat FROM public."CatalogItems" WHERE id = NEW.catalog_item_id;
    NEW.organization_id := COALESCE(NEW.organization_id, v_org); NEW.category_id := COALESCE(NEW.category_id, v_cat);
  END IF;
  IF NEW.organization_id IS NULL OR NEW.category_id IS NULL THEN RETURN NEW; END IF;
  SELECT * INTO r FROM public.msrp_get_effective_rates(NEW.organization_id, NEW.category_id);
  NEW.shipping_pct := COALESCE(r.shipping_pct, 0);
  NEW.import_tax_pct := COALESCE(r.import_tax_pct, 0);
  NEW.minimum_margin_pct := COALESCE(r.minimum_margin_pct, 0);
  NEW.msrp_pct := COALESCE(r.msrp_pct, 0);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trig_enforce_msrp_sources"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF (TG_OP = 'INSERT') OR
     (TG_OP = 'UPDATE' AND (
       (OLD.cost_exw IS DISTINCT FROM NEW.cost_exw) OR
       (OLD.category_id IS DISTINCT FROM NEW.category_id)
     )) THEN
    -- Llamar siempre que organization_id exista (también con cost_exw=0; msrp_compute pone 0 en msrp_sale_in/out)
    PERFORM public.msrp_compute_for_item(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trig_recompute_msrp_on_category_margin_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_count integer;
BEGIN
  -- Recalcular todos los items de la categoría afectada
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    v_count := public.msrp_recompute_for_category(NEW.category_id, NEW.organization_id);
    RAISE NOTICE 'Recalculados % items para categoría % después de cambio en CategoryMargins', v_count, NEW.category_id;
  ELSIF TG_OP = 'DELETE' THEN
    v_count := public.msrp_recompute_for_category(OLD.category_id, OLD.organization_id);
    RAISE NOTICE 'Recalculados % items para categoría % después de eliminación en CategoryMargins', v_count, OLD.category_id;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION "public"."trig_recompute_msrp_on_category_margin_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trig_recompute_msrp_on_cost_settings_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_item RECORD;
  v_count integer := 0;
BEGIN
  -- Solo recalcular si cambió shipping_pct o global_import_tax_pct
  IF (TG_OP = 'UPDATE' AND (
    (OLD.shipping_pct IS DISTINCT FROM NEW.shipping_pct) OR
    (OLD.global_import_tax_pct IS DISTINCT FROM NEW.global_import_tax_pct)
  )) OR (TG_OP = 'INSERT') THEN
    -- Recalcular todos los items de la organización
    FOR v_item IN
      SELECT id
      FROM public."CatalogItems"
      WHERE organization_id = NEW.organization_id
        AND cost_exw > 0
    LOOP
      BEGIN
        PERFORM public.msrp_compute_for_item(v_item.id);
        v_count := v_count + 1;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE WARNING 'Error recalculando item %: %', v_item.id, SQLERRM;
      END;
    END LOOP;
    
    RAISE NOTICE 'Recalculados % items para organización % después de cambio en CostSettings', v_count, NEW.organization_id;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trig_recompute_msrp_on_cost_settings_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trig_recompute_msrp_on_import_tax_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_count integer;
BEGIN
  -- Recalcular todos los items de la categoría afectada
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    v_count := public.msrp_recompute_for_category(NEW.category_id, NEW.organization_id);
    RAISE NOTICE 'Recalculados % items para categoría % después de cambio en ImportTaxRules', v_count, NEW.category_id;
  ELSIF TG_OP = 'DELETE' THEN
    v_count := public.msrp_recompute_for_category(OLD.category_id, OLD.organization_id);
    RAISE NOTICE 'Recalculados % items para categoría % después de eliminación en ImportTaxRules', v_count, OLD.category_id;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION "public"."trig_recompute_msrp_on_import_tax_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_quote_line_sort_orders"("p_quote_id" "uuid", "p_updates" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_update jsonb;
  v_updated_count integer := 0;
  v_result jsonb;
BEGIN
  IF p_quote_id IS NULL THEN
    RAISE EXCEPTION 'quote_id is required';
  END IF;

  IF p_updates IS NULL OR jsonb_array_length(p_updates) = 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'updated_count', 0,
      'message', 'No updates provided'
    );
  END IF;

  FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    UPDATE public."QuoteLines"
    SET
      sort_order = (v_update->>'sort_order')::integer,
      updated_at = now()
    WHERE
      id = (v_update->>'id')::uuid
      AND quote_id = p_quote_id;

    IF FOUND THEN
      v_updated_count := v_updated_count + 1;
    END IF;
  END LOOP;

  v_result := jsonb_build_object(
    'success', true,
    'updated_count', v_updated_count,
    'total_provided', jsonb_array_length(p_updates),
    'message', format('Updated %s of %s quote lines', v_updated_count, jsonb_array_length(p_updates))
  );

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."update_quote_line_sort_orders"("p_quote_id" "uuid", "p_updates" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."update_quote_line_sort_orders"("p_quote_id" "uuid", "p_updates" "jsonb") IS 'Batch update sort_order for quote lines. Input: quote_id and JSONB array of {id: uuid, sort_order: integer}.';



CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_organization_user"("p_organization_id" "uuid", "p_user_email" "text", "p_role" "public"."org_role", "p_status" "public"."org_user_status" DEFAULT 'invited'::"public"."org_user_status", "p_user_name" "text" DEFAULT NULL::"text") RETURNS TABLE("id" "uuid", "organization_id" "uuid", "user_id" "uuid", "user_email" "text", "user_name" "text", "role" "public"."org_role", "status" "public"."org_user_status", "invited_by_user_id" "uuid", "invited_at" timestamp with time zone, "accepted_at" timestamp with time zone, "deleted" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_caller_user_id uuid;
  v_caller_role public.org_role;
  v_existing_id uuid;
  v_current_user_name text;
  v_result_record public."OrganizationUsers"%ROWTYPE;
BEGIN
  -- Obtener caller user_id (SECURITY DEFINER preserva auth.uid())
  v_caller_user_id := auth.uid();
  
  IF v_caller_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validar que caller es superadmin o admin en la organización
  SELECT ou.role INTO v_caller_role
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND ou.user_id = v_caller_user_id
    AND ou.deleted = false
    AND ou.status = 'active'
  LIMIT 1;

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Caller is not a member of organization %', p_organization_id;
  END IF;

  -- Solo permitir superadmin y admin (los valores que pueden gestionar usuarios)
  -- También aceptar 'owner' como legacy (mapeado a superadmin)
  IF v_caller_role::text NOT IN ('superadmin', 'admin', 'owner') THEN
    RAISE EXCEPTION 'Only superadmins and admins can manage organization users';
  END IF;

  -- Validar que admins no pueden crear superadmins
  IF v_caller_role::text IN ('admin') AND p_role::text = 'superadmin' THEN
    RAISE EXCEPTION 'Admins cannot create superadmins';
  END IF;

  -- También prevenir que admin cree 'owner' (legacy)
  IF v_caller_role::text IN ('admin') AND p_role::text = 'owner' THEN
    RAISE EXCEPTION 'Admins cannot create owners';
  END IF;

  -- Normalizar email
  p_user_email := lower(trim(p_user_email));

  -- Buscar si ya existe (incluyendo deleted=true para "revivir")
  -- Use explicit table alias to avoid ambiguity with RETURNS TABLE
  SELECT ou.id INTO v_existing_id
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND lower(ou.user_email) = p_user_email;

  IF v_existing_id IS NOT NULL THEN
    -- UPDATE: reactivar si estaba deleted, actualizar role/status/user_name
    -- Get current user_name first to preserve it if p_user_name is null
    SELECT ou2.user_name INTO v_current_user_name
    FROM public."OrganizationUsers" ou2
    WHERE ou2.id = v_existing_id;
    
    -- Use fully qualified column reference to avoid ambiguity with RETURNS TABLE id column
    UPDATE public."OrganizationUsers"
    SET
      role = p_role,
      status = p_status,
      user_name = COALESCE(p_user_name, v_current_user_name), -- Update name if provided, else keep existing
      deleted = false,
      updated_at = now()
    WHERE public."OrganizationUsers".id = v_existing_id
    RETURNING public."OrganizationUsers".* INTO v_result_record;
    
    -- Return as TABLE
    RETURN QUERY SELECT
      v_result_record.id,
      v_result_record.organization_id,
      v_result_record.user_id,
      v_result_record.user_email,
      v_result_record.user_name,
      v_result_record.role,
      v_result_record.status,
      v_result_record.invited_by_user_id,
      v_result_record.invited_at,
      v_result_record.accepted_at,
      v_result_record.deleted,
      v_result_record.created_at,
      v_result_record.updated_at;
  ELSE
    -- INSERT: nuevo usuario
    INSERT INTO public."OrganizationUsers" (
      organization_id,
      user_email,
      user_name,
      role,
      status,
      user_id, -- NULL hasta que acepte invite
      invited_by_user_id,
      invited_at,
      deleted,
      created_at,
      updated_at
    ) VALUES (
      p_organization_id,
      p_user_email,
      p_user_name, -- Include user_name in insert
      p_role,
      p_status,
      NULL, -- user_id será NULL hasta que acepte invite
      v_caller_user_id,
      now(),
      false,
      now(),
      now()
    )
    RETURNING * INTO v_result_record;
    
    -- Return as TABLE
    RETURN QUERY SELECT
      v_result_record.id,
      v_result_record.organization_id,
      v_result_record.user_id,
      v_result_record.user_email,
      v_result_record.user_name,
      v_result_record.role,
      v_result_record.status,
      v_result_record.invited_by_user_id,
      v_result_record.invited_at,
      v_result_record.accepted_at,
      v_result_record.deleted,
      v_result_record.created_at,
      v_result_record.updated_at;
  END IF;
END;
$$;


ALTER FUNCTION "public"."upsert_organization_user"("p_organization_id" "uuid", "p_user_email" "text", "p_role" "public"."org_role", "p_status" "public"."org_user_status", "p_user_name" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."upsert_organization_user"("p_organization_id" "uuid", "p_user_email" "text", "p_role" "public"."org_role", "p_status" "public"."org_user_status", "p_user_name" "text") IS 'Upsert organization user. Only superadmins/admins can call. Returns the created/updated OrganizationUsers row. Fixed ambiguous id column reference.';



CREATE TABLE IF NOT EXISTS "public"."BOMComponents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "bom_template_id" "uuid" NOT NULL,
    "component_item_id" "uuid",
    "component_role" "text" NOT NULL,
    "qty_type" "text" DEFAULT 'fixed'::"text" NOT NULL,
    "qty_value" numeric(12,4) DEFAULT 1 NOT NULL,
    "qty_delta_mm" numeric(12,4) DEFAULT 0 NOT NULL,
    "uom" "text" DEFAULT 'ea'::"text" NOT NULL,
    "waste_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "auto_select" boolean DEFAULT true NOT NULL,
    "sku_resolution_rule" "text" DEFAULT 'ROLE_AND_COLOR'::"text" NOT NULL,
    "depends_on_role" "text",
    "cut_axis" "text",
    "cut_delta_mm" numeric(12,4) DEFAULT 0 NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "component_mode" "public"."bom_component_mode" DEFAULT 'auto'::"public"."bom_component_mode" NOT NULL,
    "is_required" boolean DEFAULT false NOT NULL,
    "type_per_unit" "text",
    "component_scope" "text" DEFAULT 'bom'::"text" NOT NULL,
    "slot_id" "uuid",
    "qty_spacing_mm" integer,
    "qty_min" numeric,
    "parent_component_id" "uuid",
    "component_sub_role" "text",
    "metadata" "jsonb",
    CONSTRAINT "BOMComponents_component_scope_check" CHECK (("component_scope" = ANY (ARRAY['bom'::"text", 'sku'::"text"]))),
    CONSTRAINT "bomcomponents_component_role_check" CHECK (("component_role" = ANY (ARRAY['tube'::"text", 'track'::"text", 'bottom_bar'::"text", 'bottom_channel'::"text", 'hem_weight'::"text", 'side_channel'::"text", 'top_rail'::"text", 'headbox'::"text", 'bracket'::"text", 'idler'::"text", 'drive'::"text", 'motor'::"text", 'chain'::"text", 'chain_stop'::"text", 'chain_tensioner'::"text", 'wand'::"text", 'end_cap'::"text", 'filler'::"text", 'tape'::"text", 'consumable'::"text", 'fastener'::"text", 'accessory'::"text", 'carrier'::"text", 'belt'::"text", 'belt_connector'::"text", 'hook'::"text", 'brush'::"text", 'fabric'::"text", 'adapter'::"text", 'bearing'::"text", 'connector'::"text", 'guide'::"text", 'rail_connector'::"text", 'spring'::"text", 'stopper'::"text", 'mounting_clip'::"text", 'end_plug'::"text"]))),
    CONSTRAINT "bomcomponents_component_scope_check" CHECK (("component_scope" = ANY (ARRAY['template'::"text", 'bom'::"text"]))),
    CONSTRAINT "bomcomponents_depends_on_role_check" CHECK ((("depends_on_role" IS NULL) OR ("depends_on_role" = ANY (ARRAY['tube'::"text", 'track'::"text", 'bottom_bar'::"text", 'bottom_channel'::"text", 'hem_weight'::"text", 'side_channel'::"text", 'top_rail'::"text", 'headbox'::"text", 'bracket'::"text", 'idler'::"text", 'drive'::"text", 'motor'::"text", 'chain'::"text", 'chain_stop'::"text", 'chain_tensioner'::"text", 'wand'::"text", 'end_cap'::"text", 'filler'::"text", 'tape'::"text", 'consumable'::"text", 'fastener'::"text", 'accessory'::"text", 'carrier'::"text", 'belt'::"text", 'belt_connector'::"text", 'hook'::"text", 'brush'::"text", 'fabric'::"text", 'adapter'::"text", 'bearing'::"text", 'connector'::"text", 'guide'::"text", 'rail_connector'::"text", 'spring'::"text", 'stopper'::"text", 'mounting_clip'::"text", 'end_plug'::"text"])))),
    CONSTRAINT "bomcomponents_fixed_requires_item" CHECK (((("component_mode" <> 'fixed'::"public"."bom_component_mode") AND ("component_item_id" IS NULL)) OR (("component_mode" = 'fixed'::"public"."bom_component_mode") AND ("component_item_id" IS NOT NULL)) OR ("component_mode" = ANY (ARRAY['select'::"public"."bom_component_mode", 'auto'::"public"."bom_component_mode", 'optional'::"public"."bom_component_mode"]))))
);


ALTER TABLE "public"."BOMComponents" OWNER TO "postgres";


COMMENT ON COLUMN "public"."BOMComponents"."component_sub_role" IS 'Optional sub-role for granularity (e.g., hardware: fastener, end_cap, adapter)';



COMMENT ON COLUMN "public"."BOMComponents"."metadata" IS 'Additional JSON metadata for component configuration';



CREATE TABLE IF NOT EXISTS "public"."BOMTemplateSlots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "bom_template_id" "uuid" NOT NULL,
    "item_role" "text" NOT NULL,
    "required" boolean DEFAULT true NOT NULL,
    "catalog_item_id" "uuid",
    "qty" numeric(12,4) DEFAULT 1 NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "selection_mode" "text" DEFAULT 'user_select'::"text" NOT NULL,
    "fixed_catalog_item_id" "uuid",
    "slot_sku" "text",
    "deleted" boolean DEFAULT false NOT NULL,
    "archived" boolean DEFAULT false NOT NULL,
    CONSTRAINT "bomtemplateslots_item_role_check" CHECK (("item_role" = ANY (ARRAY['tube'::"text", 'track'::"text", 'bottom_bar'::"text", 'bottom_channel'::"text", 'hem_weight'::"text", 'side_channel'::"text", 'top_rail'::"text", 'headbox'::"text", 'bracket'::"text", 'idler'::"text", 'drive'::"text", 'motor'::"text", 'chain'::"text", 'chain_stop'::"text", 'chain_tensioner'::"text", 'wand'::"text", 'end_cap'::"text", 'filler'::"text", 'tape'::"text", 'consumable'::"text", 'fastener'::"text", 'accessory'::"text", 'carrier'::"text", 'belt'::"text", 'belt_connector'::"text", 'hook'::"text", 'brush'::"text", 'fabric'::"text", 'adapter'::"text", 'bearing'::"text", 'connector'::"text", 'guide'::"text", 'rail_connector'::"text", 'spring'::"text", 'stopper'::"text", 'mounting_clip'::"text", 'end_plug'::"text"]))),
    CONSTRAINT "bomtemplateslots_selection_mode_check" CHECK (("selection_mode" = ANY (ARRAY['user_select'::"text", 'fixed'::"text", 'none_allowed'::"text"])))
);


ALTER TABLE "public"."BOMTemplateSlots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."BOMTemplates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "product_type_id" "uuid" NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_active" boolean DEFAULT true,
    "hardware_color" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "description" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "deleted" boolean DEFAULT false NOT NULL,
    "panel_count_min" integer DEFAULT 1 NOT NULL,
    "panel_count_max" integer DEFAULT 1 NOT NULL
);


ALTER TABLE "public"."BOMTemplates" OWNER TO "postgres";


COMMENT ON COLUMN "public"."BOMTemplates"."hardware_color" IS 'Hardware color (White, Black, Silver, Bronze, etc.) to differentiate templates for the same product type. NULL means template applies to all colors.';



COMMENT ON COLUMN "public"."BOMTemplates"."sort_order" IS 'Display order for templates (lower numbers appear first). Used for drag-and-drop reordering.';



COMMENT ON COLUMN "public"."BOMTemplates"."description" IS 'Optional description for the BOM template.';



COMMENT ON COLUMN "public"."BOMTemplates"."metadata" IS 'Additional metadata for the BOM template (rules, priority, etc).';



COMMENT ON COLUMN "public"."BOMTemplates"."panel_count_min" IS 'Minimum number of panels (paños) this template supports (1-3).';



COMMENT ON COLUMN "public"."BOMTemplates"."panel_count_max" IS 'Maximum number of panels (paños) this template supports (1-3).';



CREATE TABLE IF NOT EXISTS "public"."CatalogCategories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "parent_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "catalogcategories_parent_not_self" CHECK ((("parent_id" IS NULL) OR ("parent_id" <> "id")))
);


ALTER TABLE "public"."CatalogCategories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."CatalogItemComponents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "parent_item_id" "uuid" NOT NULL,
    "child_item_id" "uuid" NOT NULL,
    "child_role" "text" NOT NULL,
    "qty" numeric(12,4) DEFAULT 1 NOT NULL,
    "uom" "text" DEFAULT 'ea'::"text" NOT NULL,
    "required" boolean DEFAULT true NOT NULL,
    "notes" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "catalogitemcomponents_child_role_check" CHECK (("child_role" = ANY (ARRAY['adapter'::"text", 'end_cap'::"text", 'fastener'::"text", 'idler'::"text", 'chain_stop'::"text", 'chain_tensioner'::"text", 'filler'::"text", 'chain'::"text", 'belt'::"text", 'belt_connector'::"text", 'hem_weight'::"text", 'brush'::"text", 'accessory'::"text", 'carrier'::"text", 'consumable'::"text", 'hook'::"text", 'mounting_clip'::"text", 'bearing'::"text", 'connector'::"text", 'end_plug'::"text", 'guide'::"text", 'rail_connector'::"text", 'spring'::"text", 'stopper'::"text"])))
);


ALTER TABLE "public"."CatalogItemComponents" OWNER TO "postgres";


COMMENT ON TABLE "public"."CatalogItemComponents" IS 'SKU → HIJOS relationship. Defines which child components (adapter, end_cap, screw, etc) are included with a parent SKU (motor, bracket, etc). Used by generate_bom_from_slots() to expand children components.';



COMMENT ON COLUMN "public"."CatalogItemComponents"."parent_item_id" IS 'FK to CatalogItems. The parent SKU (motor, bracket, tube, etc).';



COMMENT ON COLUMN "public"."CatalogItemComponents"."child_item_id" IS 'FK to CatalogItems. The child component (adapter, end_cap, screw, etc).';



COMMENT ON COLUMN "public"."CatalogItemComponents"."child_role" IS 'Role of child component. Must be a valid child role (adapter, end_cap, screw, etc).';



COMMENT ON CONSTRAINT "catalogitemcomponents_child_role_check" ON "public"."CatalogItemComponents" IS 'Validates that child_role is one of the canonical child roles. Updated 2026-01-20 to include all required child roles: adapter, end_cap, fastener, idler, chain_stop, chain_tensioner, filler, chain, belt, belt_connector, hem_weight, brush, accessory, carrier, consumable, hook, mounting_clip, bearing, connector, end_plug, guide, rail_connector, spring, stopper';



CREATE TABLE IF NOT EXISTS "public"."CatalogItemConversions" (
    "catalog_item_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "cost_exw_input" numeric,
    "unit_of_measure_input" "text",
    "roll_width_input" numeric,
    "cost_exw_per_m" numeric,
    "cost_exw_per_m2" numeric,
    "computed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "cost_exw_per_ea" numeric
);


ALTER TABLE "public"."CatalogItemConversions" OWNER TO "postgres";


COMMENT ON TABLE "public"."CatalogItemConversions" IS 'Stored conversions for roll items (fabrics). Keeps CatalogItems clean for mass imports.';



CREATE TABLE IF NOT EXISTS "public"."CatalogItemProductTypes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "catalog_item_id" "uuid" NOT NULL,
    "product_type_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "catalog_item_sku" "text",
    "catalog_item_name" "text"
);


ALTER TABLE "public"."CatalogItemProductTypes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."CatalogItemRoles" (
    "role_code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "description" "text",
    "default_category_id" "uuid",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "role_name" "text" DEFAULT ''::"text" NOT NULL,
    "role_description" "text",
    "is_active" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."CatalogItemRoles" OWNER TO "postgres";


COMMENT ON TABLE "public"."CatalogItemRoles" IS 'Tabla canónica de roles de componentes. Fuente única de verdad para item_role y part_role en todo el sistema.';



COMMENT ON COLUMN "public"."CatalogItemRoles"."role_code" IS 'Código único del role (snake_case). Debe coincidir exactamente con valores usados en CatalogItems.item_role, BOMTemplateSlots.item_role, y BomInstanceLines.part_role.';



COMMENT ON COLUMN "public"."CatalogItemRoles"."role_name" IS 'Nombre legible del role (ej: "Motor", "Headbox", "Bottom Bar")';



COMMENT ON COLUMN "public"."CatalogItemRoles"."role_description" IS 'Descripción opcional del role';



CREATE TABLE IF NOT EXISTS "public"."CatalogItemRollSpecs" (
    "catalog_item_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "can_rotate" boolean DEFAULT false NOT NULL,
    "is_weldable" boolean DEFAULT false NOT NULL,
    "raw_material" "text",
    "openness_factor_pct" numeric(6,3),
    "weight_g_m2" numeric(10,3),
    "weight_kg_m2" numeric(10,3),
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "roll_specs_openness_range" CHECK ((("openness_factor_pct" IS NULL) OR (("openness_factor_pct" >= (0)::numeric) AND ("openness_factor_pct" <= (100)::numeric)))),
    CONSTRAINT "roll_specs_weight_nonnegative" CHECK (((("weight_g_m2" IS NULL) OR ("weight_g_m2" >= (0)::numeric)) AND (("weight_kg_m2" IS NULL) OR ("weight_kg_m2" >= (0)::numeric))))
);


ALTER TABLE "public"."CatalogItemRollSpecs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."CatalogItemSupply" (
    "catalog_item_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "supply_type" "text" NOT NULL,
    "supply_origin" "text" NOT NULL,
    "lead_time_min_days" integer NOT NULL,
    "lead_time_max_days" integer NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "CatalogItemSupply_supply_origin_check" CHECK (("supply_origin" = ANY (ARRAY['local'::"text", 'import'::"text"]))),
    CONSTRAINT "CatalogItemSupply_supply_type_check" CHECK (("supply_type" = ANY (ARRAY['stock'::"text", 'order'::"text"]))),
    CONSTRAINT "catalog_item_supply_lead_time_ok" CHECK (("lead_time_min_days" <= "lead_time_max_days"))
);


ALTER TABLE "public"."CatalogItemSupply" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."CatalogItems" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "sku" "text" NOT NULL,
    "unit_of_measure" "text" NOT NULL,
    "description" "text",
    "category_id" "uuid",
    "image_url" "text",
    "measure_basis" "text" NOT NULL,
    "collection_name" "text",
    "variant_name" "text",
    "roll_width" numeric(12,4),
    "color" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "cost_exw" numeric(12,4),
    "manufacturer" "text",
    "manufacturer_id" "uuid",
    "is_roll" boolean DEFAULT false NOT NULL,
    "roll_collection_id" "uuid",
    "roll_type" "public"."roll_type",
    "item_role" "text",
    "roll_pricing_mode" "text",
    "units_per_purchase_unit" numeric(12,4) DEFAULT 1 NOT NULL,
    "purchase_unit" "text" DEFAULT 'each'::"text" NOT NULL,
    "roll_width_value" numeric,
    "roll_width_uom" "text",
    "roll_width_m" numeric,
    "roll_length_value" numeric,
    "roll_length_uom" "text",
    "roll_length_m" numeric,
    CONSTRAINT "catalogitems_item_role_check" CHECK ((("item_role" IS NULL) OR ("item_role" = ANY (ARRAY['accessory'::"text", 'adapter'::"text", 'bearing'::"text", 'belt'::"text", 'belt_connector'::"text", 'bottom_bar'::"text", 'bottom_bar_profile'::"text", 'bottom_channel'::"text", 'bottom_rail_profile'::"text", 'bracket'::"text", 'brush'::"text", 'cable'::"text", 'carrier'::"text", 'cassette'::"text", 'chain'::"text", 'chain_clip'::"text", 'chain_stop'::"text", 'chain_tensioner'::"text", 'consumable'::"text", 'control'::"text", 'drive'::"text", 'drive_adapter'::"text", 'drive_manual'::"text", 'drive_motorized'::"text", 'end_cap'::"text", 'end_plug'::"text", 'fabric'::"text", 'fascia'::"text", 'fastener'::"text", 'filler'::"text", 'guide'::"text", 'handle'::"text", 'hardware'::"text", 'headbox'::"text", 'hook'::"text", 'idler'::"text", 'motor'::"text", 'mount_profile'::"text", 'mounting_clip'::"text", 'rail_connector'::"text", 'screw_cap'::"text", 'side_channel'::"text", 'side_channel_profile'::"text", 'spring'::"text", 'stopper'::"text", 'sub_bracket'::"text", 'tape'::"text", 'top_rail'::"text", 'top_rail_profile'::"text", 'track'::"text", 'tube'::"text", 'wand'::"text", 'window_film'::"text"])))),
    CONSTRAINT "catalogitems_purchase_unit_chk" CHECK (("purchase_unit" = ANY (ARRAY['each'::"text", 'pack'::"text", 'set'::"text", 'box'::"text", 'case'::"text"]))),
    CONSTRAINT "catalogitems_roll_length_uom_chk" CHECK ((("roll_length_uom" IS NULL) OR ("roll_length_uom" = ANY (ARRAY['m'::"text", 'yd'::"text", 'ft'::"text", 'in'::"text"])))),
    CONSTRAINT "catalogitems_roll_pricing_mode_chk" CHECK ((("roll_pricing_mode" IS NULL) OR ("roll_pricing_mode" = ANY (ARRAY['per_linear_meter'::"text", 'per_square_meter'::"text", 'per_unit'::"text"])))),
    CONSTRAINT "catalogitems_roll_type_requires_is_roll" CHECK ((("roll_type" IS NULL) OR ("is_roll" = true))),
    CONSTRAINT "catalogitems_roll_width_uom_chk" CHECK ((("roll_width_uom" IS NULL) OR ("roll_width_uom" = ANY (ARRAY['m'::"text", 'yd'::"text", 'ft'::"text", 'in'::"text"])))),
    CONSTRAINT "catalogitems_units_per_purchase_unit_chk" CHECK ((("units_per_purchase_unit" IS NULL) OR ("units_per_purchase_unit" > (0)::numeric)))
);


ALTER TABLE "public"."CatalogItems" OWNER TO "postgres";


COMMENT ON COLUMN "public"."CatalogItems"."roll_pricing_mode" IS 'How this roll/fabric is priced in quotes: per_linear_meter | per_square_meter | per_unit.';



COMMENT ON COLUMN "public"."CatalogItems"."units_per_purchase_unit" IS 'If unit_of_measure is pack/set/box, how many EA are inside that purchase unit. Used to normalize to $/ea.';



CREATE TABLE IF NOT EXISTS "public"."CatalogItemsMSRP" (
    "catalog_item_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "category_id" "uuid",
    "cost_exw" numeric(12,4) NOT NULL,
    "import_tax_cost" numeric(12,4) NOT NULL,
    "shipping_cost" numeric(12,4) NOT NULL,
    "total_cost" numeric(12,4) NOT NULL,
    "sku" "text",
    "name" "text",
    "collection_name" "text",
    "variant_name" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "unit_of_measure" "text",
    "shipping_pct" numeric(7,4),
    "import_tax_pct" numeric(7,4),
    "minimum_margin_pct" numeric(7,4),
    "msrp_pct" numeric(7,4),
    "dealer_price" numeric DEFAULT 0 NOT NULL,
    "msrp" numeric DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."CatalogItemsMSRP" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."CatalogRoleCategoryMap" (
    "organization_id" "uuid" NOT NULL,
    "role_code" "text" NOT NULL,
    "target_category_id" "uuid" NOT NULL,
    "notes" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."CatalogRoleCategoryMap" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."CategoryMargins" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "category_id" "uuid" NOT NULL,
    "minimum_margin_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "msrp_pct" numeric(7,4) DEFAULT 0.65 NOT NULL
);


ALTER TABLE "public"."CategoryMargins" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ConfiguredProducts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "quote_id" "uuid",
    "bom_template_id" "uuid" NOT NULL,
    "product_type_id" "uuid" NOT NULL,
    "width_mm" numeric(12,4),
    "height_mm" numeric(12,4),
    "quantity" numeric(12,4) DEFAULT 1 NOT NULL,
    "hardware_color" "text",
    "bom_total" numeric(12,4) DEFAULT 0,
    "labor_pct" numeric(5,2) DEFAULT 0,
    "accessories_total" numeric(12,4) DEFAULT 0,
    "total_msrp" numeric(12,4) DEFAULT 0,
    "config_snapshot" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "roll_catalog_item_id" "uuid",
    "roll_sku" "text",
    "roll_collection_name" "text",
    "roll_variant_name" "text",
    "roll_width" numeric(12,4),
    "roll_msrp_total" numeric(12,4) DEFAULT 0,
    "roll_plus_bom_total" numeric(12,4) DEFAULT 0,
    "roll_total_cost" numeric(12,4) DEFAULT 0,
    "bom_total_cost" numeric(12,4) DEFAULT 0,
    "labor_amount" numeric(12,4) DEFAULT 0,
    "bom_preview_snapshot" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."ConfiguredProducts" OWNER TO "postgres";


COMMENT ON TABLE "public"."ConfiguredProducts" IS 'Snapshot completo de producto configurado (Roll + BOM) antes de crear QuoteLine. Contiene precios calculados y toda la configuración.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."bom_total" IS 'Total MSRP sale_out de todos los componentes BOM (padres + hijos) desde BOMInstanceLines.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."config_snapshot" IS 'JSONB con snapshot completo de la configuración desde ProductConfigurator. Incluye todas las selecciones y opciones.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."roll_msrp_total" IS 'MSRP Sale out × Ancho del rollo total × Altura de la medida de measurements × quantity.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."roll_plus_bom_total" IS 'Suma de Roll MSRP + BOM Total (antes de aplicar labor y accessories).';



COMMENT ON COLUMN "public"."ConfiguredProducts"."roll_total_cost" IS 'Costo real total del roll (usando CatalogItemsMSRP.total_cost). 
Calculado como: total_cost del roll × roll_width × height_m × quantity';



COMMENT ON COLUMN "public"."ConfiguredProducts"."bom_total_cost" IS 'Costo real total del BOM (suma de CatalogItemsMSRP.total_cost de cada BOMInstanceLine).
Calculado como: SUM(total_cost × qty) para cada línea del BOM';



COMMENT ON COLUMN "public"."ConfiguredProducts"."bom_preview_snapshot" IS 'JSONB snapshot of BOM breakdown for UI preview. Contains version, totals, and items array with pricing details. Generated during create_configured_product_and_bom_preview.';



CREATE TABLE IF NOT EXISTS "public"."CostSettings" (
    "organization_id" "uuid" NOT NULL,
    "labor_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "shipping_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "global_import_tax_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "minimum_margin_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "default_msrp_pct" numeric(7,4) DEFAULT 0.65 NOT NULL,
    "import_tax_pct" numeric(7,4) GENERATED ALWAYS AS ("global_import_tax_pct") STORED
);


ALTER TABLE "public"."CostSettings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."DealerTiers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "discount_pct" numeric(5,2) NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."DealerTiers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."DealerUsers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "status" "public"."portal_user_status" DEFAULT 'draft'::"public"."portal_user_status" NOT NULL,
    "invited_by_user_id" "uuid",
    "invited_at" timestamp with time zone,
    "accepted_at" timestamp with time zone,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "organization_id" "uuid",
    "portal_user_email" "text",
    "portal_user_name" "text",
    "dealer_id" "uuid",
    "role" "text" DEFAULT 'member'::"text" NOT NULL,
    "must_change_password" boolean DEFAULT true NOT NULL,
    "temp_password_set_at" timestamp with time zone,
    CONSTRAINT "company_portal_role_check" CHECK (("role" = ANY (ARRAY['member'::"text", 'member_manager'::"text"]))),
    CONSTRAINT "companyportalusers_portal_user_role_check" CHECK (("role" = ANY (ARRAY['member_manager'::"text", 'member'::"text"]))),
    CONSTRAINT "companyportalusers_role_check" CHECK (("role" = ANY (ARRAY['member_manager'::"text", 'member'::"text"])))
);


ALTER TABLE "public"."DealerUsers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."Dealers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "dealer_name" "text" NOT NULL,
    "dealer_email" "text",
    "dealer_phone" "text",
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "dealer_no" "text",
    "identification_number" "text",
    "website" "text",
    "alt_phone" "text",
    "primary_contact_id" "uuid",
    "street_address_line_1" "text",
    "street_address_line_2" "text",
    "city" "text",
    "state" "text",
    "zip_code" "text",
    "country" "text",
    "billing_same_as_location" boolean DEFAULT true,
    "billing_street_address_line_1" "text",
    "billing_street_address_line_2" "text",
    "billing_city" "text",
    "billing_state" "text",
    "billing_zip_code" "text",
    "billing_country" "text",
    "notes" "text",
    "dealer_tier_id" "uuid",
    CONSTRAINT "dealers_org_required" CHECK (("organization_id" IS NOT NULL))
);


ALTER TABLE "public"."Dealers" OWNER TO "postgres";


COMMENT ON COLUMN "public"."Dealers"."identification_number" IS 'Tax ID or business registration number';



COMMENT ON COLUMN "public"."Dealers"."website" IS 'Company website URL';



COMMENT ON COLUMN "public"."Dealers"."alt_phone" IS 'Alternative phone number';



COMMENT ON COLUMN "public"."Dealers"."primary_contact_id" IS 'Primary contact person from DirectoryContacts';



COMMENT ON COLUMN "public"."Dealers"."street_address_line_1" IS 'Primary street address';



COMMENT ON COLUMN "public"."Dealers"."street_address_line_2" IS 'Secondary street address (suite, unit, etc.)';



COMMENT ON COLUMN "public"."Dealers"."city" IS 'City';



COMMENT ON COLUMN "public"."Dealers"."state" IS 'State or province';



COMMENT ON COLUMN "public"."Dealers"."zip_code" IS 'ZIP or postal code';



COMMENT ON COLUMN "public"."Dealers"."country" IS 'Country';



COMMENT ON COLUMN "public"."Dealers"."billing_same_as_location" IS 'If true, billing address is same as location address';



COMMENT ON COLUMN "public"."Dealers"."billing_street_address_line_1" IS 'Billing street address line 1';



COMMENT ON COLUMN "public"."Dealers"."billing_street_address_line_2" IS 'Billing street address line 2';



COMMENT ON COLUMN "public"."Dealers"."billing_city" IS 'Billing city';



COMMENT ON COLUMN "public"."Dealers"."billing_state" IS 'Billing state or province';



COMMENT ON COLUMN "public"."Dealers"."billing_zip_code" IS 'Billing ZIP or postal code';



COMMENT ON COLUMN "public"."Dealers"."billing_country" IS 'Billing country';



COMMENT ON COLUMN "public"."Dealers"."notes" IS 'Additional notes about the dealer/company';



CREATE TABLE IF NOT EXISTS "public"."DirectoryContacts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "customer_id" "uuid",
    "phone" "text",
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "contact_name" "text",
    "contact_email" "text",
    "contact_phone" "text",
    "contact_title" "text",
    "notes" "text",
    "dealer_id" "uuid",
    "contact_id_number" "text",
    "contact_type" "public"."contact_type",
    "contact_primary_phone" "text",
    "contact_cell_phone" "text",
    "contact_alt_phone" "text",
    "contact_street_address" "text",
    "contact_street_address_2" "text",
    "contact_city" "text",
    "contact_state" "text",
    "contact_zip_code" "text",
    "contact_country" "text",
    "created_by_user_id" "uuid",
    "created_by_portal_user_id" "uuid"
);


ALTER TABLE "public"."DirectoryContacts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."DirectoryCustomers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "status" "text",
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "customer_name" "text",
    "customer_email" "text",
    "customer_phone" "text",
    "customer_status" "text" DEFAULT 'active'::"text" NOT NULL,
    "notes" "text",
    "dealer_id" "uuid",
    "identification_number" "text",
    "customer_type_name" "text",
    "website" "text",
    "alt_phone" "text",
    "primary_contact_id" "uuid",
    "street_address_line_1" "text",
    "street_address_line_2" "text",
    "city" "text",
    "state" "text",
    "zip_code" "text",
    "country" "text",
    "billing_street_address_line_1" "text",
    "billing_street_address_line_2" "text",
    "billing_city" "text",
    "billing_state" "text",
    "billing_zip_code" "text",
    "billing_country" "text",
    "created_by_user_id" "uuid",
    "created_by_portal_user_id" "uuid"
);


ALTER TABLE "public"."DirectoryCustomers" OWNER TO "postgres";


COMMENT ON COLUMN "public"."DirectoryCustomers"."customer_phone" IS 'Customer phone number (main contact phone)';



COMMENT ON COLUMN "public"."DirectoryCustomers"."identification_number" IS 'Customer identification number (tax ID, etc.)';



COMMENT ON COLUMN "public"."DirectoryCustomers"."customer_type_name" IS 'Customer type: contractor, architecture_studio, design_studio, end_user';



COMMENT ON COLUMN "public"."DirectoryCustomers"."alt_phone" IS 'Alternative phone number';



COMMENT ON COLUMN "public"."DirectoryCustomers"."primary_contact_id" IS 'Primary contact person (FK to DirectoryContacts)';



CREATE TABLE IF NOT EXISTS "public"."ImportTaxRules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "category_id" "uuid" NOT NULL,
    "import_tax_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."ImportTaxRules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."Manufacturers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "code" "text",
    "website" "text",
    "notes" "text",
    "deleted" boolean DEFAULT false NOT NULL,
    "archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."Manufacturers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ManufacturingOrders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "sales_order_id" "uuid" NOT NULL,
    "manufacturing_order_no" "text",
    "status" "public"."manufacturing_order_status" DEFAULT 'draft'::"public"."manufacturing_order_status" NOT NULL,
    "priority" "text" DEFAULT 'normal'::"text" NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "dealer_id" "uuid"
);


ALTER TABLE "public"."ManufacturingOrders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."OrderList" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "sales_order_id" "uuid" NOT NULL,
    "tracking_status" "public"."sales_order_tracking_status" DEFAULT 'pending_confirmation'::"public"."sales_order_tracking_status" NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "dealer_id" "uuid"
);


ALTER TABLE "public"."OrderList" OWNER TO "postgres";


COMMENT ON TABLE "public"."OrderList" IS 'OrderList table - mirror of SalesOrders for tracking. tracking_status always mirrors SalesOrders.tracking_status.';



COMMENT ON COLUMN "public"."OrderList"."sales_order_id" IS 'FK to SalesOrders (1:1 unique). OrderList always created with SalesOrder.';



COMMENT ON COLUMN "public"."OrderList"."tracking_status" IS 'Tracking status - always mirrors SalesOrders.tracking_status (via trigger).';



CREATE TABLE IF NOT EXISTS "public"."OrganizationUserPermissions" (
    "organization_user_id" "uuid" NOT NULL,
    "permission_code" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."OrganizationUserPermissions" OWNER TO "postgres";


COMMENT ON TABLE "public"."OrganizationUserPermissions" IS 'Junction table linking OrganizationUsers to Permissions';



CREATE TABLE IF NOT EXISTS "public"."Organizations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "dealer_no_prefix" "text" DEFAULT 'AP'::"text" NOT NULL,
    "next_dealer_no" integer DEFAULT 1001 NOT NULL,
    CONSTRAINT "organizations_dealer_no_prefix_chk" CHECK ((("length"("dealer_no_prefix") >= 1) AND ("length"("dealer_no_prefix") <= 10)))
);


ALTER TABLE "public"."Organizations" OWNER TO "postgres";


COMMENT ON TABLE "public"."Organizations" IS 'Organizations table - base entity for multi-tenancy';



CREATE TABLE IF NOT EXISTS "public"."Permissions" (
    "code" "text" NOT NULL,
    "module" "text" NOT NULL,
    "description" "text"
);


ALTER TABLE "public"."Permissions" OWNER TO "postgres";


COMMENT ON TABLE "public"."Permissions" IS 'RBAC Permissions - available permissions with module grouping';



CREATE TABLE IF NOT EXISTS "public"."ProductTypeRoleRules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "product_type_id" "uuid" NOT NULL,
    "role_code" "text" NOT NULL,
    "is_required" boolean DEFAULT false NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "archived" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."ProductTypeRoleRules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ProductTypes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."ProductTypes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ProposalLines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "dealer_id" "uuid" NOT NULL,
    "proposal_id" "uuid" NOT NULL,
    "line_type" "public"."proposal_line_type" NOT NULL,
    "quote_line_id" "uuid",
    "override_mode" "public"."proposal_override_mode" DEFAULT 'inherit'::"public"."proposal_override_mode" NOT NULL,
    "discount_pct" numeric(6,3),
    "markup_pct" numeric(6,3),
    "fixed_unit_price" numeric(12,4),
    "fixed_line_total" numeric(12,4),
    "custom_category" "public"."proposal_custom_category",
    "description" "text",
    "qty" numeric(12,4) DEFAULT 1,
    "uom" "text",
    "unit_price" numeric(12,4),
    "line_total" numeric(12,4),
    "sort_order" integer DEFAULT 0 NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "proposal_lines_custom_requirements_chk" CHECK ((("line_type" <> 'custom'::"public"."proposal_line_type") OR (("description" IS NOT NULL) AND ("length"(TRIM(BOTH FROM "description")) > 0)))),
    CONSTRAINT "proposal_lines_override_mode_chk" CHECK (((("override_mode" = 'inherit'::"public"."proposal_override_mode") AND ("discount_pct" IS NULL) AND ("markup_pct" IS NULL) AND ("fixed_unit_price" IS NULL) AND ("fixed_line_total" IS NULL)) OR (("override_mode" = 'discount_pct'::"public"."proposal_override_mode") AND ("discount_pct" IS NOT NULL) AND (("discount_pct" >= (0)::numeric) AND ("discount_pct" <= (100)::numeric)) AND ("markup_pct" IS NULL) AND ("fixed_unit_price" IS NULL) AND ("fixed_line_total" IS NULL)) OR (("override_mode" = 'markup_pct'::"public"."proposal_override_mode") AND ("markup_pct" IS NOT NULL) AND (("markup_pct" >= (0)::numeric) AND ("markup_pct" <= (100)::numeric)) AND ("discount_pct" IS NULL) AND ("fixed_unit_price" IS NULL) AND ("fixed_line_total" IS NULL)) OR (("override_mode" = 'fixed_unit_price'::"public"."proposal_override_mode") AND ("fixed_unit_price" IS NOT NULL) AND ("discount_pct" IS NULL) AND ("markup_pct" IS NULL) AND ("fixed_line_total" IS NULL)) OR (("override_mode" = 'fixed_line_total'::"public"."proposal_override_mode") AND ("fixed_line_total" IS NOT NULL) AND ("discount_pct" IS NULL) AND ("markup_pct" IS NULL) AND ("fixed_unit_price" IS NULL)))),
    CONSTRAINT "proposal_lines_qty_positive_chk" CHECK ((("qty" IS NULL) OR ("qty" >= (0)::numeric))),
    CONSTRAINT "proposal_lines_type_chk" CHECK (((("line_type" = 'from_quote'::"public"."proposal_line_type") AND ("quote_line_id" IS NOT NULL)) OR (("line_type" = 'custom'::"public"."proposal_line_type") AND ("quote_line_id" IS NULL))))
);


ALTER TABLE "public"."ProposalLines" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."Proposals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "dealer_id" "uuid" NOT NULL,
    "quote_id" "uuid" NOT NULL,
    "customer_id" "uuid",
    "contact_id" "uuid",
    "status" "public"."proposal_status" DEFAULT 'draft'::"public"."proposal_status" NOT NULL,
    "proposal_no" "text",
    "version_no" integer DEFAULT 1 NOT NULL,
    "currency" "text",
    "valid_until" "date",
    "notes" "text",
    "global_discount_pct" numeric(6,3),
    "global_fee_amount" numeric(12,4) DEFAULT 0,
    "subtotal_amount" numeric(12,4),
    "total_amount" numeric(12,4),
    "created_by_user_id" "uuid",
    "created_by_portal_user_id" "uuid",
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "proposals_created_by_exactly_one_chk" CHECK (((("created_by_user_id" IS NOT NULL) AND ("created_by_portal_user_id" IS NULL)) OR (("created_by_user_id" IS NULL) AND ("created_by_portal_user_id" IS NOT NULL)))),
    CONSTRAINT "proposals_global_discount_range_chk" CHECK ((("global_discount_pct" IS NULL) OR (("global_discount_pct" >= (0)::numeric) AND ("global_discount_pct" <= (100)::numeric)))),
    CONSTRAINT "proposals_version_no_positive_chk" CHECK (("version_no" >= 1))
);


ALTER TABLE "public"."Proposals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."QuoteLineBOMSelections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "quote_line_id" "uuid" NOT NULL,
    "component_role" "text" NOT NULL,
    "catalog_item_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."QuoteLineBOMSelections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."QuoteLineComponents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "quote_line_id" "uuid" NOT NULL,
    "component_role" "text" NOT NULL,
    "kind" "text" DEFAULT 'option'::"text" NOT NULL,
    "source" "text" DEFAULT 'configured_component'::"text" NOT NULL,
    "catalog_item_id" "uuid",
    "qty" numeric(12,4) DEFAULT 1 NOT NULL,
    "unit_cost_exw" numeric(12,4),
    "payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "quotelinecomponents_component_role_check" CHECK (("component_role" = ANY (ARRAY['tube'::"text", 'track'::"text", 'bottom_bar'::"text", 'bottom_channel'::"text", 'hem_weight'::"text", 'side_channel'::"text", 'side_channels'::"text", 'top_rail'::"text", 'headbox'::"text", 'bracket'::"text", 'idler'::"text", 'drive'::"text", 'motor'::"text", 'adapter'::"text", 'chain'::"text", 'chain_stop'::"text", 'chain_tensioner'::"text", 'wand'::"text", 'end_cap'::"text", 'filler'::"text", 'tape'::"text", 'consumable'::"text", 'fastener'::"text", 'accessory'::"text", 'carrier'::"text", 'belt'::"text", 'belt_connector'::"text", 'bearing'::"text", 'hook'::"text", 'brush'::"text", 'hardware_color'::"text", 'drive_type'::"text", 'system_size'::"text", 'cassette'::"text", 'bottom_rail_type'::"text", 'tube_type'::"text", 'fabric'::"text"]))),
    CONSTRAINT "quotelinecomponents_kind_check" CHECK (("kind" = ANY (ARRAY['option'::"text", 'selection'::"text", 'override'::"text", 'accessory'::"text"])))
);


ALTER TABLE "public"."QuoteLineComponents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."QuoteLineCosts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "quote_id" "uuid" NOT NULL,
    "quote_line_id" "uuid" NOT NULL,
    "quantity" numeric DEFAULT 1 NOT NULL,
    "cost_exw" numeric DEFAULT 0 NOT NULL,
    "material_cost" numeric DEFAULT 0 NOT NULL,
    "labor_pct" numeric DEFAULT 0 NOT NULL,
    "labor_cost" numeric DEFAULT 0 NOT NULL,
    "shipping_pct" numeric DEFAULT 0 NOT NULL,
    "shipping_cost" numeric DEFAULT 0 NOT NULL,
    "import_tax_pct" numeric DEFAULT 0 NOT NULL,
    "import_tax_cost" numeric DEFAULT 0 NOT NULL,
    "total_cost" numeric DEFAULT 0 NOT NULL,
    "pricing_version" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."QuoteLineCosts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."QuoteLines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "dealer_id" "uuid",
    "quote_id" "uuid" NOT NULL,
    "catalog_item_id" "uuid",
    "category_id" "uuid",
    "sku" "text",
    "name" "text",
    "manufacturer_id" "uuid",
    "manufacturer" "text",
    "quantity" numeric(12,4) DEFAULT 1 NOT NULL,
    "width_m" numeric(12,4),
    "height_m" numeric(12,4),
    "is_roll" boolean,
    "roll_type" "text",
    "collection_name" "text",
    "variant_name" "text",
    "roll_width_m" numeric(12,4),
    "total_cost" numeric(12,4),
    "msrp" numeric(12,4),
    "pricing_version" integer DEFAULT 1 NOT NULL,
    "pricing_locked" boolean DEFAULT true NOT NULL,
    "last_priced_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "product_type" "text",
    "area" "text",
    "position" "text",
    "hardware_color" "text",
    "cassette" boolean DEFAULT false,
    "side_channel" boolean DEFAULT false,
    "drive_type" "text",
    "bom_template_id" "uuid",
    "roll_cost_snapshot" numeric,
    "bom_cost_snapshot" numeric,
    "roll_msrp_snapshot" numeric,
    "bom_msrp_snapshot" numeric,
    "configured_product_id" "uuid",
    "product_type_id" "uuid",
    "fabric_drop" "text",
    "installation_type" "text",
    "installation_location" "text",
    "unit_msrp" numeric(12,4),
    "sort_order" integer
);


ALTER TABLE "public"."QuoteLines" OWNER TO "postgres";


COMMENT ON COLUMN "public"."QuoteLines"."hardware_color" IS 'Hardware color selected by user: white, black, silver, bronze, grey, beige. Used for BOM auto-select SKU resolution.';



COMMENT ON COLUMN "public"."QuoteLines"."cassette" IS 'Whether cassette is enabled for this quote line. Used for BOM block_condition evaluation.';



COMMENT ON COLUMN "public"."QuoteLines"."side_channel" IS 'Whether side channel is enabled for this quote line. Used for BOM block_condition evaluation.';



COMMENT ON COLUMN "public"."QuoteLines"."drive_type" IS 'Drive type: manual or motor. Used for BOM block_condition evaluation and auto-select SKU resolution.';



COMMENT ON COLUMN "public"."QuoteLines"."bom_template_id" IS 'Foreign key to BOMTemplates. Identifies which BOM template should be used for BOM generation.';



COMMENT ON COLUMN "public"."QuoteLines"."roll_cost_snapshot" IS 'Snapshot del costo total del roll (material + import/shipping/labor si aplica) al momento de crear la QuoteLine.';



COMMENT ON COLUMN "public"."QuoteLines"."bom_cost_snapshot" IS 'Snapshot del costo total del BOM al momento de crear la QuoteLine.';



COMMENT ON COLUMN "public"."QuoteLines"."roll_msrp_snapshot" IS 'Snapshot del MSRP del roll al momento de crear la QuoteLine.';



COMMENT ON COLUMN "public"."QuoteLines"."bom_msrp_snapshot" IS 'Snapshot del MSRP del BOM al momento de crear la QuoteLine.';



COMMENT ON COLUMN "public"."QuoteLines"."unit_msrp" IS 'Precio unitario MSRP (sub-total por unidad). Line total = msrp = unit_msrp * quantity. Set by commit_configured_product_to_quote_line.';



CREATE TABLE IF NOT EXISTS "public"."Quotes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "quote_no" "text" NOT NULL,
    "status" "public"."quote_status" DEFAULT 'draft'::"public"."quote_status" NOT NULL,
    "tracking_status" "public"."sales_order_tracking_status",
    "customer_id" "uuid",
    "contact_id" "uuid",
    "created_by_user_id" "uuid",
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "dealer_id" "uuid",
    "created_by_portal_user_id" "uuid",
    "currency" "text" DEFAULT 'USD'::"text" NOT NULL,
    CONSTRAINT "quotes_tracking_status_only_when_approved" CHECK (((("status" = 'approved'::"public"."quote_status") AND ("tracking_status" IS NOT NULL)) OR (("status" <> 'approved'::"public"."quote_status") AND ("tracking_status" IS NULL))))
);


ALTER TABLE "public"."Quotes" OWNER TO "postgres";


COMMENT ON TABLE "public"."Quotes" IS 'Quotes table - quotes are converted to SalesOrders when approved';



COMMENT ON COLUMN "public"."Quotes"."status" IS 'Status: draft, sent, approved, canceled';



COMMENT ON COLUMN "public"."Quotes"."tracking_status" IS 'Tracking status. Only set when status=approved. NULL otherwise.';



COMMENT ON COLUMN "public"."Quotes"."customer_id" IS 'FK to customer (nullable)';



COMMENT ON COLUMN "public"."Quotes"."contact_id" IS 'FK to contact (nullable)';



CREATE TABLE IF NOT EXISTS "public"."SaleOrderLines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "sales_order_id" "uuid" NOT NULL,
    "quote_line_id" "uuid",
    "catalog_item_id" "uuid",
    "quantity" numeric(12,4) DEFAULT 1 NOT NULL,
    "width_m" numeric(12,4),
    "height_m" numeric(12,4),
    "sqm" numeric(12,4),
    "unit_price" numeric(12,4),
    "line_total" numeric(12,4),
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."SaleOrderLines" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."SalesOrders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "quote_id" "uuid" NOT NULL,
    "sales_order_no" "text" NOT NULL,
    "tracking_status" "public"."sales_order_tracking_status" DEFAULT 'pending_confirmation'::"public"."sales_order_tracking_status" NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "public"."sales_order_status" DEFAULT 'draft'::"public"."sales_order_status" NOT NULL,
    "dealer_id" "uuid"
);


ALTER TABLE "public"."SalesOrders" OWNER TO "postgres";


COMMENT ON TABLE "public"."SalesOrders" IS 'SalesOrders table - always created from approved Quotes via trigger';



COMMENT ON COLUMN "public"."SalesOrders"."quote_id" IS 'FK to Quotes (1:1 unique). SalesOrder always created from Quote.';



COMMENT ON COLUMN "public"."SalesOrders"."tracking_status" IS 'Tracking status - source of truth. Mirrored to OrderList.';



CREATE TABLE IF NOT EXISTS "public"."stg_catalog_items_import_raw" (
    "row_id" bigint NOT NULL,
    "id" "text",
    "organization_id" "text",
    "name" "text",
    "sku" "text",
    "unit_of_measure" "text",
    "description" "text",
    "category_id" "text",
    "image_url" "text",
    "measure_basis" "text",
    "is_fabric" "text",
    "collection_name" "text",
    "variant_name" "text",
    "roll_width" "text",
    "fabric_pricing_mode" "text",
    "color" "text",
    "is_active" "text",
    "created_at" "text",
    "updated_at" "text",
    "cost_exw" "text",
    "manufacturer" "text",
    "manufacturer_id" "text",
    "is_roll" "text",
    "roll_collection_id" "text",
    "roll_type" "text",
    "item_role" "text",
    "product_type_id" "text",
    "imported_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "import_batch_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."stg_catalog_items_import_raw" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."stg_catalog_items_import_raw_row_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."stg_catalog_items_import_raw_row_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."stg_catalog_items_import_raw_row_id_seq" OWNED BY "public"."stg_catalog_items_import_raw"."row_id";



ALTER TABLE ONLY "public"."stg_catalog_items_import_raw" ALTER COLUMN "row_id" SET DEFAULT "nextval"('"public"."stg_catalog_items_import_raw_row_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."BOMComponents"
    ADD CONSTRAINT "BOMComponents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."BOMTemplateSlots"
    ADD CONSTRAINT "BOMTemplateSlots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."BOMTemplates"
    ADD CONSTRAINT "BOMTemplates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."BOMTemplates"
    ADD CONSTRAINT "BOMTemplates_unique_code" UNIQUE ("organization_id", "code");



ALTER TABLE ONLY "public"."CatalogCategories"
    ADD CONSTRAINT "CatalogCategories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CatalogItemConversions"
    ADD CONSTRAINT "CatalogItemConversions_pkey" PRIMARY KEY ("catalog_item_id");



ALTER TABLE ONLY "public"."CatalogItemProductTypes"
    ADD CONSTRAINT "CatalogItemProductTypes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CatalogItemRoles"
    ADD CONSTRAINT "CatalogItemRoles_pkey" PRIMARY KEY ("role_code");



ALTER TABLE ONLY "public"."CatalogItemRollSpecs"
    ADD CONSTRAINT "CatalogItemRollSpecs_pkey" PRIMARY KEY ("catalog_item_id");



ALTER TABLE ONLY "public"."CatalogItemSupply"
    ADD CONSTRAINT "CatalogItemSupply_pkey" PRIMARY KEY ("catalog_item_id");



ALTER TABLE ONLY "public"."CatalogItemsMSRP"
    ADD CONSTRAINT "CatalogItemsMSRP_pkey" PRIMARY KEY ("catalog_item_id");



ALTER TABLE ONLY "public"."CatalogItems"
    ADD CONSTRAINT "CatalogItems_organization_id_sku_key" UNIQUE ("organization_id", "sku");



ALTER TABLE ONLY "public"."CatalogItems"
    ADD CONSTRAINT "CatalogItems_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CatalogRoleCategoryMap"
    ADD CONSTRAINT "CatalogRoleCategoryMap_pkey" PRIMARY KEY ("organization_id", "role_code");



ALTER TABLE ONLY "public"."CategoryMargins"
    ADD CONSTRAINT "CategoryMargins_organization_id_category_id_key" UNIQUE ("organization_id", "category_id");



ALTER TABLE ONLY "public"."CategoryMargins"
    ADD CONSTRAINT "CategoryMargins_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Dealers"
    ADD CONSTRAINT "Companies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CostSettings"
    ADD CONSTRAINT "CostSettings_pkey" PRIMARY KEY ("organization_id");



ALTER TABLE ONLY "public"."DealerUsers"
    ADD CONSTRAINT "CustomerPortalUsers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."DealerTiers"
    ADD CONSTRAINT "DealerTiers_organization_id_code_key" UNIQUE ("organization_id", "code");



ALTER TABLE ONLY "public"."DealerTiers"
    ADD CONSTRAINT "DealerTiers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ImportTaxRules"
    ADD CONSTRAINT "ImportTaxRules_organization_id_category_id_key" UNIQUE ("organization_id", "category_id");



ALTER TABLE ONLY "public"."ImportTaxRules"
    ADD CONSTRAINT "ImportTaxRules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Manufacturers"
    ADD CONSTRAINT "Manufacturers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ManufacturingOrders"
    ADD CONSTRAINT "ManufacturingOrders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."OrderList"
    ADD CONSTRAINT "OrderList_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."OrganizationUserPermissions"
    ADD CONSTRAINT "OrganizationUserPermissions_pkey" PRIMARY KEY ("organization_user_id", "permission_code");



ALTER TABLE ONLY "public"."OrganizationUsers"
    ADD CONSTRAINT "OrganizationUsers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Organizations"
    ADD CONSTRAINT "Organizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Permissions"
    ADD CONSTRAINT "Permissions_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."ProductTypeRoleRules"
    ADD CONSTRAINT "ProductTypeRoleRules_organization_id_product_type_id_role_c_key" UNIQUE ("organization_id", "product_type_id", "role_code");



ALTER TABLE ONLY "public"."ProductTypeRoleRules"
    ADD CONSTRAINT "ProductTypeRoleRules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ProductTypes"
    ADD CONSTRAINT "ProductTypes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ProposalLines"
    ADD CONSTRAINT "ProposalLines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."QuoteLineBOMSelections"
    ADD CONSTRAINT "QuoteLineBOMSelections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."QuoteLineBOMSelections"
    ADD CONSTRAINT "QuoteLineBOMSelections_quote_line_id_component_role_key" UNIQUE ("quote_line_id", "component_role");



ALTER TABLE ONLY "public"."QuoteLineComponents"
    ADD CONSTRAINT "QuoteLineComponents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."QuoteLineCosts"
    ADD CONSTRAINT "QuoteLineCosts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."QuoteLines"
    ADD CONSTRAINT "QuoteLines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "Quotes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."SaleOrderLines"
    ADD CONSTRAINT "SaleOrderLines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."SalesOrders"
    ADD CONSTRAINT "SalesOrders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CatalogItemComponents"
    ADD CONSTRAINT "catalogitemcomponents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CatalogItemsMSRP"
    ADD CONSTRAINT "catalogitemsmsrp_org_item_unique" UNIQUE ("organization_id", "catalog_item_id");



ALTER TABLE ONLY "public"."CategoryMargins"
    ADD CONSTRAINT "categorymargins_org_category_unique" UNIQUE ("organization_id", "category_id");



ALTER TABLE ONLY "public"."Dealers"
    ADD CONSTRAINT "companies_org_company_no_uniq" UNIQUE ("organization_id", "dealer_no");



ALTER TABLE ONLY "public"."ConfiguredProducts"
    ADD CONSTRAINT "configuredproducts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ImportTaxRules"
    ADD CONSTRAINT "importtaxrules_org_category_unique" UNIQUE ("organization_id", "category_id");



ALTER TABLE ONLY "public"."OrganizationUsers"
    ADD CONSTRAINT "organizationusers_org_email_uq" UNIQUE ("organization_id", "user_email");



ALTER TABLE ONLY "public"."ProductTypes"
    ADD CONSTRAINT "producttypes_unique_code" UNIQUE ("organization_id", "code");



ALTER TABLE ONLY "public"."ProductTypes"
    ADD CONSTRAINT "producttypes_unique_name" UNIQUE ("organization_id", "name");



ALTER TABLE ONLY "public"."stg_catalog_items_import_raw"
    ADD CONSTRAINT "stg_catalog_items_import_raw_pkey" PRIMARY KEY ("row_id");



CREATE UNIQUE INDEX "bomcomponents_unique_slot_override" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id", "slot_id") WHERE ("slot_id" IS NOT NULL);



CREATE INDEX "bomtemplateslots_role_idx" ON "public"."BOMTemplateSlots" USING "btree" ("item_role");



CREATE INDEX "bomtemplateslots_template_idx" ON "public"."BOMTemplateSlots" USING "btree" ("bom_template_id");



CREATE INDEX "catalog_item_roll_specs_org_idx" ON "public"."CatalogItemRollSpecs" USING "btree" ("organization_id");



CREATE INDEX "catalog_item_supply_org_idx" ON "public"."CatalogItemSupply" USING "btree" ("organization_id");



CREATE INDEX "catalogcategories_org_idx" ON "public"."CatalogCategories" USING "btree" ("organization_id");



CREATE UNIQUE INDEX "catalogcategories_org_parent_lowername_uidx" ON "public"."CatalogCategories" USING "btree" ("organization_id", "parent_id", "lower"("name"));



CREATE INDEX "catalogcategories_parent_idx" ON "public"."CatalogCategories" USING "btree" ("organization_id", "parent_id");



CREATE UNIQUE INDEX "catalogcategories_unique_siblings" ON "public"."CatalogCategories" USING "btree" ("organization_id", "parent_id", "lower"("name"));



CREATE UNIQUE INDEX "catalogitemcomponents_unique_parent_child" ON "public"."CatalogItemComponents" USING "btree" ("organization_id", "parent_item_id", "child_item_id") WHERE ("deleted" = false);



CREATE INDEX "catalogitemproducttypes_by_item" ON "public"."CatalogItemProductTypes" USING "btree" ("organization_id", "catalog_item_id");



CREATE INDEX "catalogitemproducttypes_by_type" ON "public"."CatalogItemProductTypes" USING "btree" ("organization_id", "product_type_id");



CREATE UNIQUE INDEX "catalogitemproducttypes_unique" ON "public"."CatalogItemProductTypes" USING "btree" ("organization_id", "catalog_item_id", "product_type_id");



CREATE UNIQUE INDEX "catalogitemroles_role_code_uniq" ON "public"."CatalogItemRoles" USING "btree" ("role_code");



CREATE INDEX "catalogitems_category_idx" ON "public"."CatalogItems" USING "btree" ("organization_id", "category_id");



CREATE INDEX "catalogitems_manufacturer_id_idx" ON "public"."CatalogItems" USING "btree" ("organization_id", "manufacturer_id");



CREATE INDEX "catalogitems_org_idx" ON "public"."CatalogItems" USING "btree" ("organization_id");



CREATE INDEX "catalogitems_org_roll_collection_idx" ON "public"."CatalogItems" USING "btree" ("organization_id", "roll_collection_id");



CREATE UNIQUE INDEX "catalogitemsmsrp_catalog_item_id_uq" ON "public"."CatalogItemsMSRP" USING "btree" ("catalog_item_id");



CREATE UNIQUE INDEX "dealerportal_dealer_email_uniq" ON "public"."DealerUsers" USING "btree" ("dealer_id", "lower"("portal_user_email")) WHERE ("deleted" = false);



CREATE UNIQUE INDEX "dealers_org_dealer_no_unique" ON "public"."Dealers" USING "btree" ("organization_id", "dealer_no") WHERE ("dealer_no" IS NOT NULL);



COMMENT ON INDEX "public"."dealers_org_dealer_no_unique" IS 'Ensure unique company_no per organization (only when company_no is set)';



CREATE INDEX "idx_bomcomponents_role" ON "public"."BOMComponents" USING "btree" ("organization_id", "component_role") WHERE (("deleted" = false) AND ("archived" = false));



CREATE INDEX "idx_bomcomponents_template" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id") WHERE (("deleted" = false) AND ("archived" = false));



CREATE INDEX "idx_bomtemplates_product_type_panel_count_color" ON "public"."BOMTemplates" USING "btree" ("product_type_id", "panel_count_min", "panel_count_max", "hardware_color") WHERE (("is_active" = true) AND (("archived" = false) OR ("archived" IS NULL)));



CREATE INDEX "idx_catalogitemcomponents_child_role" ON "public"."CatalogItemComponents" USING "btree" ("organization_id", "child_role") WHERE ("deleted" = false);



CREATE INDEX "idx_catalogitemcomponents_parent" ON "public"."CatalogItemComponents" USING "btree" ("organization_id", "parent_item_id") WHERE ("deleted" = false);



CREATE INDEX "idx_catalogitemconversions_org" ON "public"."CatalogItemConversions" USING "btree" ("organization_id");



CREATE INDEX "idx_catalogitems_org_role" ON "public"."CatalogItems" USING "btree" ("organization_id", "item_role") WHERE ("is_active" = true);



CREATE INDEX "idx_catalogitems_org_role_color" ON "public"."CatalogItems" USING "btree" ("organization_id", "item_role", "color") WHERE (("is_active" = true) AND ("is_roll" = false));



CREATE INDEX "idx_catalogitems_roll_lookup" ON "public"."CatalogItems" USING "btree" ("organization_id", "collection_name", "variant_name") WHERE (("is_active" = true) AND ("is_roll" = true));



CREATE INDEX "idx_catalogitemsmsrp_cat" ON "public"."CatalogItemsMSRP" USING "btree" ("category_id");



CREATE INDEX "idx_catalogitemsmsrp_org" ON "public"."CatalogItemsMSRP" USING "btree" ("organization_id");



CREATE INDEX "idx_catalogitemsmsrp_org_item" ON "public"."CatalogItemsMSRP" USING "btree" ("organization_id", "catalog_item_id");



CREATE INDEX "idx_companyportalusers_role" ON "public"."DealerUsers" USING "btree" ("role") WHERE ("deleted" = false);



CREATE INDEX "idx_configuredproducts_bom_preview_gin" ON "public"."ConfiguredProducts" USING "gin" ("bom_preview_snapshot");



CREATE INDEX "idx_configuredproducts_config_snapshot" ON "public"."ConfiguredProducts" USING "gin" ("config_snapshot");



CREATE INDEX "idx_configuredproducts_organization" ON "public"."ConfiguredProducts" USING "btree" ("organization_id") WHERE ("deleted" = false);



CREATE INDEX "idx_configuredproducts_product_type" ON "public"."ConfiguredProducts" USING "btree" ("product_type_id") WHERE ("deleted" = false);



CREATE INDEX "idx_configuredproducts_quote" ON "public"."ConfiguredProducts" USING "btree" ("quote_id") WHERE ("deleted" = false);



CREATE INDEX "idx_configuredproducts_template" ON "public"."ConfiguredProducts" USING "btree" ("bom_template_id") WHERE ("deleted" = false);



CREATE INDEX "idx_dealers_dealer_tier_id" ON "public"."Dealers" USING "btree" ("dealer_tier_id") WHERE ("dealer_tier_id" IS NOT NULL);



CREATE INDEX "idx_dealers_deleted" ON "public"."Dealers" USING "btree" ("deleted") WHERE ("deleted" = false);



CREATE INDEX "idx_dealers_org" ON "public"."Dealers" USING "btree" ("organization_id");



CREATE INDEX "idx_dealers_org_dealer_no" ON "public"."Dealers" USING "btree" ("organization_id", "dealer_no");



CREATE INDEX "idx_dealertiers_org_sort" ON "public"."DealerTiers" USING "btree" ("organization_id", "sort_order");



CREATE INDEX "idx_dealerusers_dealer" ON "public"."DealerUsers" USING "btree" ("dealer_id");



CREATE INDEX "idx_dircontacts_company" ON "public"."DirectoryContacts" USING "btree" ("dealer_id");



CREATE INDEX "idx_dircontacts_org" ON "public"."DirectoryContacts" USING "btree" ("organization_id") WHERE ("organization_id" IS NOT NULL);



CREATE INDEX "idx_dircustomers_company" ON "public"."DirectoryCustomers" USING "btree" ("dealer_id");



CREATE INDEX "idx_dircustomers_country" ON "public"."DirectoryCustomers" USING "btree" ("country") WHERE ("country" IS NOT NULL);



CREATE INDEX "idx_dircustomers_customer_type" ON "public"."DirectoryCustomers" USING "btree" ("customer_type_name") WHERE ("customer_type_name" IS NOT NULL);



CREATE INDEX "idx_dircustomers_org" ON "public"."DirectoryCustomers" USING "btree" ("organization_id") WHERE ("organization_id" IS NOT NULL);



CREATE INDEX "idx_dircustomers_primary_contact" ON "public"."DirectoryCustomers" USING "btree" ("primary_contact_id") WHERE ("primary_contact_id" IS NOT NULL);



CREATE INDEX "idx_directory_contacts_created_by_portal_user" ON "public"."DirectoryContacts" USING "btree" ("created_by_portal_user_id") WHERE (("deleted" = false) AND ("created_by_portal_user_id" IS NOT NULL));



CREATE INDEX "idx_directory_contacts_created_by_user" ON "public"."DirectoryContacts" USING "btree" ("created_by_user_id") WHERE (("deleted" = false) AND ("created_by_user_id" IS NOT NULL));



CREATE INDEX "idx_directory_customers_created_by_portal_user" ON "public"."DirectoryCustomers" USING "btree" ("created_by_portal_user_id") WHERE (("deleted" = false) AND ("created_by_portal_user_id" IS NOT NULL));



CREATE INDEX "idx_directory_customers_created_by_user" ON "public"."DirectoryCustomers" USING "btree" ("created_by_user_id") WHERE (("deleted" = false) AND ("created_by_user_id" IS NOT NULL));



CREATE INDEX "idx_directorycontacts_contact_type" ON "public"."DirectoryContacts" USING "btree" ("contact_type");



CREATE INDEX "idx_directorycontacts_customer" ON "public"."DirectoryContacts" USING "btree" ("customer_id");



CREATE INDEX "idx_directorycontacts_org" ON "public"."DirectoryContacts" USING "btree" ("organization_id");



CREATE INDEX "idx_directorycustomers_company_id" ON "public"."DirectoryCustomers" USING "btree" ("dealer_id");



CREATE INDEX "idx_directorycustomers_org" ON "public"."DirectoryCustomers" USING "btree" ("organization_id");



CREATE INDEX "idx_directorycustomers_org_company" ON "public"."DirectoryCustomers" USING "btree" ("organization_id", "dealer_id");



CREATE INDEX "idx_mo_company" ON "public"."ManufacturingOrders" USING "btree" ("dealer_id");



CREATE INDEX "idx_mo_org" ON "public"."ManufacturingOrders" USING "btree" ("organization_id");



CREATE INDEX "idx_mo_so" ON "public"."ManufacturingOrders" USING "btree" ("sales_order_id");



CREATE INDEX "idx_order_list_organization_id" ON "public"."OrderList" USING "btree" ("organization_id") WHERE ("deleted" = false);



CREATE INDEX "idx_order_list_sales_order_id" ON "public"."OrderList" USING "btree" ("sales_order_id") WHERE ("deleted" = false);



CREATE INDEX "idx_order_list_tracking_status" ON "public"."OrderList" USING "btree" ("tracking_status") WHERE ("deleted" = false);



CREATE INDEX "idx_orderlist_company" ON "public"."OrderList" USING "btree" ("dealer_id");



CREATE INDEX "idx_org_user_permissions_code" ON "public"."OrganizationUserPermissions" USING "btree" ("permission_code");



CREATE INDEX "idx_org_user_permissions_user_id" ON "public"."OrganizationUserPermissions" USING "btree" ("organization_user_id");



CREATE INDEX "idx_organization_users_organization_id" ON "public"."OrganizationUsers" USING "btree" ("organization_id") WHERE ("deleted" = false);



CREATE INDEX "idx_organization_users_status" ON "public"."OrganizationUsers" USING "btree" ("status") WHERE ("deleted" = false);



CREATE INDEX "idx_organization_users_user_email" ON "public"."OrganizationUsers" USING "btree" ("lower"("user_email")) WHERE ("deleted" = false);



CREATE INDEX "idx_organization_users_user_id" ON "public"."OrganizationUsers" USING "btree" ("user_id") WHERE (("user_id" IS NOT NULL) AND ("deleted" = false));



CREATE INDEX "idx_organizations_created_at" ON "public"."Organizations" USING "btree" ("created_at");



CREATE INDEX "idx_permissions_module" ON "public"."Permissions" USING "btree" ("module");



CREATE INDEX "idx_portalusers_org" ON "public"."DealerUsers" USING "btree" ("organization_id");



CREATE INDEX "idx_portalusers_user" ON "public"."DealerUsers" USING "btree" ("user_id");



CREATE INDEX "idx_qlc_org_id" ON "public"."QuoteLineComponents" USING "btree" ("organization_id");



CREATE INDEX "idx_qlc_quote_line_id" ON "public"."QuoteLineComponents" USING "btree" ("quote_line_id");



CREATE INDEX "idx_qlc_role" ON "public"."QuoteLineComponents" USING "btree" ("component_role");



CREATE INDEX "idx_quote_lines_bom_template_id" ON "public"."QuoteLines" USING "btree" ("bom_template_id") WHERE ("bom_template_id" IS NOT NULL);



CREATE INDEX "idx_quote_lines_product_type" ON "public"."QuoteLines" USING "btree" ("product_type") WHERE ("product_type" IS NOT NULL);



CREATE INDEX "idx_quotelines_catalog_item_id" ON "public"."QuoteLines" USING "btree" ("catalog_item_id");



CREATE INDEX "idx_quotelines_category_id" ON "public"."QuoteLines" USING "btree" ("category_id");



CREATE INDEX "idx_quotelines_company_id" ON "public"."QuoteLines" USING "btree" ("dealer_id");



CREATE INDEX "idx_quotelines_configured_product_id" ON "public"."QuoteLines" USING "btree" ("configured_product_id");



CREATE INDEX "idx_quotelines_org_id" ON "public"."QuoteLines" USING "btree" ("organization_id");



CREATE INDEX "idx_quotelines_quote_id" ON "public"."QuoteLines" USING "btree" ("quote_id");



CREATE INDEX "idx_quotes_company" ON "public"."Quotes" USING "btree" ("dealer_id");



CREATE INDEX "idx_quotes_created_by" ON "public"."Quotes" USING "btree" ("created_by_user_id") WHERE ("deleted" = false);



CREATE INDEX "idx_quotes_created_by_portal_user" ON "public"."Quotes" USING "btree" ("created_by_portal_user_id") WHERE (("created_by_portal_user_id" IS NOT NULL) AND ("deleted" = false));



CREATE INDEX "idx_quotes_customer_id" ON "public"."Quotes" USING "btree" ("customer_id") WHERE (("customer_id" IS NOT NULL) AND ("deleted" = false));



CREATE INDEX "idx_quotes_organization_id" ON "public"."Quotes" USING "btree" ("organization_id") WHERE ("deleted" = false);



CREATE INDEX "idx_quotes_status" ON "public"."Quotes" USING "btree" ("status") WHERE ("deleted" = false);



CREATE INDEX "idx_quotes_tracking_status" ON "public"."Quotes" USING "btree" ("tracking_status") WHERE (("deleted" = false) AND ("tracking_status" IS NOT NULL));



CREATE INDEX "idx_saleorderlines_so" ON "public"."SaleOrderLines" USING "btree" ("sales_order_id");



CREATE INDEX "idx_sales_orders_organization_id" ON "public"."SalesOrders" USING "btree" ("organization_id") WHERE ("deleted" = false);



CREATE INDEX "idx_sales_orders_quote_id" ON "public"."SalesOrders" USING "btree" ("quote_id") WHERE ("deleted" = false);



CREATE INDEX "idx_sales_orders_tracking_status" ON "public"."SalesOrders" USING "btree" ("tracking_status") WHERE ("deleted" = false);



CREATE INDEX "idx_salesorders_company" ON "public"."SalesOrders" USING "btree" ("dealer_id");



CREATE UNIQUE INDEX "importtaxrules_org_category_uniq" ON "public"."ImportTaxRules" USING "btree" ("organization_id", "category_id");



CREATE INDEX "ix_bomcomponents_item" ON "public"."BOMComponents" USING "btree" ("organization_id", "component_item_id") WHERE (("deleted" = false) AND ("archived" = false));



CREATE INDEX "ix_bomcomponents_org_role_active" ON "public"."BOMComponents" USING "btree" ("organization_id", "component_role") WHERE (("deleted" = false) AND ("archived" = false));



CREATE INDEX "ix_bomcomponents_org_slot_active" ON "public"."BOMComponents" USING "btree" ("organization_id", "slot_id") WHERE (("deleted" = false) AND ("archived" = false) AND ("slot_id" IS NOT NULL));



CREATE INDEX "ix_bomcomponents_org_template_active" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id") WHERE (("deleted" = false) AND ("archived" = false));



CREATE INDEX "ix_bomcomponents_parent" ON "public"."BOMComponents" USING "btree" ("organization_id", "parent_component_id") WHERE (("deleted" = false) AND ("archived" = false));



CREATE INDEX "ix_bomcomponents_role" ON "public"."BOMComponents" USING "btree" ("organization_id", "component_role") WHERE (("deleted" = false) AND ("archived" = false));



CREATE INDEX "ix_bomcomponents_template" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id") WHERE (("deleted" = false) AND ("archived" = false));



CREATE INDEX "ix_bomcomponents_template_tree" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id", "parent_component_id") WHERE (("deleted" = false) AND ("archived" = false));



CREATE INDEX "ix_bomcomponents_tree" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id", "parent_component_id") WHERE (("deleted" = false) AND ("archived" = false));



CREATE INDEX "ix_catalogitemcomponents_parent_role" ON "public"."CatalogItemComponents" USING "btree" ("organization_id", "parent_item_id", "child_role");



CREATE INDEX "manufacturers_org_idx" ON "public"."Manufacturers" USING "btree" ("organization_id");



CREATE UNIQUE INDEX "manufacturers_org_name_unique" ON "public"."Manufacturers" USING "btree" ("organization_id", "lower"("name"));



CREATE UNIQUE INDEX "orderlist_unique_so" ON "public"."OrderList" USING "btree" ("sales_order_id") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "org_users_unique_email" ON "public"."OrganizationUsers" USING "btree" ("organization_id", "lower"("user_email")) WHERE ("deleted" = false);



CREATE UNIQUE INDEX "organizationusers_org_email_uniq" ON "public"."OrganizationUsers" USING "btree" ("organization_id", "user_email");



CREATE UNIQUE INDEX "organizationusers_org_email_unique" ON "public"."OrganizationUsers" USING "btree" ("organization_id", "lower"("user_email")) WHERE ("deleted" = false);



COMMENT ON INDEX "public"."organizationusers_org_email_unique" IS 'Ensures unique email addresses per organization for active (non-deleted) records. Case-insensitive comparison.';



CREATE UNIQUE INDEX "organizationusers_org_user_unique" ON "public"."OrganizationUsers" USING "btree" ("organization_id", "user_id") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "orgusers_org_email_uniq" ON "public"."OrganizationUsers" USING "btree" ("organization_id", "lower"("user_email")) WHERE ("deleted" = false);



CREATE INDEX "product_type_role_rules_org_pt_idx" ON "public"."ProductTypeRoleRules" USING "btree" ("organization_id", "product_type_id");



CREATE INDEX "product_type_role_rules_org_role_idx" ON "public"."ProductTypeRoleRules" USING "btree" ("organization_id", "role_code");



CREATE INDEX "proposal_lines_proposal_idx" ON "public"."ProposalLines" USING "btree" ("proposal_id", "sort_order");



CREATE INDEX "proposal_lines_quote_line_idx" ON "public"."ProposalLines" USING "btree" ("quote_line_id");



CREATE INDEX "proposals_org_dealer_idx" ON "public"."Proposals" USING "btree" ("organization_id", "dealer_id");



CREATE INDEX "proposals_quote_idx" ON "public"."Proposals" USING "btree" ("quote_id");



CREATE UNIQUE INDEX "proposals_quote_version_uniq" ON "public"."Proposals" USING "btree" ("quote_id", "version_no") WHERE ("deleted" = false);



CREATE INDEX "proposals_status_idx" ON "public"."Proposals" USING "btree" ("status");



CREATE INDEX "qlbs_org_idx" ON "public"."QuoteLineBOMSelections" USING "btree" ("organization_id");



CREATE INDEX "qlbs_quote_line_id_idx" ON "public"."QuoteLineBOMSelections" USING "btree" ("quote_line_id");



CREATE INDEX "quote_lines_product_type_id_idx" ON "public"."QuoteLines" USING "btree" ("product_type_id");



CREATE UNIQUE INDEX "quotes_org_quote_no_unique" ON "public"."Quotes" USING "btree" ("organization_id", "quote_no") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "quotes_unique_no" ON "public"."Quotes" USING "btree" ("organization_id", "quote_no") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "sales_orders_org_so_no_unique" ON "public"."SalesOrders" USING "btree" ("organization_id", "sales_order_no") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "so_unique_quote" ON "public"."SalesOrders" USING "btree" ("quote_id") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "uq_bomcomponents_template_slot_active" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id", "slot_id") WHERE (("deleted" = false) AND ("archived" = false) AND ("slot_id" IS NOT NULL));



CREATE UNIQUE INDEX "uq_catalogitemcomponents_parent_child_role" ON "public"."CatalogItemComponents" USING "btree" ("organization_id", "parent_item_id", "child_item_id", "child_role");



CREATE UNIQUE INDEX "uq_dealers_org_name" ON "public"."Dealers" USING "btree" ("organization_id", "lower"("dealer_name")) WHERE ("deleted" = false);



CREATE UNIQUE INDEX "uq_orguserpermissions_orguser_perm" ON "public"."OrganizationUserPermissions" USING "btree" ("organization_user_id", "permission_code");



CREATE UNIQUE INDEX "ux_bomcomponents_no_duplicate_child_sku" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id", "parent_component_id", "component_item_id") WHERE (("parent_component_id" IS NOT NULL) AND ("deleted" = false) AND ("archived" = false));



CREATE OR REPLACE TRIGGER "catalog_items_recompute_msrp" AFTER UPDATE OF "cost_exw" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."trg_catalog_items_recompute_msrp"();



CREATE OR REPLACE TRIGGER "catalogitems_validate_roll_pricing_mode" BEFORE INSERT OR UPDATE OF "is_roll", "roll_pricing_mode", "roll_width", "measure_basis" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."trg_catalogitems_validate_roll_pricing_mode"();



CREATE OR REPLACE TRIGGER "catalogitems_write_conversions" AFTER INSERT OR UPDATE OF "cost_exw", "unit_of_measure", "roll_width", "roll_width_value", "roll_width_uom", "roll_width_m", "is_roll", "units_per_purchase_unit" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."trg_catalogitems_write_conversions"();



CREATE OR REPLACE TRIGGER "enforce_mo_dealer_matches_salesorder" BEFORE INSERT OR UPDATE ON "public"."ManufacturingOrders" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_mo_dealer_matches_salesorder"();



CREATE OR REPLACE TRIGGER "enforce_orderlist_dealer_matches_salesorder" BEFORE INSERT OR UPDATE ON "public"."OrderList" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_orderlist_dealer_matches_salesorder"();



CREATE OR REPLACE TRIGGER "enforce_salesorders_dealer_matches_quote" BEFORE INSERT OR UPDATE ON "public"."SalesOrders" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_salesorders_dealer_matches_quote"();



CREATE OR REPLACE TRIGGER "trg_catalog_item_roles_updated_at" BEFORE UPDATE ON "public"."CatalogItemRoles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_catalog_item_roll_specs_updated_at" BEFORE UPDATE ON "public"."CatalogItemRollSpecs" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_catalog_item_supply_updated_at" BEFORE UPDATE ON "public"."CatalogItemSupply" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_catalogcategories_insert_category_margin" AFTER INSERT ON "public"."CatalogCategories" FOR EACH ROW EXECUTE FUNCTION "public"."trg_catalogcategories_insert_category_margin"();



CREATE OR REPLACE TRIGGER "trg_catalogitemcomponents_updated_at" BEFORE UPDATE ON "public"."CatalogItemComponents" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_catalogitemroles_updated_at" BEFORE UPDATE ON "public"."CatalogItemRoles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_catalogitems_sync_collection_name" BEFORE INSERT OR UPDATE OF "roll_collection_id" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."sync_catalogitem_collection_name_from_roll_collection"();



CREATE OR REPLACE TRIGGER "trg_catalogitems_sync_manufacturer" BEFORE INSERT OR UPDATE OF "manufacturer", "organization_id" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."sync_catalogitems_manufacturer"();



CREATE OR REPLACE TRIGGER "trg_catalogitems_sync_roll_dimensions" BEFORE INSERT OR UPDATE ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."catalogitems_sync_roll_dimensions"();



CREATE OR REPLACE TRIGGER "trg_catalogitemsmsrp_enforce_rates" BEFORE INSERT OR UPDATE ON "public"."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION "public"."trig_enforce_msrp_sources"();



CREATE OR REPLACE TRIGGER "trg_catalogitemsmsrp_guard_not_null" BEFORE INSERT OR UPDATE ON "public"."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION "public"."catalogitemsmsrp_guard_not_null"();



CREATE OR REPLACE TRIGGER "trg_catalogitemsmsrp_updated_at" BEFORE UPDATE ON "public"."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_categorymargins_recompute_itemsmsrp" AFTER INSERT OR UPDATE OF "minimum_margin_pct", "msrp_pct", "is_active" ON "public"."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION "public"."_trg_categorymargins_recompute_itemsmsrp"();



CREATE OR REPLACE TRIGGER "trg_categorymargins_updated_at" BEFORE UPDATE ON "public"."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_companies_updated_at" BEFORE UPDATE ON "public"."Dealers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_companyportalusers_updated_at" BEFORE UPDATE ON "public"."DealerUsers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_configuredproducts_updated_at" BEFORE UPDATE ON "public"."ConfiguredProducts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_costsettings_recompute_itemsmsrp" AFTER UPDATE OF "shipping_pct", "global_import_tax_pct", "minimum_margin_pct", "default_msrp_pct" ON "public"."CostSettings" FOR EACH ROW EXECUTE FUNCTION "public"."_trg_costsettings_recompute_itemsmsrp"();



CREATE OR REPLACE TRIGGER "trg_costsettings_updated_at" BEFORE UPDATE ON "public"."CostSettings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_customerportalusers_updated_at" BEFORE UPDATE ON "public"."DealerUsers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_dealers_set_dealer_no" BEFORE INSERT ON "public"."Dealers" FOR EACH ROW EXECUTE FUNCTION "public"."set_dealer_no"();



CREATE OR REPLACE TRIGGER "trg_dealertiers_updated_at" BEFORE UPDATE ON "public"."DealerTiers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_dircontacts_set_dealer" BEFORE INSERT ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."tg_set_dealer_id_from_portal_user"();



CREATE OR REPLACE TRIGGER "trg_directorycontacts_fill_org_id" BEFORE INSERT OR UPDATE OF "dealer_id", "organization_id" ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."directorycontacts_fill_org_id"();



CREATE OR REPLACE TRIGGER "trg_directorycontacts_updated_at" BEFORE UPDATE ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_directorycustomers_set_dealer" BEFORE INSERT ON "public"."DirectoryCustomers" FOR EACH ROW EXECUTE FUNCTION "public"."tg_set_dealer_id_from_portal_user"();



CREATE OR REPLACE TRIGGER "trg_directorycustomers_updated_at" BEFORE UPDATE ON "public"."DirectoryCustomers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_enforce_active_item_role" BEFORE INSERT OR UPDATE OF "item_role" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_active_item_role"();



CREATE OR REPLACE TRIGGER "trg_fill_msrp_item_identity" BEFORE INSERT OR UPDATE OF "catalog_item_id", "sku", "name", "collection_name", "variant_name" ON "public"."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION "public"."fill_msrp_item_identity"();



CREATE OR REPLACE TRIGGER "trg_fill_msrp_sku_name" BEFORE INSERT OR UPDATE OF "catalog_item_id", "sku", "name" ON "public"."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION "public"."fill_msrp_sku_name"();



CREATE OR REPLACE TRIGGER "trg_importtaxrules_recompute_itemsmsrp" AFTER INSERT OR UPDATE OF "import_tax_pct", "is_active" ON "public"."ImportTaxRules" FOR EACH ROW EXECUTE FUNCTION "public"."_trg_importtaxrules_recompute_itemsmsrp"();



CREATE OR REPLACE TRIGGER "trg_importtaxrules_updated_at" BEFORE UPDATE ON "public"."ImportTaxRules" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_manufacturingorders_updated_at" BEFORE UPDATE ON "public"."ManufacturingOrders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_organizations_updated_at" BEFORE UPDATE ON "public"."Organizations" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_portalusers_updated_at" BEFORE UPDATE ON "public"."DealerUsers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_producttypes_set_updated_at" BEFORE UPDATE ON "public"."ProductTypes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_proposal_lines_set_updated_at" BEFORE UPDATE ON "public"."ProposalLines" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_proposals_set_updated_at" BEFORE UPDATE ON "public"."Proposals" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_quote_approved" AFTER UPDATE OF "status" ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."on_quote_approved_create_sales_order"();



CREATE OR REPLACE TRIGGER "trg_quote_approved_to_sales_order" BEFORE UPDATE ON "public"."Quotes" FOR EACH ROW WHEN (("old"."status" IS DISTINCT FROM "new"."status")) EXECUTE FUNCTION "public"."handle_quote_approved"();



COMMENT ON TRIGGER "trg_quote_approved_to_sales_order" ON "public"."Quotes" IS 'Trigger: Automatically creates SalesOrder and OrderList when Quote is approved. Sets Quote.tracking_status.';



CREATE OR REPLACE TRIGGER "trg_quote_line_components_updated_at" BEFORE UPDATE ON "public"."QuoteLineComponents" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_quote_lines_set_dealer_id" BEFORE INSERT OR UPDATE OF "quote_id", "organization_id", "dealer_id" ON "public"."QuoteLines" FOR EACH ROW EXECUTE FUNCTION "public"."quote_lines_set_dealer_id"();



CREATE OR REPLACE TRIGGER "trg_quote_lines_validate_dealer" BEFORE INSERT OR UPDATE OF "quote_id", "organization_id", "dealer_id" ON "public"."QuoteLines" FOR EACH ROW EXECUTE FUNCTION "public"."quote_lines_validate_dealer"();



CREATE OR REPLACE TRIGGER "trg_quotes_set_dealer" BEFORE INSERT ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."tg_set_dealer_id_from_portal_user"();



CREATE OR REPLACE TRIGGER "trg_quotes_updated_at" BEFORE UPDATE ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_recompute_msrp_on_catalog_item_change" AFTER INSERT OR UPDATE OF "cost_exw", "category_id" ON "public"."CatalogItems" FOR EACH ROW WHEN (("new"."organization_id" IS NOT NULL)) EXECUTE FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"();



CREATE OR REPLACE TRIGGER "trg_recompute_msrp_on_category_margin_change" AFTER INSERT OR DELETE OR UPDATE ON "public"."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION "public"."trig_recompute_msrp_on_category_margin_change"();



CREATE OR REPLACE TRIGGER "trg_recompute_msrp_on_cost_settings_change" AFTER INSERT OR UPDATE OF "shipping_pct", "global_import_tax_pct" ON "public"."CostSettings" FOR EACH ROW EXECUTE FUNCTION "public"."trig_recompute_msrp_on_cost_settings_change"();



CREATE OR REPLACE TRIGGER "trg_recompute_msrp_on_import_tax_change" AFTER INSERT OR DELETE OR UPDATE ON "public"."ImportTaxRules" FOR EACH ROW EXECUTE FUNCTION "public"."trig_recompute_msrp_on_import_tax_change"();



CREATE OR REPLACE TRIGGER "trg_salesorder_status" AFTER UPDATE OF "tracking_status" ON "public"."SalesOrders" FOR EACH ROW EXECUTE FUNCTION "public"."on_sales_order_status_mirror"();



CREATE OR REPLACE TRIGGER "trg_salesorders_updated_at" BEFORE UPDATE ON "public"."SalesOrders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at_product_type_role_rules" BEFORE UPDATE ON "public"."ProductTypeRoleRules" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at_product_type_role_rules"();



CREATE OR REPLACE TRIGGER "trg_sync_bom_template_slot_sku" BEFORE INSERT OR UPDATE OF "catalog_item_id", "fixed_catalog_item_id" ON "public"."BOMTemplateSlots" FOR EACH ROW EXECUTE FUNCTION "public"."sync_bom_template_slot_sku"();



CREATE OR REPLACE TRIGGER "trg_sync_catalogitems_to_msrp_safe" AFTER INSERT OR UPDATE OF "sku", "name", "collection_name", "variant_name", "unit_of_measure", "category_id", "cost_exw" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."sync_catalogitems_to_msrp_safe"();



CREATE OR REPLACE TRIGGER "trg_sync_order_list_tracking" AFTER UPDATE OF "tracking_status" ON "public"."SalesOrders" FOR EACH ROW WHEN (("old"."tracking_status" IS DISTINCT FROM "new"."tracking_status")) EXECUTE FUNCTION "public"."sync_order_list_tracking_status"();



COMMENT ON TRIGGER "trg_sync_order_list_tracking" ON "public"."SalesOrders" IS 'Trigger: Automatically syncs OrderList.tracking_status when SalesOrder.tracking_status changes.';



CREATE OR REPLACE TRIGGER "trig_catmargins_msrp" AFTER INSERT OR UPDATE OF "minimum_margin_pct", "msrp_pct" ON "public"."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION "public"."trig_catmargins_msrp"();



CREATE OR REPLACE TRIGGER "update_order_list_updated_at" BEFORE UPDATE ON "public"."OrderList" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_organization_users_updated_at" BEFORE UPDATE ON "public"."OrganizationUsers" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_quotes_updated_at" BEFORE UPDATE ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_sales_orders_updated_at" BEFORE UPDATE ON "public"."SalesOrders" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."BOMComponents"
    ADD CONSTRAINT "BOMComponents_slot_id_fkey" FOREIGN KEY ("slot_id") REFERENCES "public"."BOMTemplateSlots"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."BOMTemplateSlots"
    ADD CONSTRAINT "BOMTemplateSlots_bom_template_id_fkey" FOREIGN KEY ("bom_template_id") REFERENCES "public"."BOMTemplates"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."BOMTemplateSlots"
    ADD CONSTRAINT "BOMTemplateSlots_catalog_item_id_fkey" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id");



ALTER TABLE ONLY "public"."BOMTemplateSlots"
    ADD CONSTRAINT "BOMTemplateSlots_fixed_catalog_item_id_fkey" FOREIGN KEY ("fixed_catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."CatalogItemConversions"
    ADD CONSTRAINT "CatalogItemConversions_catalog_item_id_fkey" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."CatalogItemRollSpecs"
    ADD CONSTRAINT "CatalogItemRollSpecs_catalog_item_id_fkey" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."CatalogItemSupply"
    ADD CONSTRAINT "CatalogItemSupply_catalog_item_id_fkey" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."CatalogItemsMSRP"
    ADD CONSTRAINT "CatalogItemsMSRP_catalog_item_id_fkey" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."CatalogItems"
    ADD CONSTRAINT "CatalogItems_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."CatalogCategories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."CatalogRoleCategoryMap"
    ADD CONSTRAINT "CatalogRoleCategoryMap_role_code_fkey" FOREIGN KEY ("role_code") REFERENCES "public"."CatalogItemRoles"("role_code") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."CatalogRoleCategoryMap"
    ADD CONSTRAINT "CatalogRoleCategoryMap_target_category_id_fkey" FOREIGN KEY ("target_category_id") REFERENCES "public"."CatalogCategories"("id") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."Dealers"
    ADD CONSTRAINT "Companies_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DealerUsers"
    ADD CONSTRAINT "CustomerPortalUsers_invited_by_user_id_fkey" FOREIGN KEY ("invited_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DealerUsers"
    ADD CONSTRAINT "CustomerPortalUsers_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DealerUsers"
    ADD CONSTRAINT "CustomerPortalUsers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DealerTiers"
    ADD CONSTRAINT "DealerTiers_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."DealerUsers"
    ADD CONSTRAINT "DealerUsers_dealer_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."Dealers"
    ADD CONSTRAINT "Dealers_dealer_tier_id_fkey" FOREIGN KEY ("dealer_tier_id") REFERENCES "public"."DealerTiers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_company_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_created_by_portal_user_id_fkey" FOREIGN KEY ("created_by_portal_user_id") REFERENCES "public"."DealerUsers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."DirectoryCustomers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_company_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_created_by_portal_user_id_fkey" FOREIGN KEY ("created_by_portal_user_id") REFERENCES "public"."DealerUsers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_primary_contact_id_fkey" FOREIGN KEY ("primary_contact_id") REFERENCES "public"."DirectoryContacts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ManufacturingOrders"
    ADD CONSTRAINT "ManufacturingOrders_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."ManufacturingOrders"
    ADD CONSTRAINT "ManufacturingOrders_sales_order_id_fkey" FOREIGN KEY ("sales_order_id") REFERENCES "public"."SalesOrders"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."OrderList"
    ADD CONSTRAINT "OrderList_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."OrderList"
    ADD CONSTRAINT "OrderList_sales_order_id_fkey" FOREIGN KEY ("sales_order_id") REFERENCES "public"."SalesOrders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."OrganizationUserPermissions"
    ADD CONSTRAINT "OrganizationUserPermissions_organization_user_id_fkey" FOREIGN KEY ("organization_user_id") REFERENCES "public"."OrganizationUsers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."OrganizationUserPermissions"
    ADD CONSTRAINT "OrganizationUserPermissions_permission_code_fkey" FOREIGN KEY ("permission_code") REFERENCES "public"."Permissions"("code") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."OrganizationUsers"
    ADD CONSTRAINT "OrganizationUsers_invited_by_user_id_fkey" FOREIGN KEY ("invited_by_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."OrganizationUsers"
    ADD CONSTRAINT "OrganizationUsers_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."OrganizationUsers"
    ADD CONSTRAINT "OrganizationUsers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ProductTypeRoleRules"
    ADD CONSTRAINT "ProductTypeRoleRules_product_type_id_fkey" FOREIGN KEY ("product_type_id") REFERENCES "public"."ProductTypes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ProductTypes"
    ADD CONSTRAINT "ProductTypes_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ProposalLines"
    ADD CONSTRAINT "ProposalLines_dealer_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."ProposalLines"
    ADD CONSTRAINT "ProposalLines_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."ProposalLines"
    ADD CONSTRAINT "ProposalLines_proposal_id_fkey" FOREIGN KEY ("proposal_id") REFERENCES "public"."Proposals"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ProposalLines"
    ADD CONSTRAINT "ProposalLines_quote_line_id_fkey" FOREIGN KEY ("quote_line_id") REFERENCES "public"."QuoteLines"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_contact_id_fkey" FOREIGN KEY ("contact_id") REFERENCES "public"."DirectoryContacts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_created_by_portal_user_id_fkey" FOREIGN KEY ("created_by_portal_user_id") REFERENCES "public"."DealerUsers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."DirectoryCustomers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_dealer_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_quote_id_fkey" FOREIGN KEY ("quote_id") REFERENCES "public"."Quotes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."QuoteLineBOMSelections"
    ADD CONSTRAINT "QuoteLineBOMSelections_catalog_item_id_fkey" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id");



ALTER TABLE ONLY "public"."QuoteLineBOMSelections"
    ADD CONSTRAINT "QuoteLineBOMSelections_quote_line_id_fkey" FOREIGN KEY ("quote_line_id") REFERENCES "public"."QuoteLines"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "Quotes_created_by_portal_user_id_fkey" FOREIGN KEY ("created_by_portal_user_id") REFERENCES "public"."DealerUsers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "Quotes_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "Quotes_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."SalesOrders"
    ADD CONSTRAINT "SalesOrders_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."SalesOrders"
    ADD CONSTRAINT "SalesOrders_quote_id_fkey" FOREIGN KEY ("quote_id") REFERENCES "public"."Quotes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."BOMComponents"
    ADD CONSTRAINT "bomcomponents_item_fk" FOREIGN KEY ("component_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."BOMComponents"
    ADD CONSTRAINT "bomcomponents_slot_fk" FOREIGN KEY ("slot_id") REFERENCES "public"."BOMTemplateSlots"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."BOMComponents"
    ADD CONSTRAINT "bomcomponents_template_fk" FOREIGN KEY ("bom_template_id") REFERENCES "public"."BOMTemplates"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."BOMTemplates"
    ADD CONSTRAINT "bomtemplates_product_type_fk" FOREIGN KEY ("product_type_id") REFERENCES "public"."ProductTypes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."CatalogCategories"
    ADD CONSTRAINT "catalogcategories_parent_fk" FOREIGN KEY ("parent_id") REFERENCES "public"."CatalogCategories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."CatalogItemComponents"
    ADD CONSTRAINT "catalogitemcomponents_child_fk" FOREIGN KEY ("child_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."CatalogItemComponents"
    ADD CONSTRAINT "catalogitemcomponents_parent_fk" FOREIGN KEY ("parent_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."CatalogItemProductTypes"
    ADD CONSTRAINT "catalogitemproducttypes_catalog_item_fk" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."CatalogItemProductTypes"
    ADD CONSTRAINT "catalogitemproducttypes_product_type_fk" FOREIGN KEY ("product_type_id") REFERENCES "public"."ProductTypes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."CatalogItems"
    ADD CONSTRAINT "catalogitems_item_role_fk" FOREIGN KEY ("item_role") REFERENCES "public"."CatalogItemRoles"("role_code") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."CatalogItems"
    ADD CONSTRAINT "catalogitems_manufacturer_fk" FOREIGN KEY ("manufacturer_id") REFERENCES "public"."Manufacturers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."CatalogItemsMSRP"
    ADD CONSTRAINT "catalogitemsmsrp_catalog_item_id_fkey" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."CatalogItemsMSRP"
    ADD CONSTRAINT "catalogitemsmsrp_org_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id");



ALTER TABLE ONLY "public"."CatalogItemsMSRP"
    ADD CONSTRAINT "catalogitemsmsrp_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Dealers"
    ADD CONSTRAINT "companies_primary_contact_id_fkey" FOREIGN KEY ("primary_contact_id") REFERENCES "public"."DirectoryContacts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ConfiguredProducts"
    ADD CONSTRAINT "configuredproducts_bom_template_fkey" FOREIGN KEY ("bom_template_id") REFERENCES "public"."BOMTemplates"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."ConfiguredProducts"
    ADD CONSTRAINT "configuredproducts_organization_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."ConfiguredProducts"
    ADD CONSTRAINT "configuredproducts_product_type_fkey" FOREIGN KEY ("product_type_id") REFERENCES "public"."ProductTypes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."ConfiguredProducts"
    ADD CONSTRAINT "configuredproducts_quote_fkey" FOREIGN KEY ("quote_id") REFERENCES "public"."Quotes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ConfiguredProducts"
    ADD CONSTRAINT "configuredproducts_roll_item_fkey" FOREIGN KEY ("roll_catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "directorycontacts_dealer_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "directorycustomers_dealer_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ManufacturingOrders"
    ADD CONSTRAINT "fk_manufacturingorders_dealer" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."OrderList"
    ADD CONSTRAINT "fk_orderlist_dealer" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."QuoteLines"
    ADD CONSTRAINT "fk_quote_lines_bom_template" FOREIGN KEY ("bom_template_id") REFERENCES "public"."BOMTemplates"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "fk_quotes_dealer" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."SalesOrders"
    ADD CONSTRAINT "fk_salesorders_dealer" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."QuoteLineComponents"
    ADD CONSTRAINT "qlc_item_fk" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."QuoteLineComponents"
    ADD CONSTRAINT "qlc_quote_line_fk" FOREIGN KEY ("quote_line_id") REFERENCES "public"."QuoteLines"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."QuoteLines"
    ADD CONSTRAINT "quotelines_configured_product_id_fkey" FOREIGN KEY ("configured_product_id") REFERENCES "public"."ConfiguredProducts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."QuoteLines"
    ADD CONSTRAINT "quotelines_quote_fk" FOREIGN KEY ("quote_id") REFERENCES "public"."Quotes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."SaleOrderLines"
    ADD CONSTRAINT "saleorderlines_so_fk" FOREIGN KEY ("sales_order_id") REFERENCES "public"."SalesOrders"("id") ON DELETE CASCADE;



CREATE POLICY "Authenticated users can read permissions" ON "public"."Permissions" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."BOMTemplates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."CatalogItemComponents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."CatalogItemRollSpecs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."CatalogItemSupply" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ConfiguredProducts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."DealerTiers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."DealerUsers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Dealers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."DirectoryContacts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."DirectoryCustomers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ManufacturingOrders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."OrderList" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."OrganizationUserPermissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."OrganizationUsers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Organizations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Owners and admins can manage permissions" ON "public"."OrganizationUserPermissions" USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."id" = "OrganizationUserPermissions"."organization_user_id") AND (EXISTS ( SELECT 1
           FROM "public"."OrganizationUsers" "ou2"
          WHERE (("ou2"."organization_id" = "ou"."organization_id") AND ("ou2"."user_id" = "auth"."uid"()) AND ("ou2"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"])) AND ("ou2"."deleted" = false) AND ("ou2"."status" = 'active'::"public"."org_user_status"))))))));



CREATE POLICY "Owners can insert organizations" ON "public"."Organizations" FOR INSERT WITH CHECK (true);



CREATE POLICY "Owners can update own organizations" ON "public"."Organizations" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."organization_id" = "Organizations"."id") AND ("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."role" = 'owner'::"public"."org_role") AND ("OrganizationUsers"."deleted" = false) AND ("OrganizationUsers"."status" = 'active'::"public"."org_user_status")))));



ALTER TABLE "public"."Permissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ProposalLines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Proposals" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."QuoteLineComponents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."QuoteLines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Quotes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."SalesOrders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Users can insert own organization order list" ON "public"."OrderList" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "OrderList"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))));



CREATE POLICY "Users can insert own organization quotes" ON "public"."Quotes" FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "Quotes"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))) AND ("created_by_user_id" = "auth"."uid"())));



CREATE POLICY "Users can insert own organization sales orders" ON "public"."SalesOrders" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "SalesOrders"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))));



CREATE POLICY "Users can read own organization order list" ON "public"."OrderList" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "OrderList"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))) AND ("deleted" = false)));



CREATE POLICY "Users can read own organization permissions" ON "public"."OrganizationUserPermissions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."id" = "OrganizationUserPermissions"."organization_user_id") AND (EXISTS ( SELECT 1
           FROM "public"."OrganizationUsers" "ou2"
          WHERE (("ou2"."organization_id" = "ou"."organization_id") AND ("ou2"."user_id" = "auth"."uid"()) AND ("ou2"."deleted" = false) AND ("ou2"."status" = 'active'::"public"."org_user_status"))))))));



CREATE POLICY "Users can read own organization quotes" ON "public"."Quotes" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "Quotes"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))) AND ("deleted" = false)));



CREATE POLICY "Users can read own organization sales orders" ON "public"."SalesOrders" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "SalesOrders"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))) AND ("deleted" = false)));



CREATE POLICY "Users can read own organizations" ON "public"."Organizations" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."organization_id" = "Organizations"."id") AND ("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."deleted" = false) AND ("OrganizationUsers"."status" = 'active'::"public"."org_user_status")))));



CREATE POLICY "Users can update own organization order list" ON "public"."OrderList" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "OrderList"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))) AND ("deleted" = false)));



CREATE POLICY "Users can update own organization quotes" ON "public"."Quotes" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "Quotes"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))) AND ("deleted" = false)));



CREATE POLICY "Users can update own organization sales orders" ON "public"."SalesOrders" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "SalesOrders"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))) AND ("deleted" = false)));



CREATE POLICY "catalogitemcomponents_select_own_org" ON "public"."CatalogItemComponents" FOR SELECT TO "authenticated" USING (("public"."is_org_user_superadmin"("organization_id") OR "public"."is_org_user_member"("organization_id")));



CREATE POLICY "catalogitemcomponents_write_own_org" ON "public"."CatalogItemComponents" TO "authenticated" USING (("public"."is_org_user_superadmin"("organization_id") OR "public"."is_org_user_member"("organization_id"))) WITH CHECK (("public"."is_org_user_superadmin"("organization_id") OR "public"."is_org_user_member"("organization_id")));



CREATE POLICY "companyportalusers_select" ON "public"."DealerUsers" FOR SELECT USING ((("deleted" = false) AND ((("user_id" IS NOT NULL) AND ("user_id" = "auth"."uid"())) OR (("user_id" IS NULL) AND ("portal_user_email" IS NOT NULL) AND ("public"."current_auth_email"() IS NOT NULL) AND ("lower"(TRIM(BOTH FROM "portal_user_email")) = "public"."current_auth_email"())) OR (("organization_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "DealerUsers"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = ANY (ARRAY['active'::"public"."org_user_status", 'invited'::"public"."org_user_status"])))))))));



CREATE POLICY "configuredproducts_org_members_insert" ON "public"."ConfiguredProducts" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "ConfiguredProducts"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."deleted" = false)))));



CREATE POLICY "configuredproducts_org_members_select" ON "public"."ConfiguredProducts" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "ConfiguredProducts"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."deleted" = false)))));



CREATE POLICY "configuredproducts_org_members_update" ON "public"."ConfiguredProducts" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "ConfiguredProducts"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."deleted" = false))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "ConfiguredProducts"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."deleted" = false)))));



CREATE POLICY "dealers_insert_own_org" ON "public"."Dealers" FOR INSERT WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "dealers_select_own_org" ON "public"."Dealers" FOR SELECT USING (("public"."is_org_member"("organization_id") AND ("deleted" = false)));



CREATE POLICY "dealers_update_own_org" ON "public"."Dealers" FOR UPDATE USING ("public"."is_org_owner_or_admin"("organization_id")) WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "dealertiers_insert_own_org" ON "public"."DealerTiers" FOR INSERT WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "dealertiers_select_own_org" ON "public"."DealerTiers" FOR SELECT USING ("public"."is_org_member"("organization_id"));



CREATE POLICY "dealertiers_update_own_org" ON "public"."DealerTiers" FOR UPDATE USING ("public"."is_org_owner_or_admin"("organization_id")) WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "dealerusers_insert_own_org" ON "public"."DealerUsers" FOR INSERT WITH CHECK ("public"."is_dealer_owner_or_admin"("dealer_id"));



CREATE POLICY "dealerusers_select_stable" ON "public"."DealerUsers" FOR SELECT USING (((("dealer_id" IS NOT NULL) AND "public"."is_dealer_member"("dealer_id")) OR (("user_id" = "auth"."uid"()) AND ("deleted" = false))));



CREATE POLICY "dealerusers_update_self" ON "public"."DealerUsers" FOR UPDATE USING (((("dealer_id" IS NOT NULL) AND "public"."is_dealer_member"("dealer_id")) OR (("user_id" = "auth"."uid"()) AND ("deleted" = false)))) WITH CHECK (((("dealer_id" IS NOT NULL) AND "public"."is_dealer_member"("dealer_id")) OR (("user_id" = "auth"."uid"()) AND ("deleted" = false))));



CREATE POLICY "delete_catalog_item_roll_specs" ON "public"."CatalogItemRollSpecs" FOR DELETE USING ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "delete_catalog_item_supply" ON "public"."CatalogItemSupply" FOR DELETE USING ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "dir_contacts_write_owner_admin" ON "public"."DirectoryContacts" USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"]))))));



CREATE POLICY "dir_customers_write_owner_admin" ON "public"."DirectoryCustomers" USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"]))))));



CREATE POLICY "dircontacts_select_own_org_or_dealer" ON "public"."DirectoryContacts" FOR SELECT USING ((((("dealer_id" IS NOT NULL) AND "public"."is_dealer_member"("dealer_id")) OR (("organization_id" IS NOT NULL) AND "public"."is_org_member"("organization_id"))) AND ("deleted" = false)));



CREATE POLICY "dircustomers_select_own_org_or_dealer" ON "public"."DirectoryCustomers" FOR SELECT USING ((((("dealer_id" IS NOT NULL) AND "public"."is_dealer_member"("dealer_id")) OR (("organization_id" IS NOT NULL) AND "public"."is_org_member"("organization_id"))) AND ("deleted" = false)));



CREATE POLICY "insert_catalog_item_roll_specs" ON "public"."CatalogItemRollSpecs" FOR INSERT WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "insert_catalog_item_supply" ON "public"."CatalogItemSupply" FOR INSERT WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "mo_select" ON "public"."ManufacturingOrders" FOR SELECT USING ((("deleted" = false) AND (EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status"))))));



CREATE POLICY "mo_write" ON "public"."ManufacturingOrders" USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"]))))));



CREATE POLICY "orderlist_access" ON "public"."OrderList" USING (("organization_id" IN ( SELECT "OrganizationUsers"."organization_id"
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."deleted" = false) AND ("OrganizationUsers"."status" = 'active'::"public"."org_user_status"))))) WITH CHECK (true);



CREATE POLICY "org_admins_update" ON "public"."BOMTemplates" FOR UPDATE USING ("public"."is_org_user_member"("organization_id")) WITH CHECK ("public"."is_org_user_member"("organization_id"));



CREATE POLICY "org_admins_write" ON "public"."BOMTemplates" FOR INSERT WITH CHECK ("public"."is_org_user_member"("organization_id"));



CREATE POLICY "org_member_select" ON "public"."Organizations" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."organization_id" = "OrganizationUsers"."id") AND ("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."deleted" = false) AND ("OrganizationUsers"."status" = 'active'::"public"."org_user_status")))));



CREATE POLICY "org_members_select" ON "public"."BOMTemplates" FOR SELECT USING ("public"."is_org_user_member"("organization_id"));



CREATE POLICY "organizations_select_portal_users" ON "public"."Organizations" FOR SELECT USING ((("deleted" = false) AND (EXISTS ( SELECT 1
   FROM "public"."DealerUsers" "cpu"
  WHERE (("cpu"."organization_id" = "Organizations"."id") AND ("cpu"."deleted" = false) AND ("cpu"."status" = ANY (ARRAY['active'::"public"."portal_user_status", 'invited'::"public"."portal_user_status"])) AND ((("cpu"."user_id" IS NOT NULL) AND ("cpu"."user_id" = "auth"."uid"())) OR (("cpu"."user_id" IS NULL) AND ("cpu"."portal_user_email" IS NOT NULL) AND ("public"."current_auth_email"() IS NOT NULL) AND ("lower"(TRIM(BOTH FROM "cpu"."portal_user_email")) = "public"."current_auth_email"()))))))));



CREATE POLICY "orguserperms_delete_admin" ON "public"."OrganizationUserPermissions" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "target_ou"
  WHERE (("target_ou"."id" = "OrganizationUserPermissions"."organization_user_id") AND ("target_ou"."deleted" = false) AND "public"."is_org_user_superadmin"("target_ou"."organization_id")))));



COMMENT ON POLICY "orguserperms_delete_admin" ON "public"."OrganizationUserPermissions" IS 'Superadmin/Admin can delete permissions for users in their organization. Uses non-recursive helper function.';



CREATE POLICY "orguserperms_insert_admin" ON "public"."OrganizationUserPermissions" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "target_ou"
  WHERE (("target_ou"."id" = "OrganizationUserPermissions"."organization_user_id") AND ("target_ou"."deleted" = false) AND "public"."is_org_user_superadmin"("target_ou"."organization_id")))));



COMMENT ON POLICY "orguserperms_insert_admin" ON "public"."OrganizationUserPermissions" IS 'Superadmin/Admin can insert permissions for users in their organization. Uses non-recursive helper function.';



CREATE POLICY "orguserperms_select_own" ON "public"."OrganizationUserPermissions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."id" = "OrganizationUserPermissions"."organization_user_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))));



COMMENT ON POLICY "orguserperms_select_own" ON "public"."OrganizationUserPermissions" IS 'Users can read their own permissions via organization_user_id. This is safe because OrganizationUsers has non-recursive select policy.';



CREATE POLICY "orguserperms_update_admin" ON "public"."OrganizationUserPermissions" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "target_ou"
  WHERE (("target_ou"."id" = "OrganizationUserPermissions"."organization_user_id") AND ("target_ou"."deleted" = false) AND "public"."is_org_user_superadmin"("target_ou"."organization_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "target_ou"
  WHERE (("target_ou"."id" = "OrganizationUserPermissions"."organization_user_id") AND ("target_ou"."deleted" = false) AND "public"."is_org_user_superadmin"("target_ou"."organization_id")))));



COMMENT ON POLICY "orguserperms_update_admin" ON "public"."OrganizationUserPermissions" IS 'Superadmin/Admin can update permissions for users in their organization. Uses non-recursive helper function.';



CREATE POLICY "orgusers_select_by_org_for_superadmin" ON "public"."OrganizationUsers" FOR SELECT USING ((("deleted" = false) AND ("public"."is_org_user_superadmin"("organization_id") = true)));



CREATE POLICY "orgusers_select_own" ON "public"."OrganizationUsers" FOR SELECT USING ((("user_id" = "auth"."uid"()) AND ("deleted" = false)));



CREATE POLICY "orgusers_select_self" ON "public"."OrganizationUsers" FOR SELECT USING ((("deleted" = false) AND ("user_id" = "auth"."uid"())));



CREATE POLICY "orgusers_update_own" ON "public"."OrganizationUsers" FOR UPDATE USING ((("user_id" = "auth"."uid"()) AND ("deleted" = false))) WITH CHECK ((("user_id" = "auth"."uid"()) AND ("deleted" = false)));



CREATE POLICY "proposal_lines_select" ON "public"."ProposalLines" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "ProposalLines"."organization_id") AND ("ou"."user_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."DealerUsers" "du"
  WHERE (("du"."organization_id" = "ProposalLines"."organization_id") AND ("du"."dealer_id" = "ProposalLines"."dealer_id") AND ("du"."user_id" = "auth"."uid"()))))));



CREATE POLICY "proposal_lines_write" ON "public"."ProposalLines" USING (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "ProposalLines"."organization_id") AND ("ou"."user_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."DealerUsers" "du"
  WHERE (("du"."organization_id" = "ProposalLines"."organization_id") AND ("du"."dealer_id" = "ProposalLines"."dealer_id") AND ("du"."user_id" = "auth"."uid"()) AND ("du"."role" = 'member_manager'::"text")))))) WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "ProposalLines"."organization_id") AND ("ou"."user_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."DealerUsers" "du"
  WHERE (("du"."organization_id" = "ProposalLines"."organization_id") AND ("du"."dealer_id" = "ProposalLines"."dealer_id") AND ("du"."user_id" = "auth"."uid"()) AND ("du"."role" = 'member_manager'::"text"))))));



CREATE POLICY "proposals_select" ON "public"."Proposals" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "Proposals"."organization_id") AND ("ou"."user_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."DealerUsers" "du"
  WHERE (("du"."organization_id" = "Proposals"."organization_id") AND ("du"."dealer_id" = "Proposals"."dealer_id") AND ("du"."user_id" = "auth"."uid"()))))));



CREATE POLICY "proposals_write" ON "public"."Proposals" USING (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "Proposals"."organization_id") AND ("ou"."user_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."DealerUsers" "du"
  WHERE (("du"."organization_id" = "Proposals"."organization_id") AND ("du"."dealer_id" = "Proposals"."dealer_id") AND ("du"."user_id" = "auth"."uid"()) AND ("du"."role" = 'member_manager'::"text")))))) WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "Proposals"."organization_id") AND ("ou"."user_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."DealerUsers" "du"
  WHERE (("du"."organization_id" = "Proposals"."organization_id") AND ("du"."dealer_id" = "Proposals"."dealer_id") AND ("du"."user_id" = "auth"."uid"()) AND ("du"."role" = 'member_manager'::"text"))))));



CREATE POLICY "qlc_delete" ON "public"."QuoteLineComponents" FOR DELETE USING ("public"."is_org_user_member"("organization_id"));



CREATE POLICY "qlc_insert" ON "public"."QuoteLineComponents" FOR INSERT WITH CHECK ("public"."is_org_user_member"("organization_id"));



CREATE POLICY "qlc_select" ON "public"."QuoteLineComponents" FOR SELECT USING ("public"."is_org_user_member"("organization_id"));



CREATE POLICY "qlc_update" ON "public"."QuoteLineComponents" FOR UPDATE USING ("public"."is_org_user_member"("organization_id")) WITH CHECK ("public"."is_org_user_member"("organization_id"));



CREATE POLICY "quotelines_delete" ON "public"."QuoteLines" FOR DELETE USING ("public"."is_org_user_member"("organization_id"));



CREATE POLICY "quotelines_insert" ON "public"."QuoteLines" FOR INSERT WITH CHECK (("public"."is_org_user_member"("organization_id") AND (EXISTS ( SELECT 1
   FROM "public"."Quotes" "q"
  WHERE (("q"."id" = "QuoteLines"."quote_id") AND ("q"."organization_id" = "QuoteLines"."organization_id") AND ("q"."deleted" = false))))));



CREATE POLICY "quotelines_select" ON "public"."QuoteLines" FOR SELECT USING ("public"."is_org_user_member"("organization_id"));



CREATE POLICY "quotelines_update" ON "public"."QuoteLines" FOR UPDATE USING ("public"."is_org_user_member"("organization_id")) WITH CHECK ("public"."is_org_user_member"("organization_id"));



CREATE POLICY "quotes_access" ON "public"."Quotes" USING (("organization_id" IN ( SELECT "OrganizationUsers"."organization_id"
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."deleted" = false) AND ("OrganizationUsers"."status" = 'active'::"public"."org_user_status"))))) WITH CHECK (true);



CREATE POLICY "quotes_insert_org_or_portal" ON "public"."Quotes" FOR INSERT WITH CHECK (((("organization_id" IS NOT NULL) AND "public"."is_org_owner_or_admin"("organization_id")) OR (("dealer_id" IS NOT NULL) AND "public"."is_dealer_portal_user_with_write"("dealer_id"))));



CREATE POLICY "quotes_select" ON "public"."Quotes" FOR SELECT USING ((("deleted" = false) AND (EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status"))))));



CREATE POLICY "quotes_select_org_or_portal" ON "public"."Quotes" FOR SELECT USING (((("organization_id" IS NOT NULL) AND "public"."is_org_member"("organization_id")) OR (("dealer_id" IS NOT NULL) AND "public"."is_dealer_portal_user"("dealer_id"))));



CREATE POLICY "quotes_update_org_or_portal" ON "public"."Quotes" FOR UPDATE USING (((("organization_id" IS NOT NULL) AND "public"."is_org_member"("organization_id")) OR (("dealer_id" IS NOT NULL) AND "public"."is_dealer_portal_user"("dealer_id")))) WITH CHECK (((("organization_id" IS NOT NULL) AND "public"."is_org_member"("organization_id")) OR (("dealer_id" IS NOT NULL) AND "public"."is_dealer_portal_user"("dealer_id"))));



CREATE POLICY "quotes_write" ON "public"."Quotes" USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"]))))));



CREATE POLICY "salesorders_select" ON "public"."SalesOrders" FOR SELECT USING ((("deleted" = false) AND (EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status"))))));



CREATE POLICY "salesorders_write" ON "public"."SalesOrders" USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"]))))));



CREATE POLICY "select_catalog_item_roll_specs" ON "public"."CatalogItemRollSpecs" FOR SELECT USING ("public"."is_org_user_member"("organization_id"));



CREATE POLICY "select_catalog_item_supply" ON "public"."CatalogItemSupply" FOR SELECT USING ("public"."is_org_user_member"("organization_id"));



CREATE POLICY "so_access" ON "public"."SalesOrders" USING (("organization_id" IN ( SELECT "OrganizationUsers"."organization_id"
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."deleted" = false) AND ("OrganizationUsers"."status" = 'active'::"public"."org_user_status"))))) WITH CHECK (true);



CREATE POLICY "update_catalog_item_roll_specs" ON "public"."CatalogItemRollSpecs" FOR UPDATE USING ("public"."is_org_owner_or_admin"("organization_id")) WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "update_catalog_item_supply" ON "public"."CatalogItemSupply" FOR UPDATE USING ("public"."is_org_owner_or_admin"("organization_id")) WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


REVOKE USAGE ON SCHEMA "public" FROM PUBLIC;
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT ALL ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."_trg_categorymargins_recompute_itemsmsrp"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trg_categorymargins_recompute_itemsmsrp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trg_categorymargins_recompute_itemsmsrp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_trg_costsettings_recompute_itemsmsrp"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trg_costsettings_recompute_itemsmsrp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trg_costsettings_recompute_itemsmsrp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_trg_importtaxrules_recompute_itemsmsrp"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trg_importtaxrules_recompute_itemsmsrp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trg_importtaxrules_recompute_itemsmsrp"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."approve_quote"("p_quote_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."approve_quote"("p_quote_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."approve_quote"("p_quote_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."approve_quote"("p_quote_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."build_bom_preview_snapshot"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_bom_template_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."build_bom_preview_snapshot"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_bom_template_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."build_bom_preview_snapshot"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_bom_template_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."build_quote_line_config"("p_org_id" "uuid", "p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."build_quote_line_config"("p_org_id" "uuid", "p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."build_quote_line_config"("p_org_id" "uuid", "p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_bom_price"("p_parent_item_id" "uuid", "p_organization_id" "uuid", "p_width_m" numeric, "p_height_m" numeric, "p_area_sqm" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_bom_price"("p_parent_item_id" "uuid", "p_organization_id" "uuid", "p_width_m" numeric, "p_height_m" numeric, "p_area_sqm" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_bom_price"("p_parent_item_id" "uuid", "p_organization_id" "uuid", "p_width_m" numeric, "p_height_m" numeric, "p_area_sqm" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."catalogitems_set_to_base_factor"() TO "anon";
GRANT ALL ON FUNCTION "public"."catalogitems_set_to_base_factor"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."catalogitems_set_to_base_factor"() TO "service_role";



GRANT ALL ON FUNCTION "public"."catalogitems_sync_roll_dimensions"() TO "anon";
GRANT ALL ON FUNCTION "public"."catalogitems_sync_roll_dimensions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."catalogitems_sync_roll_dimensions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."catalogitemsmsrp_guard_not_null"() TO "anon";
GRANT ALL ON FUNCTION "public"."catalogitemsmsrp_guard_not_null"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."catalogitemsmsrp_guard_not_null"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."clear_my_must_change_password"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."clear_my_must_change_password"() TO "anon";
GRANT ALL ON FUNCTION "public"."clear_my_must_change_password"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."clear_my_must_change_password"() TO "service_role";



GRANT ALL ON FUNCTION "public"."commit_configured_product_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_configured_product_id" "uuid", "p_dealer_id" "uuid", "p_position" "text", "p_area" "text", "p_fabric_drop" "text", "p_installation_type" "text", "p_installation_location" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."commit_configured_product_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_configured_product_id" "uuid", "p_dealer_id" "uuid", "p_position" "text", "p_area" "text", "p_fabric_drop" "text", "p_installation_type" "text", "p_installation_location" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."commit_configured_product_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_configured_product_id" "uuid", "p_dealer_id" "uuid", "p_position" "text", "p_area" "text", "p_fabric_drop" "text", "p_installation_type" "text", "p_installation_location" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_quote_line_cost"("p_quote_line_id" "uuid", "p_options" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."compute_quote_line_cost"("p_quote_line_id" "uuid", "p_options" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_quote_line_cost"("p_quote_line_id" "uuid", "p_options" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_roll_conversions"("p_cost_exw" numeric, "p_uom" "text", "p_roll_width" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_roll_conversions"("p_cost_exw" numeric, "p_uom" "text", "p_roll_width" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_roll_conversions"("p_cost_exw" numeric, "p_uom" "text", "p_roll_width" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."cost_to_per_m"("p_cost" numeric, "p_uom" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."cost_to_per_m"("p_cost" numeric, "p_uom" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cost_to_per_m"("p_cost" numeric, "p_uom" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_quote_line_cost_snapshot"("p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_quote_line_cost_snapshot"("p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_quote_line_cost_snapshot"("p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."current_auth_email"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_auth_email"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_auth_email"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_dealer_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_dealer_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_dealer_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."delete_organization_user"("p_org_user_id" "uuid", "p_organization_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_organization_user"("p_org_user_id" "uuid", "p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_organization_user"("p_org_user_id" "uuid", "p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_organization_user"("p_org_user_id" "uuid", "p_organization_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."directorycontacts_fill_org_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."directorycontacts_fill_org_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."directorycontacts_fill_org_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_active_item_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_active_item_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_active_item_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_mo_dealer_matches_salesorder"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_mo_dealer_matches_salesorder"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_mo_dealer_matches_salesorder"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_orderlist_dealer_matches_salesorder"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_orderlist_dealer_matches_salesorder"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_orderlist_dealer_matches_salesorder"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_salesorders_dealer_matches_quote"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_salesorders_dealer_matches_quote"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_salesorders_dealer_matches_quote"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fill_msrp_item_identity"() TO "anon";
GRANT ALL ON FUNCTION "public"."fill_msrp_item_identity"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fill_msrp_item_identity"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fill_msrp_sku_name"() TO "anon";
GRANT ALL ON FUNCTION "public"."fill_msrp_sku_name"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fill_msrp_sku_name"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_bom_from_slots"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_bom_from_slots"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_bom_from_slots"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_bom_from_slots_for_configured_product"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_bom_from_slots_for_configured_product"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_bom_from_slots_for_configured_product"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_bom_instance_for_quote_line"("p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_bom_instance_for_quote_line"("p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_bom_instance_for_quote_line"("p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_bom_instance_for_quote_line_v1"("p_org_id" "uuid", "p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_bom_instance_for_quote_line_v1"("p_org_id" "uuid", "p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_bom_instance_for_quote_line_v1"("p_org_id" "uuid", "p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_auth_context"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_auth_context"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_auth_context"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_catalog_item_price_for_quote"("p_catalog_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_catalog_item_price_for_quote"("p_catalog_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_catalog_item_price_for_quote"("p_catalog_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_catalog_item_unit_cost_norm"("p_catalog_item_id" "uuid", "p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_catalog_item_unit_cost_norm"("p_catalog_item_id" "uuid", "p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_catalog_item_unit_cost_norm"("p_catalog_item_id" "uuid", "p_organization_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_category_id_by_path"("p_org" "uuid", "p_path" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_category_id_by_path"("p_org" "uuid", "p_path" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_category_id_by_path"("p_org" "uuid", "p_path" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_category_margins_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", OUT "msrp_pct_sale_in" numeric, OUT "msrp_pct_sale_out" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."get_category_margins_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", OUT "msrp_pct_sale_in" numeric, OUT "msrp_pct_sale_out" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_category_margins_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", OUT "msrp_pct_sale_in" numeric, OUT "msrp_pct_sale_out" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_current_portal_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_current_portal_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_current_portal_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_current_portal_user_dealer_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_current_portal_user_dealer_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_current_portal_user_dealer_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_import_tax_pct_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", "p_fallback_pct" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."get_import_tax_pct_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", "p_fallback_pct" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_import_tax_pct_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", "p_fallback_pct" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_must_change_password"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_must_change_password"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_must_change_password"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_portal_access"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_portal_access"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_portal_access"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_parent_sku_selections"("p_org_id" "uuid", "p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_parent_sku_selections"("p_org_id" "uuid", "p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_parent_sku_selections"("p_org_id" "uuid", "p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_quote_line_option_value"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_key" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_quote_line_option_value"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_key" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_quote_line_option_value"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_key" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_roll_unit_price_for_quote"("p_catalog_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_roll_unit_price_for_quote"("p_catalog_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_roll_unit_price_for_quote"("p_catalog_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_auth_user_created_for_org_users"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created_for_org_users"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created_for_org_users"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_auth_user_created_for_portal_users"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created_for_portal_users"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created_for_portal_users"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_quote_approved"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_quote_approved"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_quote_approved"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_dealer_member"("p_dealer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_dealer_member"("p_dealer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_dealer_member"("p_dealer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_dealer_owner_or_admin"("p_dealer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_dealer_owner_or_admin"("p_dealer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_dealer_owner_or_admin"("p_dealer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_dealer_portal_user"("p_dealer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_dealer_portal_user"("p_dealer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_dealer_portal_user"("p_dealer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_dealer_portal_user_with_write"("p_dealer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_dealer_portal_user_with_write"("p_dealer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_dealer_portal_user_with_write"("p_dealer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_org_member"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_org_member"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_org_member"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_org_owner_or_admin"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_org_owner_or_admin"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_org_owner_or_admin"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_org_user_member"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_org_user_member"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_org_user_member"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_org_user_superadmin"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_org_user_superadmin"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_org_user_superadmin"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_pack_uom"("p_uom" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."is_pack_uom"("p_uom" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_pack_uom"("p_uom" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_unit_uom"("p_uom" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."is_unit_uom"("p_uom" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_unit_uom"("p_uom" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."link_my_invites"() TO "anon";
GRANT ALL ON FUNCTION "public"."link_my_invites"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."link_my_invites"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."link_my_org_invites"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."link_my_org_invites"() TO "anon";
GRANT ALL ON FUNCTION "public"."link_my_org_invites"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."link_my_org_invites"() TO "service_role";



GRANT ALL ON FUNCTION "public"."list_matching_bom_templates"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."list_matching_bom_templates"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_matching_bom_templates"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "service_role";



GRANT SELECT ON TABLE "public"."OrganizationUsers" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."OrganizationUsers" TO "authenticated";
GRANT ALL ON TABLE "public"."OrganizationUsers" TO "service_role";



GRANT ALL ON FUNCTION "public"."list_organization_users"("p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."list_organization_users"("p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_organization_users"("p_organization_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."msrp_get_effective_rates"("p_org_id" "uuid", "p_category_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."msrp_get_effective_rates"("p_org_id" "uuid", "p_category_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."msrp_get_effective_rates"("p_org_id" "uuid", "p_category_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."msrp_recompute_for_category"("p_category_id" "uuid", "p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."msrp_recompute_for_category"("p_category_id" "uuid", "p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."msrp_recompute_for_category"("p_category_id" "uuid", "p_organization_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."next_dealer_no"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."next_dealer_no"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."next_dealer_no"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."on_quote_approved_create_sales_order"() TO "anon";
GRANT ALL ON FUNCTION "public"."on_quote_approved_create_sales_order"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."on_quote_approved_create_sales_order"() TO "service_role";



GRANT ALL ON FUNCTION "public"."on_sales_order_status_mirror"() TO "anon";
GRANT ALL ON FUNCTION "public"."on_sales_order_status_mirror"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."on_sales_order_status_mirror"() TO "service_role";



GRANT ALL ON FUNCTION "public"."quote_lines_set_dealer_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."quote_lines_set_dealer_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."quote_lines_set_dealer_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."quote_lines_validate_dealer"() TO "anon";
GRANT ALL ON FUNCTION "public"."quote_lines_validate_dealer"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."quote_lines_validate_dealer"() TO "service_role";



GRANT ALL ON FUNCTION "public"."rebuild_catalogitem_conversions"("p_org" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."rebuild_catalogitem_conversions"("p_org" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rebuild_catalogitem_conversions"("p_org" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" "uuid", "p_category_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" "uuid", "p_category_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" "uuid", "p_category_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_catalog_item_for_bom_component"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_component_role" "text", "p_component_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_catalog_item_for_bom_component"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_component_role" "text", "p_component_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_catalog_item_for_bom_component"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_component_role" "text", "p_component_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_component_item_id"("p_org_id" "uuid", "p_component_role" "text", "p_sku_rule" "text", "p_quote_line_id" "uuid", "p_config" "jsonb", "p_fixed_component_item_id" "uuid", "p_override_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_component_item_id"("p_org_id" "uuid", "p_component_role" "text", "p_sku_rule" "text", "p_quote_line_id" "uuid", "p_config" "jsonb", "p_fixed_component_item_id" "uuid", "p_override_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_component_item_id"("p_org_id" "uuid", "p_component_role" "text", "p_sku_rule" "text", "p_quote_line_id" "uuid", "p_config" "jsonb", "p_fixed_component_item_id" "uuid", "p_override_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_quote_line_product_type_id"("p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_quote_line_product_type_id"("p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_quote_line_product_type_id"("p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."save_quote_line_cost_snapshot"("p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."save_quote_line_cost_snapshot"("p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_quote_line_cost_snapshot"("p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."save_quote_line_prices_snapshot"("p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."save_quote_line_prices_snapshot"("p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_quote_line_prices_snapshot"("p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."select_best_bom_template"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."select_best_bom_template"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_best_bom_template"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_configured_product"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_configured_product"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_configured_product"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_quote_line_match"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_quote_line_match"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_quote_line_match"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."select_best_bom_template_v2"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_v2"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_v2"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."select_best_bom_template_v2_strict"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_v2_strict"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_v2_strict"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."select_exact_bom_template_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."select_exact_bom_template_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_exact_bom_template_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_dealer_no"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_dealer_no"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_dealer_no"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_quote_line_company_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_quote_line_company_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_quote_line_company_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at_product_type_role_rules"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at_product_type_role_rules"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at_product_type_role_rules"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_bom_template_slot_sku"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_bom_template_slot_sku"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_bom_template_slot_sku"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_catalogitem_collection_name_from_roll_collection"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_catalogitem_collection_name_from_roll_collection"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_catalogitem_collection_name_from_roll_collection"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_catalogitems_manufacturer"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_catalogitems_manufacturer"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_catalogitems_manufacturer"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_catalogitems_to_msrp"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_catalogitems_to_msrp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_catalogitems_to_msrp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_catalogitems_to_msrp_safe"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_catalogitems_to_msrp_safe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_catalogitems_to_msrp_safe"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_order_list_tracking_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_order_list_tracking_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_order_list_tracking_status"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_set_dealer_id_from_portal_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_set_dealer_id_from_portal_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_set_dealer_id_from_portal_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_catalog_items_recompute_msrp"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_catalog_items_recompute_msrp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_catalog_items_recompute_msrp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_catalogcategories_insert_category_margin"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_catalogcategories_insert_category_margin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_catalogcategories_insert_category_margin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_catalogitems_validate_roll_pricing_mode"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_catalogitems_validate_roll_pricing_mode"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_catalogitems_validate_roll_pricing_mode"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_catalogitems_write_conversions"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_catalogitems_write_conversions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_catalogitems_write_conversions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_companies_set_company_no"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_companies_set_company_no"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_companies_set_company_no"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trig_catmargins_msrp"() TO "anon";
GRANT ALL ON FUNCTION "public"."trig_catmargins_msrp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trig_catmargins_msrp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trig_enforce_msrp_sources"() TO "anon";
GRANT ALL ON FUNCTION "public"."trig_enforce_msrp_sources"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trig_enforce_msrp_sources"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trig_recompute_msrp_on_category_margin_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."trig_recompute_msrp_on_category_margin_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trig_recompute_msrp_on_category_margin_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trig_recompute_msrp_on_cost_settings_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."trig_recompute_msrp_on_cost_settings_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trig_recompute_msrp_on_cost_settings_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trig_recompute_msrp_on_import_tax_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."trig_recompute_msrp_on_import_tax_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trig_recompute_msrp_on_import_tax_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_quote_line_sort_orders"("p_quote_id" "uuid", "p_updates" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."update_quote_line_sort_orders"("p_quote_id" "uuid", "p_updates" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_quote_line_sort_orders"("p_quote_id" "uuid", "p_updates" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_organization_user"("p_organization_id" "uuid", "p_user_email" "text", "p_role" "public"."org_role", "p_status" "public"."org_user_status", "p_user_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_organization_user"("p_organization_id" "uuid", "p_user_email" "text", "p_role" "public"."org_role", "p_status" "public"."org_user_status", "p_user_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_organization_user"("p_organization_id" "uuid", "p_user_email" "text", "p_role" "public"."org_role", "p_status" "public"."org_user_status", "p_user_name" "text") TO "service_role";


















GRANT SELECT ON TABLE "public"."BOMComponents" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."BOMComponents" TO "authenticated";
GRANT ALL ON TABLE "public"."BOMComponents" TO "service_role";



GRANT SELECT ON TABLE "public"."BOMTemplateSlots" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."BOMTemplateSlots" TO "authenticated";
GRANT ALL ON TABLE "public"."BOMTemplateSlots" TO "service_role";



GRANT SELECT ON TABLE "public"."BOMTemplates" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."BOMTemplates" TO "authenticated";
GRANT ALL ON TABLE "public"."BOMTemplates" TO "service_role";



GRANT SELECT ON TABLE "public"."CatalogCategories" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogCategories" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogCategories" TO "service_role";



GRANT SELECT ON TABLE "public"."CatalogItemComponents" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogItemComponents" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogItemComponents" TO "service_role";



GRANT SELECT ON TABLE "public"."CatalogItemConversions" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogItemConversions" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogItemConversions" TO "service_role";



GRANT SELECT ON TABLE "public"."CatalogItemProductTypes" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogItemProductTypes" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogItemProductTypes" TO "service_role";



GRANT SELECT ON TABLE "public"."CatalogItemRoles" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogItemRoles" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogItemRoles" TO "service_role";



GRANT SELECT ON TABLE "public"."CatalogItemRollSpecs" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogItemRollSpecs" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogItemRollSpecs" TO "service_role";



GRANT SELECT ON TABLE "public"."CatalogItemSupply" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogItemSupply" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogItemSupply" TO "service_role";



GRANT SELECT ON TABLE "public"."CatalogItems" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogItems" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogItems" TO "service_role";



GRANT SELECT ON TABLE "public"."CatalogItemsMSRP" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogItemsMSRP" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogItemsMSRP" TO "service_role";



GRANT SELECT ON TABLE "public"."CatalogRoleCategoryMap" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogRoleCategoryMap" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogRoleCategoryMap" TO "service_role";



GRANT SELECT ON TABLE "public"."CategoryMargins" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CategoryMargins" TO "authenticated";
GRANT ALL ON TABLE "public"."CategoryMargins" TO "service_role";



GRANT SELECT ON TABLE "public"."ConfiguredProducts" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ConfiguredProducts" TO "authenticated";
GRANT ALL ON TABLE "public"."ConfiguredProducts" TO "service_role";



GRANT SELECT ON TABLE "public"."CostSettings" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CostSettings" TO "authenticated";
GRANT ALL ON TABLE "public"."CostSettings" TO "service_role";



GRANT SELECT ON TABLE "public"."DealerTiers" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."DealerTiers" TO "authenticated";
GRANT ALL ON TABLE "public"."DealerTiers" TO "service_role";



GRANT SELECT ON TABLE "public"."DealerUsers" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."DealerUsers" TO "authenticated";
GRANT ALL ON TABLE "public"."DealerUsers" TO "service_role";



GRANT SELECT ON TABLE "public"."Dealers" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."Dealers" TO "authenticated";
GRANT ALL ON TABLE "public"."Dealers" TO "service_role";



GRANT SELECT ON TABLE "public"."DirectoryContacts" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."DirectoryContacts" TO "authenticated";
GRANT ALL ON TABLE "public"."DirectoryContacts" TO "service_role";



GRANT SELECT ON TABLE "public"."DirectoryCustomers" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."DirectoryCustomers" TO "authenticated";
GRANT ALL ON TABLE "public"."DirectoryCustomers" TO "service_role";



GRANT SELECT ON TABLE "public"."ImportTaxRules" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ImportTaxRules" TO "authenticated";
GRANT ALL ON TABLE "public"."ImportTaxRules" TO "service_role";



GRANT SELECT ON TABLE "public"."Manufacturers" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."Manufacturers" TO "authenticated";
GRANT ALL ON TABLE "public"."Manufacturers" TO "service_role";



GRANT SELECT ON TABLE "public"."ManufacturingOrders" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ManufacturingOrders" TO "authenticated";
GRANT ALL ON TABLE "public"."ManufacturingOrders" TO "service_role";



GRANT SELECT ON TABLE "public"."OrderList" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."OrderList" TO "authenticated";
GRANT ALL ON TABLE "public"."OrderList" TO "service_role";



GRANT SELECT ON TABLE "public"."OrganizationUserPermissions" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."OrganizationUserPermissions" TO "authenticated";
GRANT ALL ON TABLE "public"."OrganizationUserPermissions" TO "service_role";



GRANT SELECT ON TABLE "public"."Organizations" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."Organizations" TO "authenticated";
GRANT ALL ON TABLE "public"."Organizations" TO "service_role";



GRANT SELECT ON TABLE "public"."Permissions" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."Permissions" TO "authenticated";
GRANT ALL ON TABLE "public"."Permissions" TO "service_role";



GRANT SELECT ON TABLE "public"."ProductTypeRoleRules" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ProductTypeRoleRules" TO "authenticated";
GRANT ALL ON TABLE "public"."ProductTypeRoleRules" TO "service_role";



GRANT SELECT ON TABLE "public"."ProductTypes" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ProductTypes" TO "authenticated";
GRANT ALL ON TABLE "public"."ProductTypes" TO "service_role";



GRANT SELECT ON TABLE "public"."ProposalLines" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ProposalLines" TO "authenticated";
GRANT ALL ON TABLE "public"."ProposalLines" TO "service_role";



GRANT SELECT ON TABLE "public"."Proposals" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."Proposals" TO "authenticated";
GRANT ALL ON TABLE "public"."Proposals" TO "service_role";



GRANT SELECT ON TABLE "public"."QuoteLineBOMSelections" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."QuoteLineBOMSelections" TO "authenticated";
GRANT ALL ON TABLE "public"."QuoteLineBOMSelections" TO "service_role";



GRANT SELECT ON TABLE "public"."QuoteLineComponents" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."QuoteLineComponents" TO "authenticated";
GRANT ALL ON TABLE "public"."QuoteLineComponents" TO "service_role";



GRANT SELECT ON TABLE "public"."QuoteLineCosts" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."QuoteLineCosts" TO "authenticated";
GRANT ALL ON TABLE "public"."QuoteLineCosts" TO "service_role";



GRANT SELECT ON TABLE "public"."QuoteLines" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."QuoteLines" TO "authenticated";
GRANT ALL ON TABLE "public"."QuoteLines" TO "service_role";



GRANT SELECT ON TABLE "public"."Quotes" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."Quotes" TO "authenticated";
GRANT ALL ON TABLE "public"."Quotes" TO "service_role";



GRANT SELECT ON TABLE "public"."SaleOrderLines" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."SaleOrderLines" TO "authenticated";
GRANT ALL ON TABLE "public"."SaleOrderLines" TO "service_role";



GRANT SELECT ON TABLE "public"."SalesOrders" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."SalesOrders" TO "authenticated";
GRANT ALL ON TABLE "public"."SalesOrders" TO "service_role";



GRANT SELECT ON TABLE "public"."stg_catalog_items_import_raw" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."stg_catalog_items_import_raw" TO "authenticated";
GRANT ALL ON TABLE "public"."stg_catalog_items_import_raw" TO "service_role";



GRANT SELECT,USAGE ON SEQUENCE "public"."stg_catalog_items_import_raw_row_id_seq" TO "anon";
GRANT SELECT,USAGE ON SEQUENCE "public"."stg_catalog_items_import_raw_row_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."stg_catalog_items_import_raw_row_id_seq" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,USAGE ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,USAGE ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";




























