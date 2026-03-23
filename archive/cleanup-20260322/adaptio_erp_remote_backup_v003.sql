


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


CREATE TYPE "public"."proposal_custom_line_category" AS ENUM (
    'installation',
    'transportation',
    'other'
);


ALTER TYPE "public"."proposal_custom_line_category" OWNER TO "postgres";


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


CREATE TYPE "public"."purchase_order_status" AS ENUM (
    'OPEN',
    'PARTIAL',
    'CLOSED'
);


ALTER TYPE "public"."purchase_order_status" OWNER TO "postgres";


CREATE TYPE "public"."purchase_unit_enum" AS ENUM (
    'each',
    'box',
    'pack',
    'set',
    'roll',
    'case',
    'bag',
    'kit',
    'pair'
);


ALTER TYPE "public"."purchase_unit_enum" OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."accept_app_user_invite"("p_token" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_token_hash text;
  v_inv public."AppUserInvites"%rowtype;
  v_existing public."AppUsers"%rowtype;
  v_app_user_id uuid;
begin
  if p_token is null or length(trim(p_token)) < 20 then
    raise exception 'Invalid token';
  end if;

  v_token_hash := encode(digest(p_token, 'sha256'), 'hex');

  select *
    into v_inv
  from public."AppUserInvites"
  where token_hash = v_token_hash
    and revoked_at is null
    and accepted_at is null
    and expires_at > now()
  limit 1;

  if not found then
    raise exception 'Invite not found / expired / already used';
  end if;

  if auth.uid() is null then
    raise exception 'Must be authenticated to accept invite';
  end if;

  select *
    into v_existing
  from public."AppUsers"
  where lower(email) = lower(v_inv.email)
  limit 1;

  if found then
    update public."AppUsers"
    set
      auth_user_id = coalesce(v_existing.auth_user_id, auth.uid()),
      organization_id = v_inv.organization_id,
      user_type = v_inv.user_type,
      dealer_id = case when v_inv.user_type='dealer' then v_inv.dealer_id else null end,
      role_code = v_inv.role_code,
      status = 'active',
      deleted = false,
      updated_at = now()
    where id = v_existing.id
    returning id into v_app_user_id;
  else
    insert into public."AppUsers"(
      organization_id,
      user_type,
      dealer_id,
      auth_user_id,
      email,
      display_name,
      role_code,
      status,
      deleted
    ) values (
      v_inv.organization_id,
      v_inv.user_type,
      case when v_inv.user_type='dealer' then v_inv.dealer_id else null end,
      auth.uid(),
      lower(v_inv.email),
      coalesce(v_inv.display_name, ''),
      v_inv.role_code,
      'active',
      false
    )
    returning id into v_app_user_id;
  end if;

  update public."AppUserInvites"
  set accepted_at = now(), updated_at = now()
  where id = v_inv.id;

  return v_app_user_id;
end;
$$;


ALTER FUNCTION "public"."accept_app_user_invite"("p_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."app_effective_dealer_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT public.current_dealer_id();
$$;


ALTER FUNCTION "public"."app_effective_dealer_id"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."app_effective_dealer_id"() IS 'Delegates to current_dealer_id() — session variable for acting-as dealer.';



CREATE OR REPLACE FUNCTION "public"."apply_audit_if_table_exists"("p_table" "regclass") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  tname text := (select relname from pg_class where oid = p_table);
begin
  execute format('alter table %s add column if not exists created_by_user_id uuid', p_table);
  execute format('alter table %s add column if not exists created_by_email text', p_table);
  execute format('alter table %s add column if not exists created_by_user_name text', p_table);
  execute format('alter table %s add column if not exists created_by_user_type text', p_table);
  execute format('alter table %s add column if not exists created_by_dealer_id uuid', p_table);

  execute format('alter table %s add column if not exists updated_by_user_id uuid', p_table);
  execute format('alter table %s add column if not exists updated_by_email text', p_table);
  execute format('alter table %s add column if not exists updated_by_user_name text', p_table);
  execute format('alter table %s add column if not exists updated_by_user_type text', p_table);
  execute format('alter table %s add column if not exists updated_by_dealer_id uuid', p_table);

  execute format('drop trigger if exists set_audit_fields_trg on %s', p_table);
  execute format('create trigger set_audit_fields_trg before insert or update on %s for each row execute function public.set_audit_fields()', p_table);
end;
$$;


ALTER FUNCTION "public"."apply_audit_if_table_exists"("p_table" "regclass") OWNER TO "postgres";


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



CREATE OR REPLACE FUNCTION "public"."assert_dealer_configurator_policy"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_pt_code text;
  v_allowed text[];
BEGIN
  IF p_dealer_id IS NULL THEN
    RETURN;
  END IF;

  SELECT lower(pt.code)
    INTO v_pt_code
  FROM public."ProductTypes" pt
  WHERE pt.organization_id = p_org_id
    AND pt.id = p_product_type_id;

  IF v_pt_code IS NULL THEN
    RAISE EXCEPTION 'Invalid product_type_id % for org %', p_product_type_id, p_org_id
      USING errcode = '22023';
  END IF;

  SELECT coalesce(p.allowed_product_type_codes, '{}'::text[])
    INTO v_allowed
  FROM public."DealerConfiguratorPolicies" p
  WHERE p.organization_id = p_org_id
    AND p.dealer_id = p_dealer_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF array_length(v_allowed, 1) IS NULL THEN
    RAISE EXCEPTION 'No product types assigned for this dealer'
      USING errcode = '42501';
  END IF;

  IF NOT (v_pt_code = ANY (v_allowed)) THEN
    RAISE EXCEPTION 'Product type "%" is not allowed for this dealer', v_pt_code
      USING errcode = '42501';
  END IF;
END;
$$;


ALTER FUNCTION "public"."assert_dealer_configurator_policy"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."assert_dealer_configurator_policy"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") IS 'Validates dealer configurator policy: product type must be in allowed_product_type_codes. One-Off removed.';



CREATE OR REPLACE FUNCTION "public"."build_bom_preview_snapshot"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_bom_template_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_cp RECORD;
  v_cs RECORD;
  v_config jsonb;
  v_items jsonb := '[]'::jsonb;
  v_totals jsonb;
  v_comp RECORD;
  v_child RECORD;
  v_item_info RECORD;
  v_msrp_info RECORD;
  v_roll_msrp_unit numeric := 0;
  v_roll_dealer_unit numeric := 0;
  v_roll_labor_unit numeric := 0;
  v_qty numeric;
  v_unit_price numeric;
  v_line_total numeric;
  v_width_mm numeric;
  v_height_mm numeric;
  v_width_m numeric;
  v_height_m numeric;
  v_area_m2 numeric;
  v_roll_item jsonb;
  v_children jsonb;
  v_selected boolean;
  v_roll_msrp_total numeric;
  v_bom_sum numeric;
  v_labor_amount numeric;
  v_labor_dealer numeric := 0;
  v_labor_cost numeric := 0;
  v_accessories_total numeric;
  v_total_msrp numeric;
  v_child_unit_price numeric;
  v_child_line_total numeric;
  v_roll_total_cost numeric := 0;
  v_roll_factor numeric := 0;
  v_roll_qty numeric := 0;
  v_roll_width_effective numeric;
  v_width_total_m numeric;
  v_roll_pricing_mode text;
  v_roll_measure_basis text;
  v_bom_total_cost_val numeric := 0;
  v_bom_cost_from_items numeric := 0;
  v_labor_pct numeric := 0;
  v_labor_dealer_pct numeric := 0;
  v_labor_msrp_pct numeric := 0;
  v_msrp_product_subtotal numeric := 0;
  v_base_cost numeric := 0;
  v_roll_uom text := 'm²';
  v_fabric_pricing_basis text := 'auto';
  v_cost_per_unit numeric := 0;
  v_panel_count integer := 1;
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  SELECT cs.labor_pct, cs.labor_dealer_pct, cs.labor_msrp_pct,
         cs.minimum_margin_pct, cs.default_msrp_pct, cs.fabric_pricing_basis
  INTO v_cs
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_org_id AND COALESCE(cs.is_active, true)
  ORDER BY cs.created_at DESC LIMIT 1;

  v_fabric_pricing_basis := COALESCE(v_cs.fabric_pricing_basis, 'auto');
  v_labor_pct := COALESCE(v_cs.labor_pct, 0);
  v_labor_dealer_pct := COALESCE(v_cs.labor_dealer_pct, v_cs.minimum_margin_pct, 0.35);
  v_labor_msrp_pct   := COALESCE(v_cs.labor_msrp_pct, v_cs.labor_pct, 0.05);

  v_config := COALESCE(v_cp.config_snapshot, '{}'::jsonb);

  v_width_mm := COALESCE(
    (v_config->'measurements'->>'width_total_mm')::numeric,
    v_cp.width_mm, 0
  );
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_width_m := v_width_mm / 1000.0;
  v_height_m := v_height_mm / 1000.0;
  v_area_m2 := v_width_m * v_height_m;
  v_width_total_m := v_width_m;

  -- Interconnected panels: each panel needs its own fabric cut
  v_panel_count := GREATEST(
    COALESCE((v_config->'measurements'->>'panel_count')::integer, 0),
    COALESCE(jsonb_array_length(v_config->'measurements'->'panels'), 0),
    COALESCE(jsonb_array_length(v_config->'panels'), 0),
    1
  );

  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT r.msrp, r.dealer_price, r.labor_msrp INTO v_roll_msrp_unit, v_roll_dealer_unit, v_roll_labor_unit
    FROM public.get_roll_pricing(p_org_id, v_cp.roll_catalog_item_id) r;

    SELECT ci.sku, ci.name, ci.unit_of_measure,
           ci.roll_pricing_mode, ci.measure_basis,
           COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_catalog
    INTO v_item_info
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id AND ci.organization_id = p_org_id
    LIMIT 1;

    v_roll_width_effective := COALESCE(v_cp.roll_width, (v_item_info.roll_width_catalog)::numeric, 0);

    IF COALESCE(v_item_info.roll_pricing_mode, '') = 'per_unit' THEN
      v_roll_factor := 1;
    ELSIF COALESCE(v_item_info.roll_pricing_mode, '') = 'per_linear_meter'
       OR COALESCE(v_item_info.measure_basis, '') = 'linear' THEN
      v_roll_factor := v_height_m;
    ELSE
      IF v_roll_width_effective > 0 THEN
        v_roll_factor := v_roll_width_effective * v_height_m;
      ELSE
        v_roll_factor := v_width_total_m * v_height_m;
      END IF;
    END IF;

    -- Interconnected: multiply roll factor by panel count (each panel needs its own fabric)
    v_roll_factor := v_roll_factor * v_panel_count;

    -- UNIT totals: do NOT multiply by v_cp.quantity
    v_roll_qty := GREATEST(v_roll_factor, 0);
    v_qty := v_roll_qty;
    v_unit_price := COALESCE(v_roll_msrp_unit, 0);
    v_line_total := ROUND(v_qty * v_unit_price, 2);

    IF v_fabric_pricing_basis = 'linear' THEN
      v_roll_uom := 'm';
    ELSIF v_fabric_pricing_basis = 'sqm' THEN
      v_roll_uom := 'm²';
    ELSE
      v_roll_uom := public.derive_pricing_uom(
        COALESCE(v_item_info.measure_basis, 'area'),
        COALESCE(v_item_info.roll_pricing_mode, 'per_square_meter'),
        true
      );
      IF v_roll_uom = 'm2' THEN v_roll_uom := 'm²'; END IF;
    END IF;

    SELECT cim.total_cost INTO v_cost_per_unit
    FROM public."CatalogItemsMSRP" cim
    WHERE cim.catalog_item_id = v_cp.roll_catalog_item_id AND cim.organization_id = p_org_id
    ORDER BY cim.updated_at DESC NULLS LAST LIMIT 1;

    -- UNIT: roll cost = cost_per_unit * roll_factor (no product quantity)
    v_roll_total_cost := COALESCE(v_cost_per_unit, 0) * COALESCE(v_roll_qty, 0);

    v_roll_item := jsonb_build_object(
      'id', COALESCE(v_cp.roll_catalog_item_id::text, 'roll:' || COALESCE(v_cp.roll_sku, 'unknown')),
      'kind', 'roll', 'role', 'fabric', 'level', 0, 'selected', true,
      'catalog_item_id', v_cp.roll_catalog_item_id,
      'sku', v_cp.roll_sku,
      'name', COALESCE(v_cp.roll_variant_name, v_item_info.name, v_cp.roll_sku),
      'qty', ROUND(v_qty, 3), 'uom', v_roll_uom,
      'unit_price', v_unit_price, 'line_total', v_line_total,
      'children', '[]'::jsonb,
      'meta', jsonb_build_object(
        'collection_name', v_cp.roll_collection_name,
        'variant_name', v_cp.roll_variant_name,
        'roll_width', v_cp.roll_width,
        'roll_factor', v_roll_factor
      )
    );
    v_items := v_items || v_roll_item;
  ELSE
    v_roll_total_cost := 0;
  END IF;

  IF p_bom_template_id IS NOT NULL THEN
    FOR v_comp IN
      SELECT bc.id, bc.component_role, bc.component_item_id, bc.qty_type, bc.qty_value,
             bc.qty_delta_mm, bc.uom, bc.parent_component_id, bc.sort_order
      FROM public."BOMComponents" bc
      WHERE bc.bom_template_id = p_bom_template_id
        AND bc.organization_id = p_org_id
        AND bc.deleted = false AND bc.archived = false
        AND bc.parent_component_id IS NULL
      ORDER BY bc.sort_order ASC
    LOOP
      v_selected := false;
      DECLARE
        v_role_lower text := lower(COALESCE(v_comp.component_role, ''));
        v_selected_id uuid;
        v_config2 jsonb := COALESCE(v_cp.config_snapshot, '{}'::jsonb);
      BEGIN
        CASE v_role_lower
          WHEN 'bottom_bar'     THEN v_selected_id := public.try_parse_uuid(v_config2->>'bottom_bar_item_id');
          WHEN 'headbox'        THEN v_selected_id := public.try_parse_uuid(v_config2->>'headbox_item_id');
          WHEN 'side_channel'   THEN v_selected_id := public.try_parse_uuid(v_config2->>'side_channel_item_id');
          WHEN 'bottom_channel' THEN v_selected_id := public.try_parse_uuid(v_config2->>'bottom_channel_item_id');
          WHEN 'motor'          THEN v_selected_id := public.try_parse_uuid(v_config2->>'motor_item_id');
          WHEN 'drive'          THEN v_selected_id := public.try_parse_uuid(v_config2->>'drive_item_id');
          WHEN 'tube'           THEN v_selected_id := public.try_parse_uuid(v_config2->>'tube_item_id');
          ELSE v_selected_id := NULL;
        END CASE;
        IF v_selected_id IS NOT NULL THEN
          v_comp.component_item_id := v_selected_id;
          v_selected := true;
        END IF;
      END;

      IF v_comp.component_item_id IS NULL THEN CONTINUE; END IF;

      SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
      FROM public."CatalogItems" ci
      WHERE ci.id = v_comp.component_item_id AND ci.organization_id = p_org_id LIMIT 1;

      SELECT cim.msrp, cim.total_cost INTO v_msrp_info
      FROM public."CatalogItemsMSRP" cim
      WHERE cim.catalog_item_id = v_comp.component_item_id AND cim.organization_id = p_org_id
      ORDER BY cim.updated_at DESC NULLS LAST LIMIT 1;

      v_qty := COALESCE(v_comp.qty_value, 1);
      CASE COALESCE(v_comp.qty_type, 'fixed')
        WHEN 'per_width', 'width' THEN v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_height', 'height' THEN v_qty := GREATEST(0, (v_height_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_m2', 'area' THEN v_qty := GREATEST(0, v_area_m2);
        ELSE v_qty := COALESCE(v_comp.qty_value, 1);
      END CASE;

      v_unit_price := COALESCE(v_msrp_info.msrp, 0);
      v_line_total := ROUND(v_qty * v_unit_price, 2);
      v_bom_cost_from_items := v_bom_cost_from_items + (v_qty * COALESCE(v_msrp_info.total_cost, 0));

      -- FIX: save parent item info BEFORE children loop overwrites v_item_info
      DECLARE
        v_parent_sku text := v_item_info.sku;
        v_parent_name text := v_item_info.name;
        v_parent_uom text := v_item_info.unit_of_measure;
      BEGIN

      v_children := '[]'::jsonb;
      FOR v_child IN
        SELECT bc.id, bc.component_role, bc.component_item_id, bc.qty_type, bc.qty_value, bc.qty_delta_mm, bc.uom
        FROM public."BOMComponents" bc
        WHERE bc.parent_component_id = v_comp.id
          AND bc.organization_id = p_org_id AND bc.deleted = false AND bc.archived = false
        ORDER BY bc.sort_order ASC
      LOOP
        IF v_child.component_item_id IS NULL THEN CONTINUE; END IF;

        SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
        FROM public."CatalogItems" ci
        WHERE ci.id = v_child.component_item_id AND ci.organization_id = p_org_id LIMIT 1;

        SELECT cim.msrp, cim.total_cost INTO v_msrp_info
        FROM public."CatalogItemsMSRP" cim
        WHERE cim.catalog_item_id = v_child.component_item_id AND cim.organization_id = p_org_id
        ORDER BY cim.updated_at DESC NULLS LAST LIMIT 1;

        DECLARE
          v_child_qty numeric;
          v_child_line_total numeric;
        BEGIN
          v_child_qty := COALESCE(v_child.qty_value, 1);
          CASE COALESCE(v_child.qty_type, 'fixed')
            WHEN 'per_width', 'width' THEN v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
            WHEN 'per_height', 'height' THEN v_child_qty := GREATEST(0, (v_height_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
            WHEN 'per_m2', 'area' THEN v_child_qty := GREATEST(0, v_area_m2);
            ELSE v_child_qty := COALESCE(v_child.qty_value, 1);
          END CASE;
          v_child_unit_price := COALESCE(v_msrp_info.msrp, 0);
          v_child_line_total := ROUND(v_child_qty * v_child_unit_price, 2);
          v_bom_cost_from_items := v_bom_cost_from_items + (v_child_qty * COALESCE(v_msrp_info.total_cost, 0));
          v_children := v_children || jsonb_build_object(
            'id', v_child.id::text, 'kind', 'child', 'role', COALESCE(v_child.component_role, 'child'),
            'level', 1, 'selected', false, 'catalog_item_id', v_child.component_item_id,
            'sku', v_item_info.sku, 'name', v_item_info.name,
            'qty', ROUND(v_child_qty, 3),
            'uom', COALESCE(v_child.uom, v_item_info.unit_of_measure, 'ea'),
            'unit_price', v_child_unit_price, 'line_total', v_child_line_total,
            'children', '[]'::jsonb, 'meta', '{}'::jsonb
          );
        END;
      END LOOP;

      -- Use saved parent info (not v_item_info which was overwritten by last child)
      v_items := v_items || jsonb_build_object(
        'id', v_comp.id::text, 'kind', 'parent', 'role', COALESCE(v_comp.component_role, 'component'),
        'level', 0, 'selected', v_selected, 'catalog_item_id', v_comp.component_item_id,
        'sku', v_parent_sku, 'name', v_parent_name,
        'qty', ROUND(v_qty, 3),
        'uom', COALESCE(v_comp.uom, v_parent_uom, 'ea'),
        'unit_price', v_unit_price, 'line_total', v_line_total,
        'children', v_children, 'meta', '{}'::jsonb
      );
      END;
    END LOOP;
  END IF;

  SELECT * INTO v_cp FROM public."ConfiguredProducts" WHERE id = p_configured_product_id AND organization_id = p_org_id;

  SELECT COALESCE(SUM((item->>'line_total')::numeric), 0) INTO v_roll_msrp_total
  FROM jsonb_array_elements(v_items) AS item WHERE item->>'kind' = 'roll';
  IF v_roll_msrp_total = 0 THEN v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0); END IF;

  SELECT COALESCE(SUM(
    (item->>'line_total')::numeric +
    COALESCE((SELECT SUM((c->>'line_total')::numeric) FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c), 0)
  ), 0) INTO v_bom_sum
  FROM jsonb_array_elements(v_items) AS item WHERE item->>'kind' = 'parent';
  IF v_bom_sum = 0 THEN v_bom_sum := COALESCE(v_cp.bom_total, 0); END IF;

  v_accessories_total := COALESCE(v_cp.accessories_total, 0);
  v_msrp_product_subtotal := v_roll_msrp_total + v_bom_sum + v_accessories_total;

  v_bom_total_cost_val := CASE
    WHEN v_bom_cost_from_items > 0 THEN ROUND(v_bom_cost_from_items, 4)
    ELSE COALESCE(v_cp.bom_total_cost, 0)
  END;
  v_base_cost := v_roll_total_cost + v_bom_total_cost_val + COALESCE(v_cp.accessories_total_cost, 0);
  v_labor_cost := ROUND(v_base_cost * CASE WHEN v_labor_pct <= 1 THEN v_labor_pct ELSE (v_labor_pct / 100.0) END, 4);

  v_labor_amount := ROUND(
    v_msrp_product_subtotal
    * CASE WHEN v_labor_msrp_pct <= 1 THEN v_labor_msrp_pct ELSE (v_labor_msrp_pct / 100.0) END,
    4
  );
  v_labor_dealer := ROUND(v_labor_cost / GREATEST(0.01, 1 - (CASE WHEN v_labor_dealer_pct <= 1 THEN v_labor_dealer_pct ELSE (v_labor_dealer_pct / 100.0) END)), 4);

  v_total_msrp := v_msrp_product_subtotal + v_labor_amount;

  -- All totals are UNIT (no product quantity multiplication)
  v_totals := jsonb_build_object(
    'roll_qty', v_roll_qty,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_sum,
    'accessories_total', v_accessories_total,
    'labor_pct', CASE WHEN v_labor_pct <= 1 THEN v_labor_pct * 100 ELSE v_labor_pct END,
    'labor_dealer_pct', CASE WHEN v_labor_dealer_pct <= 1 THEN v_labor_dealer_pct * 100 ELSE v_labor_dealer_pct END,
    'labor_msrp_pct', CASE WHEN v_labor_msrp_pct <= 1 THEN v_labor_msrp_pct * 100 ELSE v_labor_msrp_pct END,
    'labor_amount', v_labor_amount,
    'labor_msrp_total', v_labor_amount,
    'labor_cost', v_labor_cost,
    'labor_dealer_total', v_labor_dealer,
    'roll_total_cost', v_roll_total_cost,
    'bom_total_cost', v_bom_total_cost_val,
    'accessories_total_cost', COALESCE(v_cp.accessories_total_cost, 0),
    'total_cost', v_base_cost + v_labor_cost,
    'msrp_product_subtotal', v_msrp_product_subtotal,
    'unit_dealer_price', 0,
    'dealer_price_total', 0
  );

  RETURN jsonb_build_object('version', '1', 'product_type_id', v_cp.product_type_id, 'bom_template_id', p_bom_template_id,
    'price_basis', 'msrp', 'currency', 'USD', 'totals', v_totals, 'items', v_items);
END;
$$;


ALTER FUNCTION "public"."build_bom_preview_snapshot"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_bom_template_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."build_bom_preview_snapshot"("p_org_id" "uuid", "p_configured_product_id" "uuid", "p_bom_template_id" "uuid") IS 'BOM preview JSONB. Totals are UNIT (no product quantity). Uses labor_pct only.';



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
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_cp RECORD;
  v_cs RECORD;
  v_snapshot jsonb;
  v_totals jsonb;
  v_qty numeric := 1;

  v_roll_msrp_total numeric := 0;
  v_bom_total numeric := 0;
  v_accessories_total numeric := 0;
  v_msrp_product_subtotal numeric := 0;
  v_unit_msrp_total numeric := 0;
  v_labor_msrp numeric := 0;

  v_roll_cost numeric := 0;
  v_bom_cost numeric := 0;
  v_accessories_cost numeric := 0;
  v_materials_cost numeric := 0;
  v_labor_cost numeric := 0;
  v_total_cost numeric := 0;

  v_labor_pct numeric := 0;
  v_minimum_margin_pct numeric := 0.35;
  v_msrp_margin_pct numeric := 0.65;
  v_dealer_factor numeric := 0.65;
  v_msrp_factor numeric := 0.35;

  v_unit_dealer_price numeric := 0;
  v_dealer_price_total_unit numeric := 0;
  v_msrp_total numeric := 0;
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_totals := COALESCE(v_snapshot->'totals', '{}'::jsonb);

  -- Rebuild snapshot when cost data missing AND has bom_template_id
  IF ((v_totals->>'roll_total_cost') IS NULL OR (v_totals->>'bom_total_cost') IS NULL)
     AND v_cp.bom_template_id IS NOT NULL THEN
    v_snapshot := public.build_bom_preview_snapshot(
      v_cp.organization_id, v_cp.id, v_cp.bom_template_id
    );
    v_totals := COALESCE(v_snapshot->'totals', '{}'::jsonb);
  END IF;

  SELECT
    cs.labor_pct,
    cs.minimum_margin_pct,
    cs.default_msrp_pct
  INTO v_cs
  FROM public."CostSettings" cs
  WHERE cs.organization_id = v_cp.organization_id
    AND COALESCE(cs.is_active, true)
  ORDER BY cs.created_at DESC
  LIMIT 1;

  v_qty := GREATEST(COALESCE(v_cp.quantity, 1), 1);

  -- MSRP subtotals (snapshot totals are already UNIT)
  v_roll_msrp_total := COALESCE((v_totals->>'roll_msrp_total')::numeric, v_cp.roll_msrp_total, 0);
  v_bom_total := COALESCE((v_totals->>'bom_total')::numeric, v_cp.bom_total, 0);
  v_accessories_total := COALESCE((v_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);

  -- Cost subtotals (snapshot totals are already UNIT)
  v_roll_cost := COALESCE((v_totals->>'roll_total_cost')::numeric, v_cp.roll_total_cost, 0);
  v_bom_cost := COALESCE((v_totals->>'bom_total_cost')::numeric, v_cp.bom_total_cost, 0);
  v_accessories_cost := COALESCE((v_totals->>'accessories_total_cost')::numeric, v_cp.accessories_total_cost, 0);

  -- Defensive: legacy snapshot may have multiplied roll by qty; normalize
  IF v_qty > 1 AND (v_roll_cost > 0 OR v_roll_msrp_total > 0) THEN
    IF (v_totals->>'legacy_qty_multiplied') = 'true' THEN
      v_roll_cost := v_roll_cost / v_qty;
      v_roll_msrp_total := v_roll_msrp_total / v_qty;
    END IF;
  END IF;

  v_msrp_product_subtotal := v_roll_msrp_total + v_bom_total + v_accessories_total;

  v_labor_pct := COALESCE(v_cs.labor_pct, v_cp.labor_pct, (v_totals->>'labor_pct')::numeric, 0);
  IF v_labor_pct > 1 THEN
    v_labor_pct := v_labor_pct / 100.0;
  END IF;
  v_labor_pct := GREATEST(0, v_labor_pct);

  v_minimum_margin_pct := COALESCE(v_cs.minimum_margin_pct, (v_totals->>'minimum_margin_pct')::numeric, 0.35);
  IF v_minimum_margin_pct > 1 THEN
    v_minimum_margin_pct := v_minimum_margin_pct / 100.0;
  END IF;
  v_minimum_margin_pct := LEAST(GREATEST(v_minimum_margin_pct, 0), 0.99);

  v_msrp_margin_pct := COALESCE(v_cs.default_msrp_pct, (v_totals->>'msrp_margin_pct')::numeric, (v_totals->>'default_msrp_pct')::numeric, 0.65);
  IF v_msrp_margin_pct > 1 THEN
    v_msrp_margin_pct := v_msrp_margin_pct / 100.0;
  END IF;
  v_msrp_margin_pct := LEAST(GREATEST(v_msrp_margin_pct, 0), 0.99);

  v_dealer_factor := GREATEST(0.01, 1 - v_minimum_margin_pct);
  v_msrp_factor := GREATEST(0.01, 1 - v_msrp_margin_pct);

  -- Cost -> Dealer -> MSRP (all UNIT)
  v_materials_cost := ROUND(v_roll_cost + v_bom_cost + v_accessories_cost, 4);
  v_labor_cost := ROUND(v_materials_cost * v_labor_pct, 4);
  v_total_cost := ROUND(v_materials_cost + v_labor_cost, 4);

  v_unit_dealer_price := ROUND(v_total_cost / v_dealer_factor, 4);
  v_unit_msrp_total := ROUND(v_unit_dealer_price / v_msrp_factor, 4);
  v_dealer_price_total_unit := v_unit_dealer_price;
  v_msrp_total := ROUND(v_unit_msrp_total * v_qty, 4);

  v_labor_msrp := ROUND(GREATEST(0, v_unit_msrp_total - v_msrp_product_subtotal), 4);

  -- Update snapshot totals with unit_dealer_price and dealer_price_total (UNIT)
  v_totals := jsonb_set(v_totals, '{unit_dealer_price}', to_jsonb(v_unit_dealer_price), true);
  v_totals := jsonb_set(v_totals, '{dealer_price_total}', to_jsonb(v_dealer_price_total_unit), true);

  v_snapshot := jsonb_set(COALESCE(v_snapshot, '{}'::jsonb), '{totals}', v_totals, true);

  UPDATE public."ConfiguredProducts"
  SET
    roll_msrp_total = v_roll_msrp_total,
    bom_total = v_bom_total,
    accessories_total = v_accessories_total,
    msrp_product_subtotal = v_msrp_product_subtotal,
    labor_amount = v_labor_msrp,
    labor_msrp = v_labor_msrp,
    total_msrp = v_unit_msrp_total,
    unit_msrp_total = v_unit_msrp_total,
    roll_total_cost = v_roll_cost,
    bom_total_cost = v_bom_cost,
    accessories_total_cost = v_accessories_cost,
    unit_product_cost = v_materials_cost,
    unit_labor_cost = v_labor_cost,
    total_cost = v_total_cost,
    labor_pct = v_labor_pct,
    bom_preview_snapshot = v_snapshot,
    updated_at = now()
  WHERE id = p_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id', p_configured_product_id,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_total,
    'accessories_total', v_accessories_total,
    'msrp_product_subtotal', v_msrp_product_subtotal,
    'labor_msrp', v_labor_msrp,
    'unit_msrp_total', v_unit_msrp_total,
    'total_msrp', v_unit_msrp_total,
    'msrp_total', v_msrp_total,
    'unit_dealer_price', v_unit_dealer_price,
    'dealer_price_total', v_dealer_price_total_unit,
    'roll_cost', v_roll_cost,
    'bom_cost', v_bom_cost,
    'materials_cost', v_materials_cost,
    'labor_cost', v_labor_cost,
    'total_cost', v_total_cost,
    'labor_pct', v_labor_pct,
    'minimum_margin_pct', v_minimum_margin_pct,
    'msrp_margin_pct', v_msrp_margin_pct
  );
END;
$$;


ALTER FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") IS 'Pricing ladder: COST -> DEALER -> MSRP. Rebuilds snapshot when cost data missing. All values UNIT.';



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


CREATE OR REPLACE FUNCTION "public"."clear_effective_dealer_id"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_org_id uuid;
BEGIN
  SELECT organization_id INTO v_org_id
  FROM public."OrganizationUsers"
  WHERE user_id = auth.uid()
    AND (deleted IS NULL OR deleted = false)
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'User is not a member of any organization';
  END IF;

  INSERT INTO public.user_dealer_scope (user_id, organization_id, effective_dealer_id, updated_at)
  VALUES (auth.uid(), v_org_id, NULL, now())
  ON CONFLICT (user_id) DO UPDATE
    SET effective_dealer_id = NULL,
        organization_id    = EXCLUDED.organization_id,
        updated_at         = now();
END;
$$;


ALTER FUNCTION "public"."clear_effective_dealer_id"() OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."commit_accessories_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_accessories" "jsonb", "p_area" "text" DEFAULT NULL::"text", "p_position" "text" DEFAULT NULL::"text") RETURNS TABLE("quote_line_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_quote_line_id     uuid;
  v_dealer_id         uuid;
  v_dealer_tier_id    uuid;
  v_discount_pct      numeric(5,2);
  -- Totales acumulados
  v_total_msrp        numeric(12,4) := 0;
  v_total_cost        numeric(12,4) := 0;
  -- Por ítem
  v_item              RECORD;
  v_msrp_row          RECORD;
  v_item_msrp         numeric(12,4);
  v_item_cost         numeric(12,4);
  v_qty               int;
  -- Sale-In
  v_unit_sale_in      numeric(12,4);
BEGIN
  IF p_org_id IS NULL THEN
    RAISE EXCEPTION 'commit_accessories_to_quote_line: p_org_id is required';
  END IF;
  IF p_quote_id IS NULL THEN
    RAISE EXCEPTION 'commit_accessories_to_quote_line: p_quote_id is required';
  END IF;
  IF p_accessories IS NULL OR jsonb_array_length(p_accessories) = 0 THEN
    RAISE EXCEPTION 'commit_accessories_to_quote_line: p_accessories must be a non-empty array';
  END IF;

  -- 1. Dealer del Quote
  SELECT dealer_id INTO v_dealer_id
  FROM public."Quotes"
  WHERE id = p_quote_id
  LIMIT 1;

  -- 2. Tier del dealer → discount_pct (Bronze 35% por defecto)
  SELECT d.dealer_tier_id INTO v_dealer_tier_id
  FROM public."Dealers" d
  WHERE d.id = v_dealer_id
  LIMIT 1;

  SELECT COALESCE(dt.discount_pct, 35)
  INTO v_discount_pct
  FROM public."DealerTiers" dt
  WHERE dt.id = v_dealer_tier_id
  LIMIT 1;

  IF v_discount_pct IS NULL THEN
    v_discount_pct := 35;
  END IF;

  -- 3. Sumar MSRP y costo de cada accesorio desde CatalogItemsMSRP
  FOR v_item IN
    SELECT
      (elem->>'catalog_item_id')::uuid AS catalog_item_id,
      GREATEST(1, (elem->>'qty')::int) AS qty
    FROM jsonb_array_elements(p_accessories) AS elem
  LOOP
    -- Leer msrp y total_cost desde CatalogItemsMSRP
    SELECT cm.msrp, cm.total_cost
    INTO v_msrp_row
    FROM public."CatalogItemsMSRP" cm
    WHERE cm.catalog_item_id = v_item.catalog_item_id
      AND cm.organization_id = p_org_id
    LIMIT 1;

    IF v_msrp_row IS NULL THEN
      -- Fallback: leer cost_exw desde CatalogItems si no hay fila en CatalogItemsMSRP
      SELECT
        COALESCE(ci.cost_exw * 1.5, 0),   -- MSRP estimado (sin margen en BD)
        COALESCE(ci.cost_exw, 0)           -- costo EXW
      INTO v_item_msrp, v_item_cost
      FROM public."CatalogItems" ci
      WHERE ci.id = v_item.catalog_item_id
      LIMIT 1;
    ELSE
      v_item_msrp := COALESCE(v_msrp_row.msrp, 0);
      v_item_cost := COALESCE(v_msrp_row.total_cost, 0);
    END IF;

    v_total_msrp := v_total_msrp + (v_item_msrp * v_item.qty);
    v_total_cost := v_total_cost + (v_item_cost * v_item.qty);
  END LOOP;

  -- 4. Sale-In: MSRP × (1 - tier_discount)
  --    quantity = 1 en líneas de solo-accesorios → unit = total
  v_unit_sale_in := ROUND(v_total_msrp * (1 - v_discount_pct / 100.0), 4);

  -- 5. Insertar QuoteLine con snapshots canónicos
  PERFORM set_config('app.write_source', 'rpc', true);

  INSERT INTO public."QuoteLines" (
    organization_id,
    quote_id,
    dealer_id,
    product_type,
    configured_product_id,
    name,
    quantity,
    area,
    position,
    -- Snapshots canónicos
    unit_msrp_total_snapshot,
    unit_cost_total_snapshot,
    msrp,
    total_cost,
    -- Sale-In snapshots
    unit_sale_in_price_snapshot,
    sale_in_total,
    sale_in_discount_pct,
    -- Auditoría
    pricing_locked,
    last_priced_at,
    pricing_version
  )
  VALUES (
    p_org_id,
    p_quote_id,
    v_dealer_id,
    'accessories',
    NULL,
    'Accessories',
    1,                          -- quantity = 1 (la cantidad de cada ítem va en QuoteLineComponents)
    p_area,
    p_position,
    -- unit_* = total porque qty = 1
    ROUND(v_total_msrp, 4),
    ROUND(v_total_cost, 4),
    ROUND(v_total_msrp, 2),
    ROUND(v_total_cost, 2),
    -- Sale-In
    v_unit_sale_in,
    ROUND(v_unit_sale_in, 2),  -- sale_in_total = unit_sale_in × 1
    v_discount_pct,
    -- Auditoría
    false,
    now(),
    1
  )
  RETURNING id INTO v_quote_line_id;

  RETURN QUERY SELECT v_quote_line_id;
END;
$$;


ALTER FUNCTION "public"."commit_accessories_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_accessories" "jsonb", "p_area" "text", "p_position" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."commit_accessories_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_accessories" "jsonb", "p_area" "text", "p_position" "text") IS 'Creates a QuoteLine for accessories-only lines.
Reads MSRP and cost from CatalogItemsMSRP (no BOM, no fabric).
Applies dealer tier discount to compute sale_in snapshots.
Follows the same canonical write-path as commit_configured_product_to_quote_line.
p_accessories: [{catalog_item_id: uuid, qty: int}]';



CREATE OR REPLACE FUNCTION "public"."commit_configured_product_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_configured_product_id" "uuid", "p_dealer_id" "uuid" DEFAULT NULL::"uuid", "p_position" "text" DEFAULT NULL::"text", "p_area" "text" DEFAULT NULL::"text", "p_fabric_drop" "text" DEFAULT NULL::"text", "p_installation_type" "text" DEFAULT NULL::"text", "p_installation_location" "text" DEFAULT NULL::"text") RETURNS TABLE("quote_line_id" "uuid", "bom_instance_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_cp RECORD;
  v_roll_item RECORD;
  v_quote_line_id uuid;
  v_bom_instance_id uuid;
  v_width_m numeric(12,4);
  v_height_m numeric(12,4);
  v_line_quantity numeric(12,4);
  v_operating_type text;
  v_product_type_code text;
  v_effective_dealer_id uuid;
  v_dealer_tier_id uuid;
  v_dealer_tier_code text;
  v_unit_dealer numeric(12,4);
  v_totals jsonb;
  v_installation_type text;
  v_installation_location text;
BEGIN
  IF p_org_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_org_id is required'; END IF;
  IF p_quote_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_quote_id is required'; END IF;
  IF p_configured_product_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_configured_product_id is required'; END IF;

  PERFORM public.calculate_configured_product_totals(p_configured_product_id);

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found or does not belong to org %', p_configured_product_id, p_org_id;
  END IF;

  v_totals := COALESCE(v_cp.bom_preview_snapshot->'totals', '{}'::jsonb);
  v_line_quantity := GREATEST(COALESCE(v_cp.quantity, 1), 1);
  v_width_m := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m := COALESCE(v_cp.height_mm / 1000.0, 0);
  v_operating_type := COALESCE(
    v_cp.config_snapshot->>'operating_type',
    v_cp.config_snapshot->>'drive_type',
    v_cp.config_snapshot->>'operation_type'
  );
  v_installation_type := COALESCE(p_installation_type, v_cp.config_snapshot->>'installationType');
  v_installation_location := COALESCE(p_installation_location, v_cp.config_snapshot->>'installationLocation');

  -- unit_dealer_price from snapshot; fallback to total_cost/(1-min_margin) if missing
  v_unit_dealer := COALESCE(
    nullif((v_totals->>'unit_dealer_price')::numeric, 0),
    CASE
      WHEN (1 - COALESCE((SELECT cs.minimum_margin_pct FROM public."CostSettings" cs
            WHERE cs.organization_id = v_cp.organization_id AND COALESCE(cs.is_active, true)
            ORDER BY cs.created_at DESC LIMIT 1), 0.35)) > 0.01
      THEN v_cp.total_cost / (1 - COALESCE((SELECT cs.minimum_margin_pct FROM public."CostSettings" cs
            WHERE cs.organization_id = v_cp.organization_id AND COALESCE(cs.is_active, true)
            ORDER BY cs.created_at DESC LIMIT 1), 0.35))
      ELSE 0
    END
  );

  v_effective_dealer_id := COALESCE(
    p_dealer_id,
    (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)
  );

  SELECT d.dealer_tier_id, dt.code
  INTO v_dealer_tier_id, v_dealer_tier_code
  FROM public."Dealers" d
  LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
  WHERE d.id = v_effective_dealer_id
  LIMIT 1;

  SELECT pt.code INTO v_product_type_code
  FROM public."ProductTypes" pt
  WHERE pt.id = v_cp.product_type_id LIMIT 1;

  SELECT ci.sku, ci.name, ci.category_id, ci.manufacturer_id, m.name AS manufacturer_name,
         ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_m
  INTO v_roll_item
  FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id AND ci.is_active = true
  LIMIT 1;

  PERFORM set_config('app.write_source', 'rpc', true);

  -- COPY ONLY: all values from ConfiguredProducts; multiply by qty for line totals
  INSERT INTO public."QuoteLines" (
    organization_id, quote_id, dealer_id,
    configured_product_id, bom_template_id,
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer,
    collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity,
    hardware_color, drive_type, position, area, fabric_drop,
    installation_type, installation_location,
    roll_msrp_snapshot, bom_msrp_snapshot, labor_msrp_snapshot,
    roll_cost_snapshot, bom_cost_snapshot, labor_cost_snapshot,
    unit_msrp_total_snapshot, unit_cost_total_snapshot,
    unit_dealer_price_snapshot,
    msrp, total_cost, dealer_price_total,
    dealer_discount_pct, dealer_tier_id_snapshot, dealer_tier_code_snapshot,
    catalog_dealer_unit_snapshot, dealer_price_source,
    pricing_locked, last_priced_at, pricing_version,
    product_type, product_type_id
  )
  VALUES (
    p_org_id, p_quote_id, v_effective_dealer_id,
    v_cp.id, v_cp.bom_template_id,
    v_cp.roll_catalog_item_id,
    COALESCE(v_cp.roll_sku, v_roll_item.sku), v_roll_item.name,
    v_roll_item.category_id, v_roll_item.manufacturer_id, v_roll_item.manufacturer_name,
    COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name),
    COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name),
    v_cp.roll_catalog_item_id IS NOT NULL,
    CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END,
    COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    v_width_m, v_height_m, v_line_quantity,
    v_cp.hardware_color, v_operating_type, p_position, p_area,
    COALESCE(p_fabric_drop, v_cp.config_snapshot->>'fabricDrop', v_cp.config_snapshot->>'drop_type'),
    v_installation_type, v_installation_location,
    COALESCE(v_cp.roll_msrp_total, 0), COALESCE(v_cp.bom_total, 0), COALESCE(v_cp.labor_amount, 0),
    COALESCE((v_totals->>'roll_total_cost')::numeric, v_cp.roll_total_cost, 0),
    COALESCE((v_totals->>'bom_total_cost')::numeric, v_cp.bom_total_cost, 0),
    COALESCE(v_cp.unit_labor_cost, 0),
    COALESCE(v_cp.total_msrp, 0),
    COALESCE(v_cp.total_cost, 0),
    v_unit_dealer,
    ROUND(COALESCE(v_cp.total_msrp, 0) * v_line_quantity, 2),
    ROUND(COALESCE(v_cp.total_cost, 0) * v_line_quantity, 2),
    ROUND(v_unit_dealer * v_line_quantity, 2),
    COALESCE((SELECT COALESCE(dt.discount_pct, 35) FROM public."Dealers" d
      LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id WHERE d.id = v_effective_dealer_id LIMIT 1), 35),
    v_dealer_tier_id, v_dealer_tier_code,
    (SELECT cim.dealer_price FROM public."CatalogItemsMSRP" cim
      WHERE cim.organization_id = p_org_id AND cim.catalog_item_id = v_cp.roll_catalog_item_id
      ORDER BY cim.updated_at DESC NULLS LAST LIMIT 1),
    'tier',
    true, now(), 1,
    v_product_type_code, v_cp.product_type_id
  )
  RETURNING id INTO v_quote_line_id;

  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;


ALTER FUNCTION "public"."commit_configured_product_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_configured_product_id" "uuid", "p_dealer_id" "uuid", "p_position" "text", "p_area" "text", "p_fabric_drop" "text", "p_installation_type" "text", "p_installation_location" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."commit_configured_product_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_configured_product_id" "uuid", "p_dealer_id" "uuid", "p_position" "text", "p_area" "text", "p_fabric_drop" "text", "p_installation_type" "text", "p_installation_location" "text") IS 'Creates QuoteLine from ConfiguredProduct. COPY only from CP - no pricing recalculation. Uses unit values * qty for line totals.';



CREATE OR REPLACE FUNCTION "public"."compute_fabric_pricing_from_rule"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_style_code" "text", "p_height_m" numeric, "p_width_m" numeric, "p_roll_width_m" numeric, "p_msrp_per_m" numeric) RETURNS TABLE("qty" numeric, "pricing_uom" "text", "unit_price" numeric, "area_base_m2" numeric, "drops" numeric, "waste_pct" numeric)
    LANGUAGE "plpgsql" STABLE
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


ALTER FUNCTION "public"."compute_fabric_pricing_from_rule"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_style_code" "text", "p_height_m" numeric, "p_width_m" numeric, "p_roll_width_m" numeric, "p_msrp_per_m" numeric) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."compute_fabric_pricing_from_rule"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_style_code" "text", "p_height_m" numeric, "p_width_m" numeric, "p_roll_width_m" numeric, "p_msrp_per_m" numeric) IS 'Computes fabric qty, pricing_uom, unit_price from FabricRules. ROLLER_DROPS / AREA_BASED area, then m vs m2, waste, round_up, min_qty.';



CREATE OR REPLACE FUNCTION "public"."compute_prices_from_cost"("p_total_cost_landed" numeric, "p_sale_in_margin_pct" numeric, "p_sale_out_margin_pct" numeric) RETURNS TABLE("total_cost_landed" numeric, "dealer_price" numeric, "msrp" numeric)
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  v_cost numeric := coalesce(p_total_cost_landed, 0);
  v_m_in numeric := coalesce(p_sale_in_margin_pct, 0.35);
  v_m_out numeric := coalesce(p_sale_out_margin_pct, 0.65);
  v_dealer numeric := 0;
  v_msrp numeric := 0;
begin
  -- avoid division by zero / invalid margins
  if (1 - v_m_in) <= 0 then
    v_dealer := 0;
  else
    v_dealer := v_cost / (1 - v_m_in);
  end if;

  if (1 - v_m_out) <= 0 then
    v_msrp := 0;
  else
    v_msrp := v_dealer / (1 - v_m_out);
  end if;

  return query
  select
    v_cost,
    round(v_dealer, 4),
    round(v_msrp, 4);
end;
$$;


ALTER FUNCTION "public"."compute_prices_from_cost"("p_total_cost_landed" numeric, "p_sale_in_margin_pct" numeric, "p_sale_out_margin_pct" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_prices_from_landed_cost"("p_total_cost_landed" numeric, "p_sale_in_margin_pct" numeric DEFAULT 0.35, "p_sale_out_margin_pct" numeric DEFAULT 0.65) RETURNS TABLE("dealer_price" numeric, "msrp" numeric)
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select
    case
      when p_total_cost_landed is null then 0
      when (1 - p_sale_in_margin_pct) <= 0 then 0
      else round(p_total_cost_landed / (1 - p_sale_in_margin_pct), 4)
    end as dealer_price,
    case
      when p_total_cost_landed is null then 0
      when (1 - p_sale_in_margin_pct) <= 0 then 0
      when (1 - p_sale_out_margin_pct) <= 0 then 0
      else round(
        (p_total_cost_landed / (1 - p_sale_in_margin_pct)) / (1 - p_sale_out_margin_pct),
        4
      )
    end as msrp;
$$;


ALTER FUNCTION "public"."compute_prices_from_landed_cost"("p_total_cost_landed" numeric, "p_sale_in_margin_pct" numeric, "p_sale_out_margin_pct" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_pricing_cost_exw"("p_cost_exw" numeric, "p_purchase_uom" "text", "p_pricing_uom" "text", "p_units_per_purchase_unit" numeric, "p_roll_width_m" numeric) RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  u text := lower(trim(coalesce(p_purchase_uom,'')));
  puom text := lower(trim(coalesce(p_pricing_uom,'')));
  units numeric := nullif(p_units_per_purchase_unit, 0);
begin
  if p_cost_exw is null then
    return null;
  end if;

  -- =========================
  -- PRICING PER EA
  -- =========================
  if puom = 'ea' then
    -- si compras en unidad, NO divides
    if u in ('ea','each') then
      return p_cost_exw;
    end if;

    -- si compras en pack/set/box/bag, divides
    if u in ('set','pack','box','bag') then
      if units is null then return null; end if;
      return p_cost_exw / units;
    end if;

    -- fallback seguro: si no sabemos, NO inventamos
    return null;
  end if;

  -- =========================
  -- PRICING PER M (lineal)
  -- =========================
  if puom = 'm' then
    if u in ('m') then return p_cost_exw; end if;
    if u in ('yd','yard','yards') then return (p_cost_exw / 0.9144); end if;
    if u in ('ft','foot','feet') then return (p_cost_exw / 0.3048); end if;
    if u in ('in','inch','inches') then return (p_cost_exw / 0.0254); end if;
    return null;
  end if;

  -- =========================
  -- PRICING PER M2 (área)
  -- =========================
  if puom = 'm2' then
    -- yd2/ft2 directos
    if u in ('yd2') then return (p_cost_exw / 0.83612736); end if;
    if u in ('ft2') then return (p_cost_exw / 0.09290304); end if;

    -- si compras lineal (yd/ft/m) y quieres m2 -> necesitas roll_width_m
    if p_roll_width_m is null or p_roll_width_m <= 0 then
      return null;
    end if;

    if u in ('yd','yard','yards') then return (p_cost_exw / 0.9144) / p_roll_width_m; end if;
    if u in ('ft','foot','feet') then return (p_cost_exw / 0.3048) / p_roll_width_m; end if;
    if u in ('m') then return p_cost_exw / p_roll_width_m; end if;

    return null;
  end if;

  return null;
end;
$$;


ALTER FUNCTION "public"."compute_pricing_cost_exw"("p_cost_exw" numeric, "p_purchase_uom" "text", "p_pricing_uom" "text", "p_units_per_purchase_unit" numeric, "p_roll_width_m" numeric) OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."convert_unit_price"("p_price" numeric, "p_from" "text", "p_to" "text") RETURNS numeric
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select
    case
      when p_price is null then null
      else p_price / public.uom_factor(p_from, p_to)
    end;
$$;


ALTER FUNCTION "public"."convert_unit_price"("p_price" numeric, "p_from" "text", "p_to" "text") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."create_app_user_invite"("p_email" "text", "p_user_type" "text", "p_role_code" "text", "p_dealer_id" "uuid" DEFAULT NULL::"uuid", "p_display_name" "text" DEFAULT NULL::"text", "p_expires_in_hours" integer DEFAULT 72) RETURNS TABLE("invite_id" "uuid", "email" "text", "user_type" "text", "role_code" "text", "dealer_id" "uuid", "token" "text", "expires_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_token text;
  v_token_hash text;
  v_org_id uuid;
  v_inviter uuid;
begin
  v_inviter := public.current_app_user_id();

  select au.organization_id
    into v_org_id
  from public."AppUsers" au
  where au.id = v_inviter;

  if v_org_id is null then
    raise exception 'No organization context for inviter';
  end if;

  v_token := encode(gen_random_bytes(32), 'hex');
  v_token_hash := encode(digest(v_token, 'sha256'), 'hex');

  insert into public."AppUserInvites"(
    organization_id,
    user_type,
    dealer_id,
    email,
    display_name,
    role_code,
    invited_by_app_user_id,
    token_hash,
    expires_at
  ) values (
    v_org_id,
    p_user_type,
    case when p_user_type = 'dealer' then p_dealer_id else null end,
    lower(trim(p_email)),
    p_display_name,
    p_role_code,
    v_inviter,
    v_token_hash,
    now() + make_interval(hours => greatest(p_expires_in_hours, 1))
  )
  returning id, email, user_type, role_code, dealer_id, expires_at
  into invite_id, email, user_type, role_code, dealer_id, expires_at;

  token := v_token;
  return next;
end;
$$;


ALTER FUNCTION "public"."create_app_user_invite"("p_email" "text", "p_user_type" "text", "p_role_code" "text", "p_dealer_id" "uuid", "p_display_name" "text", "p_expires_in_hours" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid" DEFAULT NULL::"uuid", "p_quote_line_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_configured_product_id uuid;
  v_bom_template_id       uuid;
  v_preview_snapshot      jsonb;
  v_totals_after          jsonb;
  v_hardware_color        text;
  v_fabric_item_id        uuid;
  v_width_mm              numeric(12,4);
  v_height_mm             numeric(12,4);
  v_quantity              numeric(12,4);
  v_roll_sku              text;
  v_roll_collection_name  text;
  v_roll_variant_name     text;
  v_roll_width            numeric(12,4);
  v_labor_pct             numeric(12,4);
BEGIN
  PERFORM public.reject_oneoff_keys(p_config_snapshot);

  SELECT COALESCE(cs.labor_pct, 0)
  INTO v_labor_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_org_id
  LIMIT 1;

  IF v_labor_pct IS NULL THEN v_labor_pct := 0; END IF;

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

  v_width_mm := COALESCE(
    (p_config_snapshot->'measurements'->>'width_total_mm')::numeric(12,4),
    (p_config_snapshot->>'width_mm')::numeric(12,4)
  );
  v_height_mm  := (p_config_snapshot->>'height_mm')::numeric(12,4);
  v_quantity   := COALESCE((p_config_snapshot->>'quantity')::numeric(12,4), 1);

  IF v_fabric_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.collection_name, ci.variant_name, ci.roll_width
    INTO v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width
    FROM public."CatalogItems" ci
    WHERE ci.id = v_fabric_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;
  END IF;

  INSERT INTO public."ConfiguredProducts" (
    organization_id, quote_id, bom_template_id, product_type_id,
    width_mm, height_mm, quantity, hardware_color,
    roll_catalog_item_id, roll_sku, roll_collection_name, roll_variant_name, roll_width,
    config_snapshot, labor_pct,
    roll_msrp_total, bom_total, accessories_total, total_msrp
  )
  VALUES (
    p_org_id, p_quote_id, v_bom_template_id, p_product_type_id,
    v_width_mm, v_height_mm, v_quantity, v_hardware_color,
    v_fabric_item_id, v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width,
    p_config_snapshot, v_labor_pct,
    0, 0, 0, 0
  )
  RETURNING id INTO v_configured_product_id;

  v_preview_snapshot := public.build_bom_preview_snapshot(
    p_org_id, v_configured_product_id, v_bom_template_id
  );

  UPDATE public."ConfiguredProducts"
  SET bom_preview_snapshot = v_preview_snapshot, updated_at = now()
  WHERE id = v_configured_product_id AND organization_id = p_org_id;

  PERFORM public.calculate_configured_product_totals(v_configured_product_id);

  SELECT
    jsonb_build_object(
      'roll_msrp_total',           cp.roll_msrp_total,
      'bom_total',                 cp.bom_total,
      'accessories_total',         cp.accessories_total,
      'labor_amount',              cp.labor_amount,
      'total_msrp',                cp.total_msrp,
      'msrp_product_subtotal',     cp.msrp_product_subtotal,
      'labor_msrp',                cp.labor_msrp,
      'unit_msrp_total',           cp.unit_msrp_total,
      'roll_total_cost',           cp.roll_total_cost,
      'bom_total_cost',            cp.bom_total_cost,
      'accessories_total_cost',    cp.accessories_total_cost,
      'unit_product_cost',         cp.unit_product_cost,
      'unit_labor_cost',           cp.unit_labor_cost,
      'total_cost',                cp.total_cost
    )
  INTO v_totals_after
  FROM public."ConfiguredProducts" cp
  WHERE cp.id = v_configured_product_id;

  SELECT bom_preview_snapshot
  INTO v_preview_snapshot
  FROM public."ConfiguredProducts"
  WHERE id = v_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id', v_configured_product_id,
    'bom_instance_id',       NULL,
    'bom_template_id',       v_bom_template_id,
    'totals',                v_totals_after,
    'bom_preview_snapshot',  v_preview_snapshot
  );
END;
$$;


ALTER FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") IS 'Creates ConfiguredProduct + BOM snapshot + pricing totals. No _landed column references.';



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

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."AppUsers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "user_type" "text" NOT NULL,
    "dealer_id" "uuid",
    "auth_user_id" "uuid",
    "email" "text" NOT NULL,
    "display_name" "text",
    "role_code" "text" NOT NULL,
    "status" "text" NOT NULL,
    "invited_by_app_user_id" "uuid",
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "must_change_password" boolean,
    "temp_password_set_at" timestamp with time zone,
    CONSTRAINT "AppUsers_status_check" CHECK (("status" = ANY (ARRAY['invited'::"text", 'active'::"text", 'disabled'::"text"]))),
    CONSTRAINT "AppUsers_user_type_check" CHECK (("user_type" = ANY (ARRAY['org'::"text", 'dealer'::"text"]))),
    CONSTRAINT "app_users_dealer_check" CHECK (((("user_type" = 'dealer'::"text") AND ("dealer_id" IS NOT NULL)) OR (("user_type" = 'org'::"text") AND ("dealer_id" IS NULL))))
);


ALTER TABLE "public"."AppUsers" OWNER TO "postgres";


COMMENT ON TABLE "public"."AppUsers" IS 'Unified app user view (org vs dealer). Single source for current_dealer_id() and RLS.';



CREATE OR REPLACE FUNCTION "public"."current_app_user"() RETURNS "public"."AppUsers"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v public."AppUsers";
begin
  select au
    into v
  from public."AppUsers" au
  where au.auth_user_id = auth.uid()
  limit 1;

  return v;
end;
$$;


ALTER FUNCTION "public"."current_app_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_app_user_dealer_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select dealer_id
  from public."AppUsers"
  where id = public.current_app_user_id()
$$;


ALTER FUNCTION "public"."current_app_user_dealer_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_app_user_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  select au.id
  from public."AppUsers" au
  where au.email = public.jwt_email()
    and au.status = 'active'
    and coalesce(au.deleted,false) = false
  limit 1;
$$;


ALTER FUNCTION "public"."current_app_user_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_app_user_org_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select organization_id
  from public."AppUsers"
  where id = public.current_app_user_id()
$$;


ALTER FUNCTION "public"."current_app_user_org_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_app_user_type"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select user_type
  from public."AppUsers"
  where id = public.current_app_user_id()
$$;


ALTER FUNCTION "public"."current_app_user_type"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_auth_email"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT lower(nullif(trim(auth.jwt() ->> 'email'), ''));
$$;


ALTER FUNCTION "public"."current_auth_email"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_dealer_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT NULLIF(trim(current_setting('app.dealer_id', true)), '')::uuid;
$$;


ALTER FUNCTION "public"."current_dealer_id"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."current_dealer_id"() IS 'Reads app.dealer_id from session. Call init_session_context() in same transaction first.';



CREATE OR REPLACE FUNCTION "public"."current_dealer_id"("p_org_id" "uuid") RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT public.current_dealer_id();
$$;


ALTER FUNCTION "public"."current_dealer_id"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."current_dealer_id"("p_org_id" "uuid") IS 'Delegates to current_dealer_id(). Session must be initialized with init_session_context().';



CREATE OR REPLACE FUNCTION "public"."current_dealer_id_for_org"("p_org_id" "uuid") RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  select du.dealer_id
  from public."DealerUsers" du
  where du.organization_id = p_org_id
    and du.user_id = auth.uid()
    and coalesce(du.deleted,false) = false
    and (du.status is null or du.status in ('active','invited'))
  order by du.created_at desc
  limit 1;
$$;


ALTER FUNCTION "public"."current_dealer_id_for_org"("p_org_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_user_dealer_ids"("p_organization_id" "uuid") RETURNS "uuid"[]
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_has_dealer_id boolean;
  v_ids uuid[];
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'OrganizationUsers'
      and column_name = 'dealer_id'
  ) into v_has_dealer_id;

  if not v_has_dealer_id then
    return array[]::uuid[];
  end if;

  select coalesce(array_agg(distinct ou.dealer_id), array[]::uuid[])
  into v_ids
  from public."OrganizationUsers" ou
  where ou.organization_id = p_organization_id
    and ou.user_id = auth.uid()
    and coalesce(ou.deleted, false) = false
    and ou.dealer_id is not null;

  return v_ids;
end;
$$;


ALTER FUNCTION "public"."current_user_dealer_ids"("p_organization_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_user_email"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'email', '');
$$;


ALTER FUNCTION "public"."current_user_email"() OWNER TO "postgres";


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



CREATE OR REPLACE FUNCTION "public"."derive_pricing_uom"("p_measure_basis" "text", "p_roll_pricing_mode" "text", "p_is_roll" boolean) RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT CASE
    WHEN p_is_roll = true AND p_roll_pricing_mode = 'per_linear_meter'  THEN 'm'
    WHEN p_is_roll = true AND p_roll_pricing_mode = 'per_square_meter'  THEN 'm2'
    WHEN p_is_roll = true AND p_roll_pricing_mode = 'per_unit'          THEN 'ea'
    WHEN p_measure_basis = 'linear'  THEN 'm'
    WHEN p_measure_basis = 'area'    THEN 'm2'
    WHEN p_measure_basis = 'unit'    THEN 'ea'
    ELSE 'ea'
  END;
$$;


ALTER FUNCTION "public"."derive_pricing_uom"("p_measure_basis" "text", "p_roll_pricing_mode" "text", "p_is_roll" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."derive_pricing_uom"("p_measure_basis" "text", "p_roll_pricing_mode" "text", "p_is_roll" boolean) IS 'Determina pricing_uom canónico (ea|m|m2) desde measure_basis y roll_pricing_mode.
Para rolls: roll_pricing_mode tiene prioridad. Para todos: measure_basis es fallback.';



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


CREATE OR REPLACE FUNCTION "public"."freeze_proposal_snapshot"("p_proposal_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_proposal RECORD;
  v_pl RECORD;
  v_ql RECORD;
  v_cp RECORD;
  v_snapshot jsonb;
  v_config jsonb;
  v_base_mode text;
  v_base_unit numeric(12,4);
  v_base_line numeric(12,4);
BEGIN
  SELECT id, status, sent_at INTO v_proposal
  FROM public."Proposals"
  WHERE id = p_proposal_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_proposal.status NOT IN ('sent', 'accepted') THEN
    RETURN;
  END IF;

  -- For each ProposalLine from_quote with null quote_line_snapshot
  -- Select unit_msrp_total_snapshot (canonical); no unit_msrp
  FOR v_pl IN
    SELECT pl.id, pl.quote_line_id
    FROM public."ProposalLines" pl
    WHERE pl.proposal_id = p_proposal_id
      AND pl.deleted = false
      AND pl.line_type = 'from_quote'
      AND pl.quote_line_id IS NOT NULL
      AND pl.quote_line_snapshot IS NULL
  LOOP
    SELECT ql.name, ql.sku, ql.quantity, ql.width_m, ql.height_m, ql.area, ql.position,
           ql.product_type, ql.collection_name, ql.variant_name, ql.drive_type,
           ql.msrp, ql.unit_msrp_total_snapshot, ql.configured_product_id
    INTO v_ql
    FROM public."QuoteLines" ql
    WHERE ql.id = v_pl.quote_line_id
    LIMIT 1;

    IF NOT FOUND THEN
      v_snapshot := jsonb_build_object(
        'name', '—',
        'sku', NULL,
        'qty', 1,
        'width_m', NULL,
        'height_m', NULL,
        'measurements', '{}'::jsonb,
        'accessories', NULL,
        'base_price_mode', 'msrp',
        'base_unit_msrp', NULL,
        'base_line_msrp', NULL,
        'captured_at', now()
      );
    ELSE
      v_config := NULL;
      IF v_ql.configured_product_id IS NOT NULL THEN
        SELECT config_snapshot INTO v_config
        FROM public."ConfiguredProducts"
        WHERE id = v_ql.configured_product_id AND deleted = false
        LIMIT 1;
      END IF;

      -- Use unit_msrp_total_snapshot; fallback to msrp/quantity
      v_base_unit := COALESCE(v_ql.unit_msrp_total_snapshot, v_ql.msrp / NULLIF(v_ql.quantity, 0));
      v_base_line := COALESCE(v_ql.msrp, v_base_unit * COALESCE(NULLIF(v_ql.quantity, 0), 1));
      v_base_mode := CASE WHEN v_ql.msrp IS NOT NULL AND v_ql.msrp > 0 THEN 'msrp' ELSE 'unit_msrp' END;

      v_snapshot := jsonb_build_object(
        'name', v_ql.name,
        'sku', v_ql.sku,
        'qty', COALESCE(v_ql.quantity, 1),
        'width_m', v_ql.width_m,
        'height_m', v_ql.height_m,
        'area', v_ql.area,
        'position', v_ql.position,
        'product_type', v_ql.product_type,
        'collection_name', v_ql.collection_name,
        'variant_name', v_ql.variant_name,
        'drive_type', v_ql.drive_type,
        'measurements', COALESCE(v_config->'measurements', '{}'::jsonb),
        'accessories', v_config->'accessories',
        'base_price_mode', v_base_mode,
        'base_unit_msrp', v_base_unit,
        'base_line_msrp', v_base_line,
        'captured_at', now()
      );
    END IF;

    UPDATE public."ProposalLines"
    SET quote_line_snapshot = v_snapshot
    WHERE id = v_pl.id;
  END LOOP;

  UPDATE public."Proposals"
  SET sent_at = COALESCE(sent_at, now())
  WHERE id = p_proposal_id;
END;
$$;


ALTER FUNCTION "public"."freeze_proposal_snapshot"("p_proposal_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."freeze_proposal_snapshot"("p_proposal_id" "uuid") IS 'Captures QuoteLine + ConfiguredProduct snapshot. Uses unit_msrp_total_snapshot (not unit_msrp).';



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



CREATE OR REPLACE FUNCTION "public"."get_current_dealer_id"() RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
BEGIN
  PERFORM public.init_session_context();
  RETURN public.current_dealer_id();
END;
$$;


ALTER FUNCTION "public"."get_current_dealer_id"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_current_dealer_id"() IS 'Calls init_session_context() then current_dealer_id() in one transaction. Use from frontend for active dealer.';



CREATE OR REPLACE FUNCTION "public"."get_current_portal_user"() RETURNS TABLE("id" "uuid", "auth_user_id" "uuid", "email" "text", "display_name" "text", "organization_id" "uuid", "user_type" "text", "dealer_id" "uuid", "role_code" "text", "status" "text")
    LANGUAGE "sql" STABLE
    AS $$
  select
    au.id,
    au.auth_user_id,
    au.email,
    au.display_name,
    au.organization_id,
    au.user_type,
    au.dealer_id,
    au.role_code,
    au.status
  from public."AppUsers" au
  where au.id = public.current_app_user_id()
    and au.user_type = 'dealer';
$$;


ALTER FUNCTION "public"."get_current_portal_user"() OWNER TO "postgres";


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



CREATE OR REPLACE FUNCTION "public"."get_inventory_availability"("p_warehouse_id" "uuid", "p_catalog_item_ids" "uuid"[] DEFAULT NULL::"uuid"[]) RETURNS TABLE("organization_id" "uuid", "warehouse_id" "uuid", "catalog_item_id" "uuid", "on_hand_qty" numeric, "on_order_qty" numeric, "next_eta" "date", "import_lead_time_min_days" integer, "import_lead_time_max_days" integer, "risk_level" "text", "is_special_order" boolean, "availability_type" "text")
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
  SELECT
    a.organization_id,
    a.warehouse_id,
    a.catalog_item_id,
    a.on_hand_qty,
    a.on_order_qty,
    a.next_eta,
    a.import_lead_time_min_days,
    a.import_lead_time_max_days,
    a.risk_level,
    a.is_special_order,
    a.availability_type
  FROM public.inventory_availability a
  WHERE a.warehouse_id = p_warehouse_id
    AND (p_catalog_item_ids IS NULL OR a.catalog_item_id = ANY(p_catalog_item_ids));
$$;


ALTER FUNCTION "public"."get_inventory_availability"("p_warehouse_id" "uuid", "p_catalog_item_ids" "uuid"[]) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_inventory_availability"("p_warehouse_id" "uuid", "p_catalog_item_ids" "uuid"[]) IS 'Returns availability rows for a warehouse (and optional catalog_item_ids). Informative only. RLS via base tables. Do not persist in QuoteLine.';



CREATE OR REPLACE FUNCTION "public"."get_item_pricing_from_cost"("p_org_id" "uuid", "p_catalog_item_id" "uuid") RETURNS TABLE("total_cost_landed" numeric, "dealer_price" numeric, "msrp" numeric)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with cost as (
    select
      coalesce(cim.total_cost, 0) as total_cost_landed
    from public."CatalogItemsMSRP" cim
    where cim.organization_id = p_org_id
      and cim.catalog_item_id = p_catalog_item_id
    order by cim.updated_at desc nulls last
    limit 1
  ),
  prices as (
    select * from public.compute_prices_from_landed_cost(
      (select total_cost_landed from cost),
      0.35,
      0.65
    )
  )
  select
    (select total_cost_landed from cost) as total_cost_landed,
    (select dealer_price from prices) as dealer_price,
    (select msrp from prices) as msrp;
$$;


ALTER FUNCTION "public"."get_item_pricing_from_cost"("p_org_id" "uuid", "p_catalog_item_id" "uuid") OWNER TO "postgres";


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



CREATE OR REPLACE FUNCTION "public"."get_my_portal_access"() RETURNS TABLE("permission_code" "text")
    LANGUAGE "sql" STABLE
    AS $$
  select rp.permission_code
  from public."AppUserRolePermissions" rp
  where rp.role_code = (
    select au.role_code
    from public."AppUsers" au
    where au.id = public.current_app_user_id()
      and au.user_type = 'dealer'
      and au.status = 'active'
      and coalesce(au.deleted,false) = false
    limit 1
  )
  order by rp.permission_code;
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


CREATE OR REPLACE FUNCTION "public"."get_roll_pricing"("p_org_id" "uuid", "p_roll_catalog_item_id" "uuid") RETURNS TABLE("msrp" numeric, "dealer_price" numeric, "labor_msrp" numeric)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with cim as (
    select
      coalesce(cim.total_cost, 0) as total_cost_landed
    from public."CatalogItemsMSRP" cim
    where cim.organization_id = p_org_id
      and cim.catalog_item_id = p_roll_catalog_item_id
    order by cim.updated_at desc nulls last
    limit 1
  ),
  prices as (
    select * from public.compute_prices_from_landed_cost(
      (select total_cost_landed from cim),
      0.35,
      0.65
    )
  )
  select
    (select msrp from prices) as msrp,
    (select dealer_price from prices) as dealer_price,
    0::numeric as labor_msrp;
$$;


ALTER FUNCTION "public"."get_roll_pricing"("p_org_id" "uuid", "p_roll_catalog_item_id" "uuid") OWNER TO "postgres";


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
    SET "search_path" TO 'public', 'auth'
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



CREATE OR REPLACE FUNCTION "public"."init_session_context"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_row record;
  v_dealer_id uuid;
BEGIN
  SELECT au.user_type, au.organization_id, au.role_code, au.dealer_id, au.id
    INTO v_row
  FROM public."AppUsers" au
  WHERE au.auth_user_id = auth.uid()
    AND au.deleted = false
  ORDER BY CASE WHEN au.user_type = 'org' THEN 0 ELSE 1 END
  LIMIT 1;

  IF v_row IS NULL THEN
    -- No AppUser: clear session vars so RLS sees "no context"
    PERFORM set_config('app.user_type', '', true);
    PERFORM set_config('app.organization_id', '', true);
    PERFORM set_config('app.role_code', '', true);
    PERFORM set_config('app.dealer_id', '', true);
    RETURN;
  END IF;

  PERFORM set_config('app.user_type', COALESCE(v_row.user_type, ''), true);
  PERFORM set_config('app.organization_id', COALESCE(v_row.organization_id::text, ''), true);
  PERFORM set_config('app.role_code', COALESCE(v_row.role_code, ''), true);

  IF v_row.user_type = 'org' THEN
    SELECT pref.active_dealer_id INTO v_dealer_id
    FROM public."AppUserPreferences" pref
    WHERE pref.user_id = v_row.id;
  ELSE
    v_dealer_id := v_row.dealer_id;
  END IF;

  PERFORM set_config('app.dealer_id', COALESCE(v_dealer_id::text, ''), true);
END;
$$;


ALTER FUNCTION "public"."init_session_context"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."init_session_context"() IS 'Sets app.user_type, app.organization_id, app.role_code, app.dealer_id from AppUsers (and AppUserPreferences for org). Must run in same transaction as RLS reads.';



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



CREATE OR REPLACE FUNCTION "public"."is_dealer_portal_user"() RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  select exists (
    select 1
    from public."AppUsers" au
    where au.id = public.current_app_user_id()
      and au.user_type = 'dealer'
      and au.status = 'active'
      and coalesce(au.deleted,false) = false
  );
$$;


ALTER FUNCTION "public"."is_dealer_portal_user"() OWNER TO "postgres";


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



CREATE OR REPLACE FUNCTION "public"."is_dealer_portal_user_with_write"() RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  select exists (
    select 1
    from public.get_my_portal_access() p
    where p.permission_code in (
      'directory.write',
      'sales.write',
      'quotes.edit',
      'quotes.manage',
      'quotes.approve'
    )
  );
$$;


ALTER FUNCTION "public"."is_dealer_portal_user_with_write"() OWNER TO "postgres";


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



CREATE OR REPLACE FUNCTION "public"."is_dealer_user_for_org"("p_org_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  select exists (
    select 1
    from public."DealerUsers" du
    where du.organization_id = p_org_id
      and du.user_id = auth.uid()
      and coalesce(du.deleted,false) = false
      and (du.status is null or du.status in ('active','invited'))
  );
$$;


ALTER FUNCTION "public"."is_dealer_user_for_org"("p_org_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_internal_org_user"("p_organization_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_has_dealer_id boolean;
  v_ok boolean;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'OrganizationUsers'
      and column_name = 'dealer_id'
  ) into v_has_dealer_id;

  if not v_has_dealer_id then
    -- Si no existe dealer_id, tratamos a cualquier miembro org como internal
    select exists (
      select 1
      from public."OrganizationUsers" ou
      where ou.organization_id = p_organization_id
        and ou.user_id = auth.uid()
        and coalesce(ou.deleted,false) = false
    ) into v_ok;

    return v_ok;
  end if;

  select exists (
    select 1
    from public."OrganizationUsers" ou
    where ou.organization_id = p_organization_id
      and ou.user_id = auth.uid()
      and coalesce(ou.deleted,false) = false
      and ou.dealer_id is null
  ) into v_ok;

  return v_ok;
end;
$$;


ALTER FUNCTION "public"."is_internal_org_user"("p_organization_id" "uuid") OWNER TO "postgres";


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
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
  SELECT
    EXISTS (
      SELECT 1 FROM public."OrganizationUsers" ou
      WHERE ou.organization_id = p_org_id
        AND ou.user_id = auth.uid()
        AND (ou.deleted IS NULL OR ou.deleted = false)
        AND (ou.status IS NULL OR ou.status IN ('active', 'invited'))
    )
    OR
    EXISTS (
      SELECT 1 FROM public."DealerUsers" du
      WHERE du.organization_id = p_org_id
        AND du.user_id = auth.uid()
        AND (du.deleted IS NULL OR du.deleted = false)
        AND (du.status IS NULL OR du.status IN ('active', 'invited'))
    );
$$;


ALTER FUNCTION "public"."is_org_user_member"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_org_user_member"("p_org_id" "uuid") IS 'DEPRECATED: Includes DealerUsers; use is_org_user_member_strict or session_is_org_user/session_is_dealer_user.';



CREATE OR REPLACE FUNCTION "public"."is_org_user_member_strict"("p_org_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND (ou.deleted IS NULL OR ou.deleted = false)
      AND (ou.status IS NULL OR ou.status IN ('active', 'invited'))
  );
$$;


ALTER FUNCTION "public"."is_org_user_member_strict"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_org_user_member_strict"("p_org_id" "uuid") IS 'DEPRECATED: Use session_is_org_user(uuid) after init_session_context(). Replaced in Quotes, Proposals, Directory RLS by 20260224_005.';



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


COMMENT ON FUNCTION "public"."is_org_user_superadmin"("p_org_id" "uuid") IS 'DEPRECATED: Prefer session_is_admin(uuid) for org-scoped admin check after init_session_context().';



CREATE OR REPLACE FUNCTION "public"."is_pack_uom"("p_uom" "text") RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT lower(coalesce(p_uom,'')) = ANY (ARRAY[
    'pack','set','box','case','bag'
  ]);
$$;


ALTER FUNCTION "public"."is_pack_uom"("p_uom" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_portal_user_in_org"("p_org_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public."DealerUsers" du
    WHERE du.organization_id = p_org_id
      AND du.user_id = auth.uid()
      AND (du.deleted IS NULL OR du.deleted = false)
      AND (du.status IS NULL OR du.status IN ('active', 'invited'))
  );
$$;


ALTER FUNCTION "public"."is_portal_user_in_org"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_portal_user_in_org"("p_org_id" "uuid") IS 'DEPRECATED: Prefer session_is_dealer_user(uuid) after init_session_context(). Still used by org-only tables (catalog, BOM, etc.).';



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


CREATE OR REPLACE FUNCTION "public"."jwt_email"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select nullif(auth.jwt() ->> 'email', '');
$$;


ALTER FUNCTION "public"."jwt_email"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."jwt_name"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select coalesce(
    nullif(auth.jwt() #>> '{user_metadata,full_name}', ''),
    nullif(auth.jwt() #>> '{user_metadata,name}', ''),
    nullif(auth.jwt() #>> '{app_metadata,full_name}', ''),
    nullif(auth.jwt() #>> '{app_metadata,name}', ''),
    public.jwt_email()
  );
$$;


ALTER FUNCTION "public"."jwt_name"() OWNER TO "postgres";


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



CREATE OR REPLACE FUNCTION "public"."link_portal_user"("p_org_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_email text;
  v_uid uuid;
  v_dealer_id uuid;
BEGIN
  v_uid := auth.uid();
  v_email := nullif(trim(auth.jwt() ->> 'email'), '');
  IF v_uid IS NULL OR v_email IS NULL THEN
    RETURN NULL;
  END IF;

  UPDATE public."DealerUsers" du
  SET user_id = v_uid,
      updated_at = now()
  WHERE du.organization_id = p_org_id
    AND (du.deleted IS NULL OR du.deleted = false)
    AND (du.status IS NULL OR du.status IN ('active', 'invited'))
    AND du.user_id IS NULL
    AND v_email IS NOT NULL
    AND lower(trim(du.portal_user_email)) = lower(v_email)
  RETURNING du.dealer_id INTO v_dealer_id;

  RETURN v_dealer_id;
END;
$$;


ALTER FUNCTION "public"."link_portal_user"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."link_portal_user"("p_org_id" "uuid") IS 'Links DealerUsers to auth.uid() by org and JWT email. Call once per session for portal. Returns dealer_id of updated row (or NULL).';



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
    CONSTRAINT "chk_orguser_active_has_userid" CHECK ((("status" <> 'active'::"public"."org_user_status") OR ("user_id" IS NOT NULL))),
    CONSTRAINT "organizationusers_role_check" CHECK ((("role")::"text" = ANY (ARRAY['superadmin'::"text", 'admin'::"text", 'operator'::"text", 'procurement'::"text", 'finance'::"text"])))
);


ALTER TABLE "public"."OrganizationUsers" OWNER TO "postgres";


COMMENT ON TABLE "public"."OrganizationUsers" IS 'Organization users - internal users with roles (owner, admin, member, viewer)';



COMMENT ON COLUMN "public"."OrganizationUsers"."user_id" IS 'FK to auth.users. Nullable until user accepts invite.';



COMMENT ON COLUMN "public"."OrganizationUsers"."user_email" IS 'User email (lowercased). Unique per organization when not deleted.';



COMMENT ON COLUMN "public"."OrganizationUsers"."status" IS 'Status: invited (pending), active (accepted), disabled (inactive)';



COMMENT ON CONSTRAINT "chk_orguser_active_has_userid" ON "public"."OrganizationUsers" IS 'Active rows must have user_id set (invited rows may have NULL until they accept).';



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
  v_ci               record;
  v_shipping_pct     numeric;
  v_import_tax_pct   numeric;
  v_min_margin_pct   numeric;
  v_msrp_pct         numeric;
  v_pricing_uom      text;
  v_pricing_cost_exw numeric;
  v_total_cost_local numeric;
  v_dealer_price     numeric;
  v_msrp             numeric;
BEGIN
  SELECT id, organization_id, category_id,
         cost_exw, unit_of_measure, units_per_purchase_unit,
         measure_basis, is_roll, roll_pricing_mode,
         COALESCE(roll_width_m, roll_width) AS roll_width_m,
         sku, name, collection_name, variant_name
  INTO   v_ci
  FROM   public."CatalogItems"
  WHERE  id = p_item_id;

  IF v_ci.organization_id IS NULL THEN RETURN; END IF;

  SELECT r.shipping_pct, r.import_tax_pct, r.minimum_margin_pct, r.msrp_pct
  INTO   v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct
  FROM   public.msrp_get_effective_rates(v_ci.organization_id, v_ci.category_id) r;

  v_pricing_uom := public.derive_pricing_uom(
    v_ci.measure_basis, v_ci.roll_pricing_mode, v_ci.is_roll
  );

  v_pricing_cost_exw := public.compute_pricing_cost_exw(
    COALESCE(v_ci.cost_exw, 0),
    v_ci.unit_of_measure,
    v_pricing_uom,
    v_ci.units_per_purchase_unit,
    v_ci.roll_width_m
  );

  -- Si la conversión UOM fue imposible (NULL), pricing = 0
  IF v_pricing_cost_exw IS NULL OR v_pricing_cost_exw = 0 THEN
    v_total_cost_local := 0;
    v_dealer_price     := 0;
    v_msrp             := 0;
  ELSE
    -- Fórmula compuesta (alineada con GENERATED columns)
    v_total_cost_local := round(
      v_pricing_cost_exw
      * (1 + COALESCE(v_shipping_pct, 0))
      * (1 + COALESCE(v_import_tax_pct, 0)),
      4
    );
    v_dealer_price := round(v_total_cost_local / NULLIF(1 - COALESCE(v_min_margin_pct, 0), 0), 4);
    v_msrp         := round(v_dealer_price     / NULLIF(1 - COALESCE(v_msrp_pct, 0), 0),       4);
  END IF;

  -- NO incluye columnas GENERATED (shipping_cost, import_tax_cost, total_cost)
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    sku, name, collection_name, variant_name,
    unit_of_measure, pricing_uom, pricing_cost_exw,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    dealer_price, msrp, updated_at
  )
  VALUES (
    p_item_id, v_ci.organization_id, v_ci.category_id,
    v_ci.sku, v_ci.name, v_ci.collection_name, v_ci.variant_name,
    v_ci.unit_of_measure, v_pricing_uom, v_pricing_cost_exw,
    COALESCE(v_shipping_pct,   0),
    COALESCE(v_import_tax_pct, 0),
    COALESCE(v_min_margin_pct, 0),
    COALESCE(v_msrp_pct,       0),
    COALESCE(v_dealer_price,   0),
    COALESCE(v_msrp,           0),
    now()
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    organization_id    = EXCLUDED.organization_id,
    category_id        = EXCLUDED.category_id,
    sku                = EXCLUDED.sku,
    name               = EXCLUDED.name,
    collection_name    = EXCLUDED.collection_name,
    variant_name       = EXCLUDED.variant_name,
    unit_of_measure    = EXCLUDED.unit_of_measure,
    pricing_uom        = EXCLUDED.pricing_uom,
    pricing_cost_exw   = EXCLUDED.pricing_cost_exw,
    shipping_pct       = EXCLUDED.shipping_pct,
    import_tax_pct     = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    msrp_pct           = EXCLUDED.msrp_pct,
    dealer_price       = EXCLUDED.dealer_price,
    msrp               = EXCLUDED.msrp,
    updated_at         = now();
END;
$$;


ALTER FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") IS 'Calcula y persiste CatalogItemsMSRP.
  pricing_uom      = derive_pricing_uom(measure_basis, roll_pricing_mode, is_roll)
  pricing_cost_exw = compute_pricing_cost_exw(cost_exw yd/ft/m → m/m2/ea)
  shipping_cost    = pricing_cost_exw × shipping_pct                        [GENERATED]
  import_tax_cost  = pricing_cost_exw × (1+shipping_pct) × import_tax_pct  [GENERATED]
  total_cost       = pricing_cost_exw × (1+shipping_pct) × (1+import_tax_pct) [GENERATED]
  dealer_price     = total_cost / (1 - minimum_margin_pct)
  msrp             = dealer_price / (1 - msrp_pct)';



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
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
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


CREATE OR REPLACE FUNCTION "public"."populate_bom_line_base_pricing_fields"("p_bom_instance_line_id" "uuid", "p_catalog_item_id" "uuid", "p_component_qty" numeric, "p_component_uom" "text", "p_component_role" "text", "p_organization_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_catalog_item RECORD;
    v_effective_mode text;  -- modo mapeado para calculate_fabric_pricing_qty
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
    -- Fuente de verdad: roll_pricing_mode; fallback fabric_pricing_mode (legacy)
    SELECT
        ci.is_fabric,
        ci.roll_width_m,
        COALESCE(ci.roll_pricing_mode::text, ci.fabric_pricing_mode::text) AS fabric_pricing_mode,
        ci.measure_basis,
        COALESCE(ci.unit_of_measure, ci.uom) AS uom
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

        -- Fallback: legacy calculate_fabric_pricing_qty (usa per_sqm, per_linear_m, etc.)
        -- Mapeo: roll_pricing_mode (per_square_meter, per_linear_meter, per_unit) -> calculate_fabric_pricing_qty
        v_effective_mode := CASE
            WHEN v_catalog_item.fabric_pricing_mode IN ('per_square_meter', 'per_sqm') THEN 'per_sqm'
            WHEN v_catalog_item.fabric_pricing_mode IN ('per_linear_meter', 'per_linear_m') THEN 'per_linear_m'
            WHEN v_catalog_item.fabric_pricing_mode IN ('per_linear_yd', 'per_roll') THEN v_catalog_item.fabric_pricing_mode
            ELSE v_catalog_item.fabric_pricing_mode
        END;

        IF v_catalog_item.fabric_pricing_mode = 'per_unit' THEN
            v_qty_pricing := 1;
            v_uom_pricing := 'ea';
        ELSIF v_effective_mode IS NOT NULL AND v_effective_mode IN ('per_sqm', 'per_linear_m', 'per_linear_yd', 'per_roll') THEN
            SELECT * INTO v_pricing_result
            FROM public.calculate_fabric_pricing_qty(
                v_qty_base,
                v_effective_mode,
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


ALTER FUNCTION "public"."populate_bom_line_base_pricing_fields"("p_bom_instance_line_id" "uuid", "p_catalog_item_id" "uuid", "p_component_qty" numeric, "p_component_uom" "text", "p_component_role" "text", "p_organization_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."populate_bom_line_base_pricing_fields"("p_bom_instance_line_id" "uuid", "p_catalog_item_id" "uuid", "p_component_qty" numeric, "p_component_uom" "text", "p_component_role" "text", "p_organization_id" "uuid") IS 'Populates base and pricing qty/UOM in BomInstanceLines. Uses roll_pricing_mode (fallback fabric_pricing_mode). For fabric: FabricRules first, else calculate_fabric_pricing_qty. Maps per_square_meter->per_sqm, per_linear_meter->per_linear_m.';



CREATE OR REPLACE FUNCTION "public"."proposal_lines_validate_quote_line"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.quote_line_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public."Proposals" p
      JOIN public."QuoteLines" ql ON ql.id = NEW.quote_line_id
      WHERE p.id = NEW.proposal_id AND ql.quote_id = p.quote_id
    ) THEN
      RAISE EXCEPTION 'ProposalLine quote_line_id must belong to the same Quote as the Proposal';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."proposal_lines_validate_quote_line"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."proposals_ensure_created_by"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_quote RECORD;
  v_uid uuid;
BEGIN
  v_uid := auth.uid();

  IF NEW.created_by_user_id IS NULL THEN
    IF v_uid IS NOT NULL THEN
      NEW.created_by_user_id := v_uid;
    ELSIF NEW.quote_id IS NOT NULL THEN
      SELECT q.created_by_user_id INTO v_quote
      FROM public."Quotes" q WHERE q.id = NEW.quote_id;
      IF v_quote.created_by_user_id IS NOT NULL THEN
        NEW.created_by_user_id := v_quote.created_by_user_id;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."proposals_ensure_created_by"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."proposals_ensure_created_by"() IS 'Ensures created_by_user_id is set on insert (defaults to auth.uid() or Quote creator).';



CREATE OR REPLACE FUNCTION "public"."proposals_ensure_integrity"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_quote RECORD;
  v_uid uuid;
BEGIN
  v_uid := auth.uid();

  IF NEW.quote_id IS NOT NULL THEN
    SELECT q.created_by_user_id, q.dealer_id INTO v_quote
    FROM public."Quotes" q WHERE q.id = NEW.quote_id;
  END IF;

  IF NEW.dealer_id IS NULL THEN
    IF v_quote.dealer_id IS NOT NULL THEN
      NEW.dealer_id := v_quote.dealer_id;
    ELSE
      RAISE EXCEPTION 'Proposal requires dealer_id. proposal_id=%, quote_id=%',
        COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid), NEW.quote_id;
    END IF;
  END IF;

  IF NEW.created_by_user_id IS NULL THEN
    IF v_uid IS NOT NULL THEN
      NEW.created_by_user_id := v_uid;
    ELSIF v_quote.created_by_user_id IS NOT NULL THEN
      NEW.created_by_user_id := v_quote.created_by_user_id;
    ELSE
      RAISE EXCEPTION 'Proposal must have creator. proposal_id=%, quote_id=%',
        COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid), NEW.quote_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."proposals_ensure_integrity"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."proposals_ensure_integrity"() IS 'Ensures dealer_id and created_by_user_id on Proposal insert.';



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


CREATE OR REPLACE FUNCTION "public"."recalc_proposal_totals"("p_proposal_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_org_id uuid;
  v_subtotal_material numeric(12,4) := 0;
  v_installation_total numeric(12,4) := 0;
  v_installation_net numeric(12,4) := 0;
  v_other_addons numeric(12,4) := 0;
  v_inst_discount_pct numeric(7,4) := 0;
  v_inst_fee_pct numeric(7,4) := 0;
  v_subtotal numeric(12,4);
  v_discount_pct numeric(12,6);
  v_discount_amount numeric(12,4) := 0;
  v_taxable_base numeric(12,4);
  v_itbms_pct numeric(7,4) := 0.07;
  v_itbms_amount numeric(12,4) := 0;
  v_fee numeric(12,4);
  v_total numeric(12,4);
  v_exempt_itbms boolean := false;
BEGIN
  SELECT p.organization_id, COALESCE(p.exempt_itbms, false),
         COALESCE(p.global_installation_discount_pct, 0), COALESCE(p.global_installation_fee_pct, 0)
    INTO v_org_id, v_exempt_itbms, v_inst_discount_pct, v_inst_fee_pct
  FROM public."Proposals" p
  WHERE p.id = p_proposal_id AND p.deleted = false;

  IF v_org_id IS NULL THEN
    RETURN;
  END IF;

  IF NOT v_exempt_itbms THEN
    SELECT COALESCE(cs.itbms_pct, 0.07) INTO v_itbms_pct
    FROM public."CostSettings" cs
    WHERE cs.organization_id = v_org_id AND COALESCE(cs.is_active, true)
    ORDER BY cs.created_at DESC
    LIMIT 1;
  END IF;

  -- Material subtotal (lines only, no addons)
  SELECT COALESCE(SUM(
    CASE
      WHEN pl.line_type = 'custom' THEN (COALESCE(pl.qty, 1) * COALESCE(pl.unit_price, 0))
      WHEN pl.line_type = 'from_quote' AND pl.quote_line_id IS NOT NULL THEN (
        SELECT
          CASE COALESCE(pl.override_mode::text, 'inherit')
            WHEN 'inherit' THEN COALESCE(ql.msrp, (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)), 0)
            WHEN 'discount_pct' THEN (COALESCE(ql.msrp, (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)), 0) * (1 - COALESCE(pl.discount_pct, 0) / 100.0))
            WHEN 'markup_pct' THEN (COALESCE(ql.msrp, (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)), 0) * (1 + COALESCE(pl.markup_pct, 0) / 100.0))
            WHEN 'fixed_unit_price' THEN (COALESCE(pl.fixed_unit_price, 0) * COALESCE(NULLIF(ql.quantity, 0), 1))
            WHEN 'fixed_line_total' THEN COALESCE(pl.fixed_line_total, 0)
            ELSE COALESCE(ql.msrp, (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)), 0)
          END
        FROM public."QuoteLines" ql
        WHERE ql.id = pl.quote_line_id
        LIMIT 1
      )
      ELSE 0
    END
  ), 0) INTO v_subtotal_material
  FROM public."ProposalLines" pl
  WHERE pl.proposal_id = p_proposal_id AND pl.deleted = false;

  -- Installation total and other addons
  SELECT COALESCE(SUM(CASE WHEN ao.addon_type = 'installation' THEN ao.sale_amount ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN ao.addon_type <> 'installation' OR ao.addon_type IS NULL THEN ao.sale_amount ELSE 0 END), 0)
  INTO v_installation_total, v_other_addons
  FROM public."ProposalLineAddOns" ao
  WHERE ao.proposal_id = p_proposal_id AND ao.deleted = false;

  -- Apply global installation discount and fee
  v_installation_net := ROUND(
    v_installation_total * (1 - v_inst_discount_pct / 100.0) * (1 + v_inst_fee_pct / 100.0),
    2
  );

  v_subtotal := v_subtotal_material + v_installation_net + v_other_addons;

  SELECT COALESCE(p.global_discount_pct, 0), COALESCE(p.global_fee_amount, 0)
  INTO v_discount_pct, v_fee
  FROM public."Proposals" p
  WHERE p.id = p_proposal_id;

  v_discount_amount := ROUND(v_subtotal * (v_discount_pct / 100.0), 2);
  v_taxable_base := GREATEST(v_subtotal - v_discount_amount, 0);

  IF v_exempt_itbms THEN
    v_itbms_amount := 0;
  ELSE
    v_itbms_amount := ROUND(v_taxable_base * v_itbms_pct, 2);
  END IF;

  v_total := ROUND(v_taxable_base + v_itbms_amount + COALESCE(v_fee, 0), 2);

  UPDATE public."Proposals"
  SET subtotal_amount = v_subtotal,
      installation_amount = v_installation_total,
      discount_amount = v_discount_amount,
      itbms_amount = v_itbms_amount,
      total_amount = v_total
  WHERE id = p_proposal_id;
END;
$$;


ALTER FUNCTION "public"."recalc_proposal_totals"("p_proposal_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."recalc_proposal_totals"("p_proposal_id" "uuid") IS 'Recalculates Proposals totals. Installation has own discount/fee (global_installation_discount_pct, global_installation_fee_pct). Uses unit_msrp_total_snapshot.';



CREATE OR REPLACE FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_ci               record;
  v_shipping_pct     numeric := 0;
  v_import_tax_pct   numeric := 0;
  v_min_margin_pct   numeric := 0.35;
  v_msrp_pct         numeric := 0.65;
  v_pricing_uom      text;
  v_pricing_cost_exw numeric;
  v_total_cost_local numeric;
  v_dealer_price     numeric;
  v_msrp             numeric;
BEGIN
  SELECT id, category_id, cost_exw, unit_of_measure,
         units_per_purchase_unit, measure_basis, is_roll, roll_pricing_mode,
         COALESCE(roll_width_m, roll_width) AS roll_width_m
  INTO   v_ci
  FROM   public."CatalogItems"
  WHERE  id = p_catalog_item_id;

  SELECT
    COALESCE(cs.shipping_pct, 0),
    COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
    COALESCE(cs.minimum_margin_pct, 0.35),
    COALESCE(cs.default_msrp_pct, 0.65)
  INTO v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_organization_id LIMIT 1;

  SELECT COALESCE(cm.minimum_margin_pct, v_min_margin_pct),
         COALESCE(cm.msrp_pct, v_msrp_pct)
  INTO   v_min_margin_pct, v_msrp_pct
  FROM   public."CategoryMargins" cm
  WHERE  cm.organization_id = p_organization_id
    AND  cm.category_id     = v_ci.category_id
    AND  COALESCE(cm.is_active, true)
  LIMIT 1;

  v_pricing_uom := public.derive_pricing_uom(
    v_ci.measure_basis, v_ci.roll_pricing_mode, v_ci.is_roll
  );

  v_pricing_cost_exw := public.compute_pricing_cost_exw(
    COALESCE(v_ci.cost_exw, 0),
    v_ci.unit_of_measure,
    v_pricing_uom,
    v_ci.units_per_purchase_unit,
    v_ci.roll_width_m
  );

  IF v_pricing_cost_exw IS NULL OR v_pricing_cost_exw = 0 THEN
    v_total_cost_local := 0;
    v_dealer_price     := 0;
    v_msrp             := 0;
  ELSE
    v_total_cost_local := round(
      v_pricing_cost_exw * (1 + v_shipping_pct) * (1 + v_import_tax_pct), 4
    );
    v_dealer_price := round(v_total_cost_local / NULLIF(1 - v_min_margin_pct, 0), 4);
    v_msrp         := round(v_dealer_price     / NULLIF(1 - v_msrp_pct, 0),       4);
  END IF;

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    unit_of_measure, pricing_uom, pricing_cost_exw,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    dealer_price, msrp, updated_at
  )
  VALUES (
    p_catalog_item_id, p_organization_id, v_ci.category_id,
    v_ci.unit_of_measure, v_pricing_uom, v_pricing_cost_exw,
    v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct,
    COALESCE(v_dealer_price, 0), COALESCE(v_msrp, 0), now()
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    pricing_cost_exw   = EXCLUDED.pricing_cost_exw,
    unit_of_measure    = EXCLUDED.unit_of_measure,
    pricing_uom        = EXCLUDED.pricing_uom,
    shipping_pct       = EXCLUDED.shipping_pct,
    import_tax_pct     = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    msrp_pct           = EXCLUDED.msrp_pct,
    dealer_price       = EXCLUDED.dealer_price,
    msrp               = EXCLUDED.msrp,
    updated_at         = now();
END;
$$;


ALTER FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") IS 'Recompute CatalogItemsMSRP con conversión UOM y fórmula compuesta.
NO almacena cost_exw (purchase cost vive en CatalogItems).
NO escribe columnas GENERATED.';



CREATE OR REPLACE FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" "uuid", "p_category_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_item RECORD;
BEGIN
  FOR v_item IN
    WITH RECURSIVE descendants(category_id) AS (
      SELECT id FROM public."CatalogCategories" WHERE id = p_category_id
      UNION ALL
      SELECT cc.id
      FROM   public."CatalogCategories" cc
      JOIN   descendants d ON cc.parent_id = d.category_id
    )
    SELECT ci.id
    FROM   public."CatalogItems" ci
    WHERE  ci.organization_id = p_org_id
      AND  ci.category_id IN (SELECT category_id FROM descendants)
      AND  ci.is_active = true
  LOOP
    PERFORM public."recompute_catalog_item_msrp"(p_org_id, v_item.id);
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" "uuid", "p_category_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" "uuid", "p_category_id" "uuid") IS 'Recompute CatalogItemsMSRP para una categoría y sus descendientes.
Delega en recompute_catalog_item_msrp (no escribe columnas GENERATED).';



CREATE OR REPLACE FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_item RECORD;
BEGIN
  FOR v_item IN
    SELECT id
    FROM   public."CatalogItems"
    WHERE  organization_id = p_org
      AND  is_active = true
  LOOP
    PERFORM public."recompute_catalog_item_msrp"(p_org, v_item.id);
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" "uuid") IS 'Recompute CatalogItemsMSRP para toda la org.
Delega en recompute_catalog_item_msrp (no escribe columnas GENERATED).';



CREATE OR REPLACE FUNCTION "public"."recompute_quote_line_costs"("p_quote_line_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_ql RECORD;
  v_qty numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_unit_labor_msrp numeric(12,4);
  v_unit_msrp_product_subtotal numeric(12,4);
  v_unit_cost numeric(12,4);
  v_unit_labor_cost numeric(12,4);
  v_unit_product_cost numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'recompute_quote_line_costs: p_quote_line_id is required';
  END IF;

  SELECT *
  INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  IF v_ql.configured_product_id IS NOT NULL THEN
    PERFORM public.sync_quote_line_pricing_from_configured_product(p_quote_line_id);
    RETURN;
  END IF;

  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);

  v_unit_labor_msrp := COALESCE(v_ql.unit_labor_msrp, v_ql.labor_msrp_snapshot, 0);
  v_unit_msrp_product_subtotal := COALESCE(v_ql.unit_msrp_product_subtotal, COALESCE(v_ql.roll_msrp_snapshot, 0) + COALESCE(v_ql.bom_msrp_snapshot, 0) + COALESCE(v_ql.accessories_msrp_snapshot, 0));
  v_unit_msrp := COALESCE(v_ql.unit_msrp, v_unit_msrp_product_subtotal + v_unit_labor_msrp, 0);

  v_unit_labor_cost := COALESCE(v_ql.unit_labor_cost, v_ql.labor_cost_snapshot, 0);
  v_unit_product_cost := COALESCE(v_ql.unit_product_cost, COALESCE(v_ql.roll_cost_snapshot, 0) + COALESCE(v_ql.bom_cost_snapshot, 0) + COALESCE(v_ql.accessories_cost_snapshot, 0));
  v_unit_cost := COALESCE(v_ql.unit_cost, v_unit_product_cost + v_unit_labor_cost, 0);

  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    unit_labor_msrp = v_unit_labor_msrp,
    unit_msrp_product_subtotal = v_unit_msrp_product_subtotal,
    unit_msrp = v_unit_msrp,
    msrp = ROUND(v_unit_msrp * v_qty, 2),
    unit_labor_cost = v_unit_labor_cost,
    unit_product_cost = v_unit_product_cost,
    unit_cost = v_unit_cost,
    total_cost = ROUND(v_unit_cost * v_qty, 2),
    last_priced_at = now()
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;


ALTER FUNCTION "public"."recompute_quote_line_costs"("p_quote_line_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."recompute_quote_line_costs"("p_quote_line_id" "uuid") IS 'Recomputes QuoteLine pricing/costs. Delegates to sync if configured_product_id exists; otherwise enforces split + unit*qty invariants.';



CREATE OR REPLACE FUNCTION "public"."reject_oneoff_keys"("p_config" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_has_oneoff boolean := false;
  v_key text;
BEGIN
  IF p_config IS NULL THEN
    RETURN;
  END IF;

  -- Check top-level keys only (no jsonpath — avoids "syntax error at or near " " of jsonpath input")
  FOR v_key IN SELECT jsonb_object_keys(p_config)
  LOOP
    IF v_key LIKE 'oneoff\_%' ESCAPE '\' THEN
      v_has_oneoff := true;
      EXIT;
    END IF;
  END LOOP;

  IF v_has_oneoff THEN
    RAISE EXCEPTION 'OneOff is disabled. Remove oneoff_* fields from config_snapshot.';
  END IF;
END;
$$;


ALTER FUNCTION "public"."reject_oneoff_keys"("p_config" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."reject_oneoff_keys"("p_config" "jsonb") IS 'Raises exception if config jsonb contains any top-level oneoff_* keys (OneOff disabled). Uses jsonb_object_keys only to avoid jsonpath parse errors.';



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


CREATE OR REPLACE FUNCTION "public"."resolve_catalog_item_landed_price_cost"("p_org_id" "uuid", "p_item_id" "uuid") RETURNS TABLE("unit_msrp" numeric, "unit_cost" numeric)
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  v_msrp numeric := 0;
  v_total_cost numeric := 0;
  v_cost_exw numeric := 0;
  v_shipping_pct numeric := 0;
  v_import_tax_pct numeric := 0;
BEGIN
  IF p_item_id IS NULL THEN
    RETURN QUERY SELECT 0::numeric, 0::numeric;
    RETURN;
  END IF;

  SELECT m.msrp, m.total_cost
  INTO v_msrp, v_total_cost
  FROM public."CatalogItemsMSRP" m
  WHERE m.catalog_item_id = p_item_id
    AND m.organization_id = p_org_id
  LIMIT 1;

  IF v_msrp IS NULL THEN
    SELECT m.msrp, m.total_cost
    INTO v_msrp, v_total_cost
    FROM public."CatalogItemsMSRP" m
    WHERE m.catalog_item_id = p_item_id
    LIMIT 1;
  END IF;

  IF v_total_cost IS NULL THEN
    SELECT COALESCE(ci.cost_exw, 0)
    INTO v_cost_exw
    FROM public."CatalogItems" ci
    WHERE ci.id = p_item_id
    LIMIT 1;

    SELECT COALESCE(cs.shipping_pct, 0), COALESCE(cs.import_tax_pct, 0)
    INTO v_shipping_pct, v_import_tax_pct
    FROM public."CostSettings" cs
    WHERE cs.organization_id = p_org_id
    LIMIT 1;

    v_total_cost := v_cost_exw + (v_cost_exw * v_shipping_pct) + ((v_cost_exw + (v_cost_exw * v_shipping_pct)) * v_import_tax_pct);
  END IF;

  RETURN QUERY SELECT COALESCE(v_msrp, v_total_cost, 0), COALESCE(v_total_cost, 0);
END;
$$;


ALTER FUNCTION "public"."resolve_catalog_item_landed_price_cost"("p_org_id" "uuid", "p_item_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."resolve_catalog_item_landed_price_cost"("p_org_id" "uuid", "p_item_id" "uuid") IS 'Resolves landed MSRP and landed cost for one catalog item. Uses CatalogItemsMSRP first, then CostSettings fallback from CatalogItems.cost_exw.';



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



CREATE OR REPLACE FUNCTION "public"."resolve_dealer_discount_pct"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_product_type_id" "uuid" DEFAULT NULL::"uuid") RETURNS numeric
    LANGUAGE "sql" STABLE
    AS $$
  SELECT COALESCE(
    (SELECT (dt.discount_pct / 100.0)::numeric
     FROM public."Dealers" d
     LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id AND dt.organization_id = p_org_id
     WHERE p_dealer_id IS NOT NULL AND d.id = p_dealer_id AND d.organization_id = p_org_id
     LIMIT 1),
    0.65
  );
$$;


ALTER FUNCTION "public"."resolve_dealer_discount_pct"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_product_type_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."resolve_dealer_discount_pct"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_product_type_id" "uuid") IS 'Returns dealer discount as 0-1 (0.65 = 65% off). Source: Dealers.dealer_tier_id -> DealerTiers.discount_pct. Fallback 0.65 if no config.';



CREATE OR REPLACE FUNCTION "public"."resolve_default_terms_template_id"("p_organization_id" "uuid", "p_dealer_id" "uuid", "p_doc_type" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_template_id uuid;
begin
  if p_doc_type not in ('quote','proposal','sales_order') then
    raise exception 'Invalid doc_type: %', p_doc_type;
  end if;

  -- Solo default explícito por dealer; sin fallback global
  select d.template_id
  into v_template_id
  from public."DealerDocumentTermsDefaults" d
  where d.organization_id = p_organization_id
    and d.dealer_id = p_dealer_id
    and d.doc_type = p_doc_type
  limit 1;

  return v_template_id;
end;
$$;


ALTER FUNCTION "public"."resolve_default_terms_template_id"("p_organization_id" "uuid", "p_dealer_id" "uuid", "p_doc_type" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."resolve_default_terms_template_id"("p_organization_id" "uuid", "p_dealer_id" "uuid", "p_doc_type" "text") IS 'Returns template_id for dealer-specific default only. No global fallback to avoid dealer mixing.';



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


CREATE OR REPLACE FUNCTION "public"."round_up_to_increment"("p_value" numeric, "p_increment" numeric) RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
BEGIN
    IF p_increment IS NULL OR p_increment <= 0 THEN
        RETURN p_value;
    END IF;
    RETURN CEIL(p_value / p_increment) * p_increment;
END;
$$;


ALTER FUNCTION "public"."round_up_to_increment"("p_value" numeric, "p_increment" numeric) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."round_up_to_increment"("p_value" numeric, "p_increment" numeric) IS 'Rounds value up to the nearest multiple of increment. If increment is null or <=0 returns value unchanged.';



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



CREATE TABLE IF NOT EXISTS "public"."FabricRules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "product_type_id" "uuid" NOT NULL,
    "style_code" "text",
    "formula_code" "text" NOT NULL,
    "height_multiplier" numeric DEFAULT 1 NOT NULL,
    "width_multiplier" numeric DEFAULT 1 NOT NULL,
    "fullness_factor" numeric DEFAULT 1 NOT NULL,
    "extra_height_m" numeric DEFAULT 0 NOT NULL,
    "extra_width_m" numeric DEFAULT 0 NOT NULL,
    "pricing_output_uom" "text" NOT NULL,
    "waste_pct" numeric DEFAULT 0.15 NOT NULL,
    "round_to_increment" numeric DEFAULT 0.01 NOT NULL,
    "min_qty" numeric DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "FabricRules_formula_code_check" CHECK (("formula_code" = ANY (ARRAY['ROLLER_DROPS'::"text", 'AREA_BASED'::"text"]))),
    CONSTRAINT "FabricRules_pricing_output_uom_check" CHECK (("pricing_output_uom" = ANY (ARRAY['m'::"text", 'm2'::"text"])))
);


ALTER TABLE "public"."FabricRules" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."select_fabric_rule"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_style_code" "text") RETURNS SETOF "public"."FabricRules"
    LANGUAGE "plpgsql" STABLE
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


ALTER FUNCTION "public"."select_fabric_rule"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_style_code" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."select_fabric_rule"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_style_code" "text") IS 'Returns the active FabricRule for org/product_type and optional style_code. One row or none.';



CREATE OR REPLACE FUNCTION "public"."session_is_admin"("p_org_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT public.session_is_org_user(p_org_id)
    AND current_setting('app.role_code', true) IN ('owner', 'admin', 'superadmin');
$$;


ALTER FUNCTION "public"."session_is_admin"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."session_is_admin"("p_org_id" "uuid") IS 'True if session is org admin/owner/superadmin for given org.';



CREATE OR REPLACE FUNCTION "public"."session_is_dealer_portal"("p_dealer_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT current_setting('app.user_type', true) = 'dealer'
    AND NULLIF(trim(current_setting('app.dealer_id', true)), '')::uuid = p_dealer_id;
$$;


ALTER FUNCTION "public"."session_is_dealer_portal"("p_dealer_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."session_is_dealer_portal"("p_dealer_id" "uuid") IS 'True if session is dealer portal for given dealer_id.';



CREATE OR REPLACE FUNCTION "public"."session_is_dealer_user"("p_org_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT current_setting('app.user_type', true) = 'dealer'
    AND NULLIF(trim(current_setting('app.organization_id', true)), '')::uuid = p_org_id;
$$;


ALTER FUNCTION "public"."session_is_dealer_user"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."session_is_dealer_user"("p_org_id" "uuid") IS 'True if session context is dealer (portal) user for given org.';



CREATE OR REPLACE FUNCTION "public"."session_is_org_user"("p_org_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT current_setting('app.user_type', true) = 'org'
    AND NULLIF(trim(current_setting('app.organization_id', true)), '')::uuid = p_org_id;
$$;


ALTER FUNCTION "public"."session_is_org_user"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."session_is_org_user"("p_org_id" "uuid") IS 'True if session context is org user for given org.';



CREATE OR REPLACE FUNCTION "public"."set_acting_dealer"("p_dealer_id" "uuid") RETURNS TABLE("active_dealer_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_app_user_id uuid;
  v_org_id uuid;
  v_user_type text;
  v_ok boolean;
BEGIN
  SELECT id, organization_id, user_type
    INTO v_app_user_id, v_org_id, v_user_type
  FROM public."AppUsers"
  WHERE auth_user_id = auth.uid()
    AND deleted = false
  ORDER BY CASE WHEN user_type = 'org' THEN 0 ELSE 1 END
  LIMIT 1;

  IF v_app_user_id IS NULL THEN
    RAISE EXCEPTION 'AppUser not found for auth user';
  END IF;

  IF v_user_type <> 'org' THEN
    RAISE EXCEPTION 'Only org users can use acting-as';
  END IF;

  IF p_dealer_id IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM public."Dealers" d
      WHERE d.id = p_dealer_id
        AND d.organization_id = v_org_id
        AND (d.deleted IS NULL OR d.deleted = false)
    ) INTO v_ok;

    IF NOT v_ok THEN
      RAISE EXCEPTION 'Dealer not in same organization or does not exist';
    END IF;
  END IF;

  INSERT INTO public."AppUserPreferences"(user_id, active_dealer_id)
  VALUES (v_app_user_id, p_dealer_id)
  ON CONFLICT (user_id)
  DO UPDATE SET active_dealer_id = excluded.active_dealer_id;

  -- So that the rest of the transaction sees the new acting dealer
  PERFORM set_config('app.dealer_id', COALESCE(p_dealer_id::text, ''), true);

  RETURN QUERY SELECT p_dealer_id;
END;
$$;


ALTER FUNCTION "public"."set_acting_dealer"("p_dealer_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."set_acting_dealer"("p_dealer_id" "uuid") IS 'Sets acting-as dealer for org user and app.dealer_id in session. Call init_session_context() in next request so RLS sees it.';



CREATE OR REPLACE FUNCTION "public"."set_audit_app_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if tg_op = 'INSERT' then
    new.created_by_app_user_id := public.current_app_user_id();
    new.updated_by_app_user_id := public.current_app_user_id();
  elsif tg_op = 'UPDATE' then
    new.updated_by_app_user_id := public.current_app_user_id();
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."set_audit_app_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_audit_fields"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_is_dealer boolean;
  v_dealer_id uuid;
  v_portal_email text;
  v_portal_name text;
BEGIN
  v_is_dealer := public.is_dealer_user_for_org(new.organization_id);
  v_dealer_id := public.current_dealer_id_for_org(new.organization_id);

  IF v_is_dealer THEN
    SELECT du.portal_user_email, du.portal_user_name
      INTO v_portal_email, v_portal_name
    FROM public."DealerUsers" du
    WHERE du.organization_id = new.organization_id
      AND du.user_id = auth.uid()
      AND coalesce(du.deleted, false) = false
      AND (du.status IS NULL OR du.status IN ('active','invited'))
    ORDER BY du.created_at DESC
    LIMIT 1;
  END IF;

  IF tg_op = 'INSERT' THEN
    BEGIN
      IF new.created_by_user_id IS NULL THEN new.created_by_user_id := auth.uid(); END IF;
    EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

    BEGIN
      IF new.created_by_email IS NULL THEN new.created_by_email := coalesce(v_portal_email, public.jwt_email()); END IF;
    EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

    BEGIN
      IF new.created_by_user_name IS NULL THEN new.created_by_user_name := coalesce(v_portal_name, public.jwt_name()); END IF;
    EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

    BEGIN
      IF new.created_by_user_type IS NULL THEN new.created_by_user_type := CASE WHEN v_is_dealer THEN 'portal' ELSE 'internal' END; END IF;
    EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

    BEGIN
      IF new.created_by_dealer_id IS NULL THEN new.created_by_dealer_id := v_dealer_id; END IF;
    EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;
  END IF;

  BEGIN
    new.updated_by_user_id := auth.uid();
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  BEGIN
    new.updated_by_email := coalesce(v_portal_email, public.jwt_email());
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  BEGIN
    new.updated_by_user_name := coalesce(v_portal_name, public.jwt_name());
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  BEGIN
    new.updated_by_user_type := CASE WHEN v_is_dealer THEN 'portal' ELSE 'internal' END;
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  BEGIN
    new.updated_by_dealer_id := v_dealer_id;
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  RETURN new;
END;
$$;


ALTER FUNCTION "public"."set_audit_fields"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."set_audit_fields"() IS 'Audit fields. Checks column existence to support tables that dropped legacy columns (Quotes, Proposals).';



CREATE OR REPLACE FUNCTION "public"."set_created_by_fields"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
BEGIN
  BEGIN
    IF new.created_by_user_id IS NULL THEN new.created_by_user_id := auth.uid(); END IF;
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  BEGIN
    IF new.created_by_email IS NULL THEN new.created_by_email := public.current_user_email(); END IF;
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  RETURN new;
END;
$$;


ALTER FUNCTION "public"."set_created_by_fields"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."set_created_by_fields"() IS 'Sets created_by_user_id and created_by_email. Checks column existence for Quotes/Proposals that dropped legacy columns.';



CREATE OR REPLACE FUNCTION "public"."set_dealer_default_terms_template"("p_dealer_id" "uuid", "p_doc_type" "text", "p_template_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_org_id uuid;
  v_dealer_org uuid;
  v_template_org uuid;
  v_template_dealer uuid;
begin
  if p_doc_type not in ('quote','proposal','sales_order') then
    raise exception 'Invalid doc_type: %', p_doc_type;
  end if;

  -- Caller org: OrganizationUsers (internal) OR DealerUsers member_manager (portal)
  select ou.organization_id into v_org_id
  from public."OrganizationUsers" ou
  where ou.user_id = auth.uid()
    and (ou.deleted is null or ou.deleted = false)
  limit 1;

  if v_org_id is null then
    -- Portal: Dealer Manager for this dealer
    if not public.is_dealer_portal_user_with_write(p_dealer_id) then
      raise exception 'Permission denied: only org users or dealer managers for their dealer';
    end if;
    select d.organization_id into v_org_id
    from public."Dealers" d
    where d.id = p_dealer_id and (d.deleted is null or d.deleted = false)
    limit 1;
  end if;

  if v_org_id is null then
    raise exception 'User is not a member of any organization';
  end if;

  -- Validate dealer in org
  select d.organization_id into v_dealer_org
  from public."Dealers" d
  where d.id = p_dealer_id and (d.deleted is null or d.deleted = false);

  if v_dealer_org is null or v_dealer_org <> v_org_id then
    raise exception 'Dealer % not found in your organization', p_dealer_id;
  end if;

  -- Validate template belongs to org and is either global or same dealer
  select t.organization_id, t.dealer_id
    into v_template_org, v_template_dealer
  from public."DocumentTermsTemplates" t
  where t.id = p_template_id;

  if v_template_org is null or v_template_org <> v_org_id then
    raise exception 'Template not in your organization';
  end if;

  if v_template_dealer is not null and v_template_dealer <> p_dealer_id then
    raise exception 'Template is not global nor for this dealer';
  end if;

  insert into public."DealerDocumentTermsDefaults" (
    organization_id, dealer_id, doc_type, template_id, updated_by_auth_user_id, updated_at
  ) values (
    v_org_id, p_dealer_id, p_doc_type, p_template_id, auth.uid(), now()
  )
  on conflict (dealer_id, doc_type) do update
    set template_id = excluded.template_id,
        organization_id = excluded.organization_id,
        updated_by_auth_user_id = excluded.updated_by_auth_user_id,
        updated_at = now();
end;
$$;


ALTER FUNCTION "public"."set_dealer_default_terms_template"("p_dealer_id" "uuid", "p_doc_type" "text", "p_template_id" "uuid") OWNER TO "postgres";


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



CREATE OR REPLACE FUNCTION "public"."set_effective_dealer_id"("p_dealer_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_org_id uuid;
  v_dealer_org uuid;
BEGIN
  -- Resolve caller's organization
  SELECT organization_id INTO v_org_id
  FROM public."OrganizationUsers"
  WHERE user_id = auth.uid()
    AND (deleted IS NULL OR deleted = false)
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'User is not a member of any organization';
  END IF;

  -- Validate dealer belongs to same org
  IF p_dealer_id IS NOT NULL THEN
    SELECT organization_id INTO v_dealer_org
    FROM public."Dealers"
    WHERE id = p_dealer_id AND (deleted IS NULL OR deleted = false);

    IF v_dealer_org IS NULL OR v_dealer_org != v_org_id THEN
      RAISE EXCEPTION 'Dealer % not found in organization %', p_dealer_id, v_org_id;
    END IF;
  END IF;

  -- Upsert scope
  INSERT INTO public.user_dealer_scope (user_id, organization_id, effective_dealer_id, updated_at)
  VALUES (auth.uid(), v_org_id, p_dealer_id, now())
  ON CONFLICT (user_id) DO UPDATE
    SET effective_dealer_id = EXCLUDED.effective_dealer_id,
        organization_id    = EXCLUDED.organization_id,
        updated_at         = now();

  RETURN p_dealer_id;
END;
$$;


ALTER FUNCTION "public"."set_effective_dealer_id"("p_dealer_id" "uuid") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."set_quote_line_msrp_from_value"("p_quote_line_id" "uuid", "p_total_msrp" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_ql RECORD;
  v_qty numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_line_msrp numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'set_quote_line_msrp_from_value: p_quote_line_id is required';
  END IF;
  IF p_total_msrp IS NULL OR p_total_msrp < 0 THEN
    RETURN;
  END IF;

  SELECT id, organization_id, quantity
  INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);
  v_unit_msrp := ROUND(p_total_msrp, 4);
  v_line_msrp := ROUND(v_unit_msrp * v_qty, 2);

  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    msrp = v_line_msrp,
    unit_msrp = v_unit_msrp,
    last_priced_at = now()
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;


ALTER FUNCTION "public"."set_quote_line_msrp_from_value"("p_quote_line_id" "uuid", "p_total_msrp" numeric) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."set_quote_line_msrp_from_value"("p_quote_line_id" "uuid", "p_total_msrp" numeric) IS 'Sets QuoteLine unit_msrp (per-unit) and msrp=unit_msrp*qty. p_total_msrp is the price for ONE unit.';



CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $$;


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


CREATE OR REPLACE FUNCTION "public"."soft_delete_directory_contact"("p_contact_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public."DirectoryContacts" c
  SET deleted = true, updated_at = now()
  WHERE c.id = p_contact_id
    AND (c.deleted IS NULL OR c.deleted = false)
    AND c.organization_id IS NOT NULL
    AND (
      public.is_org_user_member(c.organization_id)
      OR (public.current_dealer_id(c.organization_id) IS NOT NULL AND c.dealer_id = public.current_dealer_id(c.organization_id))
    );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."soft_delete_directory_contact"("p_contact_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."soft_delete_directory_contact"("p_contact_id" "uuid") IS 'Soft-delete a directory contact. Only if current user has access (org member or same dealer).';



CREATE OR REPLACE FUNCTION "public"."soft_delete_directory_customer"("p_customer_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public."DirectoryCustomers" c
  SET deleted = true, updated_at = now()
  WHERE c.id = p_customer_id
    AND (c.deleted IS NULL OR c.deleted = false)
    AND c.organization_id IS NOT NULL
    AND (
      public.is_org_user_member(c.organization_id)
      OR (public.current_dealer_id(c.organization_id) IS NOT NULL AND c.dealer_id = public.current_dealer_id(c.organization_id))
    );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."soft_delete_directory_customer"("p_customer_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."soft_delete_directory_customer"("p_customer_id" "uuid") IS 'Soft-delete a directory customer. Only if current user has access (org member or same dealer).';



CREATE OR REPLACE FUNCTION "public"."soft_delete_proposals"("p_proposal_ids" "uuid"[]) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public."Proposals" p
  SET deleted = true, updated_at = now()
  WHERE p.id = ANY(p_proposal_ids)
    AND (p.deleted IS NULL OR p.deleted = false)
    AND p.organization_id IS NOT NULL
    AND (
      public.is_org_user_member(p.organization_id)
      OR (public.current_dealer_id(p.organization_id) IS NOT NULL AND p.dealer_id = public.current_dealer_id(p.organization_id))
    );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."soft_delete_proposals"("p_proposal_ids" "uuid"[]) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."soft_delete_proposals"("p_proposal_ids" "uuid"[]) IS 'Soft-delete proposals by ID. Only rows the current user can access (org member or same dealer).';



CREATE OR REPLACE FUNCTION "public"."soft_delete_quotes"("p_quote_ids" "uuid"[]) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public."Quotes" q
  SET deleted = true, updated_at = now()
  WHERE q.id = ANY(p_quote_ids)
    AND (q.deleted IS NULL OR q.deleted = false)
    AND q.organization_id IS NOT NULL
    AND (
      public.is_org_user_member(q.organization_id)
      OR (public.current_dealer_id(q.organization_id) IS NOT NULL AND q.dealer_id = public.current_dealer_id(q.organization_id))
    );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."soft_delete_quotes"("p_quote_ids" "uuid"[]) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."soft_delete_quotes"("p_quote_ids" "uuid"[]) IS 'Soft-delete quotes by ID. Only rows the current user can access (org member or same dealer).';



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
    sku, name, collection_name, variant_name,
    unit_of_measure,
    pricing_uom,
    pricing_cost_exw,
    dealer_price, msrp
  )
  VALUES (
    NEW.id, NEW.organization_id, NEW.category_id,
    NEW.sku, NEW.name, NEW.collection_name, NEW.variant_name,
    NEW.unit_of_measure,
    public.derive_pricing_uom(NEW.measure_basis, NEW.roll_pricing_mode, NEW.is_roll),
    COALESCE(NEW.cost_exw, 0),
    0, 0
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    sku             = EXCLUDED.sku,
    name            = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name    = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure,
    pricing_uom     = EXCLUDED.pricing_uom,
    category_id     = EXCLUDED.category_id,
    updated_at      = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_catalogitems_to_msrp"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_catalogitems_to_msrp"() IS 'Sync identidad + pricing_uom desde CatalogItems a CatalogItemsMSRP.
INSERT: pricing_cost_exw = cost_exw inicial (sin conversión); msrp_compute_for_item corrige después.
ON CONFLICT: solo toca identidad. NO escribe cost_exw en CIM (fue eliminado).
NO escribe columnas GENERATED.';



CREATE OR REPLACE FUNCTION "public"."sync_catalogitems_to_msrp_safe"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_new_pricing_uom text;
  v_should_recompute boolean := false;
BEGIN
  v_new_pricing_uom := public.derive_pricing_uom(
    NEW.measure_basis, NEW.roll_pricing_mode, NEW.is_roll
  );

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    pricing_cost_exw,
    dealer_price, msrp,
    sku, name, collection_name, variant_name,
    unit_of_measure,
    pricing_uom,
    updated_at
  )
  VALUES (
    NEW.id, NEW.organization_id, NEW.category_id,
    COALESCE(NEW.cost_exw, 0),
    0, 0,
    NEW.sku, NEW.name, NEW.collection_name, NEW.variant_name,
    NEW.unit_of_measure,
    v_new_pricing_uom,
    now()
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    sku             = EXCLUDED.sku,
    name            = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name    = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure,
    pricing_uom     = EXCLUDED.pricing_uom,
    category_id     = EXCLUDED.category_id,
    updated_at      = now();

  -- Si cambió unit_of_measure, measure_basis o roll_pricing_mode,
  -- el pricing_uom y pricing_cost_exw en CIM quedaron stale.
  -- Llamar msrp_compute_for_item para recalcular completamente.
  IF TG_OP = 'INSERT' THEN
    v_should_recompute := true;
  ELSIF TG_OP = 'UPDATE' THEN
    v_should_recompute := (
      (OLD.unit_of_measure   IS DISTINCT FROM NEW.unit_of_measure)  OR
      (OLD.measure_basis     IS DISTINCT FROM NEW.measure_basis)     OR
      (OLD.roll_pricing_mode IS DISTINCT FROM NEW.roll_pricing_mode) OR
      (OLD.cost_exw          IS DISTINCT FROM NEW.cost_exw)
    );
  END IF;

  IF v_should_recompute AND COALESCE(NEW.cost_exw, 0) > 0 THEN
    PERFORM public.msrp_compute_for_item(NEW.id);
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_catalogitems_to_msrp_safe"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_catalogitems_to_msrp_safe"() IS 'Sync identidad + pricing_uom desde CatalogItems a CatalogItemsMSRP.
Si cambia unit_of_measure, measure_basis, roll_pricing_mode o cost_exw,
llama msrp_compute_for_item para recalcular pricing_cost_exw, dealer_price y msrp.
NO escribe columnas GENERATED.';



CREATE OR REPLACE FUNCTION "public"."sync_dealer_user_to_appuser"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.deleted = true AND (OLD.deleted = false OR OLD.deleted IS NULL) AND OLD.user_id IS NOT NULL THEN
    UPDATE public."AppUsers"
    SET deleted = true, updated_at = now()
    WHERE auth_user_id = OLD.user_id
      AND user_type = 'dealer'
      AND dealer_id = OLD.dealer_id
      AND deleted = false;
    RETURN NEW;
  END IF;

  IF NEW.user_id IS NULL OR (NEW.deleted = true) THEN
    RETURN NEW;
  END IF;

  INSERT INTO public."AppUsers" (
    organization_id, user_type, dealer_id, auth_user_id, email, display_name,
    role_code, status, must_change_password, deleted, created_at, updated_at,
    temp_password_set_at
  )
  VALUES (
    NEW.organization_id,
    'dealer',
    NEW.dealer_id,
    NEW.user_id,
    NEW.portal_user_email,
    NEW.portal_user_name,
    COALESCE(NEW.role::text, 'dealer_member'),
    COALESCE(NEW.status, 'active'),
    COALESCE(NEW.must_change_password, false),
    COALESCE(NEW.deleted, false),
    COALESCE(NEW.created_at, now()),
    COALESCE(NEW.updated_at, now()),
    NEW.temp_password_set_at
  )
  ON CONFLICT (auth_user_id, user_type, COALESCE(dealer_id, '00000000-0000-0000-0000-000000000000'::uuid))
  DO UPDATE SET
    email = EXCLUDED.email,
    display_name = EXCLUDED.display_name,
    role_code = EXCLUDED.role_code,
    status = EXCLUDED.status,
    must_change_password = EXCLUDED.must_change_password,
    deleted = EXCLUDED.deleted,
    temp_password_set_at = EXCLUDED.temp_password_set_at,
    updated_at = now();

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_dealer_user_to_appuser"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_dealer_user_to_appuser"() IS 'Trigger: sync DealerUsers -> AppUsers (dealer row). Upsert by (auth_user_id, user_type, dealer_id).';



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



CREATE OR REPLACE FUNCTION "public"."sync_org_user_to_appuser"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Soft delete: marcar AppUser como deleted
  IF NEW.deleted = true AND (OLD.deleted = false OR OLD.deleted IS NULL) THEN
    UPDATE public."AppUsers"
    SET deleted = true, updated_at = now()
    WHERE auth_user_id = OLD.user_id
      AND user_type = 'org'
      AND organization_id = OLD.organization_id
      AND deleted = false;
    RETURN NEW;
  END IF;

  -- Solo sincronizar si tiene user_id y no está deleted
  IF NEW.user_id IS NULL OR NEW.deleted = true THEN
    RETURN NEW;
  END IF;

  INSERT INTO public."AppUsers" (
    organization_id, user_type, dealer_id, auth_user_id, email, display_name,
    role_code, status, must_change_password, deleted, created_at, updated_at,
    temp_password_set_at
  )
  VALUES (
    NEW.organization_id,
    'org',
    NULL,
    NEW.user_id,
    NEW.user_email,
    NEW.user_name,
    COALESCE(NEW.role::text, 'member'),
    COALESCE(NEW.status, 'active'),
    COALESCE(NEW.must_change_password, false),
    false,
    COALESCE(NEW.created_at, now()),
    COALESCE(NEW.updated_at, now()),
    NEW.temp_password_set_at
  )
  ON CONFLICT (auth_user_id, user_type, COALESCE(dealer_id, '00000000-0000-0000-0000-000000000000'::uuid))
  DO UPDATE SET
    email = EXCLUDED.email,
    display_name = EXCLUDED.display_name,
    role_code = EXCLUDED.role_code,
    status = EXCLUDED.status,
    must_change_password = EXCLUDED.must_change_password,
    temp_password_set_at = EXCLUDED.temp_password_set_at,
    updated_at = now();

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_org_user_to_appuser"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_org_user_to_appuser"() IS 'Trigger: sync OrganizationUsers -> AppUsers (org row). Upsert by (auth_user_id, user_type, dealer_id).';



CREATE OR REPLACE FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_ql           RECORD;
  v_cp           RECORD;
  v_totals       jsonb;
  v_qty          numeric(12,4);
  v_unit_msrp    numeric(12,4);
  v_unit_cost    numeric(12,4);
  v_dealer_tier_id uuid;
  v_dealer_tier_code text;
  v_discount_pct numeric(5,2);
  v_unit_dealer_price numeric(12,4);
  v_catalog_dealer_unit numeric(12,4);
  v_labor_cost   numeric(12,4);
  v_labor_msrp   numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required';
  END IF;

  SELECT ql.id, ql.organization_id, ql.configured_product_id,
         ql.quantity, ql.pricing_locked, ql.quote_id
  INTO v_ql
  FROM public."QuoteLines" ql
  WHERE ql.id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;
  IF v_ql.configured_product_id IS NULL THEN RETURN; END IF;
  IF COALESCE(v_ql.pricing_locked, false) = true THEN RETURN; END IF;

  PERFORM public.calculate_configured_product_totals(v_ql.configured_product_id);

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = v_ql.configured_product_id
    AND organization_id = v_ql.organization_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found for QuoteLine %', v_ql.configured_product_id, p_quote_line_id;
  END IF;

  v_totals := COALESCE(v_cp.bom_preview_snapshot->'totals', '{}'::jsonb);
  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);

  v_unit_msrp := COALESCE(v_cp.total_msrp, (v_totals->>'total_msrp')::numeric, 0);

  v_labor_cost := COALESCE(v_cp.unit_labor_cost, (v_totals->>'labor_cost')::numeric, (v_totals->>'unit_labor_cost')::numeric, 0);
  v_labor_msrp := COALESCE(v_cp.labor_amount, v_cp.labor_msrp, (v_totals->>'labor_amount')::numeric, (v_totals->>'labor_msrp_total')::numeric, 0);

  v_unit_cost := COALESCE(v_cp.unit_product_cost, 0) + v_labor_cost;
  IF v_unit_cost = 0 THEN
    v_unit_cost := COALESCE(
      (v_totals->>'total_cost')::numeric,
      COALESCE(v_cp.roll_total_cost, 0)
        + COALESCE(v_cp.bom_total_cost, 0)
        + COALESCE(v_cp.accessories_total_cost, 0)
        + v_labor_cost,
      0
    );
  END IF;

  SELECT d.dealer_tier_id, dt.code, COALESCE(dt.discount_pct, 35)
  INTO v_dealer_tier_id, v_dealer_tier_code, v_discount_pct
  FROM public."Quotes" q
  JOIN public."Dealers" d ON d.id = q.dealer_id
  LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
  WHERE q.id = v_ql.quote_id
  LIMIT 1;

  IF v_discount_pct IS NULL THEN
    v_discount_pct := 35;
  END IF;

  v_unit_dealer_price := (v_totals->>'unit_dealer_price')::numeric;
  IF v_unit_dealer_price IS NULL OR v_unit_dealer_price <= 0 THEN
    v_unit_dealer_price := ROUND(v_unit_msrp * (1 - v_discount_pct / 100.0), 4);
  END IF;

  SELECT cim.dealer_price
  INTO v_catalog_dealer_unit
  FROM public."CatalogItemsMSRP" cim
  WHERE cim.organization_id = v_ql.organization_id
    AND cim.catalog_item_id = v_cp.roll_catalog_item_id
  ORDER BY cim.updated_at DESC NULLS LAST
  LIMIT 1;

  PERFORM set_config('app.write_source', 'rpc', true);

  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot         = COALESCE(v_cp.roll_msrp_total, (v_totals->>'roll_msrp_total')::numeric, 0),
    bom_msrp_snapshot          = COALESCE(v_cp.bom_total, (v_totals->>'bom_total')::numeric, 0),
    labor_msrp_snapshot        = v_labor_msrp,
    roll_cost_snapshot         = COALESCE(v_cp.roll_total_cost, (v_totals->>'roll_total_cost')::numeric, 0),
    bom_cost_snapshot          = COALESCE(v_cp.bom_total_cost, (v_totals->>'bom_total_cost')::numeric, 0),
    labor_cost_snapshot        = v_labor_cost,
    unit_msrp_total_snapshot   = v_unit_msrp,
    unit_cost_total_snapshot   = v_unit_cost,
    msrp                       = ROUND(v_unit_msrp * v_qty, 2),
    total_cost                 = ROUND(v_unit_cost * v_qty, 2),
    unit_dealer_price_snapshot = v_unit_dealer_price,
    dealer_price_total         = ROUND(v_unit_dealer_price * v_qty, 2),
    dealer_discount_pct        = v_discount_pct,
    dealer_tier_id_snapshot    = v_dealer_tier_id,
    dealer_tier_code_snapshot  = v_dealer_tier_code,
    catalog_dealer_unit_snapshot = v_catalog_dealer_unit,
    dealer_price_source        = 'tier',
    last_priced_at             = now(),
    pricing_version            = COALESCE(pricing_version, 0) + 1,
    pricing_locked             = true
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;


ALTER FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid") IS 'Refreshes QuoteLine pricing from ConfiguredProduct. Includes labor_cost_snapshot, labor_msrp_snapshot from labor chain.';



CREATE OR REPLACE FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid", "p_force" boolean DEFAULT false) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_ql RECORD;
  v_cp RECORD;
  v_totals jsonb;
  v_qty numeric(12,4);
  v_unit_dealer numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required';
  END IF;

  SELECT ql.id, ql.organization_id, ql.configured_product_id, ql.quantity, ql.pricing_locked
  INTO v_ql
  FROM public."QuoteLines" ql
  WHERE ql.id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;
  IF v_ql.configured_product_id IS NULL THEN RETURN; END IF;

  IF COALESCE(v_ql.pricing_locked, false) = true AND NOT p_force THEN
    RETURN;
  END IF;

  PERFORM public.calculate_configured_product_totals(v_ql.configured_product_id);

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = v_ql.configured_product_id
    AND organization_id = v_ql.organization_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found for QuoteLine %', v_ql.configured_product_id, p_quote_line_id;
  END IF;

  v_totals := COALESCE(v_cp.bom_preview_snapshot->'totals', '{}'::jsonb);
  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);

  v_unit_dealer := COALESCE(
    nullif((v_totals->>'unit_dealer_price')::numeric, 0),
    CASE
      WHEN (1 - COALESCE((SELECT cs.minimum_margin_pct FROM public."CostSettings" cs
            WHERE cs.organization_id = v_cp.organization_id AND COALESCE(cs.is_active, true)
            ORDER BY cs.created_at DESC LIMIT 1), 0.35)) > 0.01
      THEN v_cp.total_cost / (1 - COALESCE((SELECT cs.minimum_margin_pct FROM public."CostSettings" cs
            WHERE cs.organization_id = v_cp.organization_id AND COALESCE(cs.is_active, true)
            ORDER BY cs.created_at DESC LIMIT 1), 0.35))
      ELSE 0
    END
  );

  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);
  PERFORM set_config('app.write_source', 'rpc', true);

  -- COPY ONLY: from ConfiguredProducts; use QuoteLine quantity for line totals
  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot         = COALESCE(v_cp.roll_msrp_total, 0),
    bom_msrp_snapshot          = COALESCE(v_cp.bom_total, 0),
    labor_msrp_snapshot        = COALESCE(v_cp.labor_amount, 0),
    roll_cost_snapshot         = COALESCE((v_totals->>'roll_total_cost')::numeric, v_cp.roll_total_cost, 0),
    bom_cost_snapshot          = COALESCE((v_totals->>'bom_total_cost')::numeric, v_cp.bom_total_cost, 0),
    labor_cost_snapshot        = COALESCE(v_cp.unit_labor_cost, 0),
    unit_msrp_total_snapshot   = COALESCE(v_cp.total_msrp, 0),
    unit_cost_total_snapshot   = COALESCE(v_cp.total_cost, 0),
    unit_dealer_price_snapshot = v_unit_dealer,
    msrp                       = ROUND(COALESCE(v_cp.total_msrp, 0) * v_qty, 2),
    total_cost                 = ROUND(COALESCE(v_cp.total_cost, 0) * v_qty, 2),
    dealer_price_total         = ROUND(v_unit_dealer * v_qty, 2),
    last_priced_at             = now(),
    pricing_version            = COALESCE(pricing_version, 0) + 1
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;


ALTER FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid", "p_force" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid", "p_force" boolean) IS 'Refreshes QuoteLine pricing from ConfiguredProduct. COPY only. p_force=true ignores pricing_locked.';



CREATE OR REPLACE FUNCTION "public"."sync_quote_line_scope"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  select organization_id, dealer_id
  into NEW.organization_id, NEW.dealer_id
  from public."Quotes"
  where id = NEW.quote_id;

  return NEW;
end;
$$;


ALTER FUNCTION "public"."sync_quote_line_scope"() OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."trg_assert_cp_policy"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_dealer_id uuid;
begin
  if new.quote_id is not null then
    select q.dealer_id into v_dealer_id
    from public."Quotes" q
    where q.organization_id = new.organization_id
      and q.id = new.quote_id;
  end if;

  perform public.assert_dealer_configurator_policy(
    new.organization_id,
    v_dealer_id,
    new.product_type_id,
    coalesce(new.config_snapshot, '{}'::jsonb)
  );

  return new;
end;
$$;


ALTER FUNCTION "public"."trg_assert_cp_policy"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_assert_policy_configured_products"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_dealer_id uuid;
  v_product_type_id uuid;
  v_snapshot jsonb;
BEGIN
  -- Only enforce when row is tied to a quote that has dealer_id
  IF NEW.quote_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT q.dealer_id
    INTO v_dealer_id
  FROM public."Quotes" q
  WHERE q.id = NEW.quote_id
  LIMIT 1;

  IF v_dealer_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_product_type_id := NEW.product_type_id;
  v_snapshot := COALESCE(NEW.config_snapshot, '{}'::jsonb);

  PERFORM public.assert_dealer_configurator_policy(
    NEW.organization_id,
    v_dealer_id,
    v_product_type_id,
    v_snapshot
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_assert_policy_configured_products"() OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."trg_enforce_dealer_policy_on_configured_product"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_dealer_id uuid;
BEGIN

  IF NEW.quote_id IS NOT NULL THEN
    SELECT dealer_id
    INTO v_dealer_id
    FROM public."Quotes"
    WHERE id = NEW.quote_id
    LIMIT 1;
  END IF;

  IF v_dealer_id IS NOT NULL THEN
    PERFORM public.assert_dealer_configurator_policy(
      NEW.organization_id,
      v_dealer_id,
      NEW.product_type_id,
      COALESCE(NEW.config_snapshot, '{}'::jsonb)
    );
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_enforce_dealer_policy_on_configured_product"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_proposal_line_addons_recalc_totals"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_proposal_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_proposal_id := OLD.proposal_id;
  ELSE
    v_proposal_id := NEW.proposal_id;
  END IF;
  IF v_proposal_id IS NOT NULL THEN
    PERFORM public.recalc_proposal_totals(v_proposal_id);
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_proposal_line_addons_recalc_totals"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_proposal_lines_recalc_totals"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_proposal_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_proposal_id := OLD.proposal_id;
  ELSE
    v_proposal_id := NEW.proposal_id;
  END IF;
  IF v_proposal_id IS NOT NULL THEN
    PERFORM public.recalc_proposal_totals(v_proposal_id);
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_proposal_lines_recalc_totals"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_proposals_freeze_snapshot_on_sent"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF OLD.status = 'draft' AND NEW.status = 'sent' THEN
    PERFORM public.freeze_proposal_snapshot(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_proposals_freeze_snapshot_on_sent"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_proposals_recalc_totals"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF OLD.global_discount_pct IS DISTINCT FROM NEW.global_discount_pct
     OR OLD.global_fee_amount IS DISTINCT FROM NEW.global_fee_amount
     OR OLD.global_installation_discount_pct IS DISTINCT FROM NEW.global_installation_discount_pct
     OR OLD.global_installation_fee_pct IS DISTINCT FROM NEW.global_installation_fee_pct THEN
    PERFORM public.recalc_proposal_totals(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_proposals_recalc_totals"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_quote_lines_allow_pricing_write_only_via_rpc"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF current_setting('app.write_source', true) = 'rpc' THEN
    RETURN NEW;
  END IF;

  IF OLD.roll_msrp_snapshot            IS DISTINCT FROM NEW.roll_msrp_snapshot
     OR OLD.bom_msrp_snapshot          IS DISTINCT FROM NEW.bom_msrp_snapshot
     OR OLD.roll_cost_snapshot         IS DISTINCT FROM NEW.roll_cost_snapshot
     OR OLD.bom_cost_snapshot          IS DISTINCT FROM NEW.bom_cost_snapshot
     OR OLD.msrp                       IS DISTINCT FROM NEW.msrp
     OR OLD.total_cost                 IS DISTINCT FROM NEW.total_cost
     OR OLD.unit_msrp_total_snapshot   IS DISTINCT FROM NEW.unit_msrp_total_snapshot
     OR OLD.unit_cost_total_snapshot   IS DISTINCT FROM NEW.unit_cost_total_snapshot
     OR OLD.unit_dealer_price_snapshot IS DISTINCT FROM NEW.unit_dealer_price_snapshot
     OR OLD.dealer_price_total         IS DISTINCT FROM NEW.dealer_price_total
     OR OLD.dealer_discount_pct        IS DISTINCT FROM NEW.dealer_discount_pct
     OR OLD.dealer_tier_id_snapshot    IS DISTINCT FROM NEW.dealer_tier_id_snapshot
     OR OLD.dealer_tier_code_snapshot  IS DISTINCT FROM NEW.dealer_tier_code_snapshot
     OR OLD.catalog_dealer_unit_snapshot IS DISTINCT FROM NEW.catalog_dealer_unit_snapshot
     OR OLD.dealer_price_source        IS DISTINCT FROM NEW.dealer_price_source
     OR OLD.pricing_version            IS DISTINCT FROM NEW.pricing_version
     OR OLD.last_priced_at             IS DISTINCT FROM NEW.last_priced_at
  THEN
    RAISE EXCEPTION
      'QuoteLines: pricing/snapshot columns can only be written via '
      'commit_configured_product_to_quote_line or sync_quote_line_pricing_from_configured_product '
      '(set app.write_source=rpc). Protected: msrp, total_cost, unit_msrp_total_snapshot, '
      'unit_cost_total_snapshot, unit_dealer_price_snapshot, dealer_price_total, dealer_discount_pct, '
      'dealer_tier_id/code_snapshot, catalog_dealer_unit_snapshot, dealer_price_source, '
      'roll/bom snapshots, pricing_version, last_priced_at.';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_quote_lines_allow_pricing_write_only_via_rpc"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_quote_lines_guard_pricing_update"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_pricing_changed boolean := false;
  v_allowed text;
BEGIN
  v_allowed := current_setting('app.allow_quote_line_pricing_update', true);

  IF (OLD.msrp IS DISTINCT FROM NEW.msrp)
     OR (OLD.unit_msrp IS DISTINCT FROM NEW.unit_msrp)
     OR (OLD.unit_msrp_product_subtotal IS DISTINCT FROM NEW.unit_msrp_product_subtotal)
     OR (OLD.unit_labor_msrp IS DISTINCT FROM NEW.unit_labor_msrp)
     OR (OLD.roll_msrp_snapshot IS DISTINCT FROM NEW.roll_msrp_snapshot)
     OR (OLD.bom_msrp_snapshot IS DISTINCT FROM NEW.bom_msrp_snapshot)
     OR (OLD.accessories_msrp_snapshot IS DISTINCT FROM NEW.accessories_msrp_snapshot)
     OR (OLD.labor_msrp_snapshot IS DISTINCT FROM NEW.labor_msrp_snapshot)
     OR (OLD.roll_cost_snapshot IS DISTINCT FROM NEW.roll_cost_snapshot)
     OR (OLD.bom_cost_snapshot IS DISTINCT FROM NEW.bom_cost_snapshot)
     OR (OLD.accessories_cost_snapshot IS DISTINCT FROM NEW.accessories_cost_snapshot)
     OR (OLD.labor_cost_snapshot IS DISTINCT FROM NEW.labor_cost_snapshot)
     OR (OLD.unit_product_cost IS DISTINCT FROM NEW.unit_product_cost)
     OR (OLD.unit_labor_cost IS DISTINCT FROM NEW.unit_labor_cost)
     OR (OLD.unit_cost IS DISTINCT FROM NEW.unit_cost)
     OR (OLD.total_cost IS DISTINCT FROM NEW.total_cost)
     OR (OLD.last_priced_at IS DISTINCT FROM NEW.last_priced_at)
     OR (OLD.pricing_version IS DISTINCT FROM NEW.pricing_version)
     OR (OLD.pricing_locked IS DISTINCT FROM NEW.pricing_locked)
  THEN
    v_pricing_changed := true;
  END IF;

  IF v_pricing_changed AND COALESCE(trim(v_allowed), '') <> 'true' THEN
    RAISE EXCEPTION 'QuoteLines pricing columns can only be updated via pricing RPCs.';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_quote_lines_guard_pricing_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_reject_oneoff_on_configured_products"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  perform public.reject_oneoff_keys(new.config_snapshot);
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_reject_oneoff_on_configured_products"() OWNER TO "postgres";


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
DECLARE
  v_org uuid; v_cat uuid; r record; v_tc numeric;
BEGIN
  v_org := NEW.organization_id; v_cat := NEW.category_id;
  IF v_org IS NULL OR v_cat IS NULL THEN
    SELECT organization_id, category_id INTO v_org, v_cat
    FROM   public."CatalogItems" WHERE id = NEW.catalog_item_id;
    NEW.organization_id := COALESCE(NEW.organization_id, v_org);
    NEW.category_id     := COALESCE(NEW.category_id, v_cat);
  END IF;
  IF NEW.organization_id IS NULL OR NEW.category_id IS NULL THEN RETURN NEW; END IF;

  SELECT * INTO r FROM public.msrp_get_effective_rates(NEW.organization_id, NEW.category_id);
  NEW.shipping_pct       := COALESCE(r.shipping_pct, 0);
  NEW.import_tax_pct     := COALESCE(r.import_tax_pct, 0);
  NEW.minimum_margin_pct := COALESCE(r.minimum_margin_pct, 0);
  NEW.msrp_pct           := COALESCE(r.msrp_pct, 0);

  -- Recomputa dealer/msrp con fórmula compuesta si hay pricing_cost_exw
  IF COALESCE(NEW.pricing_cost_exw, 0) > 0 THEN
    v_tc := round(
      NEW.pricing_cost_exw * (1 + NEW.shipping_pct) * (1 + NEW.import_tax_pct), 4
    );
    NEW.dealer_price := round(v_tc / NULLIF(1 - NEW.minimum_margin_pct, 0), 4);
    NEW.msrp         := round(NEW.dealer_price / NULLIF(1 - NEW.msrp_pct, 0), 4);
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trig_enforce_msrp_sources"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."trig_enforce_msrp_sources"() IS 'BEFORE trigger: sincroniza shipping_pct/import_tax_pct/minimum_margin_pct/msrp_pct
desde msrp_get_effective_rates. Si pricing_cost_exw > 0, recomputa dealer_price/msrp.
NO escribe a columnas GENERATED (shipping_cost, import_tax_cost, total_cost).';



CREATE OR REPLACE FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF (TG_OP = 'INSERT') OR
     (TG_OP = 'UPDATE' AND (
       (OLD.cost_exw         IS DISTINCT FROM NEW.cost_exw)     OR
       (OLD.category_id      IS DISTINCT FROM NEW.category_id)  OR
       -- UOM/pricing changes that affect pricing_uom and pricing_cost_exw
       (OLD.unit_of_measure  IS DISTINCT FROM NEW.unit_of_measure)  OR
       (OLD.measure_basis    IS DISTINCT FROM NEW.measure_basis)     OR
       (OLD.roll_pricing_mode IS DISTINCT FROM NEW.roll_pricing_mode) OR
       (OLD.roll_width_m     IS DISTINCT FROM NEW.roll_width_m)      OR
       (OLD.roll_width       IS DISTINCT FROM NEW.roll_width)         OR
       (OLD.units_per_purchase_unit IS DISTINCT FROM NEW.units_per_purchase_unit)
     )) THEN
    PERFORM public.msrp_compute_for_item(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"() IS 'Recomputa CatalogItemsMSRP cuando cambian campos que afectan pricing:
cost_exw, category_id, unit_of_measure, measure_basis, roll_pricing_mode,
roll_width_m, roll_width, units_per_purchase_unit.
Llama a msrp_compute_for_item que recalcula pricing_uom, pricing_cost_exw
y todos los costos derivados.';



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


CREATE OR REPLACE FUNCTION "public"."try_parse_uuid"("p_text" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
BEGIN
  IF p_text IS NULL OR trim(p_text) = '' THEN
    RETURN NULL;
  END IF;
  RETURN p_text::uuid;
EXCEPTION WHEN invalid_text_representation OR OTHERS THEN
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."try_parse_uuid"("p_text" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."uom_factor"("p_from" "text", "p_to" "text") RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  f text := lower(trim(p_from));
  t text := lower(trim(p_to));
begin
  if f = t then
    return 1;
  end if;

  -- lineal
  if f in ('yd','yard','yards') and t in ('m','meter','meters') then return 0.9144; end if;
  if f in ('ft','foot','feet') and t in ('m','meter','meters') then return 0.3048; end if;
  if f in ('in','inch','inches') and t in ('m','meter','meters') then return 0.0254; end if;

  -- área
  if f in ('yd2','yard2','sqyd','sq_yd','square_yard','square_yards') and t in ('m2','sqm','sq_m','square_meter','square_meters') then
    return 0.83612736; -- 0.9144^2
  end if;
  if f in ('ft2','foot2','sqft','sq_ft','square_foot','square_feet') and t in ('m2','sqm','sq_m','square_meter','square_meters') then
    return 0.09290304; -- 0.3048^2
  end if;

  -- unidades (ea)
  if f in ('ea','each','unit') and t in ('ea','each','unit') then return 1; end if;

  raise exception 'No uom_factor mapping for % -> %', p_from, p_to;
end;
$$;


ALTER FUNCTION "public"."uom_factor"("p_from" "text", "p_to" "text") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."upsert_dealer_configurator_policy"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_allowed_product_type_codes" "text"[], "p_allow_variants_catalog" boolean, "p_allow_accessories_only" boolean, "p_allow_hardware" boolean, "p_allow_operating_system" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public."DealerConfiguratorPolicies" (
    organization_id,
    dealer_id,
    allowed_product_type_codes,
    allow_variants_catalog,
    allow_accessories_only,
    allow_hardware,
    allow_operating_system
  )
  VALUES (
    p_org_id,
    p_dealer_id,
    p_allowed_product_type_codes,
    p_allow_variants_catalog,
    p_allow_accessories_only,
    p_allow_hardware,
    p_allow_operating_system
  )
  ON CONFLICT (organization_id, dealer_id)
  DO UPDATE SET
    allowed_product_type_codes = EXCLUDED.allowed_product_type_codes,
    allow_variants_catalog = EXCLUDED.allow_variants_catalog,
    allow_accessories_only = EXCLUDED.allow_accessories_only,
    allow_hardware = EXCLUDED.allow_hardware,
    allow_operating_system = EXCLUDED.allow_operating_system,
    updated_at = now();
END;
$$;


ALTER FUNCTION "public"."upsert_dealer_configurator_policy"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_allowed_product_type_codes" "text"[], "p_allow_variants_catalog" boolean, "p_allow_accessories_only" boolean, "p_allow_hardware" boolean, "p_allow_operating_system" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."upsert_dealer_configurator_policy"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_allowed_product_type_codes" "text"[], "p_allow_variants_catalog" boolean, "p_allow_accessories_only" boolean, "p_allow_hardware" boolean, "p_allow_operating_system" boolean) IS 'Upserts one row in DealerConfiguratorPolicies per (org, dealer). One-Off (allow_variants_oneoff) removed.';



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



CREATE TABLE IF NOT EXISTS "public"."AppUserInvites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "user_type" "text" NOT NULL,
    "dealer_id" "uuid",
    "email" "text" NOT NULL,
    "display_name" "text",
    "role_code" "text" NOT NULL,
    "invited_by_app_user_id" "uuid",
    "token_hash" "text" NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "accepted_at" timestamp with time zone,
    "revoked_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "AppUserInvites_user_type_check" CHECK (("user_type" = ANY (ARRAY['org'::"text", 'dealer'::"text"])))
);


ALTER TABLE "public"."AppUserInvites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."AppUserPermissions" (
    "app_user_id" "uuid" NOT NULL,
    "permission_code" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."AppUserPermissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."AppUserPreferences" (
    "user_id" "uuid" NOT NULL,
    "active_dealer_id" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."AppUserPreferences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."AppUserRolePermissions" (
    "role_code" "text" NOT NULL,
    "permission_code" "text" NOT NULL
);


ALTER TABLE "public"."AppUserRolePermissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."AppUserRoles" (
    "code" "text" NOT NULL,
    "user_type" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "is_system" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "AppUserRoles_user_type_check" CHECK (("user_type" = ANY (ARRAY['org'::"text", 'dealer'::"text"])))
);


ALTER TABLE "public"."AppUserRoles" OWNER TO "postgres";


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
    "roll_width_value" numeric,
    "roll_width_uom" "text",
    "roll_width_m" numeric,
    "roll_length_value" numeric,
    "roll_length_uom" "text",
    "roll_length_m" numeric,
    "purchase_unit" "public"."purchase_unit_enum" DEFAULT 'each'::"public"."purchase_unit_enum" NOT NULL,
    CONSTRAINT "catalogitems_item_role_check" CHECK ((("item_role" IS NULL) OR ("item_role" = ANY (ARRAY['accessory'::"text", 'adapter'::"text", 'bearing'::"text", 'belt'::"text", 'belt_connector'::"text", 'bottom_bar'::"text", 'bottom_bar_profile'::"text", 'bottom_channel'::"text", 'bottom_rail_profile'::"text", 'bracket'::"text", 'brush'::"text", 'cable'::"text", 'carrier'::"text", 'cassette'::"text", 'chain'::"text", 'chain_clip'::"text", 'chain_stop'::"text", 'chain_tensioner'::"text", 'consumable'::"text", 'control'::"text", 'drive'::"text", 'drive_adapter'::"text", 'drive_manual'::"text", 'drive_motorized'::"text", 'end_cap'::"text", 'end_plug'::"text", 'fabric'::"text", 'fascia'::"text", 'fastener'::"text", 'filler'::"text", 'guide'::"text", 'handle'::"text", 'hardware'::"text", 'headbox'::"text", 'hook'::"text", 'idler'::"text", 'motor'::"text", 'mount_profile'::"text", 'mounting_clip'::"text", 'rail_connector'::"text", 'screw_cap'::"text", 'side_channel'::"text", 'side_channel_profile'::"text", 'spring'::"text", 'stopper'::"text", 'sub_bracket'::"text", 'tape'::"text", 'top_rail'::"text", 'top_rail_profile'::"text", 'track'::"text", 'tube'::"text", 'wand'::"text", 'window_film'::"text"])))),
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
    "sku" "text",
    "name" "text",
    "collection_name" "text",
    "variant_name" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "unit_of_measure" "text",
    "shipping_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "import_tax_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "minimum_margin_pct" numeric(7,4),
    "msrp_pct" numeric(7,4),
    "dealer_price" numeric DEFAULT 0 NOT NULL,
    "msrp" numeric DEFAULT 0 NOT NULL,
    "pricing_uom" "text",
    "pricing_cost_exw" numeric(12,4),
    "shipping_cost" numeric GENERATED ALWAYS AS ("round"((COALESCE("pricing_cost_exw", (0)::numeric) * COALESCE("shipping_pct", (0)::numeric)), 4)) STORED,
    "import_tax_cost" numeric GENERATED ALWAYS AS ("round"(((COALESCE("pricing_cost_exw", (0)::numeric) * ((1)::numeric + COALESCE("shipping_pct", (0)::numeric))) * COALESCE("import_tax_pct", (0)::numeric)), 4)) STORED,
    "total_cost" numeric GENERATED ALWAYS AS ("round"(((COALESCE("pricing_cost_exw", (0)::numeric) * ((1)::numeric + COALESCE("shipping_pct", (0)::numeric))) * ((1)::numeric + COALESCE("import_tax_pct", (0)::numeric))), 4)) STORED,
    CONSTRAINT "catalogitemsmsrp_pricing_uom_chk" CHECK (("pricing_uom" = ANY (ARRAY['ea'::"text", 'm'::"text", 'm2'::"text"])))
);


ALTER TABLE "public"."CatalogItemsMSRP" OWNER TO "postgres";


COMMENT ON COLUMN "public"."CatalogItemsMSRP"."unit_of_measure" IS 'UOM de compra/origen del suplidor (ej: yd, ft, ea, set, box, pack).
Copia de CatalogItems.unit_of_measure. Solo informativo para compras; NO usar para pricing.';



COMMENT ON COLUMN "public"."CatalogItemsMSRP"."msrp" IS 'MSRP base por unidad: landed sin mano de obra (BOM + Roll + Shipping + ImportTax). unit_msrp_total = msrp + labor_msrp.';



COMMENT ON COLUMN "public"."CatalogItemsMSRP"."pricing_uom" IS 'UOM canónico de pricing. Solo valores: ea | m | m2.
Derivado de CatalogItems.roll_pricing_mode (rolls) o ea (no-rolls).
El precio msrp/dealer_price está expresado en esta UOM.';



COMMENT ON COLUMN "public"."CatalogItemsMSRP"."pricing_cost_exw" IS 'Costo EXW normalizado a pricing_uom (ea/m/m2). BASE de todos los cálculos de pricing.
shipping_cost, import_tax_cost, total_cost son GENERATED desde este valor.';



COMMENT ON COLUMN "public"."CatalogItemsMSRP"."shipping_cost" IS 'GENERATED: pricing_cost_exw × shipping_pct. NO escribir.';



COMMENT ON COLUMN "public"."CatalogItemsMSRP"."import_tax_cost" IS 'GENERATED: pricing_cost_exw × (1+shipping_pct) × import_tax_pct. Impuesto sobre (costo+envío). NO escribir.';



COMMENT ON COLUMN "public"."CatalogItemsMSRP"."total_cost" IS 'GENERATED: pricing_cost_exw × (1+shipping_pct) × (1+import_tax_pct). Base para dealer_price/msrp. NO escribir.';



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
    "labor_amount" numeric(12,4) DEFAULT 0,
    "bom_preview_snapshot" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "msrp_product_subtotal" numeric(12,4) DEFAULT 0,
    "roll_total_cost" numeric(12,4) DEFAULT 0,
    "bom_total_cost" numeric(12,4) DEFAULT 0,
    "labor_msrp" numeric(12,4) DEFAULT 0,
    "unit_labor_cost" numeric(12,4) DEFAULT 0,
    "unit_msrp_total" numeric(12,4) DEFAULT 0,
    "unit_product_cost" numeric(12,4) DEFAULT 0,
    "accessories_total_cost" numeric(12,4) DEFAULT 0,
    "total_cost" numeric(12,4) DEFAULT 0,
    CONSTRAINT "configured_products_no_landed_keys_chk" CHECK ((("bom_preview_snapshot" IS NULL) OR (NOT (("bom_preview_snapshot")::"text" ~~* '%_landed%'::"text"))))
);


ALTER TABLE "public"."ConfiguredProducts" OWNER TO "postgres";


COMMENT ON TABLE "public"."ConfiguredProducts" IS 'Snapshot completo de producto configurado (Roll + BOM) antes de crear QuoteLine. Contiene precios calculados y toda la configuración.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."bom_total" IS 'Total MSRP sale_out de todos los componentes BOM (padres + hijos) desde BOMInstanceLines.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."config_snapshot" IS 'JSONB con snapshot completo de la configuración desde ProductConfigurator. Incluye todas las selecciones y opciones.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."roll_msrp_total" IS 'MSRP Sale out × Ancho del rollo total × Altura de la medida de measurements × quantity.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."bom_preview_snapshot" IS 'JSONB snapshot of BOM breakdown for UI preview. Contains version, totals, and items array with pricing details. Generated during create_configured_product_and_bom_preview.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."msrp_product_subtotal" IS 'Per-unit MSRP product subtotal (roll + BOM + accessories), without labor.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."roll_total_cost" IS 'Roll cost from CatalogItemsMSRP.total_cost.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."bom_total_cost" IS 'BOM components cost from CatalogItemsMSRP.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."labor_msrp" IS 'Per-unit labor portion added after msrp_product_subtotal.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."unit_product_cost" IS 'Per-unit product cost (roll + BOM + accessories), without labor.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."accessories_total_cost" IS 'Accessories cost from CatalogItemsMSRP.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."total_cost" IS 'Per-unit total cost including labor.';



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
    "import_tax_pct" numeric(7,4) GENERATED ALWAYS AS ("global_import_tax_pct") STORED,
    "itbms_pct" numeric(7,4) DEFAULT 0.07 NOT NULL,
    "fabric_pricing_basis" "text" DEFAULT 'auto'::"text" NOT NULL,
    "labor_dealer_pct" numeric(7,4) DEFAULT NULL::numeric,
    "labor_msrp_pct" numeric(7,4) DEFAULT NULL::numeric,
    CONSTRAINT "costsettings_fabric_pricing_basis_chk" CHECK (("fabric_pricing_basis" = ANY (ARRAY['auto'::"text", 'linear'::"text", 'sqm'::"text"]))),
    CONSTRAINT "costsettings_itbms_pct_range" CHECK ((("itbms_pct" >= (0)::numeric) AND ("itbms_pct" <= (1)::numeric)))
);


ALTER TABLE "public"."CostSettings" OWNER TO "postgres";


COMMENT ON COLUMN "public"."CostSettings"."itbms_pct" IS 'ITBMS % (0-1, e.g. 0.07 = 7%). Used in Proposals totals.';



COMMENT ON COLUMN "public"."CostSettings"."fabric_pricing_basis" IS 'Display/quote basis for fabric rolls: auto (from roll_pricing_mode), linear (m), sqm (m²). Only affects bom_preview_snapshot display; does not change costs.';



COMMENT ON COLUMN "public"."CostSettings"."labor_dealer_pct" IS 'Labor dealer margin-on-sale (0.35 = 35%). labor_dealer = labor_cost / (1 - labor_dealer_pct). If NULL, falls back to minimum_margin_pct.';



COMMENT ON COLUMN "public"."CostSettings"."labor_msrp_pct" IS 'Labor MSRP margin-on-sale (0.65 = 65%). labor_msrp = labor_dealer / (1 - labor_msrp_pct). If NULL, falls back to default_msrp_pct.';



CREATE TABLE IF NOT EXISTS "public"."DealerConfiguratorPolicies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "dealer_id" "uuid" NOT NULL,
    "allowed_product_type_codes" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "allow_variants_catalog" boolean DEFAULT true NOT NULL,
    "allow_accessories_only" boolean DEFAULT false NOT NULL,
    "allow_hardware" boolean DEFAULT true NOT NULL,
    "allow_operating_system" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."DealerConfiguratorPolicies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."DealerDocumentTermsDefaults" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "dealer_id" "uuid" NOT NULL,
    "doc_type" "text" NOT NULL,
    "template_id" "uuid" NOT NULL,
    "updated_by_auth_user_id" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "DealerDocumentTermsDefaults_doc_type_check" CHECK (("doc_type" = ANY (ARRAY['quote'::"text", 'proposal'::"text", 'sales_order'::"text"])))
);


ALTER TABLE "public"."DealerDocumentTermsDefaults" OWNER TO "postgres";


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
    CONSTRAINT "chk_dealeruser_active_has_userid" CHECK ((("status" <> 'active'::"public"."portal_user_status") OR ("user_id" IS NOT NULL))),
    CONSTRAINT "company_portal_role_check" CHECK (("role" = ANY (ARRAY['member'::"text", 'member_manager'::"text"]))),
    CONSTRAINT "companyportalusers_portal_user_role_check" CHECK (("role" = ANY (ARRAY['member_manager'::"text", 'member'::"text"]))),
    CONSTRAINT "companyportalusers_role_check" CHECK (("role" = ANY (ARRAY['member_manager'::"text", 'member'::"text"])))
);


ALTER TABLE "public"."DealerUsers" OWNER TO "postgres";


COMMENT ON CONSTRAINT "chk_dealeruser_active_has_userid" ON "public"."DealerUsers" IS 'Active portal users must have user_id set.';



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
    "logo_url" "text",
    "primary_contact_app_user_id" "uuid",
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



COMMENT ON COLUMN "public"."Dealers"."logo_url" IS 'URL of dealer logo (e.g. from storage). Shown on Proposal detail and print/PDF.';



COMMENT ON COLUMN "public"."Dealers"."primary_contact_app_user_id" IS 'Primary contact: AppUser (dealer) with role Dealer Manager for this dealer.';



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
    "created_by_email" "text",
    "created_by_user_name" "text",
    "created_by_user_type" "text",
    "created_by_dealer_id" "uuid",
    "updated_by_user_id" "uuid",
    "updated_by_email" "text",
    "updated_by_user_name" "text",
    "updated_by_user_type" "text",
    "updated_by_dealer_id" "uuid",
    "created_by_app_user_id" "uuid",
    "updated_by_app_user_id" "uuid"
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
    "created_by_email" "text",
    "created_by_user_name" "text",
    "created_by_user_type" "text",
    "created_by_dealer_id" "uuid",
    "updated_by_user_id" "uuid",
    "updated_by_email" "text",
    "updated_by_user_name" "text",
    "updated_by_user_type" "text",
    "updated_by_dealer_id" "uuid"
);


ALTER TABLE "public"."DirectoryCustomers" OWNER TO "postgres";


COMMENT ON COLUMN "public"."DirectoryCustomers"."customer_phone" IS 'Customer phone number (main contact phone)';



COMMENT ON COLUMN "public"."DirectoryCustomers"."identification_number" IS 'Customer identification number (tax ID, etc.)';



COMMENT ON COLUMN "public"."DirectoryCustomers"."customer_type_name" IS 'Customer type: contractor, architecture_studio, design_studio, end_user';



COMMENT ON COLUMN "public"."DirectoryCustomers"."alt_phone" IS 'Alternative phone number';



COMMENT ON COLUMN "public"."DirectoryCustomers"."primary_contact_id" IS 'Primary contact person (FK to DirectoryContacts)';



CREATE TABLE IF NOT EXISTS "public"."DocumentTermsTemplates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "dealer_id" "uuid",
    "doc_type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "content" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by_auth_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "DocumentTermsTemplates_doc_type_check" CHECK (("doc_type" = ANY (ARRAY['quote'::"text", 'proposal'::"text", 'sales_order'::"text"])))
);


ALTER TABLE "public"."DocumentTermsTemplates" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."InventoryBalances" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "catalog_item_id" "uuid" NOT NULL,
    "quantity" numeric(12,4) DEFAULT 0 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "inv_balances_quantity_non_neg" CHECK (("quantity" >= (0)::numeric))
);


ALTER TABLE "public"."InventoryBalances" OWNER TO "postgres";


COMMENT ON TABLE "public"."InventoryBalances" IS 'Current stock per org/warehouse/catalog_item. Source of truth for inventory_on_hand view.';



CREATE TABLE IF NOT EXISTS "public"."InventoryItemProfiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "catalog_item_id" "uuid" NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "import_lead_time_min_days" integer,
    "import_lead_time_max_days" integer,
    "risk_level" "text",
    "is_special_order" boolean DEFAULT false NOT NULL,
    "preferred_supplier_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "inv_profiles_risk_level_chk" CHECK ((("risk_level" IS NULL) OR ("lower"("risk_level") = ANY (ARRAY['low'::"text", 'medium'::"text", 'high'::"text", 'critical'::"text"]))))
);


ALTER TABLE "public"."InventoryItemProfiles" OWNER TO "postgres";


COMMENT ON TABLE "public"."InventoryItemProfiles" IS 'Per material + warehouse: import lead time, risk, special order. Used by inventory_availability view (informative only).';



COMMENT ON COLUMN "public"."InventoryItemProfiles"."risk_level" IS 'low | medium | high | critical. Informative for availability badge.';



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


CREATE TABLE IF NOT EXISTS "public"."ProposalLineAddOns" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "dealer_id" "uuid" NOT NULL,
    "proposal_id" "uuid" NOT NULL,
    "proposal_line_id" "uuid" NOT NULL,
    "addon_type" "text" DEFAULT 'installation'::"text" NOT NULL,
    "cost_amount" numeric(12,4) DEFAULT 0 NOT NULL,
    "pricing_mode" "text" DEFAULT 'markup_pct'::"text" NOT NULL,
    "markup_pct" numeric(7,4),
    "sale_amount" numeric(12,4) DEFAULT 0 NOT NULL,
    "taxable" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "ProposalLineAddOns_addon_type_check" CHECK (("addon_type" = ANY (ARRAY['installation'::"text", 'delivery'::"text", 'measurement'::"text", 'other'::"text"]))),
    CONSTRAINT "ProposalLineAddOns_pricing_mode_check" CHECK (("pricing_mode" = ANY (ARRAY['markup_pct'::"text", 'fixed_price'::"text"])))
);


ALTER TABLE "public"."ProposalLineAddOns" OWNER TO "postgres";


COMMENT ON TABLE "public"."ProposalLineAddOns" IS 'Add-ons per ProposalLine (e.g. installation, delivery). Used for ITBMS and line totals.';



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
    "quote_line_snapshot" "jsonb",
    "line_adjustment_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "unit_cost" numeric(12,4),
    "area" "text",
    "position" "text",
    CONSTRAINT "proposal_lines_custom_requirements_chk" CHECK ((("line_type" <> 'custom'::"public"."proposal_line_type") OR (("description" IS NOT NULL) AND ("length"(TRIM(BOTH FROM "description")) > 0)))),
    CONSTRAINT "proposal_lines_line_adjustment_pct_chk" CHECK ((("line_adjustment_pct" >= ('-100'::integer)::numeric) AND ("line_adjustment_pct" <= (100)::numeric))),
    CONSTRAINT "proposal_lines_override_mode_chk" CHECK (((("override_mode" = 'inherit'::"public"."proposal_override_mode") AND ("discount_pct" IS NULL) AND ("markup_pct" IS NULL) AND ("fixed_unit_price" IS NULL) AND ("fixed_line_total" IS NULL)) OR (("override_mode" = 'discount_pct'::"public"."proposal_override_mode") AND ("discount_pct" IS NOT NULL) AND (("discount_pct" >= (0)::numeric) AND ("discount_pct" <= (100)::numeric)) AND ("markup_pct" IS NULL) AND ("fixed_unit_price" IS NULL) AND ("fixed_line_total" IS NULL)) OR (("override_mode" = 'markup_pct'::"public"."proposal_override_mode") AND ("markup_pct" IS NOT NULL) AND (("markup_pct" >= (0)::numeric) AND ("markup_pct" <= (100)::numeric)) AND ("discount_pct" IS NULL) AND ("fixed_unit_price" IS NULL) AND ("fixed_line_total" IS NULL)) OR (("override_mode" = 'fixed_unit_price'::"public"."proposal_override_mode") AND ("fixed_unit_price" IS NOT NULL) AND ("discount_pct" IS NULL) AND ("markup_pct" IS NULL) AND ("fixed_line_total" IS NULL)) OR (("override_mode" = 'fixed_line_total'::"public"."proposal_override_mode") AND ("fixed_line_total" IS NOT NULL) AND ("discount_pct" IS NULL) AND ("markup_pct" IS NULL) AND ("fixed_unit_price" IS NULL)))),
    CONSTRAINT "proposal_lines_qty_positive_chk" CHECK ((("qty" IS NULL) OR ("qty" >= (0)::numeric))),
    CONSTRAINT "proposal_lines_type_chk" CHECK (((("line_type" = 'from_quote'::"public"."proposal_line_type") AND ("quote_line_id" IS NOT NULL)) OR (("line_type" = 'custom'::"public"."proposal_line_type") AND ("quote_line_id" IS NULL))))
);


ALTER TABLE "public"."ProposalLines" OWNER TO "postgres";


COMMENT ON TABLE "public"."ProposalLines" IS 'Lines of a Proposal: from_quote (QuoteLine + overrides) or custom (extras).';



COMMENT ON COLUMN "public"."ProposalLines"."quote_line_id" IS 'Required when line_type = from_quote. Optional override: discount_pct, markup_pct, or fixed_unit_price.';



COMMENT ON COLUMN "public"."ProposalLines"."custom_category" IS 'Category for custom line: installation, transportation, other.';



COMMENT ON COLUMN "public"."ProposalLines"."description" IS 'Required for custom lines (e.g. Installation, Transport).';



COMMENT ON COLUMN "public"."ProposalLines"."quote_line_snapshot" IS 'Snapshot of QuoteLine + ConfiguredProduct data when proposal status changed to sent. Used by ProposalPrint when present.';



COMMENT ON COLUMN "public"."ProposalLines"."line_adjustment_pct" IS 'Line adjustment %: -10 = discount 10%, +10 = fee 10%, 0 = no change. Applied to base from QuoteLine/snapshot.';



COMMENT ON COLUMN "public"."ProposalLines"."unit_cost" IS 'Unit cost for custom lines. Margin % on sale = (unit_price - unit_cost) / unit_price * 100.';



COMMENT ON COLUMN "public"."ProposalLines"."area" IS 'Area/location for the line (custom lines).';



COMMENT ON COLUMN "public"."ProposalLines"."position" IS 'Position identifier for the line (custom lines).';



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
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "sent_at" timestamp with time zone,
    "snapshot_version" integer DEFAULT 1,
    "discount_amount" numeric(12,4),
    "itbms_amount" numeric(12,4),
    "description" "text",
    "exempt_itbms" boolean DEFAULT false NOT NULL,
    "terms_title" "text",
    "terms_content" "text",
    "terms_source_template_id" "uuid",
    "installation_amount" numeric(12,4) DEFAULT 0 NOT NULL,
    "global_installation_discount_pct" numeric(7,4) DEFAULT 0,
    "global_installation_fee_pct" numeric(7,4) DEFAULT 0,
    CONSTRAINT "proposals_global_discount_range_chk" CHECK ((("global_discount_pct" IS NULL) OR (("global_discount_pct" >= (0)::numeric) AND ("global_discount_pct" <= (100)::numeric)))),
    CONSTRAINT "proposals_version_no_positive_chk" CHECK (("version_no" >= 1))
);


ALTER TABLE "public"."Proposals" OWNER TO "postgres";


COMMENT ON TABLE "public"."Proposals" IS 'Customer-facing proposal derived from a Quote. Editable (overrides, extras). 1 Quote → N Proposals.';



COMMENT ON COLUMN "public"."Proposals"."quote_id" IS 'Source Quote (technical/audit). Proposal does not modify Quote.';



COMMENT ON COLUMN "public"."Proposals"."customer_id" IS 'Customer (DirectoryCustomers). Default from Quote but editable.';



COMMENT ON COLUMN "public"."Proposals"."contact_id" IS 'Contact (DirectoryContacts). Default from Quote but editable.';



COMMENT ON COLUMN "public"."Proposals"."global_discount_pct" IS 'Optional global discount applied to proposal total (e.g. 0.05 = 5%).';



COMMENT ON COLUMN "public"."Proposals"."global_fee_amount" IS 'Optional global fee added to proposal total.';



COMMENT ON COLUMN "public"."Proposals"."sent_at" IS 'Timestamp when proposal status was first set to sent (used for freeze snapshot).';



COMMENT ON COLUMN "public"."Proposals"."snapshot_version" IS 'Version of snapshot schema for future migrations.';



COMMENT ON COLUMN "public"."Proposals"."discount_amount" IS 'Amount of global discount (before ITBMS). Shown in PDF only when > 0.';



COMMENT ON COLUMN "public"."Proposals"."itbms_amount" IS 'ITBMS amount. Calculated from taxable_base * itbms_pct.';



COMMENT ON COLUMN "public"."Proposals"."description" IS 'Short proposal description (header). Use notes for Notes / Terms and Conditions.';



COMMENT ON COLUMN "public"."Proposals"."exempt_itbms" IS 'Si true, la Proposal no incluye ITBMS. itbms_amount = 0, total = taxable_base + fee.';



COMMENT ON COLUMN "public"."Proposals"."installation_amount" IS 'Sum of installation addons (raw, for display). Net after discount/fee goes into subtotal.';



COMMENT ON COLUMN "public"."Proposals"."global_installation_discount_pct" IS 'Discount % applied to installation addons total (e.g. 15 = 15%).';



COMMENT ON COLUMN "public"."Proposals"."global_installation_fee_pct" IS 'Fee/surcharge % applied to installation addons total (e.g. 5 = 5%).';



CREATE TABLE IF NOT EXISTS "public"."PurchaseOrderLines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "purchase_order_id" "uuid" NOT NULL,
    "catalog_item_id" "uuid" NOT NULL,
    "ordered_qty" numeric(12,4) DEFAULT 0 NOT NULL,
    "received_qty" numeric(12,4) DEFAULT 0 NOT NULL,
    "unit" "text" DEFAULT 'ea'::"text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "po_lines_ordered_qty_non_neg" CHECK (("ordered_qty" >= (0)::numeric)),
    CONSTRAINT "po_lines_received_lte_ordered" CHECK (("received_qty" <= "ordered_qty")),
    CONSTRAINT "po_lines_received_qty_non_neg" CHECK (("received_qty" >= (0)::numeric))
);


ALTER TABLE "public"."PurchaseOrderLines" OWNER TO "postgres";


COMMENT ON TABLE "public"."PurchaseOrderLines" IS 'PO lines. received_qty updated by receipts. inventory_on_order uses (ordered_qty - received_qty) for OPEN/PARTIAL POs.';



CREATE TABLE IF NOT EXISTS "public"."PurchaseOrders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "po_number" "text",
    "expected_date" "date",
    "status" "public"."purchase_order_status" DEFAULT 'OPEN'::"public"."purchase_order_status" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."PurchaseOrders" OWNER TO "postgres";


COMMENT ON TABLE "public"."PurchaseOrders" IS 'Purchase orders. warehouse_id required. expected_date = ETA. status OPEN/PARTIAL/CLOSED for inventory_on_order.';



COMMENT ON COLUMN "public"."PurchaseOrders"."expected_date" IS 'ETA: expected delivery date for transit calculation.';



COMMENT ON COLUMN "public"."PurchaseOrders"."status" IS 'OPEN = not received; PARTIAL = some received; CLOSED = fully received.';



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


CREATE TABLE IF NOT EXISTS "public"."QuoteLines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "dealer_id" "uuid" NOT NULL,
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
    "sort_order" integer,
    "metadata" "jsonb",
    "unit_msrp_product_subtotal" numeric(12,4) DEFAULT 0,
    "accessories_msrp_snapshot" numeric(12,4) DEFAULT 0,
    "labor_msrp_snapshot" numeric(12,4) DEFAULT 0,
    "accessories_cost_snapshot" numeric(12,4) DEFAULT 0,
    "labor_cost_snapshot" numeric(12,4) DEFAULT 0,
    "unit_msrp_total_snapshot" numeric(12,4) DEFAULT NULL::numeric,
    "unit_cost_total_snapshot" numeric(12,4) DEFAULT NULL::numeric,
    "total_cost" numeric(12,4) DEFAULT NULL::numeric,
    "unit_dealer_price_snapshot" numeric(12,4) DEFAULT NULL::numeric,
    "dealer_price_total" numeric(12,4) DEFAULT NULL::numeric,
    "dealer_discount_pct" numeric(5,2) DEFAULT NULL::numeric,
    "dealer_tier_id_snapshot" "uuid",
    "dealer_tier_code_snapshot" "text",
    "catalog_dealer_unit_snapshot" numeric,
    "dealer_price_source" "text",
    CONSTRAINT "chk_quotelines_dealer_price_coherent" CHECK ((("unit_dealer_price_snapshot" IS NULL) OR ("dealer_price_total" IS NULL) OR ("quantity" IS NULL) OR ("quantity" <= (0)::numeric) OR ("abs"(("dealer_price_total" - ("unit_dealer_price_snapshot" * "quantity"))) <= 0.02)))
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



COMMENT ON COLUMN "public"."QuoteLines"."metadata" IS 'JSONB for panel config, accessories list (product_type=accessories), etc.';



COMMENT ON COLUMN "public"."QuoteLines"."unit_msrp_product_subtotal" IS 'Per-unit MSRP subtotal without labor.';



COMMENT ON COLUMN "public"."QuoteLines"."unit_msrp_total_snapshot" IS 'Snapshot canónico del MSRP unitario (roll+bom+accessories+labor) al commit/sync. msrp = unit_msrp_total_snapshot * quantity.';



COMMENT ON COLUMN "public"."QuoteLines"."unit_cost_total_snapshot" IS 'Snapshot canónico del costo unitario al commit/sync. total_cost = unit_cost_total_snapshot * quantity.';



COMMENT ON COLUMN "public"."QuoteLines"."total_cost" IS 'Costo total de la línea (unit_cost_total_snapshot * quantity).';



COMMENT ON COLUMN "public"."QuoteLines"."unit_dealer_price_snapshot" IS 'Dealer price unitario = MSRP × (1 - tier_discount_pct/100). Snapshot al momento del commit/sync.';



COMMENT ON COLUMN "public"."QuoteLines"."dealer_price_total" IS 'Dealer price total = unit_dealer_price_snapshot × quantity.';



COMMENT ON COLUMN "public"."QuoteLines"."dealer_discount_pct" IS '% descuento del tier del dealer aplicado (ej. Bronze=35%). Canónico: siempre por tier, nunca NULL.';



COMMENT ON COLUMN "public"."QuoteLines"."dealer_tier_id_snapshot" IS 'Snapshot: dealer tier id usado para calcular Dealer Price.';



COMMENT ON COLUMN "public"."QuoteLines"."dealer_tier_code_snapshot" IS 'Snapshot: dealer tier code usado (PLATINUM/GOLD/etc).';



COMMENT ON COLUMN "public"."QuoteLines"."catalog_dealer_unit_snapshot" IS 'AUDIT: CatalogItemsMSRP.dealer_price del roll (si existe). NO se usa para calcular Dealer Price.';



COMMENT ON COLUMN "public"."QuoteLines"."dealer_price_source" IS 'AUDIT: fuente Dealer Price. Canónico: tier.';



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
    "dealer_id" "uuid" NOT NULL,
    "currency" "text" DEFAULT 'USD'::"text" NOT NULL,
    "description" "text",
    "po_number" "text",
    "exempt_itbms" boolean DEFAULT false NOT NULL,
    "terms_title" "text",
    "terms_content" "text",
    "terms_source_template_id" "uuid",
    "notes" "text",
    CONSTRAINT "quotes_tracking_status_only_when_approved" CHECK (((("status" = 'approved'::"public"."quote_status") AND ("tracking_status" IS NOT NULL)) OR (("status" <> 'approved'::"public"."quote_status") AND ("tracking_status" IS NULL))))
);


ALTER TABLE "public"."Quotes" OWNER TO "postgres";


COMMENT ON TABLE "public"."Quotes" IS 'Quotes table - quotes are converted to SalesOrders when approved';



COMMENT ON COLUMN "public"."Quotes"."status" IS 'Status: draft, sent, approved, canceled';



COMMENT ON COLUMN "public"."Quotes"."tracking_status" IS 'Tracking status. Only set when status=approved. NULL otherwise.';



COMMENT ON COLUMN "public"."Quotes"."customer_id" IS 'FK to customer (nullable)';



COMMENT ON COLUMN "public"."Quotes"."contact_id" IS 'FK to contact (nullable)';



COMMENT ON COLUMN "public"."Quotes"."description" IS 'Quote description or notes. Shown as Description in UI.';



COMMENT ON COLUMN "public"."Quotes"."po_number" IS 'Dealer PO / order tracking number (optional).';



COMMENT ON COLUMN "public"."Quotes"."exempt_itbms" IS 'Si true, el Quote no incluye ITBMS. Subtotal = Total.';



COMMENT ON COLUMN "public"."Quotes"."notes" IS 'Printable note for quote PDF left block (Notas). Distinct from description.';



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
    "dealer_id" "uuid",
    "created_by_user_id" "uuid",
    "created_by_email" "text",
    "created_by_user_name" "text",
    "created_by_user_type" "text",
    "created_by_dealer_id" "uuid",
    "updated_by_user_id" "uuid",
    "updated_by_email" "text",
    "updated_by_user_name" "text",
    "updated_by_user_type" "text",
    "updated_by_dealer_id" "uuid",
    "terms_title" "text",
    "terms_content" "text",
    "terms_source_template_id" "uuid"
);


ALTER TABLE "public"."SalesOrders" OWNER TO "postgres";


COMMENT ON TABLE "public"."SalesOrders" IS 'SalesOrders table - always created from approved Quotes via trigger';



COMMENT ON COLUMN "public"."SalesOrders"."quote_id" IS 'FK to Quotes (1:1 unique). SalesOrder always created from Quote.';



COMMENT ON COLUMN "public"."SalesOrders"."tracking_status" IS 'Tracking status - source of truth. Mirrored to OrderList.';



CREATE TABLE IF NOT EXISTS "public"."Warehouses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "code" "text",
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."Warehouses" OWNER TO "postgres";


COMMENT ON TABLE "public"."Warehouses" IS 'Warehouses per organization. PO and inventory views are scoped by warehouse.';



CREATE OR REPLACE VIEW "public"."inventory_on_hand" AS
 SELECT "organization_id",
    "warehouse_id",
    "catalog_item_id",
    "sum"("quantity") AS "on_hand_qty",
    "max"("updated_at") AS "updated_at"
   FROM "public"."InventoryBalances" "ib"
  GROUP BY "organization_id", "warehouse_id", "catalog_item_id";


ALTER VIEW "public"."inventory_on_hand" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."inventory_on_order" AS
 SELECT "po"."organization_id",
    "po"."warehouse_id",
    "pol"."catalog_item_id",
    "sum"(GREATEST(("pol"."ordered_qty" - "pol"."received_qty"), (0)::numeric)) AS "on_order_qty",
    "min"("po"."expected_date") FILTER (WHERE ("po"."expected_date" IS NOT NULL)) AS "next_eta"
   FROM ("public"."PurchaseOrders" "po"
     JOIN "public"."PurchaseOrderLines" "pol" ON (("pol"."purchase_order_id" = "po"."id")))
  WHERE (("po"."status" = ANY (ARRAY['OPEN'::"public"."purchase_order_status", 'PARTIAL'::"public"."purchase_order_status"])) AND (("pol"."ordered_qty" - "pol"."received_qty") > (0)::numeric))
  GROUP BY "po"."organization_id", "po"."warehouse_id", "pol"."catalog_item_id";


ALTER VIEW "public"."inventory_on_order" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."inventory_availability" AS
 SELECT COALESCE("h"."organization_id", "o"."organization_id") AS "organization_id",
    COALESCE("h"."warehouse_id", "o"."warehouse_id") AS "warehouse_id",
    COALESCE("h"."catalog_item_id", "o"."catalog_item_id") AS "catalog_item_id",
    COALESCE("h"."on_hand_qty", (0)::numeric) AS "on_hand_qty",
    COALESCE("o"."on_order_qty", (0)::numeric) AS "on_order_qty",
    "o"."next_eta",
        CASE
            WHEN (COALESCE("h"."on_hand_qty", (0)::numeric) > (0)::numeric) THEN 'IN_STOCK'::"text"
            WHEN (COALESCE("o"."on_order_qty", (0)::numeric) > (0)::numeric) THEN 'ON_ORDER'::"text"
            ELSE 'OUT_OF_STOCK'::"text"
        END AS "availability",
    "p"."risk_level",
    ("lower"("p"."risk_level") = ANY (ARRAY['high'::"text", 'critical'::"text"])) AS "is_risk",
    COALESCE("p"."is_special_order", false) AS "is_special_order",
    "p"."import_lead_time_min_days",
    "p"."import_lead_time_max_days",
    "p"."preferred_supplier_id",
    GREATEST(COALESCE("h"."updated_at", '-infinity'::timestamp with time zone), COALESCE(("o"."next_eta")::timestamp with time zone, '-infinity'::timestamp with time zone), COALESCE("p"."updated_at", '-infinity'::timestamp with time zone)) AS "updated_at"
   FROM (("public"."inventory_on_hand" "h"
     FULL JOIN "public"."inventory_on_order" "o" ON ((("o"."organization_id" = "h"."organization_id") AND ("o"."warehouse_id" = "h"."warehouse_id") AND ("o"."catalog_item_id" = "h"."catalog_item_id"))))
     LEFT JOIN "public"."InventoryItemProfiles" "p" ON ((("p"."warehouse_id" = COALESCE("h"."warehouse_id", "o"."warehouse_id")) AND ("p"."catalog_item_id" = COALESCE("h"."catalog_item_id", "o"."catalog_item_id")))));


ALTER VIEW "public"."inventory_availability" OWNER TO "postgres";


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



CREATE TABLE IF NOT EXISTS "public"."user_dealer_scope" (
    "user_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "effective_dealer_id" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_dealer_scope" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_catalog_item_pricing_uom" AS
 SELECT "id" AS "catalog_item_id",
        CASE
            WHEN ("roll_pricing_mode" = 'per_linear_meter'::"text") THEN 'm'::"text"
            WHEN ("roll_pricing_mode" = 'per_square_meter'::"text") THEN 'm2'::"text"
            WHEN ("roll_pricing_mode" = 'per_unit'::"text") THEN 'ea'::"text"
            ELSE NULL::"text"
        END AS "pricing_uom"
   FROM "public"."CatalogItems" "ci";


ALTER VIEW "public"."v_catalog_item_pricing_uom" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_configured_products_legacy_costs" AS
 SELECT "id",
    "organization_id",
    "roll_total_cost" AS "roll_total_cost_landed",
    "bom_total_cost" AS "bom_total_cost_landed",
    "accessories_total_cost" AS "accessories_total_cost_landed",
    "unit_product_cost" AS "unit_product_cost_landed",
    "unit_product_cost" AS "total_cost_landed_without_labor",
    "total_cost" AS "total_cost_with_labor"
   FROM "public"."ConfiguredProducts";


ALTER VIEW "public"."v_configured_products_legacy_costs" OWNER TO "postgres";


COMMENT ON VIEW "public"."v_configured_products_legacy_costs" IS 'Temporary view exposing cost columns as *_landed aliases. Use ConfiguredProducts directly with new column names.';



ALTER TABLE ONLY "public"."stg_catalog_items_import_raw" ALTER COLUMN "row_id" SET DEFAULT "nextval"('"public"."stg_catalog_items_import_raw_row_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."AppUserInvites"
    ADD CONSTRAINT "AppUserInvites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."AppUserPermissions"
    ADD CONSTRAINT "AppUserPermissions_pkey" PRIMARY KEY ("app_user_id", "permission_code");



ALTER TABLE ONLY "public"."AppUserPreferences"
    ADD CONSTRAINT "AppUserPreferences_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."AppUserRolePermissions"
    ADD CONSTRAINT "AppUserRolePermissions_pkey" PRIMARY KEY ("role_code", "permission_code");



ALTER TABLE ONLY "public"."AppUserRoles"
    ADD CONSTRAINT "AppUserRoles_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."AppUsers"
    ADD CONSTRAINT "AppUsers_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."DealerConfiguratorPolicies"
    ADD CONSTRAINT "DealerConfiguratorPolicies_organization_id_dealer_id_key" UNIQUE ("organization_id", "dealer_id");



ALTER TABLE ONLY "public"."DealerConfiguratorPolicies"
    ADD CONSTRAINT "DealerConfiguratorPolicies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."DealerDocumentTermsDefaults"
    ADD CONSTRAINT "DealerDocumentTermsDefaults_dealer_id_doc_type_key" UNIQUE ("dealer_id", "doc_type");



ALTER TABLE ONLY "public"."DealerDocumentTermsDefaults"
    ADD CONSTRAINT "DealerDocumentTermsDefaults_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."DealerTiers"
    ADD CONSTRAINT "DealerTiers_organization_id_code_key" UNIQUE ("organization_id", "code");



ALTER TABLE ONLY "public"."DealerTiers"
    ADD CONSTRAINT "DealerTiers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."DocumentTermsTemplates"
    ADD CONSTRAINT "DocumentTermsTemplates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."FabricRules"
    ADD CONSTRAINT "FabricRules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ImportTaxRules"
    ADD CONSTRAINT "ImportTaxRules_organization_id_category_id_key" UNIQUE ("organization_id", "category_id");



ALTER TABLE ONLY "public"."ImportTaxRules"
    ADD CONSTRAINT "ImportTaxRules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."InventoryBalances"
    ADD CONSTRAINT "InventoryBalances_organization_id_warehouse_id_catalog_item_key" UNIQUE ("organization_id", "warehouse_id", "catalog_item_id");



ALTER TABLE ONLY "public"."InventoryBalances"
    ADD CONSTRAINT "InventoryBalances_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."InventoryItemProfiles"
    ADD CONSTRAINT "InventoryItemProfiles_catalog_item_id_warehouse_id_key" UNIQUE ("catalog_item_id", "warehouse_id");



ALTER TABLE ONLY "public"."InventoryItemProfiles"
    ADD CONSTRAINT "InventoryItemProfiles_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."ProposalLineAddOns"
    ADD CONSTRAINT "ProposalLineAddOns_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ProposalLines"
    ADD CONSTRAINT "ProposalLines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."PurchaseOrderLines"
    ADD CONSTRAINT "PurchaseOrderLines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."PurchaseOrders"
    ADD CONSTRAINT "PurchaseOrders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."QuoteLineComponents"
    ADD CONSTRAINT "QuoteLineComponents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."QuoteLines"
    ADD CONSTRAINT "QuoteLines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "Quotes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."SaleOrderLines"
    ADD CONSTRAINT "SaleOrderLines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."SalesOrders"
    ADD CONSTRAINT "SalesOrders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."Warehouses"
    ADD CONSTRAINT "Warehouses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CatalogItemComponents"
    ADD CONSTRAINT "catalogitemcomponents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CatalogItemsMSRP"
    ADD CONSTRAINT "catalogitemsmsrp_org_catalog_item_unique" UNIQUE ("organization_id", "catalog_item_id");



ALTER TABLE ONLY "public"."CategoryMargins"
    ADD CONSTRAINT "categorymargins_org_category_unique" UNIQUE ("organization_id", "category_id");



ALTER TABLE "public"."QuoteLines"
    ADD CONSTRAINT "chk_quotelines_msrp_coherent" CHECK ((("unit_msrp_total_snapshot" IS NULL) OR ("msrp" IS NULL) OR ("quantity" IS NULL) OR ("quantity" <= (0)::numeric) OR ("abs"(("msrp" - ("unit_msrp_total_snapshot" * "quantity"))) <= 0.02))) NOT VALID;



ALTER TABLE "public"."QuoteLines"
    ADD CONSTRAINT "chk_quotelines_total_cost_coherent" CHECK ((("unit_cost_total_snapshot" IS NULL) OR ("total_cost" IS NULL) OR ("quantity" IS NULL) OR ("quantity" <= (0)::numeric) OR ("abs"(("total_cost" - ("unit_cost_total_snapshot" * "quantity"))) <= 0.02))) NOT VALID;



ALTER TABLE "public"."QuoteLines"
    ADD CONSTRAINT "chk_quotelines_unit_snapshots_non_neg" CHECK (((("unit_msrp_total_snapshot" IS NULL) OR ("unit_msrp_total_snapshot" >= (0)::numeric)) AND (("unit_cost_total_snapshot" IS NULL) OR ("unit_cost_total_snapshot" >= (0)::numeric)))) NOT VALID;



ALTER TABLE ONLY "public"."Dealers"
    ADD CONSTRAINT "companies_org_company_no_uniq" UNIQUE ("organization_id", "dealer_no");



ALTER TABLE ONLY "public"."ConfiguredProducts"
    ADD CONSTRAINT "configuredproducts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."DealerDocumentTermsDefaults"
    ADD CONSTRAINT "dealer_terms_unique" UNIQUE ("organization_id", "dealer_id", "doc_type");



ALTER TABLE ONLY "public"."Dealers"
    ADD CONSTRAINT "dealers_org_id_id_uniq" UNIQUE ("organization_id", "id");



ALTER TABLE ONLY "public"."ImportTaxRules"
    ADD CONSTRAINT "importtaxrules_org_category_unique" UNIQUE ("organization_id", "category_id");



ALTER TABLE ONLY "public"."OrganizationUsers"
    ADD CONSTRAINT "organizationusers_org_email_uq" UNIQUE ("organization_id", "user_email");



ALTER TABLE ONLY "public"."ProductTypes"
    ADD CONSTRAINT "producttypes_unique_code" UNIQUE ("organization_id", "code");



ALTER TABLE ONLY "public"."ProductTypes"
    ADD CONSTRAINT "producttypes_unique_name" UNIQUE ("organization_id", "name");



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "proposals_org_dealer_id_uniq" UNIQUE ("organization_id", "dealer_id", "id");



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "quotes_org_dealer_id_uniq" UNIQUE ("organization_id", "dealer_id", "id");



ALTER TABLE ONLY "public"."stg_catalog_items_import_raw"
    ADD CONSTRAINT "stg_catalog_items_import_raw_pkey" PRIMARY KEY ("row_id");



ALTER TABLE ONLY "public"."user_dealer_scope"
    ADD CONSTRAINT "user_dealer_scope_pkey" PRIMARY KEY ("user_id");



CREATE INDEX "app_user_invites_dealer_idx" ON "public"."AppUserInvites" USING "btree" ("dealer_id");



CREATE INDEX "app_user_invites_email_idx" ON "public"."AppUserInvites" USING "btree" ("email");



CREATE INDEX "app_user_invites_org_idx" ON "public"."AppUserInvites" USING "btree" ("organization_id");



CREATE INDEX "app_user_invites_token_hash_idx" ON "public"."AppUserInvites" USING "btree" ("token_hash");



CREATE INDEX "app_user_prefs_active_dealer_idx" ON "public"."AppUserPreferences" USING "btree" ("active_dealer_id");



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



CREATE INDEX "idx_appuserpermissions_permission_code" ON "public"."AppUserPermissions" USING "btree" ("permission_code");



CREATE INDEX "idx_appusers_auth_user" ON "public"."AppUsers" USING "btree" ("auth_user_id") WHERE ("deleted" = false);



CREATE INDEX "idx_appusers_auth_user_type" ON "public"."AppUsers" USING "btree" ("auth_user_id", "user_type") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "idx_appusers_auth_user_type_dealer_unique" ON "public"."AppUsers" USING "btree" ("auth_user_id", "user_type", COALESCE("dealer_id", '00000000-0000-0000-0000-000000000000'::"uuid")) WHERE ("deleted" = false);



CREATE INDEX "idx_appusers_org_type_dealer" ON "public"."AppUsers" USING "btree" ("organization_id", "user_type", "dealer_id");



CREATE INDEX "idx_appusers_organization_id" ON "public"."AppUsers" USING "btree" ("organization_id") WHERE ("deleted" = false);



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



CREATE INDEX "idx_ddtd_dealer" ON "public"."DealerDocumentTermsDefaults" USING "btree" ("dealer_id");



CREATE INDEX "idx_ddtd_dealer_doc" ON "public"."DealerDocumentTermsDefaults" USING "btree" ("dealer_id", "doc_type");



CREATE INDEX "idx_ddtd_org" ON "public"."DealerDocumentTermsDefaults" USING "btree" ("organization_id");



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



CREATE INDEX "idx_directory_contacts_created_by_user" ON "public"."DirectoryContacts" USING "btree" ("created_by_user_id") WHERE (("deleted" = false) AND ("created_by_user_id" IS NOT NULL));



CREATE INDEX "idx_directory_customers_created_by_user" ON "public"."DirectoryCustomers" USING "btree" ("created_by_user_id") WHERE (("deleted" = false) AND ("created_by_user_id" IS NOT NULL));



CREATE INDEX "idx_directorycontacts_contact_type" ON "public"."DirectoryContacts" USING "btree" ("contact_type");



CREATE INDEX "idx_directorycontacts_customer" ON "public"."DirectoryContacts" USING "btree" ("customer_id");



CREATE INDEX "idx_directorycontacts_org" ON "public"."DirectoryContacts" USING "btree" ("organization_id");



CREATE INDEX "idx_directorycustomers_company_id" ON "public"."DirectoryCustomers" USING "btree" ("dealer_id");



CREATE INDEX "idx_directorycustomers_org" ON "public"."DirectoryCustomers" USING "btree" ("organization_id");



CREATE INDEX "idx_directorycustomers_org_company" ON "public"."DirectoryCustomers" USING "btree" ("organization_id", "dealer_id");



CREATE INDEX "idx_dtt_dealer" ON "public"."DocumentTermsTemplates" USING "btree" ("dealer_id");



CREATE INDEX "idx_dtt_doc_type" ON "public"."DocumentTermsTemplates" USING "btree" ("doc_type");



CREATE INDEX "idx_dtt_org" ON "public"."DocumentTermsTemplates" USING "btree" ("organization_id");



CREATE INDEX "idx_dtt_org_dealer_doc" ON "public"."DocumentTermsTemplates" USING "btree" ("organization_id", "dealer_id", "doc_type");



CREATE INDEX "idx_dtt_org_doc" ON "public"."DocumentTermsTemplates" USING "btree" ("organization_id", "doc_type");



CREATE INDEX "idx_inv_balances_catalog_item" ON "public"."InventoryBalances" USING "btree" ("catalog_item_id");



CREATE INDEX "idx_inv_balances_org_wh" ON "public"."InventoryBalances" USING "btree" ("organization_id", "warehouse_id");



CREATE INDEX "idx_inv_profiles_catalog_item" ON "public"."InventoryItemProfiles" USING "btree" ("catalog_item_id");



CREATE INDEX "idx_inv_profiles_warehouse" ON "public"."InventoryItemProfiles" USING "btree" ("warehouse_id");



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



CREATE INDEX "idx_po_lines_catalog_item_id" ON "public"."PurchaseOrderLines" USING "btree" ("catalog_item_id");



CREATE INDEX "idx_po_lines_po_id" ON "public"."PurchaseOrderLines" USING "btree" ("purchase_order_id");



CREATE INDEX "idx_portalusers_org" ON "public"."DealerUsers" USING "btree" ("organization_id");



CREATE INDEX "idx_portalusers_user" ON "public"."DealerUsers" USING "btree" ("user_id");



CREATE INDEX "idx_proposal_line_addons_proposal" ON "public"."ProposalLineAddOns" USING "btree" ("proposal_id") WHERE ("deleted" = false);



CREATE INDEX "idx_proposal_line_addons_proposal_line" ON "public"."ProposalLineAddOns" USING "btree" ("proposal_line_id") WHERE ("deleted" = false);



CREATE INDEX "idx_proposallines_proposal_id" ON "public"."ProposalLines" USING "btree" ("proposal_id");



CREATE INDEX "idx_proposallines_quote_line_id" ON "public"."ProposalLines" USING "btree" ("quote_line_id") WHERE ("quote_line_id" IS NOT NULL);



CREATE INDEX "idx_proposals_customer_id" ON "public"."Proposals" USING "btree" ("customer_id") WHERE (("customer_id" IS NOT NULL) AND ("deleted" = false));



CREATE INDEX "idx_proposals_dealer_id" ON "public"."Proposals" USING "btree" ("dealer_id") WHERE ("deleted" = false);



CREATE INDEX "idx_proposals_organization_id" ON "public"."Proposals" USING "btree" ("organization_id") WHERE ("deleted" = false);



CREATE INDEX "idx_proposals_quote_id" ON "public"."Proposals" USING "btree" ("quote_id") WHERE ("deleted" = false);



CREATE INDEX "idx_proposals_status" ON "public"."Proposals" USING "btree" ("status") WHERE ("deleted" = false);



CREATE INDEX "idx_purchase_orders_expected_date" ON "public"."PurchaseOrders" USING "btree" ("expected_date");



CREATE INDEX "idx_purchase_orders_organization_id" ON "public"."PurchaseOrders" USING "btree" ("organization_id");



CREATE INDEX "idx_purchase_orders_status" ON "public"."PurchaseOrders" USING "btree" ("status");



CREATE INDEX "idx_purchase_orders_warehouse_id" ON "public"."PurchaseOrders" USING "btree" ("warehouse_id");



CREATE INDEX "idx_qlc_org_id" ON "public"."QuoteLineComponents" USING "btree" ("organization_id");



CREATE INDEX "idx_qlc_quote_line_id" ON "public"."QuoteLineComponents" USING "btree" ("quote_line_id");



CREATE INDEX "idx_qlc_role" ON "public"."QuoteLineComponents" USING "btree" ("component_role");



CREATE INDEX "idx_quote_lines_bom_template_id" ON "public"."QuoteLines" USING "btree" ("bom_template_id") WHERE ("bom_template_id" IS NOT NULL);



CREATE INDEX "idx_quote_lines_metadata" ON "public"."QuoteLines" USING "gin" ("metadata");



CREATE INDEX "idx_quote_lines_product_type" ON "public"."QuoteLines" USING "btree" ("product_type") WHERE ("product_type" IS NOT NULL);



CREATE INDEX "idx_quotelines_catalog_item_id" ON "public"."QuoteLines" USING "btree" ("catalog_item_id");



CREATE INDEX "idx_quotelines_category_id" ON "public"."QuoteLines" USING "btree" ("category_id");



CREATE INDEX "idx_quotelines_company_id" ON "public"."QuoteLines" USING "btree" ("dealer_id");



CREATE INDEX "idx_quotelines_configured_product_id" ON "public"."QuoteLines" USING "btree" ("configured_product_id");



CREATE INDEX "idx_quotelines_org_id" ON "public"."QuoteLines" USING "btree" ("organization_id");



CREATE INDEX "idx_quotelines_quote_id" ON "public"."QuoteLines" USING "btree" ("quote_id");



CREATE INDEX "idx_quotes_company" ON "public"."Quotes" USING "btree" ("dealer_id");



CREATE INDEX "idx_quotes_created_by" ON "public"."Quotes" USING "btree" ("created_by_user_id") WHERE ("deleted" = false);



CREATE INDEX "idx_quotes_customer_id" ON "public"."Quotes" USING "btree" ("customer_id") WHERE (("customer_id" IS NOT NULL) AND ("deleted" = false));



CREATE INDEX "idx_quotes_organization_id" ON "public"."Quotes" USING "btree" ("organization_id") WHERE ("deleted" = false);



CREATE INDEX "idx_quotes_status" ON "public"."Quotes" USING "btree" ("status") WHERE ("deleted" = false);



CREATE INDEX "idx_quotes_tracking_status" ON "public"."Quotes" USING "btree" ("tracking_status") WHERE (("deleted" = false) AND ("tracking_status" IS NOT NULL));



CREATE INDEX "idx_saleorderlines_so" ON "public"."SaleOrderLines" USING "btree" ("sales_order_id");



CREATE INDEX "idx_sales_orders_organization_id" ON "public"."SalesOrders" USING "btree" ("organization_id") WHERE ("deleted" = false);



CREATE INDEX "idx_sales_orders_quote_id" ON "public"."SalesOrders" USING "btree" ("quote_id") WHERE ("deleted" = false);



CREATE INDEX "idx_sales_orders_tracking_status" ON "public"."SalesOrders" USING "btree" ("tracking_status") WHERE ("deleted" = false);



CREATE INDEX "idx_salesorders_company" ON "public"."SalesOrders" USING "btree" ("dealer_id");



CREATE INDEX "idx_uds_org" ON "public"."user_dealer_scope" USING "btree" ("organization_id");



CREATE INDEX "idx_uds_org_dealer" ON "public"."user_dealer_scope" USING "btree" ("organization_id", "effective_dealer_id");



CREATE INDEX "idx_warehouses_organization_id" ON "public"."Warehouses" USING "btree" ("organization_id");



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



CREATE INDEX "quote_lines_product_type_id_idx" ON "public"."QuoteLines" USING "btree" ("product_type_id");



CREATE UNIQUE INDEX "quotes_org_dealer_quote_no_unique" ON "public"."Quotes" USING "btree" ("organization_id", "dealer_id", "quote_no") WHERE ("deleted" = false);



COMMENT ON INDEX "public"."quotes_org_dealer_quote_no_unique" IS 'Quote numbers are unique per organization and per dealer. Each dealer has independent sequence (QT-000001, QT-000002...).';



CREATE UNIQUE INDEX "sales_orders_org_so_no_unique" ON "public"."SalesOrders" USING "btree" ("organization_id", "sales_order_no") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "so_unique_quote" ON "public"."SalesOrders" USING "btree" ("quote_id") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "uq_bomcomponents_template_slot_active" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id", "slot_id") WHERE (("deleted" = false) AND ("archived" = false) AND ("slot_id" IS NOT NULL));



CREATE UNIQUE INDEX "uq_catalogitemcomponents_parent_child_role" ON "public"."CatalogItemComponents" USING "btree" ("organization_id", "parent_item_id", "child_item_id", "child_role");



CREATE UNIQUE INDEX "uq_dealers_org_name" ON "public"."Dealers" USING "btree" ("organization_id", "lower"("dealer_name")) WHERE ("deleted" = false);



CREATE UNIQUE INDEX "uq_fabric_rule" ON "public"."FabricRules" USING "btree" ("organization_id", "product_type_id", COALESCE("style_code", ''::"text"));



CREATE UNIQUE INDEX "uq_orguserpermissions_orguser_perm" ON "public"."OrganizationUserPermissions" USING "btree" ("organization_user_id", "permission_code");



CREATE UNIQUE INDEX "uq_proposals_org_dealer_proposal_no" ON "public"."Proposals" USING "btree" ("organization_id", "dealer_id", "proposal_no") WHERE (("deleted" = false) AND ("proposal_no" IS NOT NULL) AND ("proposal_no" <> ''::"text"));



COMMENT ON INDEX "public"."uq_proposals_org_dealer_proposal_no" IS 'Proposal numbers are unique per organization and per dealer. Each dealer has independent sequence (PRO-0100, PRO-0101...).';



CREATE UNIQUE INDEX "ux_bomcomponents_no_duplicate_child_sku" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id", "parent_component_id", "component_item_id") WHERE (("parent_component_id" IS NOT NULL) AND ("deleted" = false) AND ("archived" = false));



CREATE OR REPLACE TRIGGER "catalog_items_recompute_msrp" AFTER UPDATE OF "cost_exw" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."trg_catalog_items_recompute_msrp"();



CREATE OR REPLACE TRIGGER "catalogitems_validate_roll_pricing_mode" BEFORE INSERT OR UPDATE OF "is_roll", "roll_pricing_mode", "roll_width", "measure_basis" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."trg_catalogitems_validate_roll_pricing_mode"();



CREATE OR REPLACE TRIGGER "catalogitems_write_conversions" AFTER INSERT OR UPDATE OF "cost_exw", "unit_of_measure", "roll_width", "roll_width_value", "roll_width_uom", "roll_width_m", "is_roll", "units_per_purchase_unit" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."trg_catalogitems_write_conversions"();



CREATE OR REPLACE TRIGGER "enforce_mo_dealer_matches_salesorder" BEFORE INSERT OR UPDATE ON "public"."ManufacturingOrders" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_mo_dealer_matches_salesorder"();



CREATE OR REPLACE TRIGGER "enforce_orderlist_dealer_matches_salesorder" BEFORE INSERT OR UPDATE ON "public"."OrderList" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_orderlist_dealer_matches_salesorder"();



CREATE OR REPLACE TRIGGER "enforce_salesorders_dealer_matches_quote" BEFORE INSERT OR UPDATE ON "public"."SalesOrders" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_salesorders_dealer_matches_quote"();



CREATE OR REPLACE TRIGGER "set_audit_fields_trg" BEFORE INSERT OR UPDATE ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."set_audit_fields"();



CREATE OR REPLACE TRIGGER "set_audit_fields_trg" BEFORE INSERT OR UPDATE ON "public"."DirectoryCustomers" FOR EACH ROW EXECUTE FUNCTION "public"."set_audit_fields"();



CREATE OR REPLACE TRIGGER "set_audit_fields_trg" BEFORE INSERT OR UPDATE ON "public"."Proposals" FOR EACH ROW EXECUTE FUNCTION "public"."set_audit_fields"();



CREATE OR REPLACE TRIGGER "set_audit_fields_trg" BEFORE INSERT OR UPDATE ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."set_audit_fields"();



CREATE OR REPLACE TRIGGER "set_audit_fields_trg" BEFORE INSERT OR UPDATE ON "public"."SalesOrders" FOR EACH ROW EXECUTE FUNCTION "public"."set_audit_fields"();



CREATE OR REPLACE TRIGGER "trg_app_user_invites_updated_at" BEFORE UPDATE ON "public"."AppUserInvites" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_app_user_prefs_updated_at" BEFORE UPDATE ON "public"."AppUserPreferences" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_appuserroles_set_updated_at" BEFORE UPDATE ON "public"."AppUserRoles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_appusers_updated_at" BEFORE UPDATE ON "public"."AppUsers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_assert_cp_policy" BEFORE INSERT OR UPDATE OF "product_type_id", "config_snapshot", "quote_id" ON "public"."ConfiguredProducts" FOR EACH ROW EXECUTE FUNCTION "public"."trg_assert_cp_policy"();



CREATE OR REPLACE TRIGGER "trg_assert_policy_configured_products_ins" BEFORE INSERT ON "public"."ConfiguredProducts" FOR EACH ROW EXECUTE FUNCTION "public"."trg_assert_policy_configured_products"();



CREATE OR REPLACE TRIGGER "trg_assert_policy_configured_products_upd" BEFORE UPDATE OF "product_type_id", "quote_id", "config_snapshot" ON "public"."ConfiguredProducts" FOR EACH ROW EXECUTE FUNCTION "public"."trg_assert_policy_configured_products"();



CREATE OR REPLACE TRIGGER "trg_audit_directory_contacts" BEFORE INSERT OR UPDATE ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."set_audit_fields"();



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



CREATE OR REPLACE TRIGGER "trg_ddtd_set_updated_at" BEFORE UPDATE ON "public"."DealerDocumentTermsDefaults" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_dealers_set_dealer_no" BEFORE INSERT ON "public"."Dealers" FOR EACH ROW EXECUTE FUNCTION "public"."set_dealer_no"();



CREATE OR REPLACE TRIGGER "trg_dealertiers_updated_at" BEFORE UPDATE ON "public"."DealerTiers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_dircontacts_set_dealer" BEFORE INSERT ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."tg_set_dealer_id_from_portal_user"();



CREATE OR REPLACE TRIGGER "trg_directory_contacts_audit" BEFORE INSERT OR UPDATE ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."set_audit_app_user"();



CREATE OR REPLACE TRIGGER "trg_directorycontacts_fill_org_id" BEFORE INSERT OR UPDATE OF "dealer_id", "organization_id" ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."directorycontacts_fill_org_id"();



CREATE OR REPLACE TRIGGER "trg_directorycontacts_set_created_by" BEFORE INSERT ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by_fields"();



CREATE OR REPLACE TRIGGER "trg_directorycontacts_updated_at" BEFORE UPDATE ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_directorycustomers_set_created_by" BEFORE INSERT ON "public"."DirectoryCustomers" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by_fields"();



CREATE OR REPLACE TRIGGER "trg_directorycustomers_set_dealer" BEFORE INSERT ON "public"."DirectoryCustomers" FOR EACH ROW EXECUTE FUNCTION "public"."tg_set_dealer_id_from_portal_user"();



CREATE OR REPLACE TRIGGER "trg_directorycustomers_updated_at" BEFORE UPDATE ON "public"."DirectoryCustomers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_dtt_set_updated_at" BEFORE UPDATE ON "public"."DocumentTermsTemplates" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_enforce_active_item_role" BEFORE INSERT OR UPDATE OF "item_role" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_active_item_role"();



CREATE OR REPLACE TRIGGER "trg_enforce_dealer_policy_on_configured_product" BEFORE INSERT OR UPDATE ON "public"."ConfiguredProducts" FOR EACH ROW EXECUTE FUNCTION "public"."trg_enforce_dealer_policy_on_configured_product"();



CREATE OR REPLACE TRIGGER "trg_fill_msrp_item_identity" BEFORE INSERT OR UPDATE OF "catalog_item_id", "sku", "name", "collection_name", "variant_name" ON "public"."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION "public"."fill_msrp_item_identity"();



CREATE OR REPLACE TRIGGER "trg_fill_msrp_sku_name" BEFORE INSERT OR UPDATE OF "catalog_item_id", "sku", "name" ON "public"."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION "public"."fill_msrp_sku_name"();



CREATE OR REPLACE TRIGGER "trg_importtaxrules_recompute_itemsmsrp" AFTER INSERT OR UPDATE OF "import_tax_pct", "is_active" ON "public"."ImportTaxRules" FOR EACH ROW EXECUTE FUNCTION "public"."_trg_importtaxrules_recompute_itemsmsrp"();



CREATE OR REPLACE TRIGGER "trg_importtaxrules_updated_at" BEFORE UPDATE ON "public"."ImportTaxRules" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_manufacturingorders_updated_at" BEFORE UPDATE ON "public"."ManufacturingOrders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_organizations_updated_at" BEFORE UPDATE ON "public"."Organizations" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_portalusers_updated_at" BEFORE UPDATE ON "public"."DealerUsers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_producttypes_set_updated_at" BEFORE UPDATE ON "public"."ProductTypes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_proposal_line_addons_recalc_totals" AFTER INSERT OR DELETE OR UPDATE ON "public"."ProposalLineAddOns" FOR EACH ROW EXECUTE FUNCTION "public"."trg_proposal_line_addons_recalc_totals"();



CREATE OR REPLACE TRIGGER "trg_proposal_line_addons_set_updated_at" BEFORE UPDATE ON "public"."ProposalLineAddOns" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_proposal_lines_recalc_totals" AFTER INSERT OR DELETE OR UPDATE ON "public"."ProposalLines" FOR EACH ROW EXECUTE FUNCTION "public"."trg_proposal_lines_recalc_totals"();



CREATE OR REPLACE TRIGGER "trg_proposal_lines_set_updated_at" BEFORE UPDATE ON "public"."ProposalLines" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_proposal_lines_updated_at" BEFORE UPDATE ON "public"."ProposalLines" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_proposal_lines_validate_quote_line" BEFORE INSERT OR UPDATE OF "quote_line_id", "proposal_id" ON "public"."ProposalLines" FOR EACH ROW EXECUTE FUNCTION "public"."proposal_lines_validate_quote_line"();



CREATE OR REPLACE TRIGGER "trg_proposals_ensure_integrity" BEFORE INSERT OR UPDATE ON "public"."Proposals" FOR EACH ROW EXECUTE FUNCTION "public"."proposals_ensure_integrity"();

ALTER TABLE "public"."Proposals" ENABLE ALWAYS TRIGGER "trg_proposals_ensure_integrity";



CREATE OR REPLACE TRIGGER "trg_proposals_freeze_snapshot_on_sent" AFTER UPDATE OF "status" ON "public"."Proposals" FOR EACH ROW EXECUTE FUNCTION "public"."trg_proposals_freeze_snapshot_on_sent"();



CREATE OR REPLACE TRIGGER "trg_proposals_recalc_totals" AFTER UPDATE OF "global_discount_pct", "global_fee_amount", "global_installation_discount_pct", "global_installation_fee_pct" ON "public"."Proposals" FOR EACH ROW EXECUTE FUNCTION "public"."trg_proposals_recalc_totals"();



CREATE OR REPLACE TRIGGER "trg_proposals_set_updated_at" BEFORE UPDATE ON "public"."Proposals" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_proposals_updated_at" BEFORE UPDATE ON "public"."Proposals" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_ql_sync_scope" BEFORE INSERT OR UPDATE OF "quote_id" ON "public"."QuoteLines" FOR EACH ROW EXECUTE FUNCTION "public"."sync_quote_line_scope"();



CREATE OR REPLACE TRIGGER "trg_quote_approved" AFTER UPDATE OF "status" ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."on_quote_approved_create_sales_order"();



CREATE OR REPLACE TRIGGER "trg_quote_approved_to_sales_order" BEFORE UPDATE ON "public"."Quotes" FOR EACH ROW WHEN (("old"."status" IS DISTINCT FROM "new"."status")) EXECUTE FUNCTION "public"."handle_quote_approved"();



COMMENT ON TRIGGER "trg_quote_approved_to_sales_order" ON "public"."Quotes" IS 'Trigger: Automatically creates SalesOrder and OrderList when Quote is approved. Sets Quote.tracking_status.';



CREATE OR REPLACE TRIGGER "trg_quote_line_components_updated_at" BEFORE UPDATE ON "public"."QuoteLineComponents" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_quote_lines_pricing_write_via_rpc_only" BEFORE UPDATE ON "public"."QuoteLines" FOR EACH ROW EXECUTE FUNCTION "public"."trg_quote_lines_allow_pricing_write_only_via_rpc"();



CREATE OR REPLACE TRIGGER "trg_quote_lines_set_dealer_id" BEFORE INSERT OR UPDATE OF "quote_id", "organization_id", "dealer_id" ON "public"."QuoteLines" FOR EACH ROW EXECUTE FUNCTION "public"."quote_lines_set_dealer_id"();



CREATE OR REPLACE TRIGGER "trg_quote_lines_validate_dealer" BEFORE INSERT OR UPDATE OF "quote_id", "organization_id", "dealer_id" ON "public"."QuoteLines" FOR EACH ROW EXECUTE FUNCTION "public"."quote_lines_validate_dealer"();



CREATE OR REPLACE TRIGGER "trg_quotes_set_created_by" BEFORE INSERT ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."set_created_by_fields"();



CREATE OR REPLACE TRIGGER "trg_quotes_set_dealer" BEFORE INSERT ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."tg_set_dealer_id_from_portal_user"();



CREATE OR REPLACE TRIGGER "trg_quotes_updated_at" BEFORE UPDATE ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_recompute_msrp_on_catalog_item_change" AFTER INSERT OR UPDATE OF "cost_exw", "category_id", "unit_of_measure", "measure_basis", "roll_pricing_mode", "roll_width_m", "roll_width", "units_per_purchase_unit" ON "public"."CatalogItems" FOR EACH ROW WHEN (("new"."organization_id" IS NOT NULL)) EXECUTE FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"();



CREATE OR REPLACE TRIGGER "trg_recompute_msrp_on_category_margin_change" AFTER INSERT OR DELETE OR UPDATE ON "public"."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION "public"."trig_recompute_msrp_on_category_margin_change"();



CREATE OR REPLACE TRIGGER "trg_recompute_msrp_on_cost_settings_change" AFTER INSERT OR UPDATE OF "shipping_pct", "global_import_tax_pct" ON "public"."CostSettings" FOR EACH ROW EXECUTE FUNCTION "public"."trig_recompute_msrp_on_cost_settings_change"();



CREATE OR REPLACE TRIGGER "trg_recompute_msrp_on_import_tax_change" AFTER INSERT OR DELETE OR UPDATE ON "public"."ImportTaxRules" FOR EACH ROW EXECUTE FUNCTION "public"."trig_recompute_msrp_on_import_tax_change"();



CREATE OR REPLACE TRIGGER "trg_reject_oneoff_on_configured_products" BEFORE INSERT OR UPDATE OF "config_snapshot" ON "public"."ConfiguredProducts" FOR EACH ROW EXECUTE FUNCTION "public"."trg_reject_oneoff_on_configured_products"();



CREATE OR REPLACE TRIGGER "trg_salesorder_status" AFTER UPDATE OF "tracking_status" ON "public"."SalesOrders" FOR EACH ROW EXECUTE FUNCTION "public"."on_sales_order_status_mirror"();



CREATE OR REPLACE TRIGGER "trg_salesorders_updated_at" BEFORE UPDATE ON "public"."SalesOrders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at_product_type_role_rules" BEFORE UPDATE ON "public"."ProductTypeRoleRules" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at_product_type_role_rules"();



CREATE OR REPLACE TRIGGER "trg_sync_bom_template_slot_sku" BEFORE INSERT OR UPDATE OF "catalog_item_id", "fixed_catalog_item_id" ON "public"."BOMTemplateSlots" FOR EACH ROW EXECUTE FUNCTION "public"."sync_bom_template_slot_sku"();



CREATE OR REPLACE TRIGGER "trg_sync_catalogitems_to_msrp_safe" AFTER INSERT OR UPDATE OF "sku", "name", "collection_name", "variant_name", "unit_of_measure", "category_id", "cost_exw" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."sync_catalogitems_to_msrp_safe"();



CREATE OR REPLACE TRIGGER "trg_sync_dealeruser_appuser" AFTER INSERT OR UPDATE ON "public"."DealerUsers" FOR EACH ROW EXECUTE FUNCTION "public"."sync_dealer_user_to_appuser"();



CREATE OR REPLACE TRIGGER "trg_sync_order_list_tracking" AFTER UPDATE OF "tracking_status" ON "public"."SalesOrders" FOR EACH ROW WHEN (("old"."tracking_status" IS DISTINCT FROM "new"."tracking_status")) EXECUTE FUNCTION "public"."sync_order_list_tracking_status"();



COMMENT ON TRIGGER "trg_sync_order_list_tracking" ON "public"."SalesOrders" IS 'Trigger: Automatically syncs OrderList.tracking_status when SalesOrder.tracking_status changes.';



CREATE OR REPLACE TRIGGER "trg_sync_orguser_appuser" AFTER INSERT OR UPDATE ON "public"."OrganizationUsers" FOR EACH ROW EXECUTE FUNCTION "public"."sync_org_user_to_appuser"();



CREATE OR REPLACE TRIGGER "trg_sync_quote_line_scope" BEFORE INSERT OR UPDATE OF "quote_id" ON "public"."QuoteLines" FOR EACH ROW EXECUTE FUNCTION "public"."sync_quote_line_scope"();



CREATE OR REPLACE TRIGGER "trig_catmargins_msrp" AFTER INSERT OR UPDATE OF "minimum_margin_pct", "msrp_pct" ON "public"."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION "public"."trig_catmargins_msrp"();



CREATE OR REPLACE TRIGGER "update_order_list_updated_at" BEFORE UPDATE ON "public"."OrderList" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_organization_users_updated_at" BEFORE UPDATE ON "public"."OrganizationUsers" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_quotes_updated_at" BEFORE UPDATE ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_sales_orders_updated_at" BEFORE UPDATE ON "public"."SalesOrders" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."AppUserPermissions"
    ADD CONSTRAINT "AppUserPermissions_app_user_id_fkey" FOREIGN KEY ("app_user_id") REFERENCES "public"."AppUsers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."AppUserPermissions"
    ADD CONSTRAINT "AppUserPermissions_permission_code_fkey" FOREIGN KEY ("permission_code") REFERENCES "public"."Permissions"("code") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."AppUserPreferences"
    ADD CONSTRAINT "AppUserPreferences_active_dealer_id_fkey" FOREIGN KEY ("active_dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."AppUserPreferences"
    ADD CONSTRAINT "AppUserPreferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."AppUsers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."AppUserRolePermissions"
    ADD CONSTRAINT "AppUserRolePermissions_permission_code_fkey" FOREIGN KEY ("permission_code") REFERENCES "public"."Permissions"("code") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."AppUserRolePermissions"
    ADD CONSTRAINT "AppUserRolePermissions_role_code_fkey" FOREIGN KEY ("role_code") REFERENCES "public"."AppUserRoles"("code") ON DELETE CASCADE;



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



ALTER TABLE ONLY "public"."DealerConfiguratorPolicies"
    ADD CONSTRAINT "DealerConfiguratorPolicies_dealer_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."DealerConfiguratorPolicies"
    ADD CONSTRAINT "DealerConfiguratorPolicies_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."DealerDocumentTermsDefaults"
    ADD CONSTRAINT "DealerDocumentTermsDefaults_dealer_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."DealerDocumentTermsDefaults"
    ADD CONSTRAINT "DealerDocumentTermsDefaults_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."DocumentTermsTemplates"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DealerTiers"
    ADD CONSTRAINT "DealerTiers_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."DealerUsers"
    ADD CONSTRAINT "DealerUsers_dealer_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."Dealers"
    ADD CONSTRAINT "Dealers_dealer_tier_id_fkey" FOREIGN KEY ("dealer_tier_id") REFERENCES "public"."DealerTiers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_company_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."DirectoryCustomers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_company_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_primary_contact_id_fkey" FOREIGN KEY ("primary_contact_id") REFERENCES "public"."DirectoryContacts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."FabricRules"
    ADD CONSTRAINT "FabricRules_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id");



ALTER TABLE ONLY "public"."FabricRules"
    ADD CONSTRAINT "FabricRules_product_type_id_fkey" FOREIGN KEY ("product_type_id") REFERENCES "public"."ProductTypes"("id");



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



ALTER TABLE ONLY "public"."ProposalLineAddOns"
    ADD CONSTRAINT "ProposalLineAddOns_dealer_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."ProposalLineAddOns"
    ADD CONSTRAINT "ProposalLineAddOns_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ProposalLineAddOns"
    ADD CONSTRAINT "ProposalLineAddOns_proposal_id_fkey" FOREIGN KEY ("proposal_id") REFERENCES "public"."Proposals"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ProposalLineAddOns"
    ADD CONSTRAINT "ProposalLineAddOns_proposal_line_id_fkey" FOREIGN KEY ("proposal_line_id") REFERENCES "public"."ProposalLines"("id") ON DELETE CASCADE;



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
    ADD CONSTRAINT "Proposals_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."DirectoryCustomers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_dealer_id_fkey" FOREIGN KEY ("dealer_id") REFERENCES "public"."Dealers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_quote_id_fkey" FOREIGN KEY ("quote_id") REFERENCES "public"."Quotes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "Proposals_terms_source_template_id_fkey" FOREIGN KEY ("terms_source_template_id") REFERENCES "public"."DocumentTermsTemplates"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "Quotes_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "Quotes_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "Quotes_terms_source_template_id_fkey" FOREIGN KEY ("terms_source_template_id") REFERENCES "public"."DocumentTermsTemplates"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."SalesOrders"
    ADD CONSTRAINT "SalesOrders_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."SalesOrders"
    ADD CONSTRAINT "SalesOrders_quote_id_fkey" FOREIGN KEY ("quote_id") REFERENCES "public"."Quotes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."SalesOrders"
    ADD CONSTRAINT "SalesOrders_terms_source_template_id_fkey" FOREIGN KEY ("terms_source_template_id") REFERENCES "public"."DocumentTermsTemplates"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."AppUsers"
    ADD CONSTRAINT "appusers_role_code_fk" FOREIGN KEY ("role_code") REFERENCES "public"."AppUserRoles"("code");



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



ALTER TABLE ONLY "public"."DealerDocumentTermsDefaults"
    ADD CONSTRAINT "dealer_terms_dealer_fk" FOREIGN KEY ("organization_id", "dealer_id") REFERENCES "public"."Dealers"("organization_id", "id") ON UPDATE RESTRICT ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Dealers"
    ADD CONSTRAINT "dealers_primary_contact_app_user_id_fkey" FOREIGN KEY ("primary_contact_app_user_id") REFERENCES "public"."AppUsers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "dir_contacts_dealer_fk" FOREIGN KEY ("organization_id", "dealer_id") REFERENCES "public"."Dealers"("organization_id", "id") ON UPDATE RESTRICT ON DELETE CASCADE;



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "dir_customers_dealer_fk" FOREIGN KEY ("organization_id", "dealer_id") REFERENCES "public"."Dealers"("organization_id", "id") ON UPDATE RESTRICT ON DELETE CASCADE;



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



ALTER TABLE ONLY "public"."InventoryBalances"
    ADD CONSTRAINT "inv_balances_catalog_item_fk" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."InventoryBalances"
    ADD CONSTRAINT "inv_balances_org_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."InventoryBalances"
    ADD CONSTRAINT "inv_balances_warehouse_fk" FOREIGN KEY ("warehouse_id") REFERENCES "public"."Warehouses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."InventoryItemProfiles"
    ADD CONSTRAINT "inv_profiles_catalog_item_fk" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."InventoryItemProfiles"
    ADD CONSTRAINT "inv_profiles_warehouse_fk" FOREIGN KEY ("warehouse_id") REFERENCES "public"."Warehouses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."PurchaseOrderLines"
    ADD CONSTRAINT "po_lines_catalog_item_fk" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."PurchaseOrderLines"
    ADD CONSTRAINT "po_lines_po_fk" FOREIGN KEY ("purchase_order_id") REFERENCES "public"."PurchaseOrders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ProposalLines"
    ADD CONSTRAINT "proposallines_proposal_fk" FOREIGN KEY ("organization_id", "dealer_id", "proposal_id") REFERENCES "public"."Proposals"("organization_id", "dealer_id", "id") ON UPDATE RESTRICT ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Proposals"
    ADD CONSTRAINT "proposals_dealer_fk" FOREIGN KEY ("organization_id", "dealer_id") REFERENCES "public"."Dealers"("organization_id", "id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."PurchaseOrders"
    ADD CONSTRAINT "purchase_orders_organization_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."PurchaseOrders"
    ADD CONSTRAINT "purchase_orders_warehouse_fk" FOREIGN KEY ("warehouse_id") REFERENCES "public"."Warehouses"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."QuoteLineComponents"
    ADD CONSTRAINT "qlc_item_fk" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."QuoteLineComponents"
    ADD CONSTRAINT "qlc_quote_line_fk" FOREIGN KEY ("quote_line_id") REFERENCES "public"."QuoteLines"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."QuoteLines"
    ADD CONSTRAINT "quotelines_configured_product_id_fkey" FOREIGN KEY ("configured_product_id") REFERENCES "public"."ConfiguredProducts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."QuoteLines"
    ADD CONSTRAINT "quotelines_quote_fk" FOREIGN KEY ("quote_id") REFERENCES "public"."Quotes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "quotes_dealer_fk" FOREIGN KEY ("organization_id", "dealer_id") REFERENCES "public"."Dealers"("organization_id", "id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."SaleOrderLines"
    ADD CONSTRAINT "saleorderlines_so_fk" FOREIGN KEY ("sales_order_id") REFERENCES "public"."SalesOrders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_dealer_scope"
    ADD CONSTRAINT "user_dealer_scope_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."Warehouses"
    ADD CONSTRAINT "warehouses_organization_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE "public"."AppUserInvites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."AppUserPreferences" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Authenticated users can read permissions" ON "public"."Permissions" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."BOMTemplates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."CatalogItemComponents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."CatalogItemRollSpecs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."CatalogItemSupply" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ConfiguredProducts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."DealerDocumentTermsDefaults" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."DealerTiers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."DealerUsers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Dealers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."DirectoryContacts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."DirectoryCustomers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."DocumentTermsTemplates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."InventoryBalances" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."InventoryItemProfiles" ENABLE ROW LEVEL SECURITY;


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


ALTER TABLE "public"."ProposalLineAddOns" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ProposalLines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Proposals" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."PurchaseOrderLines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."PurchaseOrders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."QuoteLineComponents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."QuoteLines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Quotes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."SalesOrders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Users can insert own organization order list" ON "public"."OrderList" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "OrderList"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))));



CREATE POLICY "Users can read own organization order list" ON "public"."OrderList" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "OrderList"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))) AND ("deleted" = false)));



CREATE POLICY "Users can read own organization permissions" ON "public"."OrganizationUserPermissions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."id" = "OrganizationUserPermissions"."organization_user_id") AND (EXISTS ( SELECT 1
           FROM "public"."OrganizationUsers" "ou2"
          WHERE (("ou2"."organization_id" = "ou"."organization_id") AND ("ou2"."user_id" = "auth"."uid"()) AND ("ou2"."deleted" = false) AND ("ou2"."status" = 'active'::"public"."org_user_status"))))))));



CREATE POLICY "Users can read own organizations" ON "public"."Organizations" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."organization_id" = "Organizations"."id") AND ("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."deleted" = false) AND ("OrganizationUsers"."status" = 'active'::"public"."org_user_status")))));



CREATE POLICY "Users can update own organization order list" ON "public"."OrderList" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "OrderList"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status")))) AND ("deleted" = false)));



CREATE POLICY "Users can view ConfiguredProducts for their organization" ON "public"."ConfiguredProducts" FOR SELECT USING ((("organization_id" IN ( SELECT "OrganizationUsers"."organization_id"
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."deleted" = false)))) OR ("organization_id" IN ( SELECT "DealerUsers"."organization_id"
   FROM "public"."DealerUsers"
  WHERE (("DealerUsers"."user_id" = "auth"."uid"()) AND ("DealerUsers"."deleted" = false))))));



ALTER TABLE "public"."Warehouses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "app_user_invites_insert" ON "public"."AppUserInvites" FOR INSERT WITH CHECK (("public"."current_app_user_id"() IS NOT NULL));



CREATE POLICY "app_user_invites_read_own" ON "public"."AppUserInvites" FOR SELECT USING (("invited_by_app_user_id" = "public"."current_app_user_id"()));



CREATE POLICY "app_user_invites_update_own" ON "public"."AppUserInvites" FOR UPDATE USING (("invited_by_app_user_id" = "public"."current_app_user_id"())) WITH CHECK (("invited_by_app_user_id" = "public"."current_app_user_id"()));



CREATE POLICY "app_user_prefs_insert_own" ON "public"."AppUserPreferences" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."AppUsers" "au"
  WHERE (("au"."id" = "AppUserPreferences"."user_id") AND ("au"."auth_user_id" = "auth"."uid"())))));



CREATE POLICY "app_user_prefs_select_own" ON "public"."AppUserPreferences" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."AppUsers" "au"
  WHERE (("au"."id" = "AppUserPreferences"."user_id") AND ("au"."auth_user_id" = "auth"."uid"())))));



CREATE POLICY "app_user_prefs_update_own" ON "public"."AppUserPreferences" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."AppUsers" "au"
  WHERE (("au"."id" = "AppUserPreferences"."user_id") AND ("au"."auth_user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."AppUsers" "au"
  WHERE (("au"."id" = "AppUserPreferences"."user_id") AND ("au"."auth_user_id" = "auth"."uid"())))));



CREATE POLICY "bom_templates_select_own_org" ON "public"."BOMTemplates" FOR SELECT TO "authenticated" USING ((("organization_id" IN ( SELECT "OrganizationUsers"."organization_id"
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."deleted" = false)))) OR ("organization_id" IN ( SELECT "DealerUsers"."organization_id"
   FROM "public"."DealerUsers"
  WHERE (("DealerUsers"."user_id" = "auth"."uid"()) AND ("DealerUsers"."deleted" = false)))) OR ("organization_id" IS NULL)));



CREATE POLICY "catalogitemcomponents_select_own_org" ON "public"."CatalogItemComponents" FOR SELECT TO "authenticated" USING (("public"."is_org_user_superadmin"("organization_id") OR "public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "catalogitemcomponents_write_own_org" ON "public"."CatalogItemComponents" TO "authenticated" USING (("public"."is_org_user_superadmin"("organization_id") OR "public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id"))) WITH CHECK (("public"."is_org_user_superadmin"("organization_id") OR "public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "companyportalusers_select" ON "public"."DealerUsers" FOR SELECT USING ((("deleted" = false) AND ((("user_id" IS NOT NULL) AND ("user_id" = "auth"."uid"())) OR (("user_id" IS NULL) AND ("portal_user_email" IS NOT NULL) AND ("public"."current_auth_email"() IS NOT NULL) AND ("lower"(TRIM(BOTH FROM "portal_user_email")) = "public"."current_auth_email"())) OR (("organization_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "DealerUsers"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = ANY (ARRAY['active'::"public"."org_user_status", 'invited'::"public"."org_user_status"])))))))));



CREATE POLICY "configuredproducts_org_members_insert" ON "public"."ConfiguredProducts" FOR INSERT WITH CHECK (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "configuredproducts_org_members_select" ON "public"."ConfiguredProducts" FOR SELECT USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "configuredproducts_org_members_update" ON "public"."ConfiguredProducts" FOR UPDATE USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id"))) WITH CHECK (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "ddtd_select" ON "public"."DealerDocumentTermsDefaults" FOR SELECT TO "authenticated" USING ((("organization_id" IN ( SELECT "ou"."organization_id"
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND (("ou"."deleted" IS NULL) OR ("ou"."deleted" = false))))) AND ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND (("ou"."deleted" IS NULL) OR ("ou"."deleted" = false))))) OR ("dealer_id" = ( SELECT "au"."dealer_id"
   FROM "public"."AppUsers" "au"
  WHERE ("au"."auth_user_id" = "auth"."uid"())
 LIMIT 1)))));



CREATE POLICY "dealers_insert_own_org" ON "public"."Dealers" FOR INSERT WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "dealers_select_own_org" ON "public"."Dealers" FOR SELECT USING (((("deleted" IS NULL) OR ("deleted" = false)) AND ("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id"))));



CREATE POLICY "dealers_update_own_org" ON "public"."Dealers" FOR UPDATE USING ("public"."is_org_owner_or_admin"("organization_id")) WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "dealertiers_insert_own_org" ON "public"."DealerTiers" FOR INSERT WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "dealertiers_select_own_org" ON "public"."DealerTiers" FOR SELECT USING ("public"."is_org_member"("organization_id"));



CREATE POLICY "dealertiers_update_own_org" ON "public"."DealerTiers" FOR UPDATE USING ("public"."is_org_owner_or_admin"("organization_id")) WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "dealerusers_insert_own_org" ON "public"."DealerUsers" FOR INSERT WITH CHECK ("public"."is_dealer_owner_or_admin"("dealer_id"));



CREATE POLICY "dealerusers_select_bomtemplates" ON "public"."BOMTemplates" FOR SELECT USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "dealerusers_select_configured_products" ON "public"."ConfiguredProducts" FOR SELECT USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "dealerusers_select_stable" ON "public"."DealerUsers" FOR SELECT USING (((("dealer_id" IS NOT NULL) AND "public"."is_dealer_member"("dealer_id")) OR (("user_id" = "auth"."uid"()) AND ("deleted" = false))));



CREATE POLICY "dealerusers_update_self" ON "public"."DealerUsers" FOR UPDATE USING (((("dealer_id" IS NOT NULL) AND "public"."is_dealer_member"("dealer_id")) OR (("user_id" = "auth"."uid"()) AND ("deleted" = false)))) WITH CHECK (((("dealer_id" IS NOT NULL) AND "public"."is_dealer_member"("dealer_id")) OR (("user_id" = "auth"."uid"()) AND ("deleted" = false))));



CREATE POLICY "delete_catalog_item_roll_specs" ON "public"."CatalogItemRollSpecs" FOR DELETE USING ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "delete_catalog_item_supply" ON "public"."CatalogItemSupply" FOR DELETE USING ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "dircontacts_insert" ON "public"."DirectoryContacts" FOR INSERT TO "authenticated" WITH CHECK ((("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"())))));



CREATE POLICY "dircontacts_select" ON "public"."DirectoryContacts" FOR SELECT TO "authenticated" USING (((("deleted" = false) OR ("deleted" IS NULL)) AND ("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"())))));



CREATE POLICY "dircontacts_update" ON "public"."DirectoryContacts" FOR UPDATE TO "authenticated" USING (((("deleted" = false) OR ("deleted" IS NULL)) AND ("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"()))))) WITH CHECK ((("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"())))));



CREATE POLICY "dircustomers_insert" ON "public"."DirectoryCustomers" FOR INSERT TO "authenticated" WITH CHECK ((("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"())))));



CREATE POLICY "dircustomers_select" ON "public"."DirectoryCustomers" FOR SELECT TO "authenticated" USING (((("deleted" = false) OR ("deleted" IS NULL)) AND ("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"())))));



CREATE POLICY "dircustomers_update" ON "public"."DirectoryCustomers" FOR UPDATE TO "authenticated" USING (((("deleted" = false) OR ("deleted" IS NULL)) AND ("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"()))))) WITH CHECK ((("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"())))));



CREATE POLICY "dtt_insert" ON "public"."DocumentTermsTemplates" FOR INSERT TO "authenticated" WITH CHECK (((("organization_id" IN ( SELECT "ou"."organization_id"
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND (("ou"."deleted" IS NULL) OR ("ou"."deleted" = false))))) AND (EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND (("ou"."deleted" IS NULL) OR ("ou"."deleted" = false)))))) OR (("dealer_id" IS NOT NULL) AND ("dealer_id" = ( SELECT "au"."dealer_id"
   FROM "public"."AppUsers" "au"
  WHERE ("au"."auth_user_id" = "auth"."uid"())
 LIMIT 1))) OR (("dealer_id" IS NOT NULL) AND "public"."is_dealer_portal_user_with_write"("dealer_id") AND ("organization_id" = ( SELECT "d"."organization_id"
   FROM "public"."Dealers" "d"
  WHERE (("d"."id" = "DocumentTermsTemplates"."dealer_id") AND (("d"."deleted" IS NULL) OR ("d"."deleted" = false)))
 LIMIT 1)))));



CREATE POLICY "dtt_select" ON "public"."DocumentTermsTemplates" FOR SELECT TO "authenticated" USING (((("organization_id" IN ( SELECT "ou"."organization_id"
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND (("ou"."deleted" IS NULL) OR ("ou"."deleted" = false))))) AND (("dealer_id" IS NULL) OR ("dealer_id" IN ( SELECT "au"."dealer_id"
   FROM "public"."AppUsers" "au"
  WHERE (("au"."auth_user_id" = "auth"."uid"()) AND ("au"."dealer_id" IS NOT NULL))
 LIMIT 1)) OR (EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou2"
  WHERE (("ou2"."user_id" = "auth"."uid"()) AND (("ou2"."deleted" IS NULL) OR ("ou2"."deleted" = false))))))) OR (("dealer_id" IS NOT NULL) AND "public"."is_dealer_portal_user"("dealer_id")) OR (("dealer_id" IS NULL) AND ("organization_id" IN ( SELECT "du"."organization_id"
   FROM "public"."DealerUsers" "du"
  WHERE (("du"."user_id" = "auth"."uid"()) AND (("du"."deleted" IS NULL) OR ("du"."deleted" = false)) AND (("du"."status" IS NULL) OR ("du"."status" = ANY (ARRAY['active'::"public"."portal_user_status", 'invited'::"public"."portal_user_status"])))))))));



CREATE POLICY "dtt_update" ON "public"."DocumentTermsTemplates" FOR UPDATE TO "authenticated" USING (((("organization_id" IN ( SELECT "ou"."organization_id"
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND (("ou"."deleted" IS NULL) OR ("ou"."deleted" = false))))) AND ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND (("ou"."deleted" IS NULL) OR ("ou"."deleted" = false))))) OR ("dealer_id" = ( SELECT "au"."dealer_id"
   FROM "public"."AppUsers" "au"
  WHERE ("au"."auth_user_id" = "auth"."uid"())
 LIMIT 1)))) OR ("dealer_id" = ( SELECT "au"."dealer_id"
   FROM "public"."AppUsers" "au"
  WHERE ("au"."auth_user_id" = "auth"."uid"())
 LIMIT 1)) OR (("dealer_id" IS NOT NULL) AND "public"."is_dealer_portal_user_with_write"("dealer_id")))) WITH CHECK (true);



CREATE POLICY "insert_catalog_item_roll_specs" ON "public"."CatalogItemRollSpecs" FOR INSERT WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "insert_catalog_item_supply" ON "public"."CatalogItemSupply" FOR INSERT WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "inv_balances_insert_org" ON "public"."InventoryBalances" FOR INSERT WITH CHECK (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "inv_balances_select_org" ON "public"."InventoryBalances" FOR SELECT USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "inv_balances_update_org" ON "public"."InventoryBalances" FOR UPDATE USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "inv_profiles_insert_org" ON "public"."InventoryItemProfiles" FOR INSERT WITH CHECK (("public"."is_org_user_member_strict"(( SELECT "w"."organization_id"
   FROM "public"."Warehouses" "w"
  WHERE ("w"."id" = "InventoryItemProfiles"."warehouse_id"))) OR "public"."is_portal_user_in_org"(( SELECT "w"."organization_id"
   FROM "public"."Warehouses" "w"
  WHERE ("w"."id" = "InventoryItemProfiles"."warehouse_id")))));



CREATE POLICY "inv_profiles_select_org" ON "public"."InventoryItemProfiles" FOR SELECT USING (("public"."is_org_user_member_strict"(( SELECT "w"."organization_id"
   FROM "public"."Warehouses" "w"
  WHERE ("w"."id" = "InventoryItemProfiles"."warehouse_id"))) OR "public"."is_portal_user_in_org"(( SELECT "w"."organization_id"
   FROM "public"."Warehouses" "w"
  WHERE ("w"."id" = "InventoryItemProfiles"."warehouse_id")))));



CREATE POLICY "inv_profiles_update_org" ON "public"."InventoryItemProfiles" FOR UPDATE USING (("public"."is_org_user_member_strict"(( SELECT "w"."organization_id"
   FROM "public"."Warehouses" "w"
  WHERE ("w"."id" = "InventoryItemProfiles"."warehouse_id"))) OR "public"."is_portal_user_in_org"(( SELECT "w"."organization_id"
   FROM "public"."Warehouses" "w"
  WHERE ("w"."id" = "InventoryItemProfiles"."warehouse_id")))));



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



CREATE POLICY "org_admins_update" ON "public"."BOMTemplates" FOR UPDATE USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id"))) WITH CHECK (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "org_admins_write" ON "public"."BOMTemplates" FOR INSERT WITH CHECK (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "org_member_select" ON "public"."Organizations" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."organization_id" = "OrganizationUsers"."id") AND ("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."deleted" = false) AND ("OrganizationUsers"."status" = 'active'::"public"."org_user_status")))));



CREATE POLICY "org_members_select" ON "public"."BOMTemplates" FOR SELECT USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



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



CREATE POLICY "po_lines_insert_via_po" ON "public"."PurchaseOrderLines" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."PurchaseOrders" "po"
  WHERE (("po"."id" = "PurchaseOrderLines"."purchase_order_id") AND ("public"."is_org_user_member_strict"("po"."organization_id") OR "public"."is_portal_user_in_org"("po"."organization_id"))))));



CREATE POLICY "po_lines_select_via_po" ON "public"."PurchaseOrderLines" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."PurchaseOrders" "po"
  WHERE (("po"."id" = "PurchaseOrderLines"."purchase_order_id") AND ("public"."is_org_user_member_strict"("po"."organization_id") OR "public"."is_portal_user_in_org"("po"."organization_id"))))));



CREATE POLICY "po_lines_update_via_po" ON "public"."PurchaseOrderLines" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."PurchaseOrders" "po"
  WHERE (("po"."id" = "PurchaseOrderLines"."purchase_order_id") AND ("public"."is_org_user_member_strict"("po"."organization_id") OR "public"."is_portal_user_in_org"("po"."organization_id"))))));



CREATE POLICY "proposal_line_addons_delete" ON "public"."ProposalLineAddOns" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."Proposals" "p"
  WHERE (("p"."id" = "ProposalLineAddOns"."proposal_id") AND ((("p"."organization_id" IS NOT NULL) AND "public"."is_org_member"("p"."organization_id")) OR (("p"."dealer_id" IS NOT NULL) AND ("public"."is_dealer_portal_user_with_write"("p"."dealer_id") OR ("public"."is_dealer_portal_user"("p"."dealer_id") AND ("p"."created_by_user_id" = "auth"."uid"())))))))));



CREATE POLICY "proposal_line_addons_insert" ON "public"."ProposalLineAddOns" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."Proposals" "p"
  WHERE (("p"."id" = "ProposalLineAddOns"."proposal_id") AND ("p"."deleted" = false) AND ((("p"."organization_id" IS NOT NULL) AND "public"."is_org_member"("p"."organization_id")) OR (("p"."dealer_id" IS NOT NULL) AND ("public"."is_dealer_portal_user_with_write"("p"."dealer_id") OR ("public"."is_dealer_portal_user"("p"."dealer_id") AND ("p"."created_by_user_id" = "auth"."uid"())))))))));



CREATE POLICY "proposal_line_addons_select" ON "public"."ProposalLineAddOns" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."Proposals" "p"
  WHERE (("p"."id" = "ProposalLineAddOns"."proposal_id") AND ((("p"."organization_id" IS NOT NULL) AND "public"."is_org_member"("p"."organization_id")) OR (("p"."dealer_id" IS NOT NULL) AND "public"."is_dealer_portal_user"("p"."dealer_id")))))));



CREATE POLICY "proposal_line_addons_update" ON "public"."ProposalLineAddOns" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."Proposals" "p"
  WHERE (("p"."id" = "ProposalLineAddOns"."proposal_id") AND ((("p"."organization_id" IS NOT NULL) AND "public"."is_org_member"("p"."organization_id")) OR (("p"."dealer_id" IS NOT NULL) AND ("public"."is_dealer_portal_user_with_write"("p"."dealer_id") OR ("public"."is_dealer_portal_user"("p"."dealer_id") AND ("p"."created_by_user_id" = "auth"."uid"()))))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."Proposals" "p"
  WHERE (("p"."id" = "ProposalLineAddOns"."proposal_id") AND ((("p"."organization_id" IS NOT NULL) AND "public"."is_org_member"("p"."organization_id")) OR (("p"."dealer_id" IS NOT NULL) AND ("public"."is_dealer_portal_user_with_write"("p"."dealer_id") OR ("public"."is_dealer_portal_user"("p"."dealer_id") AND ("p"."created_by_user_id" = "auth"."uid"())))))))));



CREATE POLICY "proposallines_delete" ON "public"."ProposalLines" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."Proposals" "p"
  WHERE (("p"."id" = "ProposalLines"."proposal_id") AND ((("p"."organization_id" IS NOT NULL) AND "public"."is_org_member"("p"."organization_id")) OR (("p"."dealer_id" IS NOT NULL) AND ("public"."is_dealer_portal_user_with_write"("p"."dealer_id") OR ("public"."is_dealer_portal_user"("p"."dealer_id") AND ("p"."created_by_user_id" = "auth"."uid"())))))))));



CREATE POLICY "proposallines_insert" ON "public"."ProposalLines" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."Proposals" "p"
  WHERE (("p"."id" = "ProposalLines"."proposal_id") AND ("p"."deleted" = false) AND ((("p"."organization_id" IS NOT NULL) AND "public"."is_org_member"("p"."organization_id")) OR (("p"."dealer_id" IS NOT NULL) AND ("public"."is_dealer_portal_user_with_write"("p"."dealer_id") OR ("public"."is_dealer_portal_user"("p"."dealer_id") AND ("p"."created_by_user_id" = "auth"."uid"())))))))));



CREATE POLICY "proposallines_select" ON "public"."ProposalLines" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."Proposals" "p"
  WHERE (("p"."id" = "ProposalLines"."proposal_id") AND ("p"."deleted" IS NOT TRUE) AND ((("p"."organization_id" IS NOT NULL) AND "public"."is_org_member"("p"."organization_id")) OR (("p"."dealer_id" IS NOT NULL) AND "public"."is_dealer_portal_user"("p"."dealer_id")))))));



CREATE POLICY "proposallines_update" ON "public"."ProposalLines" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."Proposals" "p"
  WHERE (("p"."id" = "ProposalLines"."proposal_id") AND ((("p"."organization_id" IS NOT NULL) AND "public"."is_org_member"("p"."organization_id")) OR (("p"."dealer_id" IS NOT NULL) AND ("public"."is_dealer_portal_user_with_write"("p"."dealer_id") OR ("public"."is_dealer_portal_user"("p"."dealer_id") AND ("p"."created_by_user_id" = "auth"."uid"()))))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."Proposals" "p"
  WHERE (("p"."id" = "ProposalLines"."proposal_id") AND ((("p"."organization_id" IS NOT NULL) AND "public"."is_org_member"("p"."organization_id")) OR (("p"."dealer_id" IS NOT NULL) AND ("public"."is_dealer_portal_user_with_write"("p"."dealer_id") OR ("public"."is_dealer_portal_user"("p"."dealer_id") AND ("p"."created_by_user_id" = "auth"."uid"())))))))));



CREATE POLICY "proposals_insert" ON "public"."Proposals" FOR INSERT TO "authenticated" WITH CHECK ((("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"())))));



CREATE POLICY "proposals_select" ON "public"."Proposals" FOR SELECT TO "authenticated" USING ((("deleted" IS NOT TRUE) AND ("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"())) OR (("dealer_id" IS NOT NULL) AND "public"."session_is_dealer_portal"("dealer_id")))));



CREATE POLICY "proposals_update" ON "public"."Proposals" FOR UPDATE TO "authenticated" USING ((("deleted" IS NOT TRUE) AND ("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR (("dealer_id" IS NOT NULL) AND "public"."session_is_dealer_portal"("dealer_id") AND (("current_setting"('app.role_code'::"text", true) = 'dealer_manager'::"text") OR ("created_by_user_id" = "auth"."uid"())))))) WITH CHECK ((("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR (("dealer_id" IS NOT NULL) AND "public"."session_is_dealer_portal"("dealer_id") AND (("current_setting"('app.role_code'::"text", true) = 'dealer_manager'::"text") OR ("created_by_user_id" = "auth"."uid"()))))));



CREATE POLICY "purchase_orders_insert_org" ON "public"."PurchaseOrders" FOR INSERT WITH CHECK (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "purchase_orders_select_org" ON "public"."PurchaseOrders" FOR SELECT USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "purchase_orders_update_org" ON "public"."PurchaseOrders" FOR UPDATE USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "qlc_delete" ON "public"."QuoteLineComponents" FOR DELETE USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "qlc_insert" ON "public"."QuoteLineComponents" FOR INSERT WITH CHECK (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "qlc_select" ON "public"."QuoteLineComponents" FOR SELECT USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "qlc_update" ON "public"."QuoteLineComponents" FOR UPDATE USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id"))) WITH CHECK (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "quotelines_delete" ON "public"."QuoteLines" FOR DELETE USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "quotelines_insert" ON "public"."QuoteLines" FOR INSERT WITH CHECK ((("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")) AND (EXISTS ( SELECT 1
   FROM "public"."Quotes" "q"
  WHERE (("q"."id" = "QuoteLines"."quote_id") AND ("q"."organization_id" = "QuoteLines"."organization_id") AND ("q"."deleted" = false))))));



CREATE POLICY "quotelines_select" ON "public"."QuoteLines" FOR SELECT USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "quotelines_update" ON "public"."QuoteLines" FOR UPDATE USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id"))) WITH CHECK (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "quotes_insert" ON "public"."Quotes" FOR INSERT TO "authenticated" WITH CHECK ((("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"())))));



CREATE POLICY "quotes_select" ON "public"."Quotes" FOR SELECT TO "authenticated" USING ((("deleted" IS NOT TRUE) AND ("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"())))));



CREATE POLICY "quotes_update" ON "public"."Quotes" FOR UPDATE TO "authenticated" USING ((("deleted" IS NOT TRUE) AND ("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"()))))) WITH CHECK ((("organization_id" IS NOT NULL) AND (("public"."session_is_org_user"("organization_id") AND (("public"."current_dealer_id"() IS NULL) OR ("dealer_id" = "public"."current_dealer_id"()))) OR ("public"."session_is_dealer_user"("organization_id") AND ("dealer_id" = "public"."current_dealer_id"())))));



CREATE POLICY "salesorders_dealer_insert" ON "public"."SalesOrders" FOR INSERT WITH CHECK ((("organization_id" IS NOT NULL) AND ("dealer_id" IS NOT NULL) AND ("dealer_id" = ANY ("public"."current_user_dealer_ids"("organization_id")))));



CREATE POLICY "salesorders_dealer_select" ON "public"."SalesOrders" FOR SELECT USING ((("organization_id" IS NOT NULL) AND ("dealer_id" IS NOT NULL) AND ("dealer_id" = ANY ("public"."current_user_dealer_ids"("organization_id")))));



CREATE POLICY "salesorders_dealer_update" ON "public"."SalesOrders" FOR UPDATE USING ((("organization_id" IS NOT NULL) AND ("dealer_id" IS NOT NULL) AND ("dealer_id" = ANY ("public"."current_user_dealer_ids"("organization_id"))))) WITH CHECK ((("organization_id" IS NOT NULL) AND ("dealer_id" IS NOT NULL) AND ("dealer_id" = ANY ("public"."current_user_dealer_ids"("organization_id")))));



CREATE POLICY "salesorders_org_insert" ON "public"."SalesOrders" FOR INSERT TO "authenticated" WITH CHECK ((("organization_id" IS NOT NULL) AND "public"."is_internal_org_user"("organization_id")));



CREATE POLICY "salesorders_org_select" ON "public"."SalesOrders" FOR SELECT TO "authenticated" USING ((("organization_id" IS NOT NULL) AND "public"."is_internal_org_user"("organization_id")));



CREATE POLICY "salesorders_org_update" ON "public"."SalesOrders" FOR UPDATE TO "authenticated" USING ((("organization_id" IS NOT NULL) AND "public"."is_internal_org_user"("organization_id"))) WITH CHECK ((("organization_id" IS NOT NULL) AND "public"."is_internal_org_user"("organization_id")));



CREATE POLICY "select_catalog_item_roll_specs" ON "public"."CatalogItemRollSpecs" FOR SELECT USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "select_catalog_item_supply" ON "public"."CatalogItemSupply" FOR SELECT USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "uds_owner" ON "public"."user_dealer_scope" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "update_catalog_item_roll_specs" ON "public"."CatalogItemRollSpecs" FOR UPDATE USING ("public"."is_org_owner_or_admin"("organization_id")) WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "update_catalog_item_supply" ON "public"."CatalogItemSupply" FOR UPDATE USING ("public"."is_org_owner_or_admin"("organization_id")) WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



ALTER TABLE "public"."user_dealer_scope" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "warehouses_insert_org" ON "public"."Warehouses" FOR INSERT WITH CHECK (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "warehouses_select_org" ON "public"."Warehouses" FOR SELECT USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));



CREATE POLICY "warehouses_update_org" ON "public"."Warehouses" FOR UPDATE USING (("public"."is_org_user_member_strict"("organization_id") OR "public"."is_portal_user_in_org"("organization_id")));





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



GRANT ALL ON FUNCTION "public"."accept_app_user_invite"("p_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."accept_app_user_invite"("p_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."accept_app_user_invite"("p_token" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."app_effective_dealer_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."app_effective_dealer_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."app_effective_dealer_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."apply_audit_if_table_exists"("p_table" "regclass") TO "anon";
GRANT ALL ON FUNCTION "public"."apply_audit_if_table_exists"("p_table" "regclass") TO "authenticated";
GRANT ALL ON FUNCTION "public"."apply_audit_if_table_exists"("p_table" "regclass") TO "service_role";



REVOKE ALL ON FUNCTION "public"."approve_quote"("p_quote_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."approve_quote"("p_quote_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."approve_quote"("p_quote_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."approve_quote"("p_quote_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."assert_dealer_configurator_policy"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."assert_dealer_configurator_policy"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."assert_dealer_configurator_policy"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") TO "service_role";



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



GRANT ALL ON FUNCTION "public"."clear_effective_dealer_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."clear_effective_dealer_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."clear_effective_dealer_id"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."clear_my_must_change_password"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."clear_my_must_change_password"() TO "anon";
GRANT ALL ON FUNCTION "public"."clear_my_must_change_password"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."clear_my_must_change_password"() TO "service_role";



GRANT ALL ON FUNCTION "public"."commit_accessories_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_accessories" "jsonb", "p_area" "text", "p_position" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."commit_accessories_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_accessories" "jsonb", "p_area" "text", "p_position" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."commit_accessories_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_accessories" "jsonb", "p_area" "text", "p_position" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."commit_configured_product_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_configured_product_id" "uuid", "p_dealer_id" "uuid", "p_position" "text", "p_area" "text", "p_fabric_drop" "text", "p_installation_type" "text", "p_installation_location" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."commit_configured_product_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_configured_product_id" "uuid", "p_dealer_id" "uuid", "p_position" "text", "p_area" "text", "p_fabric_drop" "text", "p_installation_type" "text", "p_installation_location" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."commit_configured_product_to_quote_line"("p_org_id" "uuid", "p_quote_id" "uuid", "p_configured_product_id" "uuid", "p_dealer_id" "uuid", "p_position" "text", "p_area" "text", "p_fabric_drop" "text", "p_installation_type" "text", "p_installation_location" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_fabric_pricing_from_rule"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_style_code" "text", "p_height_m" numeric, "p_width_m" numeric, "p_roll_width_m" numeric, "p_msrp_per_m" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_fabric_pricing_from_rule"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_style_code" "text", "p_height_m" numeric, "p_width_m" numeric, "p_roll_width_m" numeric, "p_msrp_per_m" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_fabric_pricing_from_rule"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_style_code" "text", "p_height_m" numeric, "p_width_m" numeric, "p_roll_width_m" numeric, "p_msrp_per_m" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_prices_from_cost"("p_total_cost_landed" numeric, "p_sale_in_margin_pct" numeric, "p_sale_out_margin_pct" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_prices_from_cost"("p_total_cost_landed" numeric, "p_sale_in_margin_pct" numeric, "p_sale_out_margin_pct" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_prices_from_cost"("p_total_cost_landed" numeric, "p_sale_in_margin_pct" numeric, "p_sale_out_margin_pct" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_prices_from_landed_cost"("p_total_cost_landed" numeric, "p_sale_in_margin_pct" numeric, "p_sale_out_margin_pct" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_prices_from_landed_cost"("p_total_cost_landed" numeric, "p_sale_in_margin_pct" numeric, "p_sale_out_margin_pct" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_prices_from_landed_cost"("p_total_cost_landed" numeric, "p_sale_in_margin_pct" numeric, "p_sale_out_margin_pct" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_pricing_cost_exw"("p_cost_exw" numeric, "p_purchase_uom" "text", "p_pricing_uom" "text", "p_units_per_purchase_unit" numeric, "p_roll_width_m" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_pricing_cost_exw"("p_cost_exw" numeric, "p_purchase_uom" "text", "p_pricing_uom" "text", "p_units_per_purchase_unit" numeric, "p_roll_width_m" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_pricing_cost_exw"("p_cost_exw" numeric, "p_purchase_uom" "text", "p_pricing_uom" "text", "p_units_per_purchase_unit" numeric, "p_roll_width_m" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_quote_line_cost"("p_quote_line_id" "uuid", "p_options" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."compute_quote_line_cost"("p_quote_line_id" "uuid", "p_options" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_quote_line_cost"("p_quote_line_id" "uuid", "p_options" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_roll_conversions"("p_cost_exw" numeric, "p_uom" "text", "p_roll_width" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."compute_roll_conversions"("p_cost_exw" numeric, "p_uom" "text", "p_roll_width" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_roll_conversions"("p_cost_exw" numeric, "p_uom" "text", "p_roll_width" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."convert_unit_price"("p_price" numeric, "p_from" "text", "p_to" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."convert_unit_price"("p_price" numeric, "p_from" "text", "p_to" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."convert_unit_price"("p_price" numeric, "p_from" "text", "p_to" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."cost_to_per_m"("p_cost" numeric, "p_uom" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."cost_to_per_m"("p_cost" numeric, "p_uom" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cost_to_per_m"("p_cost" numeric, "p_uom" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_app_user_invite"("p_email" "text", "p_user_type" "text", "p_role_code" "text", "p_dealer_id" "uuid", "p_display_name" "text", "p_expires_in_hours" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."create_app_user_invite"("p_email" "text", "p_user_type" "text", "p_role_code" "text", "p_dealer_id" "uuid", "p_display_name" "text", "p_expires_in_hours" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_app_user_invite"("p_email" "text", "p_user_type" "text", "p_role_code" "text", "p_dealer_id" "uuid", "p_display_name" "text", "p_expires_in_hours" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_quote_line_cost_snapshot"("p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_quote_line_cost_snapshot"("p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_quote_line_cost_snapshot"("p_quote_line_id" "uuid") TO "service_role";



GRANT SELECT ON TABLE "public"."AppUsers" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."AppUsers" TO "authenticated";
GRANT ALL ON TABLE "public"."AppUsers" TO "service_role";



REVOKE ALL ON FUNCTION "public"."current_app_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."current_app_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_app_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_app_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_app_user_dealer_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_app_user_dealer_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_app_user_dealer_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_app_user_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_app_user_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_app_user_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_app_user_org_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_app_user_org_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_app_user_org_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_app_user_type"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_app_user_type"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_app_user_type"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_auth_email"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_auth_email"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_auth_email"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_dealer_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_dealer_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_dealer_id"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."current_dealer_id"("p_org_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."current_dealer_id"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."current_dealer_id"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_dealer_id"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."current_dealer_id_for_org"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."current_dealer_id_for_org"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_dealer_id_for_org"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."current_user_dealer_ids"("p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_dealer_ids"("p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_dealer_ids"("p_organization_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."current_user_email"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_email"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_email"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_dealer_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_dealer_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_dealer_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."delete_organization_user"("p_org_user_id" "uuid", "p_organization_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_organization_user"("p_org_user_id" "uuid", "p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_organization_user"("p_org_user_id" "uuid", "p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_organization_user"("p_org_user_id" "uuid", "p_organization_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."derive_pricing_uom"("p_measure_basis" "text", "p_roll_pricing_mode" "text", "p_is_roll" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."derive_pricing_uom"("p_measure_basis" "text", "p_roll_pricing_mode" "text", "p_is_roll" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."derive_pricing_uom"("p_measure_basis" "text", "p_roll_pricing_mode" "text", "p_is_roll" boolean) TO "service_role";



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



GRANT ALL ON FUNCTION "public"."freeze_proposal_snapshot"("p_proposal_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."freeze_proposal_snapshot"("p_proposal_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."freeze_proposal_snapshot"("p_proposal_id" "uuid") TO "service_role";



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



REVOKE ALL ON FUNCTION "public"."get_current_dealer_id"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_current_dealer_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_current_dealer_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_current_dealer_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_current_portal_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_current_portal_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_current_portal_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_current_portal_user_dealer_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_current_portal_user_dealer_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_current_portal_user_dealer_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_import_tax_pct_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", "p_fallback_pct" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."get_import_tax_pct_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", "p_fallback_pct" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_import_tax_pct_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", "p_fallback_pct" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_inventory_availability"("p_warehouse_id" "uuid", "p_catalog_item_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."get_inventory_availability"("p_warehouse_id" "uuid", "p_catalog_item_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_inventory_availability"("p_warehouse_id" "uuid", "p_catalog_item_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_item_pricing_from_cost"("p_org_id" "uuid", "p_catalog_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_item_pricing_from_cost"("p_org_id" "uuid", "p_catalog_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_item_pricing_from_cost"("p_org_id" "uuid", "p_catalog_item_id" "uuid") TO "service_role";



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



GRANT ALL ON FUNCTION "public"."get_roll_pricing"("p_org_id" "uuid", "p_roll_catalog_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_roll_pricing"("p_org_id" "uuid", "p_roll_catalog_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_roll_pricing"("p_org_id" "uuid", "p_roll_catalog_item_id" "uuid") TO "service_role";



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



REVOKE ALL ON FUNCTION "public"."init_session_context"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."init_session_context"() TO "anon";
GRANT ALL ON FUNCTION "public"."init_session_context"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."init_session_context"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_dealer_member"("p_dealer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_dealer_member"("p_dealer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_dealer_member"("p_dealer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_dealer_owner_or_admin"("p_dealer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_dealer_owner_or_admin"("p_dealer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_dealer_owner_or_admin"("p_dealer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_dealer_portal_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_dealer_portal_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_dealer_portal_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_dealer_portal_user"("p_dealer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_dealer_portal_user"("p_dealer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_dealer_portal_user"("p_dealer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_dealer_portal_user_with_write"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_dealer_portal_user_with_write"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_dealer_portal_user_with_write"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_dealer_portal_user_with_write"("p_dealer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_dealer_portal_user_with_write"("p_dealer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_dealer_portal_user_with_write"("p_dealer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_dealer_user_for_org"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_dealer_user_for_org"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_dealer_user_for_org"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_internal_org_user"("p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_internal_org_user"("p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_internal_org_user"("p_organization_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_org_member"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_org_member"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_org_member"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_org_owner_or_admin"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_org_owner_or_admin"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_org_owner_or_admin"("p_org_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_org_user_member"("p_org_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_org_user_member"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_org_user_member"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_org_user_member"("p_org_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_org_user_member_strict"("p_org_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_org_user_member_strict"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_org_user_member_strict"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_org_user_member_strict"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_org_user_superadmin"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_org_user_superadmin"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_org_user_superadmin"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_pack_uom"("p_uom" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."is_pack_uom"("p_uom" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_pack_uom"("p_uom" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_portal_user_in_org"("p_org_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_portal_user_in_org"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_portal_user_in_org"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_portal_user_in_org"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_unit_uom"("p_uom" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."is_unit_uom"("p_uom" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_unit_uom"("p_uom" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."jwt_email"() TO "anon";
GRANT ALL ON FUNCTION "public"."jwt_email"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."jwt_email"() TO "service_role";



GRANT ALL ON FUNCTION "public"."jwt_name"() TO "anon";
GRANT ALL ON FUNCTION "public"."jwt_name"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."jwt_name"() TO "service_role";



GRANT ALL ON FUNCTION "public"."link_my_invites"() TO "anon";
GRANT ALL ON FUNCTION "public"."link_my_invites"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."link_my_invites"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."link_my_org_invites"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."link_my_org_invites"() TO "anon";
GRANT ALL ON FUNCTION "public"."link_my_org_invites"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."link_my_org_invites"() TO "service_role";



GRANT ALL ON FUNCTION "public"."link_portal_user"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."link_portal_user"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."link_portal_user"("p_org_id" "uuid") TO "service_role";



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



GRANT ALL ON FUNCTION "public"."populate_bom_line_base_pricing_fields"("p_bom_instance_line_id" "uuid", "p_catalog_item_id" "uuid", "p_component_qty" numeric, "p_component_uom" "text", "p_component_role" "text", "p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."populate_bom_line_base_pricing_fields"("p_bom_instance_line_id" "uuid", "p_catalog_item_id" "uuid", "p_component_qty" numeric, "p_component_uom" "text", "p_component_role" "text", "p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."populate_bom_line_base_pricing_fields"("p_bom_instance_line_id" "uuid", "p_catalog_item_id" "uuid", "p_component_qty" numeric, "p_component_uom" "text", "p_component_role" "text", "p_organization_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."proposal_lines_validate_quote_line"() TO "anon";
GRANT ALL ON FUNCTION "public"."proposal_lines_validate_quote_line"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."proposal_lines_validate_quote_line"() TO "service_role";



GRANT ALL ON FUNCTION "public"."proposals_ensure_created_by"() TO "anon";
GRANT ALL ON FUNCTION "public"."proposals_ensure_created_by"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."proposals_ensure_created_by"() TO "service_role";



GRANT ALL ON FUNCTION "public"."proposals_ensure_integrity"() TO "anon";
GRANT ALL ON FUNCTION "public"."proposals_ensure_integrity"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."proposals_ensure_integrity"() TO "service_role";



GRANT ALL ON FUNCTION "public"."quote_lines_set_dealer_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."quote_lines_set_dealer_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."quote_lines_set_dealer_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."quote_lines_validate_dealer"() TO "anon";
GRANT ALL ON FUNCTION "public"."quote_lines_validate_dealer"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."quote_lines_validate_dealer"() TO "service_role";



GRANT ALL ON FUNCTION "public"."rebuild_catalogitem_conversions"("p_org" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."rebuild_catalogitem_conversions"("p_org" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rebuild_catalogitem_conversions"("p_org" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."recalc_proposal_totals"("p_proposal_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recalc_proposal_totals"("p_proposal_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalc_proposal_totals"("p_proposal_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" "uuid", "p_category_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" "uuid", "p_category_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" "uuid", "p_category_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."recompute_quote_line_costs"("p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recompute_quote_line_costs"("p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recompute_quote_line_costs"("p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."reject_oneoff_keys"("p_config" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."reject_oneoff_keys"("p_config" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reject_oneoff_keys"("p_config" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_catalog_item_for_bom_component"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_component_role" "text", "p_component_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_catalog_item_for_bom_component"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_component_role" "text", "p_component_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_catalog_item_for_bom_component"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_component_role" "text", "p_component_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_catalog_item_landed_price_cost"("p_org_id" "uuid", "p_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_catalog_item_landed_price_cost"("p_org_id" "uuid", "p_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_catalog_item_landed_price_cost"("p_org_id" "uuid", "p_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_component_item_id"("p_org_id" "uuid", "p_component_role" "text", "p_sku_rule" "text", "p_quote_line_id" "uuid", "p_config" "jsonb", "p_fixed_component_item_id" "uuid", "p_override_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_component_item_id"("p_org_id" "uuid", "p_component_role" "text", "p_sku_rule" "text", "p_quote_line_id" "uuid", "p_config" "jsonb", "p_fixed_component_item_id" "uuid", "p_override_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_component_item_id"("p_org_id" "uuid", "p_component_role" "text", "p_sku_rule" "text", "p_quote_line_id" "uuid", "p_config" "jsonb", "p_fixed_component_item_id" "uuid", "p_override_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_dealer_discount_pct"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_product_type_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_dealer_discount_pct"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_product_type_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_dealer_discount_pct"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_product_type_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_default_terms_template_id"("p_organization_id" "uuid", "p_dealer_id" "uuid", "p_doc_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_default_terms_template_id"("p_organization_id" "uuid", "p_dealer_id" "uuid", "p_doc_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_default_terms_template_id"("p_organization_id" "uuid", "p_dealer_id" "uuid", "p_doc_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_quote_line_product_type_id"("p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_quote_line_product_type_id"("p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_quote_line_product_type_id"("p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."round_up_to_increment"("p_value" numeric, "p_increment" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."round_up_to_increment"("p_value" numeric, "p_increment" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."round_up_to_increment"("p_value" numeric, "p_increment" numeric) TO "service_role";



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



GRANT SELECT ON TABLE "public"."FabricRules" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."FabricRules" TO "authenticated";
GRANT ALL ON TABLE "public"."FabricRules" TO "service_role";



GRANT ALL ON FUNCTION "public"."select_fabric_rule"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_style_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."select_fabric_rule"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_style_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_fabric_rule"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_style_code" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."session_is_admin"("p_org_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."session_is_admin"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."session_is_admin"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."session_is_admin"("p_org_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."session_is_dealer_portal"("p_dealer_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."session_is_dealer_portal"("p_dealer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."session_is_dealer_portal"("p_dealer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."session_is_dealer_portal"("p_dealer_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."session_is_dealer_user"("p_org_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."session_is_dealer_user"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."session_is_dealer_user"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."session_is_dealer_user"("p_org_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."session_is_org_user"("p_org_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."session_is_org_user"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."session_is_org_user"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."session_is_org_user"("p_org_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_acting_dealer"("p_dealer_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_acting_dealer"("p_dealer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."set_acting_dealer"("p_dealer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_acting_dealer"("p_dealer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_audit_app_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_audit_app_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_audit_app_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_audit_fields"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_audit_fields"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_audit_fields"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_created_by_fields"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_created_by_fields"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_created_by_fields"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_dealer_default_terms_template"("p_dealer_id" "uuid", "p_doc_type" "text", "p_template_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_dealer_default_terms_template"("p_dealer_id" "uuid", "p_doc_type" "text", "p_template_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."set_dealer_default_terms_template"("p_dealer_id" "uuid", "p_doc_type" "text", "p_template_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_dealer_default_terms_template"("p_dealer_id" "uuid", "p_doc_type" "text", "p_template_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_dealer_no"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_dealer_no"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_dealer_no"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_effective_dealer_id"("p_dealer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."set_effective_dealer_id"("p_dealer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_effective_dealer_id"("p_dealer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_quote_line_company_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_quote_line_company_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_quote_line_company_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_quote_line_msrp_from_value"("p_quote_line_id" "uuid", "p_total_msrp" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."set_quote_line_msrp_from_value"("p_quote_line_id" "uuid", "p_total_msrp" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_quote_line_msrp_from_value"("p_quote_line_id" "uuid", "p_total_msrp" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at_product_type_role_rules"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at_product_type_role_rules"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at_product_type_role_rules"() TO "service_role";



GRANT ALL ON FUNCTION "public"."soft_delete_directory_contact"("p_contact_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."soft_delete_directory_contact"("p_contact_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."soft_delete_directory_contact"("p_contact_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."soft_delete_directory_customer"("p_customer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."soft_delete_directory_customer"("p_customer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."soft_delete_directory_customer"("p_customer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."soft_delete_proposals"("p_proposal_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."soft_delete_proposals"("p_proposal_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."soft_delete_proposals"("p_proposal_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."soft_delete_quotes"("p_quote_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."soft_delete_quotes"("p_quote_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."soft_delete_quotes"("p_quote_ids" "uuid"[]) TO "service_role";



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



GRANT ALL ON FUNCTION "public"."sync_dealer_user_to_appuser"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_dealer_user_to_appuser"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_dealer_user_to_appuser"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_order_list_tracking_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_order_list_tracking_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_order_list_tracking_status"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_org_user_to_appuser"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_org_user_to_appuser"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_org_user_to_appuser"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid", "p_force" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid", "p_force" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_quote_line_pricing_from_configured_product"("p_quote_line_id" "uuid", "p_force" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_quote_line_scope"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_quote_line_scope"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_quote_line_scope"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_set_dealer_id_from_portal_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_set_dealer_id_from_portal_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_set_dealer_id_from_portal_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_assert_cp_policy"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_assert_cp_policy"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_assert_cp_policy"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_assert_policy_configured_products"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_assert_policy_configured_products"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_assert_policy_configured_products"() TO "service_role";



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



GRANT ALL ON FUNCTION "public"."trg_enforce_dealer_policy_on_configured_product"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_enforce_dealer_policy_on_configured_product"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_enforce_dealer_policy_on_configured_product"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_proposal_line_addons_recalc_totals"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_proposal_line_addons_recalc_totals"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_proposal_line_addons_recalc_totals"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_proposal_lines_recalc_totals"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_proposal_lines_recalc_totals"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_proposal_lines_recalc_totals"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_proposals_freeze_snapshot_on_sent"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_proposals_freeze_snapshot_on_sent"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_proposals_freeze_snapshot_on_sent"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_proposals_recalc_totals"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_proposals_recalc_totals"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_proposals_recalc_totals"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_quote_lines_allow_pricing_write_only_via_rpc"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_quote_lines_allow_pricing_write_only_via_rpc"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_quote_lines_allow_pricing_write_only_via_rpc"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_quote_lines_guard_pricing_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_quote_lines_guard_pricing_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_quote_lines_guard_pricing_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_reject_oneoff_on_configured_products"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_reject_oneoff_on_configured_products"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_reject_oneoff_on_configured_products"() TO "service_role";



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



GRANT ALL ON FUNCTION "public"."try_parse_uuid"("p_text" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."try_parse_uuid"("p_text" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."try_parse_uuid"("p_text" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."uom_factor"("p_from" "text", "p_to" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."uom_factor"("p_from" "text", "p_to" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."uom_factor"("p_from" "text", "p_to" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_quote_line_sort_orders"("p_quote_id" "uuid", "p_updates" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."update_quote_line_sort_orders"("p_quote_id" "uuid", "p_updates" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_quote_line_sort_orders"("p_quote_id" "uuid", "p_updates" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_dealer_configurator_policy"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_allowed_product_type_codes" "text"[], "p_allow_variants_catalog" boolean, "p_allow_accessories_only" boolean, "p_allow_hardware" boolean, "p_allow_operating_system" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_dealer_configurator_policy"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_allowed_product_type_codes" "text"[], "p_allow_variants_catalog" boolean, "p_allow_accessories_only" boolean, "p_allow_hardware" boolean, "p_allow_operating_system" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_dealer_configurator_policy"("p_org_id" "uuid", "p_dealer_id" "uuid", "p_allowed_product_type_codes" "text"[], "p_allow_variants_catalog" boolean, "p_allow_accessories_only" boolean, "p_allow_hardware" boolean, "p_allow_operating_system" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_organization_user"("p_organization_id" "uuid", "p_user_email" "text", "p_role" "public"."org_role", "p_status" "public"."org_user_status", "p_user_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_organization_user"("p_organization_id" "uuid", "p_user_email" "text", "p_role" "public"."org_role", "p_status" "public"."org_user_status", "p_user_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_organization_user"("p_organization_id" "uuid", "p_user_email" "text", "p_role" "public"."org_role", "p_status" "public"."org_user_status", "p_user_name" "text") TO "service_role";


















GRANT SELECT ON TABLE "public"."AppUserInvites" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."AppUserInvites" TO "authenticated";
GRANT ALL ON TABLE "public"."AppUserInvites" TO "service_role";



GRANT SELECT ON TABLE "public"."AppUserPermissions" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."AppUserPermissions" TO "authenticated";
GRANT ALL ON TABLE "public"."AppUserPermissions" TO "service_role";



GRANT SELECT ON TABLE "public"."AppUserPreferences" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."AppUserPreferences" TO "authenticated";
GRANT ALL ON TABLE "public"."AppUserPreferences" TO "service_role";



GRANT SELECT ON TABLE "public"."AppUserRolePermissions" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."AppUserRolePermissions" TO "authenticated";
GRANT ALL ON TABLE "public"."AppUserRolePermissions" TO "service_role";



GRANT SELECT ON TABLE "public"."AppUserRoles" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."AppUserRoles" TO "authenticated";
GRANT ALL ON TABLE "public"."AppUserRoles" TO "service_role";



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



GRANT SELECT ON TABLE "public"."DealerConfiguratorPolicies" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."DealerConfiguratorPolicies" TO "authenticated";
GRANT ALL ON TABLE "public"."DealerConfiguratorPolicies" TO "service_role";



GRANT SELECT ON TABLE "public"."DealerDocumentTermsDefaults" TO "anon";
GRANT SELECT ON TABLE "public"."DealerDocumentTermsDefaults" TO "authenticated";
GRANT ALL ON TABLE "public"."DealerDocumentTermsDefaults" TO "service_role";



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



GRANT SELECT ON TABLE "public"."DocumentTermsTemplates" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."DocumentTermsTemplates" TO "authenticated";
GRANT ALL ON TABLE "public"."DocumentTermsTemplates" TO "service_role";



GRANT SELECT ON TABLE "public"."ImportTaxRules" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ImportTaxRules" TO "authenticated";
GRANT ALL ON TABLE "public"."ImportTaxRules" TO "service_role";



GRANT SELECT ON TABLE "public"."InventoryBalances" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."InventoryBalances" TO "authenticated";
GRANT ALL ON TABLE "public"."InventoryBalances" TO "service_role";



GRANT SELECT ON TABLE "public"."InventoryItemProfiles" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."InventoryItemProfiles" TO "authenticated";
GRANT ALL ON TABLE "public"."InventoryItemProfiles" TO "service_role";



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



GRANT SELECT ON TABLE "public"."ProposalLineAddOns" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ProposalLineAddOns" TO "authenticated";
GRANT ALL ON TABLE "public"."ProposalLineAddOns" TO "service_role";



GRANT SELECT ON TABLE "public"."ProposalLines" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ProposalLines" TO "authenticated";
GRANT ALL ON TABLE "public"."ProposalLines" TO "service_role";



GRANT SELECT ON TABLE "public"."Proposals" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."Proposals" TO "authenticated";
GRANT ALL ON TABLE "public"."Proposals" TO "service_role";



GRANT SELECT ON TABLE "public"."PurchaseOrderLines" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."PurchaseOrderLines" TO "authenticated";
GRANT ALL ON TABLE "public"."PurchaseOrderLines" TO "service_role";



GRANT SELECT ON TABLE "public"."PurchaseOrders" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."PurchaseOrders" TO "authenticated";
GRANT ALL ON TABLE "public"."PurchaseOrders" TO "service_role";



GRANT SELECT ON TABLE "public"."QuoteLineComponents" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."QuoteLineComponents" TO "authenticated";
GRANT ALL ON TABLE "public"."QuoteLineComponents" TO "service_role";



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



GRANT SELECT ON TABLE "public"."Warehouses" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."Warehouses" TO "authenticated";
GRANT ALL ON TABLE "public"."Warehouses" TO "service_role";



GRANT SELECT ON TABLE "public"."inventory_on_hand" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."inventory_on_hand" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_on_hand" TO "service_role";



GRANT SELECT ON TABLE "public"."inventory_on_order" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."inventory_on_order" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_on_order" TO "service_role";



GRANT SELECT ON TABLE "public"."inventory_availability" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."inventory_availability" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_availability" TO "service_role";



GRANT SELECT ON TABLE "public"."stg_catalog_items_import_raw" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."stg_catalog_items_import_raw" TO "authenticated";
GRANT ALL ON TABLE "public"."stg_catalog_items_import_raw" TO "service_role";



GRANT SELECT,USAGE ON SEQUENCE "public"."stg_catalog_items_import_raw_row_id_seq" TO "anon";
GRANT SELECT,USAGE ON SEQUENCE "public"."stg_catalog_items_import_raw_row_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."stg_catalog_items_import_raw_row_id_seq" TO "service_role";



GRANT SELECT ON TABLE "public"."user_dealer_scope" TO "anon";
GRANT ALL ON TABLE "public"."user_dealer_scope" TO "service_role";
GRANT SELECT ON TABLE "public"."user_dealer_scope" TO "authenticated";



GRANT SELECT ON TABLE "public"."v_catalog_item_pricing_uom" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."v_catalog_item_pricing_uom" TO "authenticated";
GRANT ALL ON TABLE "public"."v_catalog_item_pricing_uom" TO "service_role";



GRANT SELECT ON TABLE "public"."v_configured_products_legacy_costs" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."v_configured_products_legacy_costs" TO "authenticated";
GRANT ALL ON TABLE "public"."v_configured_products_legacy_costs" TO "service_role";









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




























