


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


CREATE OR REPLACE FUNCTION "public"."approve_quote"("p_quote_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_company_id uuid;
  v_role text;
begin
  select company_id, portal_user_role
  into v_company_id, v_role
  from public."CompanyPortalUsers"
  where user_id = auth.uid()
    and deleted = false
    and portal_user_status = 'active'
  limit 1;

  if v_company_id is null then
    raise exception 'Not a portal user';
  end if;

  if v_role <> 'member_manager' then
    raise exception 'Forbidden: only member_manager can approve quotes';
  end if;

  update public."Quotes"
  set status = 'approved',
      updated_at = now()
  where id = p_quote_id
    and deleted = false
    and company_id = v_company_id;

  if not found then
    raise exception 'Quote not found for your company';
  end if;
end;
$$;


ALTER FUNCTION "public"."approve_quote"("p_quote_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_portal_user RECORD;
  v_quote RECORD;
  v_new_status public.quote_status;
  v_result json;
BEGIN
  -- Get current portal user (now uses status column)
  SELECT * INTO v_portal_user
  FROM public.get_current_portal_user()
  LIMIT 1;

  IF v_portal_user.id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated as active portal user';
  END IF;

  -- Validate role: ONLY member_manager can approve
  IF v_portal_user.portal_user_role != 'member_manager' THEN
    RAISE EXCEPTION 'Only member managers can approve/reject quotes';
  END IF;

  -- Get quote
  SELECT * INTO v_quote
  FROM public."Quotes"
  WHERE id = p_quote_id
    AND deleted = false;

  IF v_quote.id IS NULL THEN
    RAISE EXCEPTION 'Quote not found';
  END IF;

  -- Validate company match
  IF v_quote.company_id != v_portal_user.company_id THEN
    RAISE EXCEPTION 'Quote does not belong to your company';
  END IF;

  -- Validate action
  IF p_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Invalid action. Must be "approve" or "reject"';
  END IF;

  -- Validate quote status (can only approve/reject from appropriate states)
  -- Allow approval from: 'draft', 'sent', 'pending_approval'
  IF v_quote.status NOT IN ('draft', 'sent', 'pending_approval') THEN
    RAISE EXCEPTION 'Quote status (%) does not allow approval/rejection. Must be draft, sent, or pending_approval', v_quote.status;
  END IF;

  -- Set new status
  IF p_action = 'approve' THEN
    v_new_status := 'approved'::public.quote_status;
  ELSE
    v_new_status := 'rejected'::public.quote_status;
  END IF;

  -- Update quote (bypasses RLS because function is SECURITY DEFINER)
  UPDATE public."Quotes"
  SET 
    status = v_new_status,
    updated_at = now()
  WHERE id = p_quote_id;

  -- Return result
  v_result := json_build_object(
    'success', true,
    'quote_id', p_quote_id,
    'action', p_action,
    'new_status', v_new_status,
    'message', format('Quote %s successfully', p_action)
  );

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;


ALTER FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") IS 'Approve or reject a quote. ONLY member_manager role can call. Validates company match and quote status. Uses status column.';



CREATE OR REPLACE FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_cp RECORD;
    v_bom_instance_id uuid;
    -- MSRP totals
    v_roll_msrp_total numeric(12,4) := 0;
    v_bom_total numeric(12,4) := 0;
    v_subtotal_msrp numeric(12,4) := 0;
    v_roll_plus_bom_total numeric(12,4) := 0;
    -- Cost totals
    v_roll_total_cost numeric(12,4) := 0;
    v_bom_total_cost numeric(12,4) := 0;
    -- Labor
    v_labor_pct numeric(7,4) := 0;
    v_labor_amount numeric(12,4) := 0;
    -- Otros
    v_accessories_total numeric(12,4) := 0;
    v_total_msrp numeric(12,4) := 0;
    v_width_m numeric(12,4);
    v_height_m numeric(12,4);
    v_quantity numeric(12,4);
    v_roll_msrp numeric(12,4);
    v_roll_total_cost_per_unit numeric(12,4);
    v_bom_line RECORD;
    v_part_msrp numeric(12,4);
    v_part_total_cost numeric(12,4);
BEGIN
    -- 1. Obtener ConfiguredProduct
    SELECT * INTO v_cp
    FROM public."ConfiguredProducts"
    WHERE id = p_configured_product_id
        AND deleted = false;

    IF v_cp.id IS NULL THEN
        RAISE EXCEPTION 'ConfiguredProduct not found %', p_configured_product_id;
    END IF;

    -- 2. Obtener BOMInstance asociado
    SELECT id INTO v_bom_instance_id
    FROM public."BOMInstances"
    WHERE configured_product_id = p_configured_product_id
        AND deleted = false
    ORDER BY created_at DESC
    LIMIT 1;

    -- 3. Calcular Roll MSRP Total y Roll Total Cost
    IF v_cp.roll_catalog_item_id IS NOT NULL THEN
        -- Obtener MSRP sale_out y total_cost del roll
        SELECT 
            msrp_sale_out,
            total_cost
        INTO v_roll_msrp, v_roll_total_cost_per_unit
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_cp.roll_catalog_item_id
            AND organization_id = v_cp.organization_id
        LIMIT 1;

        -- Si no se encontró, intentar sin organization_id (fallback)
        IF v_roll_msrp IS NULL THEN
            SELECT 
                msrp_sale_out,
                total_cost
            INTO v_roll_msrp, v_roll_total_cost_per_unit
            FROM public."CatalogItemsMSRP"
            WHERE catalog_item_id = v_cp.roll_catalog_item_id
                AND organization_id IS NULL
            LIMIT 1;
        END IF;

        -- Si aún no se encontró, registrar warning y usar 0
        IF v_roll_msrp IS NULL THEN
            RAISE WARNING 'CatalogItemsMSRP no encontrado para roll catalog_item_id % (organization_id: %). Usando 0.', 
                v_cp.roll_catalog_item_id, v_cp.organization_id;
            v_roll_msrp := 0;
            v_roll_total_cost_per_unit := 0;
        ELSE
            v_roll_msrp := COALESCE(v_roll_msrp, 0);
            v_roll_total_cost_per_unit := COALESCE(v_roll_total_cost_per_unit, 0);
        END IF;
        
        -- Usar roll_width guardado en ConfiguredProduct (snapshot)
        v_width_m := COALESCE(v_cp.roll_width, 0);

        IF v_roll_msrp > 0 AND v_width_m > 0 AND v_cp.height_mm IS NOT NULL THEN
            v_height_m := v_cp.height_mm / 1000.0; -- Convertir mm a metros
            v_quantity := COALESCE(v_cp.quantity, 1);
            
            -- Calcular MSRP total
            v_roll_msrp_total := v_roll_msrp * v_width_m * v_height_m * v_quantity;
            
            -- Calcular costo total real
            v_roll_total_cost := v_roll_total_cost_per_unit * v_width_m * v_height_m * v_quantity;
        END IF;
    END IF;

    -- 4. Calcular BOM Total (MSRP y Costo)
    IF v_bom_instance_id IS NOT NULL THEN
        FOR v_bom_line IN
            SELECT 
                bil.resolved_part_id,
                bil.qty
            FROM public."BOMInstanceLines" bil
            WHERE bil.bom_instance_id = v_bom_instance_id
                AND bil.deleted = false
                AND bil.resolved_part_id IS NOT NULL
        LOOP
            -- Obtener MSRP sale_out y total_cost de cada componente
            SELECT 
                msrp_sale_out,
                total_cost
            INTO v_part_msrp, v_part_total_cost
            FROM public."CatalogItemsMSRP"
            WHERE catalog_item_id = v_bom_line.resolved_part_id
                AND organization_id = v_cp.organization_id
            LIMIT 1;

            -- Si no se encontró, intentar sin organization_id (fallback)
            IF v_part_msrp IS NULL THEN
                SELECT 
                    msrp_sale_out,
                    total_cost
                INTO v_part_msrp, v_part_total_cost
                FROM public."CatalogItemsMSRP"
                WHERE catalog_item_id = v_bom_line.resolved_part_id
                    AND organization_id IS NULL
                LIMIT 1;
            END IF;

            -- Si aún no se encontró, registrar warning y usar 0
            IF v_part_msrp IS NULL THEN
                RAISE WARNING 'CatalogItemsMSRP no encontrado para catalog_item_id % (organization_id: %). Usando 0.', 
                    v_bom_line.resolved_part_id, v_cp.organization_id;
                v_part_msrp := 0;
                v_part_total_cost := 0;
            ELSE
                v_part_msrp := COALESCE(v_part_msrp, 0);
                v_part_total_cost := COALESCE(v_part_total_cost, 0);
            END IF;
            
            -- Sumar MSRP
            v_bom_total := v_bom_total + (v_part_msrp * v_bom_line.qty);
            
            -- Sumar costo real
            v_bom_total_cost := v_bom_total_cost + (v_part_total_cost * v_bom_line.qty);
        END LOOP;
    END IF;

    -- 5. Calcular subtotal MSRP (sin labor)
    v_subtotal_msrp := COALESCE(v_roll_msrp_total, 0) + COALESCE(v_bom_total, 0);

    -- 6. Obtener labor_pct desde CostSettings (por organization_id)
    -- ✅ Prioridad: CostSettings > metadata > ConfiguredProducts.labor_pct > 0
    SELECT labor_pct INTO v_labor_pct
    FROM public."CostSettings"
    WHERE organization_id = v_cp.organization_id
        AND is_active = true
    LIMIT 1;

    -- Si no se encontró en CostSettings, intentar desde metadata o columna
    IF v_labor_pct IS NULL THEN
        v_labor_pct := COALESCE(
            (v_cp.metadata->>'labor_pct')::numeric,
            v_cp.labor_pct,
            0
        );
    END IF;

    -- Asegurar que labor_pct esté en formato decimal (ej: 0.15 para 15%)
    -- CostSettings.labor_pct ya está en formato decimal (0.15 = 15%)
    -- Si viene de metadata o columna y está > 1, convertir a decimal
    IF v_labor_pct > 1 THEN
        v_labor_pct := v_labor_pct / 100.0;
    END IF;
    
    -- Normalizar: si es NULL o negativo, usar 0
    v_labor_pct := COALESCE(v_labor_pct, 0);
    IF v_labor_pct < 0 THEN
        v_labor_pct := 0;
    END IF;

    -- 7. Calcular labor_amount y roll_plus_bom_total (con labor)
    v_labor_amount := v_subtotal_msrp * v_labor_pct;
    -- ✅ FÓRMULA: roll_plus_bom_total = subtotal_msrp * (1 + labor_pct)
    v_roll_plus_bom_total := v_subtotal_msrp * (1 + v_labor_pct);

    -- 8. Obtener accessories_total (si existe en metadata)
    v_accessories_total := COALESCE(
        (v_cp.metadata->>'accessories_total')::numeric,
        v_cp.accessories_total,
        0
    );

    -- 9. Calcular Total MSRP final (incluye accessories)
    v_total_msrp := v_roll_plus_bom_total + v_accessories_total;

    -- 10. Actualizar ConfiguredProduct con todos los totals
    UPDATE public."ConfiguredProducts"
    SET 
        -- MSRP totals
        roll_msrp_total = v_roll_msrp_total,
        bom_total = v_bom_total,
        roll_plus_bom_total = v_roll_plus_bom_total, -- ✅ Ya incluye labor
        -- Cost totals
        roll_total_cost = v_roll_total_cost,
        bom_total_cost = v_bom_total_cost,
        -- Labor
        labor_pct = v_labor_pct,
        labor_amount = v_labor_amount, -- ✅ Nuevo
        -- Otros
        accessories_total = v_accessories_total,
        total_msrp = v_total_msrp,
        updated_at = now()
    WHERE id = p_configured_product_id;

    -- 11. Retornar totals como JSONB
    RETURN jsonb_build_object(
        'roll_msrp_total', v_roll_msrp_total,
        'bom_total', v_bom_total,
        'subtotal_msrp', v_subtotal_msrp, -- ✅ Nuevo: sin labor
        'labor_pct', v_labor_pct,
        'labor_amount', v_labor_amount, -- ✅ Nuevo
        'roll_plus_bom_total', v_roll_plus_bom_total, -- ✅ Con labor
        'roll_total_cost', v_roll_total_cost,
        'bom_total_cost', v_bom_total_cost,
        'accessories_total', v_accessories_total,
        'total_msrp', v_total_msrp
    );
END;
$$;


ALTER FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") IS 'Calcula y actualiza totals de ConfiguredProduct:
- MSRP: roll_msrp_total, bom_total, subtotal_msrp (sin labor), roll_plus_bom_total (con labor)
- Labor: labor_pct (desde CostSettings), labor_amount, aplicado a roll_plus_bom_total
- Costos: roll_total_cost, bom_total_cost
✅ FÓRMULA: roll_plus_bom_total = (roll_msrp_total + bom_total) * (1 + labor_pct)
✅ Usa BOMInstances y BOMInstanceLines (mayúsculas).';



CREATE OR REPLACE FUNCTION "public"."can_read_company_portal_user"("p_portal_row_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
  v_org_id uuid;
BEGIN
  IF public.is_portal_user_self(p_portal_row_id) THEN
    RETURN true;
  END IF;

  SELECT cpu.organization_id
    INTO v_org_id
  FROM public."CompanyPortalUsers" cpu
  WHERE cpu.id = p_portal_row_id
    AND cpu.deleted = false
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN public.is_org_user_member(v_org_id);
END;
$$;


ALTER FUNCTION "public"."can_read_company_portal_user"("p_portal_row_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."can_read_company_portal_user"("p_portal_row_id" "uuid") IS 'Readable if user is self or internal member of same organization.';



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


CREATE OR REPLACE FUNCTION "public"."create_bom_instance_for_configured_product"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_bom_instance_id uuid;
    v_configured_product RECORD;
BEGIN
    -- ✅ VALIDACIÓN: quote_line_id es REQUERIDO
    IF p_quote_line_id IS NULL THEN
        RAISE EXCEPTION 'quote_line_id is required to create BOMInstance';
    END IF;

    -- Validar que ConfiguredProduct existe
    SELECT * INTO v_configured_product
    FROM public."ConfiguredProducts"
    WHERE id = p_configured_product_id
        AND organization_id = p_org_id
        AND deleted = false;

    IF v_configured_product.id IS NULL THEN
        RAISE EXCEPTION 'ConfiguredProduct % not found or is deleted', p_configured_product_id;
    END IF;

    -- Verificar si ya existe BOMInstance para este quote_line_id
    SELECT id INTO v_bom_instance_id
    FROM public."BOMInstances"
    WHERE organization_id = p_org_id
        AND quote_line_id = p_quote_line_id
        AND deleted = false
    LIMIT 1;

    IF v_bom_instance_id IS NOT NULL THEN
        -- Ya existe, retornar
        RETURN v_bom_instance_id;
    END IF;

    -- Crear BOMInstance usando generate_bom_from_slots_for_configured_product
    -- ahora con quote_line_id
    v_bom_instance_id := public.generate_bom_from_slots_for_configured_product(
        p_org_id,
        p_configured_product_id,
        p_product_type_id,
        p_quote_line_id  -- ✅ Pasar quote_line_id
    );
    
    RETURN v_bom_instance_id;
END;
$$;


ALTER FUNCTION "public"."create_bom_instance_for_configured_product"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_bom_instance_for_configured_product"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid") IS 'Crea BOMInstance para un ConfiguredProduct existente cuando ya se tiene quote_line_id.
✅ REQUIERE: quote_line_id NO NULL (valida constraint).
Se usa después de crear QuoteLine para crear el BOMInstance asociado.';



CREATE OR REPLACE FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid" DEFAULT NULL::"uuid", "p_quote_line_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_configured_product_id uuid;
    v_bom_template_id uuid;
    v_bom_instance_id uuid;
    v_totals jsonb;
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
    -- 1. Resolver BOM template usando config_snapshot
    v_bom_template_id := public.select_best_bom_template_for_configured_product(
        p_org_id,
        p_product_type_id,
        p_config_snapshot
    );

    IF v_bom_template_id IS NULL THEN
        RAISE EXCEPTION 'No matching BOMTemplate found for org %, product_type %', 
            p_org_id, p_product_type_id;
    END IF;

    -- 2. Extraer datos principales del config_snapshot
    v_hardware_color := COALESCE(
        p_config_snapshot->>'hardware_color',
        p_config_snapshot->>'hardwareColor',
        p_config_snapshot->>'operatingSystemColor'
    );
    
    v_fabric_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid;
    IF v_fabric_item_id IS NULL THEN
        v_fabric_item_id := (p_config_snapshot->>'fabric_catalog_item_id')::uuid; -- Legacy compatibility
    END IF;
    IF v_fabric_item_id IS NULL THEN
        v_fabric_item_id := (p_config_snapshot->>'variantId')::uuid;
    END IF;
    
    v_width_mm := (p_config_snapshot->>'width_mm')::numeric;
    IF v_width_mm IS NULL THEN
        v_width_mm := COALESCE((p_config_snapshot->>'width_m')::numeric, 0) * 1000;
    END IF;
    
    v_height_mm := (p_config_snapshot->>'height_mm')::numeric;
    IF v_height_mm IS NULL THEN
        v_height_mm := COALESCE((p_config_snapshot->>'height_m')::numeric, 0) * 1000;
    END IF;
    
    v_quantity := COALESCE((p_config_snapshot->>'quantity')::numeric, 1);

    -- 3. Obtener info del roll si existe
    IF v_fabric_item_id IS NOT NULL THEN
        SELECT 
            ci.sku, 
            ci.collection_name, 
            ci.variant_name,
            ci.roll_width
        INTO 
            v_roll_sku, 
            v_roll_collection_name, 
            v_roll_variant_name,
            v_roll_width
        FROM public."CatalogItems" ci
        WHERE ci.id = v_fabric_item_id
            AND ci.is_fabric = true
            AND ci.is_active = true
            AND (ci.organization_id = p_org_id OR ci.organization_id IS NULL)
        LIMIT 1;
    END IF;

    -- 4. Crear ConfiguredProduct
    INSERT INTO public."ConfiguredProducts"(
        organization_id,
        quote_id,
        bom_template_id,
        product_type_id,
        roll_catalog_item_id,
        roll_sku,
        roll_collection_name,
        roll_variant_name,
        roll_width,
        width_mm,
        height_mm,
        quantity,
        hardware_color,
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
    ) VALUES (
        p_org_id,
        p_quote_id,
        v_bom_template_id,
        p_product_type_id,
        v_fabric_item_id,
        v_roll_sku,
        v_roll_collection_name,
        v_roll_variant_name,
        v_roll_width,
        v_width_mm,
        v_height_mm,
        v_quantity,
        v_hardware_color,
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

    -- 5. ✅ CAMBIO CRÍTICO: NO crear BOMInstance en el preview
    -- El BOMInstance se creará después cuando se tenga quote_line_id
    -- Esto evita violar el constraint NOT NULL en BOMInstances.quote_line_id
    v_bom_instance_id := NULL;
    
    IF p_quote_line_id IS NULL THEN
        -- Registrar info para debugging
        RAISE NOTICE 'BOMInstance NO creado en preview: quote_line_id es NULL. Se creará después cuando se tenga QuoteLine.';
    END IF;

    -- 6. Calcular totals (aunque no haya BOMInstance aún, se puede calcular desde ConfiguredProduct)
    v_totals := public.calculate_configured_product_totals(v_configured_product_id);

    -- 7. Retornar resultado
    RETURN jsonb_build_object(
        'configured_product_id', v_configured_product_id,
        'bom_instance_id', v_bom_instance_id,  -- NULL si no se creó
        'bom_template_id', v_bom_template_id,
        'totals', v_totals
    );
END;
$$;


ALTER FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") IS 'Crea ConfiguredProduct y opcionalmente BOMInstance.
✅ CAMBIO: Solo crea BOMInstance si se proporciona quote_line_id.
Si quote_line_id es NULL, NO crea BOMInstance (se creará después cuando se tenga QuoteLine).
Esto evita violar el constraint NOT NULL en BOMInstances.quote_line_id.';



CREATE OR REPLACE FUNCTION "public"."current_auth_email"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT lower(nullif(trim(auth.jwt() ->> 'email'), ''));
$$;


ALTER FUNCTION "public"."current_auth_email"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_company_portal_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_deleted_count int;
BEGIN
  -- Soft delete: mark as deleted and disabled
  UPDATE public."CompanyPortalUsers"
  SET 
    deleted = true,
    status = 'disabled',
    updated_at = now()
  WHERE 
    id = p_portal_user_id
    AND organization_id = p_organization_id
    AND deleted = false;
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  IF v_deleted_count = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Portal user not found or already deleted'
    );
  END IF;
  
  RETURN jsonb_build_object('success', true);
END;
$$;


ALTER FUNCTION "public"."delete_company_portal_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."delete_company_portal_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") IS 'Soft delete a company portal user. Marks deleted=true and status=disabled. Bypasses RLS. Only callable by authenticated users with proper organization membership.';



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
  -- Si ya viene, listo
  IF NEW.organization_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Si hay company_id, derivar org_id desde Companies
  IF NEW.company_id IS NOT NULL THEN
    SELECT c.organization_id
      INTO NEW.organization_id
    FROM public."Companies" c
    WHERE c.id = NEW.company_id
      AND c.deleted = false
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


CREATE OR REPLACE FUNCTION "public"."enforce_mo_company_matches_salesorder"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_so_company uuid;
begin
  if new.sales_order_id is null then
    raise exception 'ManufacturingOrders.sales_order_id is required';
  end if;

  select so.company_id
    into v_so_company
  from public."SalesOrders" so
  where so.id = new.sales_order_id;

  -- Si SO aún no tiene company_id, no bloqueamos (MVP).
  if v_so_company is null then
    return new;
  end if;

  if new.company_id is null then
    new.company_id := v_so_company;
  end if;

  if new.company_id <> v_so_company then
    raise exception 'ManufacturingOrders.company_id must match SalesOrders.company_id';
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."enforce_mo_company_matches_salesorder"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_orderlist_company_matches_salesorder"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_so_company uuid;
begin
  -- si no tienes sales_order_id en OrderList, este trigger no sirve.
  if new.sales_order_id is null then
    return new;
  end if;

  select so.company_id
    into v_so_company
  from public."SalesOrders" so
  where so.id = new.sales_order_id;

  if v_so_company is null then
    return new;
  end if;

  if new.company_id is null then
    new.company_id := v_so_company;
  end if;

  if new.company_id <> v_so_company then
    raise exception 'OrderList.company_id must match SalesOrders.company_id';
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."enforce_orderlist_company_matches_salesorder"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_salesorders_company_matches_quote"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_quote_company uuid;
begin
  if new.quote_id is null then
    raise exception 'SalesOrders.quote_id is required';
  end if;

  select q.company_id
    into v_quote_company
  from public."Quotes" q
  where q.id = new.quote_id;

  -- Si el quote aún no tiene company_id, no bloqueamos (MVP).
  if v_quote_company is null then
    return new;
  end if;

  if new.company_id is null then
    new.company_id := v_quote_company;
  end if;

  if new.company_id <> v_quote_company then
    raise exception 'SalesOrders.company_id must match Quotes.company_id';
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."enforce_salesorders_company_matches_quote"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fill_msrp_item_identity"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_sku text;
  v_name text;
  v_collection_name text;
  v_variant_name text;
begin
  if
    new.sku is null
    or new.name is null
    or new.collection_name is null
    or new.variant_name is null
  then
    select
      ci.sku,
      ci.name,
      ci.collection_name,
      ci.variant_name
    into
      v_sku,
      v_name,
      v_collection_name,
      v_variant_name
    from public."CatalogItems" ci
    where ci.id = new.catalog_item_id;

    if new.sku is null then new.sku := v_sku; end if;
    if new.name is null then new.name := v_name; end if;
    if new.collection_name is null then new.collection_name := v_collection_name; end if;
    if new.variant_name is null then new.variant_name := v_variant_name; end if;
  end if;

  return new;
end;
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
    v_operation_type text;
    v_should_skip_slot boolean;
BEGIN
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

    v_operation_type := COALESCE(
        v_config_snapshot->>'operation_type',
        v_config_snapshot->>'operatingSystem',
        v_config_snapshot->>'drive_type',
        NULL
    );
    
    IF v_operation_type = 'motorized' THEN
        v_operation_type := 'motor';
    ELSIF v_operation_type = 'manual' THEN
        v_operation_type := 'manual';
    END IF;

    IF p_quote_line_id IS NULL THEN
        RAISE NOTICE 'BOMInstance NO creado: quote_line_id es NULL. Retornando NULL.';
        RETURN NULL;
    END IF;

    UPDATE public."BOMInstances"
        SET deleted = true
    WHERE organization_id = p_org_id
        AND (
            (configured_product_id = p_configured_product_id AND configured_product_id IS NOT NULL)
            OR (quote_line_id = p_quote_line_id AND quote_line_id IS NOT NULL)
        )
        AND deleted = false;

    BEGIN
        INSERT INTO public."BOMInstances"(
            organization_id, 
            quote_line_id,
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

    FOR v_slot IN
        SELECT *
        FROM public."BOMTemplateSlots"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
        ORDER BY item_role ASC
    LOOP
        v_should_skip_slot := false;
        
        IF v_operation_type = 'motor' THEN
            IF v_slot.item_role = 'drive' OR LOWER(v_slot.item_role) LIKE '%drive%' THEN
                v_should_skip_slot := true;
            END IF;
        ELSIF v_operation_type = 'manual' THEN
            IF v_slot.item_role = 'motor' OR LOWER(v_slot.item_role) LIKE '%motor%' THEN
                v_should_skip_slot := true;
            END IF;
        END IF;
        
        IF v_should_skip_slot THEN
            CONTINUE;
        END IF;

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
        ELSIF v_resolved_item IS NULL AND v_qty > 0 THEN
            RAISE WARNING 'Skipping BOM line insertion for role %: qty=% but resolved_part_id is NULL', v_slot.item_role, v_qty;
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
✅ CRITICAL: Filtra slots según operation_type:
- Si operation_type = "motor", EXCLUYE slots con role "drive"
- Si operation_type = "manual", EXCLUYE slots con role "motor"
Esto asegura que los precios sean diferentes entre motor y manual.
Lee selecciones desde config_snapshot JSONB. Aplica reglas mounting_clip con qty_type=per_width.';



CREATE OR REPLACE FUNCTION "public"."generate_bom_instance_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_config jsonb;
  v_template_id uuid;
  v_instance_id uuid;
  v_ql public."QuoteLines";
  v_comp public."BOMComponents";
  v_override_item uuid;
  v_item_id uuid;
  v_qty numeric(12,4);
  v_width_mm numeric(12,4);
  v_height_mm numeric(12,4);
  v_unit_cost numeric(12,4);
BEGIN
  SELECT * INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id
    AND organization_id = p_org_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine not found %', p_quote_line_id;
  END IF;

  v_config := public.build_quote_line_config(p_org_id, p_quote_line_id);
  v_template_id := public.select_best_bom_template(p_org_id, p_product_type_id, v_config);

  -- idempotency: soft-delete previous active instance
  -- ✅ CORRECCIÓN: Usar BOMInstances (mayúsculas)
  UPDATE public."BOMInstances"
    SET deleted = true
  WHERE organization_id = p_org_id
    AND quote_line_id = p_quote_line_id
    AND deleted = false;

  -- ✅ CORRECCIÓN: Usar BOMInstances (mayúsculas)
  INSERT INTO public."BOMInstances"(organization_id, quote_line_id, bom_template_id)
  VALUES (p_org_id, p_quote_line_id, v_template_id)
  RETURNING id INTO v_instance_id;

  v_width_mm := COALESCE(v_ql.width_m, 0) * 1000;
  v_height_mm := COALESCE(v_ql.height_m, 0) * 1000;

  FOR v_comp IN
    SELECT *
    FROM public."BOMComponents"
    WHERE organization_id = p_org_id
      AND bom_template_id = v_template_id
      AND deleted = false
      AND archived = false
    ORDER BY (depends_on_role IS NOT NULL)::int, sort_order ASC
  LOOP
    -- override?
    SELECT qlc.catalog_item_id INTO v_override_item
    FROM public."QuoteLineComponents" qlc
    WHERE qlc.organization_id = p_org_id
      AND qlc.quote_line_id = p_quote_line_id
      AND qlc.component_role = v_comp.component_role
      AND qlc.kind = 'override'
      AND qlc.deleted = false
    LIMIT 1;

    -- qty calc
    IF v_comp.qty_type = 'fixed' THEN
      v_qty := v_comp.qty_value;
    ELSIF v_comp.qty_type = 'per_width' THEN
      v_qty := ((v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0) * v_comp.qty_value;
    ELSIF v_comp.qty_type = 'per_height' THEN
      v_qty := ((v_height_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0) * v_comp.qty_value;
    ELSIF v_comp.qty_type = 'per_area' THEN
      v_qty := ((v_width_mm/1000.0) * (v_height_mm/1000.0)) * v_comp.qty_value;
    ELSE
      v_qty := v_comp.qty_value;
    END IF;

    IF v_comp.waste_pct IS NOT NULL AND v_comp.waste_pct > 0 THEN
      v_qty := v_qty * (1 + v_comp.waste_pct);
    END IF;

    -- resolve item
    v_item_id := COALESCE(v_override_item, v_comp.component_item_id);

    IF v_item_id IS NOT NULL AND v_qty > 0 THEN
      SELECT ci.cost_exw INTO v_unit_cost
      FROM public."CatalogItems" ci
      WHERE ci.id = v_item_id;
      
      v_unit_cost := COALESCE(v_unit_cost, 0);

      -- ✅ CORRECCIÓN: Usar BOMInstanceLines (mayúsculas)
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
        v_item_id,
        v_comp.component_role,
        v_qty,
        v_comp.uom,
        v_unit_cost,
        false
      );
    END IF;
  END LOOP;

  RETURN v_instance_id;
END;
$$;


ALTER FUNCTION "public"."generate_bom_instance_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."generate_bom_instance_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") IS 'Genera BOMInstance y BOMInstanceLines para un QuoteLine.
✅ CORREGIDO: Usa BOMInstances y BOMInstanceLines (mayúsculas).';



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


CREATE OR REPLACE FUNCTION "public"."get_auth_context"() RETURNS TABLE("user_id" "uuid", "is_org_user" boolean, "is_portal_user" boolean, "organization_id" "uuid", "company_id" "uuid", "needs_password" boolean, "access_allowed" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid;
  v_org_user_id uuid;
  v_portal_user_id uuid;
  v_organization_id uuid;
  v_company_id uuid;
  v_org_status text;
  v_portal_status text;
  v_org_must_change_password boolean;
  v_portal_must_change_password boolean;
  v_is_org_user boolean := false;
  v_is_portal_user boolean := false;
  v_access_allowed boolean := false;
  v_needs_password boolean := false;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  -- If no user, return empty context
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 
      NULL::uuid,
      false::boolean,
      false::boolean,
      NULL::uuid,
      NULL::uuid,
      false::boolean,
      false::boolean;
    RETURN;
  END IF;

  -- Check for OrganizationUser membership (active or invited)
  SELECT 
    ou.id,
    ou.organization_id,
    ou.status,
    COALESCE(ou.must_change_password, false)
  INTO 
    v_org_user_id,
    v_organization_id,
    v_org_status,
    v_org_must_change_password
  FROM public."OrganizationUsers" ou
  WHERE ou.user_id = v_user_id
    AND ou.deleted = false
    AND ou.status IN ('active', 'invited')
  LIMIT 1;

  IF v_org_user_id IS NOT NULL THEN
    v_is_org_user := true;
    v_access_allowed := true;
  END IF;

  -- Check for CompanyPortalUser membership (active or invited)
  IF v_org_user_id IS NULL THEN
    SELECT 
      cpu.id,
      cpu.company_id,
      cpu.organization_id,
      cpu.status,
      COALESCE(cpu.must_change_password, false)
    INTO 
      v_portal_user_id,
      v_company_id,
      v_organization_id,
      v_portal_status,
      v_portal_must_change_password
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.user_id = v_user_id
      AND cpu.deleted = false
      AND cpu.status IN ('active', 'invited')
    LIMIT 1;

    IF v_portal_user_id IS NOT NULL THEN
      v_is_portal_user := true;
      v_access_allowed := true;
    END IF;
  ELSE
    -- If org user, also try to get company_id and status from portal user
    SELECT 
      cpu.company_id,
      cpu.status,
      COALESCE(cpu.must_change_password, false)
    INTO 
      v_company_id,
      v_portal_status,
      v_portal_must_change_password
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.user_id = v_user_id
      AND cpu.deleted = false
      AND cpu.status IN ('active', 'invited')
    LIMIT 1;
  END IF;

  -- ✅ needs_password = true if must_change_password is true in EITHER table
  v_needs_password := COALESCE(v_org_must_change_password, false) OR COALESCE(v_portal_must_change_password, false);

  -- Return context
  RETURN QUERY SELECT 
    v_user_id,
    v_is_org_user,
    v_is_portal_user,
    v_organization_id,
    v_company_id,
    v_needs_password,
    v_access_allowed;
END;
$$;


ALTER FUNCTION "public"."get_auth_context"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_auth_context"() IS 'Get authentication context for current user. Checks membership in OrganizationUsers and CompanyPortalUsers. Returns membership status, organization/company IDs, password requirement (from must_change_password), and access permission. NO dependency on Profiles table. STABLE function safe for use in queries.';



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
  -- Valores por defecto
  msrp_pct_sale_in := 0.35;
  msrp_pct_sale_out := 0.65;

  -- Si no hay category_id, retornar defaults
  IF p_category_id IS NULL THEN
    RETURN;
  END IF;

  v_current_category_id := p_category_id;

  -- Buscar márgenes subiendo por la jerarquía de categorías
  WHILE v_current_category_id IS NOT NULL AND NOT v_found LOOP
    SELECT 
      COALESCE(cm.msrp_pct_sale_in, 0.35),
      COALESCE(cm.msrp_pct_sale_out, 0.65)
    INTO msrp_pct_sale_in, msrp_pct_sale_out
    FROM public."CategoryMargins" cm
    WHERE cm.organization_id = p_organization_id
      AND cm.category_id = v_current_category_id
      AND COALESCE(cm.is_active, true) = true
    LIMIT 1;

    -- Si encontramos, salir
    IF FOUND THEN
      v_found := true;
    ELSE
      -- Si no encontramos, intentar con la categoría padre
      SELECT parent_id INTO v_current_category_id
      FROM public."CatalogCategories"
      WHERE id = v_current_category_id;
    END IF;
  END LOOP;

  -- Si no encontramos nada, usar defaults
  IF NOT v_found THEN
    msrp_pct_sale_in := 0.35;
    msrp_pct_sale_out := 0.65;
  END IF;
END;
$$;


ALTER FUNCTION "public"."get_category_margins_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", OUT "msrp_pct_sale_in" numeric, OUT "msrp_pct_sale_out" numeric) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_category_margins_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", OUT "msrp_pct_sale_in" numeric, OUT "msrp_pct_sale_out" numeric) IS 'Busca márgenes (msrp_pct_sale_in, msrp_pct_sale_out) para una categoría, subiendo por la jerarquía hasta encontrar una regla activa. Si no encuentra, retorna defaults (35%, 65%).';



CREATE OR REPLACE FUNCTION "public"."get_current_portal_user"() RETURNS TABLE("id" "uuid", "organization_id" "uuid", "company_id" "uuid", "portal_user_role" "text", "status" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cpu.id,
    cpu.organization_id,
    cpu.company_id,
    -- Use role column directly (normalize legacy values)
    CASE 
      WHEN cpu.role IN ('member_manager', 'manager') THEN 'member_manager'::text
      WHEN cpu.role = 'member' THEN 'member'::text
      ELSE 'member'::text -- default fallback
    END as portal_user_role,
    cpu.status::text as status
  FROM public."CompanyPortalUsers" cpu
  WHERE (
    cpu.user_id = auth.uid()
    OR cpu.portal_user_email = (auth.jwt() ->> 'email')
  )
    AND cpu.deleted = false
    AND cpu.status IN ('active', 'invited')
  LIMIT 1;
END;
$$;


ALTER FUNCTION "public"."get_current_portal_user"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_current_portal_user"() IS 'Get current portal user info using status column. Returns empty if not a portal user or not active. Supports both user_id and email matching.';



CREATE OR REPLACE FUNCTION "public"."get_current_portal_user_company_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  select company_id
  from public."CompanyPortalUsers"
  where user_id = auth.uid()
    and deleted = false
    and portal_user_status = 'active'
  limit 1;
$$;


ALTER FUNCTION "public"."get_current_portal_user_company_id"() OWNER TO "postgres";


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
  UPDATE public."CompanyPortalUsers"
  SET
    user_id = NEW.id,
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


COMMENT ON FUNCTION "public"."handle_auth_user_created_for_portal_users"() IS 'Automatically links CompanyPortalUsers invites when a new auth.users is created. Uses ONLY "status" column (not portal_user_status).';



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



CREATE OR REPLACE FUNCTION "public"."is_company_member"("p_company_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."Companies" c
    JOIN public."OrganizationUsers" ou ON ou.organization_id = c.organization_id
    WHERE c.id = p_company_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;


ALTER FUNCTION "public"."is_company_member"("p_company_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_company_member"("p_company_id" "uuid") IS 'Check if current user is member of company via organization. SECURITY DEFINER to avoid RLS recursion.';



CREATE OR REPLACE FUNCTION "public"."is_company_owner_or_admin"("p_company_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."Companies" c
    JOIN public."OrganizationUsers" ou ON ou.organization_id = c.organization_id
    WHERE c.id = p_company_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('superadmin', 'owner', 'admin') -- Added 'superadmin'
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;


ALTER FUNCTION "public"."is_company_owner_or_admin"("p_company_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_company_owner_or_admin"("p_company_id" "uuid") IS 'Check if current user is superadmin/owner/admin of company via organization. SECURITY DEFINER to avoid RLS recursion. Updated to include superadmin role.';



CREATE OR REPLACE FUNCTION "public"."is_company_portal_user"("p_company_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.company_id = p_company_id
      AND (
        cpu.user_id = auth.uid()
        OR cpu.portal_user_email = (auth.jwt() ->> 'email')
      )
      AND cpu.deleted = false
      AND cpu.status IN ('active', 'invited')
  );
END;
$$;


ALTER FUNCTION "public"."is_company_portal_user"("p_company_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_company_portal_user"("p_company_id" "uuid") IS 'Returns true if current user is a CompanyPortalUser (portal user) for the given company.';



CREATE OR REPLACE FUNCTION "public"."is_company_portal_user_with_write"("p_company_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.company_id = p_company_id
      AND (
        cpu.user_id = auth.uid()
        OR lower(cpu.portal_user_email) = lower(auth.jwt() ->> 'email')
      )
      AND cpu.deleted = false
      AND cpu.status IN ('active', 'invited')
      AND cpu.role IN ('member_manager')   -- ✅ solo los que pueden write
  );
END;
$$;


ALTER FUNCTION "public"."is_company_portal_user_with_write"("p_company_id" "uuid") OWNER TO "postgres";


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

  SELECT cpu.user_id, cpu.portal_user_email
    INTO v_row_user_id, v_row_email
  FROM public."CompanyPortalUsers" cpu
  WHERE cpu.id = p_portal_row_id
    AND cpu.deleted = false
  LIMIT 1;

  -- not found
  IF v_row_user_id IS NULL AND v_row_email IS NULL THEN
    RETURN false;
  END IF;

  -- linked user_id match
  IF v_row_user_id IS NOT NULL AND v_row_user_id = v_uid THEN
    RETURN true;
  END IF;

  -- fallback email match (unlinked invites)
  v_jwt_email := NULLIF(lower(trim(auth.jwt() ->> 'email')), '');

  IF v_jwt_email IS NOT NULL
     AND v_row_email IS NOT NULL
     AND lower(trim(v_row_email)) = v_jwt_email THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;


ALTER FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") IS 'True if current user matches the portal record by user_id or jwt email fallback.';



CREATE OR REPLACE FUNCTION "public"."link_my_invites"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_org_updated int := 0;
  v_portal_updated int := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select lower(coalesce(auth.jwt() ->> 'email', '')) into v_email;

  if v_email = '' then
    raise exception 'Missing email in auth context';
  end if;

  -- OrganizationUsers: pegar user_id y activar si estaba invited
  update public."OrganizationUsers"
    set user_id = v_uid,
        status = case when status = 'invited' then 'active' else status end,
        updated_at = now()
  where lower(user_email) = v_email
    and (user_id is null or user_id = v_uid);

  get diagnostics v_org_updated = row_count;

  -- CompanyPortalUsers: ojo a tu columna de email: portal_user_email
  update public."CompanyPortalUsers"
    set user_id = v_uid,
        status = case when status = 'invited' then 'active' else status end,
        updated_at = now()
  where lower(portal_user_email) = v_email
    and (user_id is null or user_id = v_uid);

  get diagnostics v_portal_updated = row_count;

  return jsonb_build_object(
    'ok', true,
    'org_updated', v_org_updated,
    'portal_updated', v_portal_updated
  );
end;
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
  v_updated_ids uuid[] := ARRAY[]::uuid[];
  v_portal_linked_count integer := 0;
  v_portal_updated_ids uuid[] := ARRAY[]::uuid[];
BEGIN
  v_user_id := auth.uid();
  v_user_email := (SELECT email FROM auth.users WHERE id = v_user_id);

  IF v_user_id IS NULL OR v_user_email IS NULL THEN
    RAISE WARNING '[link_my_org_invites] No authenticated user or email found. Skipping link.';
    RETURN QUERY SELECT 0::integer, ARRAY[]::uuid[];
    RETURN;
  END IF;

  -- Link OrganizationUsers
  WITH updated AS (
    UPDATE public."OrganizationUsers"
    SET
      user_id = v_user_id,
      status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
      accepted_at = COALESCE(accepted_at, now()),
      updated_at = now()
    WHERE lower(user_email) = lower(v_user_email)
      AND user_id IS NULL
      AND deleted = false
    RETURNING id
  )
  SELECT COUNT(*)::integer, ARRAY_AGG(id)::uuid[]
  INTO v_linked_count, v_updated_ids
  FROM updated;

  -- Link CompanyPortalUsers (✅ SOLO status)
  WITH updated_portal AS (
    UPDATE public."CompanyPortalUsers"
    SET
      user_id = v_user_id,
      status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
      accepted_at = COALESCE(accepted_at, now()),
      updated_at = now()
    WHERE lower(portal_user_email) = lower(v_user_email)
      AND user_id IS NULL
      AND deleted = false
    RETURNING id
  )
  SELECT COUNT(*)::integer, ARRAY_AGG(id)::uuid[]
  INTO v_portal_linked_count, v_portal_updated_ids
  FROM updated_portal;

  RETURN QUERY
    SELECT (v_linked_count + v_portal_linked_count)::integer,
           (COALESCE(v_updated_ids, ARRAY[]::uuid[]) || COALESCE(v_portal_updated_ids, ARRAY[]::uuid[]))::uuid[];
END;
$$;


ALTER FUNCTION "public"."link_my_org_invites"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."link_my_org_invites"() IS 'Links both OrganizationUsers and CompanyPortalUsers invites for the current authenticated user. Matches by email. Uses ONLY "status" column (not portal_user_status). Returns combined count and array of all updated IDs.';



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



CREATE OR REPLACE FUNCTION "public"."msrp_compute_for_item"("item_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_total_cost numeric;
  v_sale_in_margin  numeric := 0.35; -- margen sobre venta para Sale-In (vs costo)
  v_retail_margin    numeric := 0.65; -- margen sobre venta del canal retail (Sale-In -> Sale-Out)
  v_msrp_sale_in  numeric;
  v_msrp_sale_out numeric;
BEGIN
  -- 1) Trae el total_cost desde CatalogItemsMSRP
  SELECT total_cost
    INTO v_total_cost
  FROM public."CatalogItemsMSRP"
  WHERE catalog_item_id = item_id;

  IF v_total_cost IS NULL THEN
    RAISE EXCEPTION 'No total_cost for catalog_item_id %', item_id;
  END IF;

  -- 2) Sale-In desde costo (margin on sale)
  v_msrp_sale_in := round(v_total_cost / nullif(1 - v_sale_in_margin, 0), 4);

  -- 3) Sale-Out desde Sale-In (retail margin on sale)
  -- sale_in = sale_out * (1 - retail_margin)  => sale_out = sale_in / (1 - retail_margin)
  v_msrp_sale_out := round(v_msrp_sale_in / nullif(1 - v_retail_margin, 0), 4);

  -- 4) Guarda
  UPDATE public."CatalogItemsMSRP"
  SET msrp_sale_in  = v_msrp_sale_in,
      msrp_sale_out = v_msrp_sale_out,
      updated_at = now()
  WHERE catalog_item_id = item_id;
END;
$$;


ALTER FUNCTION "public"."msrp_compute_for_item"("item_id" "uuid") OWNER TO "postgres";


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



CREATE OR REPLACE FUNCTION "public"."next_company_no"("p_org_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_next_no integer;
BEGIN
  -- Atomically increment next_company_no and get the new value
  UPDATE public."Organizations"
  SET next_company_no = next_company_no + 1
  WHERE id = p_org_id
  RETURNING next_company_no INTO v_next_no;
  
  -- If organization not found, raise error
  IF v_next_no IS NULL THEN
    RAISE EXCEPTION 'Organization % not found', p_org_id;
  END IF;
  
  -- Return sequential number as text (e.g., "1", "2", "3")
  RETURN v_next_no::text;
END;
$$;


ALTER FUNCTION "public"."next_company_no"("p_org_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."next_company_no"("p_org_id" "uuid") IS 'Atomically increments Organizations.next_company_no and returns sequential company number as text. Used by trigger on Companies insert. SECURITY DEFINER to avoid RLS recursion.';



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



CREATE OR REPLACE FUNCTION "public"."select_best_bom_template"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  v_template_id uuid;
BEGIN
  WITH candidates AS (
    SELECT
      t.id,
      t.updated_at,
      COALESCE((t.metadata->>'priority')::int, 0) AS priority,
      COALESCE((
        SELECT COUNT(*)
        FROM jsonb_each(t.metadata->'compat') c(k, v)
        WHERE
          p_config ? k
          AND (
            (jsonb_typeof(v) = 'array' AND v @> jsonb_build_array(p_config->>k))
            OR (jsonb_typeof(v) = 'string' AND v = to_jsonb(p_config->>k))
            OR (jsonb_typeof(v) = 'object' AND v = (p_config->k)) -- allow object match
          )
      ), 0) AS score
    FROM public."BOMTemplates" t
    WHERE
      t.organization_id = p_org_id
      AND t.product_type_id = p_product_type_id
      AND t.deleted = false
      AND t.archived = false
      AND t.active = true
  )
  SELECT id INTO v_template_id
  FROM candidates
  ORDER BY score DESC, priority DESC, updated_at DESC
  LIMIT 1;

  IF v_template_id IS NULL THEN
    RAISE EXCEPTION 'No BOMTemplate found for org %, product_type %', p_org_id, p_product_type_id;
  END IF;

  RETURN v_template_id;
END $$;


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



CREATE OR REPLACE FUNCTION "public"."select_best_bom_template_for_quote_line"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  v_best_template_id uuid;
  v_best_score int := -1;
  v_candidate RECORD;
  v_match_score int;
  v_user_roles text[];
BEGIN
  -- 1. Obtener roles seleccionados por el usuario (kind='selection')
  SELECT ARRAY_AGG(DISTINCT qlc.component_role) INTO v_user_roles
  FROM public."QuoteLineComponents" qlc
  WHERE qlc.organization_id = p_org_id
    AND qlc.quote_line_id = p_quote_line_id
    AND qlc.kind = 'selection'
    AND qlc.deleted = false;

  -- Si no hay roles seleccionados, usar array vacío
  v_user_roles := COALESCE(v_user_roles, ARRAY[]::text[]);

  -- 2. Buscar templates por product_type_id
  FOR v_candidate IN
    SELECT 
      bt.id,
      bt.updated_at,
      COALESCE((bt.metadata->>'priority')::int, 0) AS priority
    FROM public."BOMTemplates" bt
    WHERE bt.organization_id = p_org_id
      AND bt.product_type_id = p_product_type_id
      AND bt.deleted = false
      AND bt.archived = false
      AND bt.active = true
    ORDER BY 
      priority DESC,
      bt.updated_at DESC
  LOOP
    -- 3. Score por coincidencias de roles
    SELECT COUNT(*) INTO v_match_score
    FROM public."BOMTemplateSlots" slots
    WHERE slots.organization_id = p_org_id
      AND slots.bom_template_id = v_candidate.id
      AND slots.item_role = ANY(v_user_roles);

    IF v_match_score > v_best_score THEN
      v_best_score := v_match_score;
      v_best_template_id := v_candidate.id;
    END IF;
  END LOOP;

  -- 4. Fallback: primer template por ProductType
  IF v_best_template_id IS NULL THEN
    SELECT bt.id INTO v_best_template_id
    FROM public."BOMTemplates" bt
    WHERE bt.organization_id = p_org_id
      AND bt.product_type_id = p_product_type_id
      AND bt.deleted = false
      AND bt.archived = false
      AND bt.active = true
    ORDER BY 
      COALESCE((bt.metadata->>'priority')::int, 0) DESC,
      bt.updated_at DESC
    LIMIT 1;
  END IF;

  RETURN v_best_template_id;
END;
$$;


ALTER FUNCTION "public"."select_best_bom_template_for_quote_line"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."select_best_bom_template_for_quote_line"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") IS 'Selecciona el mejor BOMTemplate basado en:
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


CREATE OR REPLACE FUNCTION "public"."set_company_no"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Only set company_no if it's null or empty
  IF NEW.company_no IS NULL OR TRIM(NEW.company_no) = '' THEN
    NEW.company_no := public.next_company_no(NEW.organization_id);
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_company_no"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."set_company_no"() IS 'Trigger function to auto-assign company_no on Companies insert if not provided. Never recalculates existing company_no.';



CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at := now();
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
begin
  update public."CatalogItemsMSRP" cim
  set
    sku             = new.sku,
    name            = new.name,
    collection_name = new.collection_name,
    variant_name    = new.variant_name
  where cim.catalog_item_id = new.id;

  return new;
end;
$$;


ALTER FUNCTION "public"."sync_catalogitems_to_msrp"() OWNER TO "postgres";


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



CREATE OR REPLACE FUNCTION "public"."tg_set_company_id_from_portal_user"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v record;
begin
  -- if already provided, keep it
  if new.company_id is not null then
    return new;
  end if;

  -- if function exists, try to infer from portal user
  begin
    select * into v
    from public.get_current_portal_user();

    if v.id is not null then
      new.company_id := v.company_id;
    end if;

  exception
    when undefined_function then
      -- get_current_portal_user() not installed; do nothing
      null;
  end;

  return new;
end;
$$;


ALTER FUNCTION "public"."tg_set_company_id_from_portal_user"() OWNER TO "postgres";


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
DECLARE
  v_item_id uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF (OLD.msrp_pct_sale_in = NEW.msrp_pct_sale_in) 
       AND (OLD.msrp_pct_sale_out = NEW.msrp_pct_sale_out) THEN
      RETURN NEW;
    END IF;
  END IF;
  
  -- Recompute all items in this category
  FOR v_item_id IN
    SELECT id FROM public."CatalogItems"
    WHERE organization_id = NEW.organization_id
      AND category_id = NEW.category_id
      AND cost_exw IS NOT NULL AND cost_exw > 0
      AND is_active = true
  LOOP
    PERFORM "public"."msrp_compute_for_item"(v_item_id);
  END LOOP;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trig_catmargins_msrp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Recalcular si cambió cost_exw o category_id
  IF (TG_OP = 'INSERT') OR 
     (TG_OP = 'UPDATE' AND (
       (OLD.cost_exw IS DISTINCT FROM NEW.cost_exw) OR
       (OLD.category_id IS DISTINCT FROM NEW.category_id)
     )) THEN
    IF NEW.cost_exw > 0 AND NEW.organization_id IS NOT NULL THEN
      PERFORM public.msrp_compute_for_item(NEW.id);
    END IF;
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
    CONSTRAINT "BOMComponents_component_scope_check" CHECK (("component_scope" = ANY (ARRAY['bom'::"text", 'sku'::"text"]))),
    CONSTRAINT "bomcomponents_component_role_check" CHECK (("component_role" = ANY (ARRAY['tube'::"text", 'track'::"text", 'bottom_bar'::"text", 'bottom_channel'::"text", 'hem_weight'::"text", 'side_channel'::"text", 'top_rail'::"text", 'headbox'::"text", 'bracket'::"text", 'idler'::"text", 'drive'::"text", 'motor'::"text", 'chain'::"text", 'chain_stop'::"text", 'chain_tensioner'::"text", 'wand'::"text", 'end_cap'::"text", 'filler'::"text", 'tape'::"text", 'consumable'::"text", 'fastener'::"text", 'accessory'::"text", 'carrier'::"text", 'belt'::"text", 'belt_connector'::"text", 'hook'::"text", 'brush'::"text", 'fabric'::"text", 'adapter'::"text", 'bearing'::"text", 'connector'::"text", 'guide'::"text", 'rail_connector'::"text", 'spring'::"text", 'stopper'::"text", 'mounting_clip'::"text", 'end_plug'::"text"]))),
    CONSTRAINT "bomcomponents_component_scope_check" CHECK (("component_scope" = ANY (ARRAY['template'::"text", 'bom'::"text"]))),
    CONSTRAINT "bomcomponents_depends_on_role_check" CHECK ((("depends_on_role" IS NULL) OR ("depends_on_role" = ANY (ARRAY['tube'::"text", 'track'::"text", 'bottom_bar'::"text", 'bottom_channel'::"text", 'hem_weight'::"text", 'side_channel'::"text", 'top_rail'::"text", 'headbox'::"text", 'bracket'::"text", 'idler'::"text", 'drive'::"text", 'motor'::"text", 'chain'::"text", 'chain_stop'::"text", 'chain_tensioner'::"text", 'wand'::"text", 'end_cap'::"text", 'filler'::"text", 'tape'::"text", 'consumable'::"text", 'fastener'::"text", 'accessory'::"text", 'carrier'::"text", 'belt'::"text", 'belt_connector'::"text", 'hook'::"text", 'brush'::"text", 'fabric'::"text", 'adapter'::"text", 'bearing'::"text", 'connector'::"text", 'guide'::"text", 'rail_connector'::"text", 'spring'::"text", 'stopper'::"text", 'mounting_clip'::"text", 'end_plug'::"text"])))),
    CONSTRAINT "bomcomponents_fixed_requires_item" CHECK (((("component_mode" <> 'fixed'::"public"."bom_component_mode") AND ("component_item_id" IS NULL)) OR (("component_mode" = 'fixed'::"public"."bom_component_mode") AND ("component_item_id" IS NOT NULL)) OR ("component_mode" = ANY (ARRAY['select'::"public"."bom_component_mode", 'auto'::"public"."bom_component_mode", 'optional'::"public"."bom_component_mode"]))))
);


ALTER TABLE "public"."BOMComponents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."BOMInstanceLines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "bom_instance_id" "uuid" NOT NULL,
    "bom_component_id" "uuid",
    "resolved_part_id" "uuid",
    "part_role" "text" NOT NULL,
    "qty" numeric(12,4) NOT NULL,
    "uom" "text" NOT NULL,
    "cut_length_mm" numeric(12,4),
    "cut_width_mm" numeric(12,4),
    "cut_height_mm" numeric(12,4),
    "unit_cost_exw" numeric(12,4),
    "total_cost_exw" numeric(12,4),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    CONSTRAINT "bominstancelines_part_role_check" CHECK (("part_role" = ANY (ARRAY['tube'::"text", 'track'::"text", 'bottom_bar'::"text", 'bottom_channel'::"text", 'hem_weight'::"text", 'side_channel'::"text", 'top_rail'::"text", 'headbox'::"text", 'bracket'::"text", 'idler'::"text", 'drive'::"text", 'motor'::"text", 'adapter'::"text", 'chain'::"text", 'chain_stop'::"text", 'chain_tensioner'::"text", 'wand'::"text", 'end_cap'::"text", 'filler'::"text", 'tape'::"text", 'consumable'::"text", 'fastener'::"text", 'accessory'::"text", 'carrier'::"text", 'belt'::"text", 'belt_connector'::"text"])))
);


ALTER TABLE "public"."BOMInstanceLines" OWNER TO "postgres";


COMMENT ON COLUMN "public"."BOMInstanceLines"."resolved_part_id" IS 'FK to CatalogItems. Can be NULL for structural lines without SKU (user has not selected yet).';



CREATE TABLE IF NOT EXISTS "public"."BOMInstances" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "quote_line_id" "uuid" NOT NULL,
    "bom_template_id" "uuid" NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "configured_product_id" "uuid"
);


ALTER TABLE "public"."BOMInstances" OWNER TO "postgres";


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
    "description" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "product_type" "text",
    "headbox_type" "public"."headbox_type",
    "system_size" "public"."system_size",
    "color" "text",
    "side_channel_mode" "public"."side_channel_mode",
    "operating_system" "public"."operating_system",
    "is_active" boolean DEFAULT true,
    "hardware_color" "text"
);


ALTER TABLE "public"."BOMTemplates" OWNER TO "postgres";


COMMENT ON COLUMN "public"."BOMTemplates"."hardware_color" IS 'Hardware color (White, Black, Silver, Bronze, etc.) to differentiate templates for the same product type. NULL means template applies to all colors.';



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
    "is_fabric" boolean DEFAULT false NOT NULL,
    "collection_name" "text",
    "variant_name" "text",
    "roll_width" numeric(12,4),
    "fabric_pricing_mode" "text",
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
    CONSTRAINT "catalogitems_item_role_check" CHECK ((("item_role" IS NULL) OR ("item_role" = ANY (ARRAY['accessory'::"text", 'adapter'::"text", 'bearing'::"text", 'belt'::"text", 'belt_connector'::"text", 'bottom_bar'::"text", 'bottom_bar_profile'::"text", 'bottom_channel'::"text", 'bottom_rail_profile'::"text", 'bracket'::"text", 'brush'::"text", 'cable'::"text", 'carrier'::"text", 'cassette'::"text", 'chain'::"text", 'chain_clip'::"text", 'chain_stop'::"text", 'chain_tensioner'::"text", 'consumable'::"text", 'control'::"text", 'drive'::"text", 'drive_adapter'::"text", 'drive_manual'::"text", 'drive_motorized'::"text", 'end_cap'::"text", 'end_plug'::"text", 'fabric'::"text", 'fascia'::"text", 'fastener'::"text", 'filler'::"text", 'guide'::"text", 'handle'::"text", 'hardware'::"text", 'headbox'::"text", 'hook'::"text", 'idler'::"text", 'motor'::"text", 'mount_profile'::"text", 'mounting_clip'::"text", 'rail_connector'::"text", 'screw_cap'::"text", 'side_channel'::"text", 'side_channel_profile'::"text", 'spring'::"text", 'stopper'::"text", 'sub_bracket'::"text", 'tape'::"text", 'top_rail'::"text", 'top_rail_profile'::"text", 'track'::"text", 'tube'::"text", 'wand'::"text", 'window_film'::"text"])))),
    CONSTRAINT "catalogitems_roll_type_requires_is_roll" CHECK ((("roll_type" IS NULL) OR ("is_roll" = true)))
);


ALTER TABLE "public"."CatalogItems" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."CatalogItemsMSRP" (
    "catalog_item_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "category_id" "uuid",
    "cost_exw" numeric(12,4) NOT NULL,
    "import_tax_cost" numeric(12,4) NOT NULL,
    "shipping_cost" numeric(12,4) NOT NULL,
    "total_cost" numeric(12,4) NOT NULL,
    "msrp_sale_in" numeric(12,4) NOT NULL,
    "msrp_sale_out" numeric(12,4) NOT NULL,
    "sku" "text",
    "name" "text",
    "collection_name" "text",
    "variant_name" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
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
    "msrp_pct_sale_in" numeric(7,4) DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "msrp_pct_sale_out" numeric(7,4) DEFAULT 0.65 NOT NULL
);


ALTER TABLE "public"."CategoryMargins" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."Companies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "company_name" "text" NOT NULL,
    "company_email" "text",
    "company_phone" "text",
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "company_no" "text",
    "customer_type" "public"."customer_type" DEFAULT 'reseller'::"public"."customer_type",
    CONSTRAINT "companies_org_required" CHECK (("organization_id" IS NOT NULL))
);


ALTER TABLE "public"."Companies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."CompanyPortalUsers" (
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
    "company_id" "uuid",
    "role" "text" DEFAULT 'member'::"text" NOT NULL,
    "must_change_password" boolean DEFAULT true NOT NULL,
    "temp_password_set_at" timestamp with time zone,
    CONSTRAINT "company_portal_role_check" CHECK (("role" = ANY (ARRAY['member'::"text", 'member_manager'::"text"]))),
    CONSTRAINT "companyportalusers_portal_user_role_check" CHECK (("role" = ANY (ARRAY['member_manager'::"text", 'member'::"text"]))),
    CONSTRAINT "companyportalusers_role_check" CHECK (("role" = ANY (ARRAY['member_manager'::"text", 'member'::"text"])))
);


ALTER TABLE "public"."CompanyPortalUsers" OWNER TO "postgres";


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
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
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
    "bottom_bar_item_id" "uuid",
    "bottom_bar_sku" "text",
    "headbox_item_id" "uuid",
    "headbox_sku" "text",
    "side_channel_item_id" "uuid",
    "side_channel_sku" "text",
    "bottom_channel_item_id" "uuid",
    "bottom_channel_sku" "text",
    "motor_item_id" "uuid",
    "motor_sku" "text",
    "drive_item_id" "uuid",
    "drive_sku" "text",
    "tube_item_id" "uuid",
    "tube_sku" "text",
    "operating_type" "text",
    "roll_total_cost" numeric(12,4) DEFAULT 0,
    "bom_total_cost" numeric(12,4) DEFAULT 0,
    "labor_amount" numeric(12,4) DEFAULT 0
);


ALTER TABLE "public"."ConfiguredProducts" OWNER TO "postgres";


COMMENT ON TABLE "public"."ConfiguredProducts" IS 'Snapshot completo de producto configurado (Roll + BOM) antes de crear QuoteLine. Contiene precios calculados y toda la configuración.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."bom_total" IS 'Total MSRP sale_out de todos los componentes BOM (padres + hijos) desde BOMInstanceLines.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."config_snapshot" IS 'JSONB con snapshot completo de la configuración desde ProductConfigurator. Incluye todas las selecciones y opciones.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."metadata" IS 'JSONB para datos adicionales flexibles.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."roll_msrp_total" IS 'MSRP Sale out × Ancho del rollo total × Altura de la medida de measurements × quantity.';



COMMENT ON COLUMN "public"."ConfiguredProducts"."roll_plus_bom_total" IS 'Suma de Roll MSRP + BOM Total (antes de aplicar labor y accessories).';



COMMENT ON COLUMN "public"."ConfiguredProducts"."roll_total_cost" IS 'Costo real total del roll (usando CatalogItemsMSRP.total_cost). 
Calculado como: total_cost del roll × roll_width × height_m × quantity';



COMMENT ON COLUMN "public"."ConfiguredProducts"."bom_total_cost" IS 'Costo real total del BOM (suma de CatalogItemsMSRP.total_cost de cada BOMInstanceLine).
Calculado como: SUM(total_cost × qty) para cada línea del BOM';



CREATE TABLE IF NOT EXISTS "public"."CostSettings" (
    "organization_id" "uuid" NOT NULL,
    "labor_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "shipping_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "global_import_tax_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "minimum_margin_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "reseller_discount_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "distributor_discount_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "partner_discount_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "vip_discount_pct" numeric(7,4) DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "default_msrp_pct_sale_out" numeric(7,4) DEFAULT 0.65 NOT NULL
);


ALTER TABLE "public"."CostSettings" OWNER TO "postgres";


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
    "company_id" "uuid",
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
    "contact_country" "text"
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
    "company_id" "uuid",
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
    "billing_country" "text"
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
    "company_id" "uuid"
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
    "company_id" "uuid"
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
    "company_no_prefix" "text" DEFAULT 'AP'::"text" NOT NULL,
    "next_company_no" integer DEFAULT 1001 NOT NULL,
    CONSTRAINT "organizations_company_no_prefix_chk" CHECK ((("length"("company_no_prefix") >= 1) AND ("length"("company_no_prefix") <= 10)))
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


CREATE TABLE IF NOT EXISTS "public"."QuoteLineComponents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "quote_line_id" "uuid" NOT NULL,
    "component_role" "text" NOT NULL,
    "kind" "text" DEFAULT 'option'::"text" NOT NULL,
    "catalog_item_id" "uuid",
    "payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "source" "text" DEFAULT 'configured_component'::"text" NOT NULL,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "quotelinecomponents_component_role_check" CHECK ((("component_role" IS NULL) OR ("component_role" = ANY (ARRAY['tube'::"text", 'track'::"text", 'bottom_bar'::"text", 'bottom_channel'::"text", 'hem_weight'::"text", 'side_channel'::"text", 'top_rail'::"text", 'headbox'::"text", 'bracket'::"text", 'idler'::"text", 'drive'::"text", 'motor'::"text", 'adapter'::"text", 'chain'::"text", 'chain_stop'::"text", 'chain_tensioner'::"text", 'wand'::"text", 'end_cap'::"text", 'filler'::"text", 'tape'::"text", 'consumable'::"text", 'fastener'::"text", 'accessory'::"text", 'carrier'::"text", 'belt'::"text", 'belt_connector'::"text", 'fabric'::"text", 'hardware_color'::"text", 'drive_type'::"text", 'system_size'::"text", 'cassette'::"text", 'bottom_rail_type'::"text", 'tube_type'::"text", 'side_channels'::"text", 'bearing'::"text", 'hook'::"text", 'brush'::"text"]))))
);


ALTER TABLE "public"."QuoteLineComponents" OWNER TO "postgres";


COMMENT ON COLUMN "public"."QuoteLineComponents"."kind" IS 'Type of component entry: 
- "option": Configuration option (color, size, etc)
- "override": Manual override of BOM component
- "selection": User-selected SKU for a parent role (motor, bracket, etc)';



CREATE TABLE IF NOT EXISTS "public"."QuoteLines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "company_id" "uuid",
    "quote_id" "uuid" NOT NULL,
    "catalog_item_id" "uuid",
    "category_id" "uuid",
    "sku" "text",
    "name" "text",
    "manufacturer_id" "uuid",
    "manufacturer" "text",
    "pricing_basis" "public"."pricing_basis",
    "unit_of_measure" "text",
    "quantity" numeric(12,4) DEFAULT 1 NOT NULL,
    "width_m" numeric(12,4),
    "height_m" numeric(12,4),
    "is_roll" boolean,
    "roll_type" "text",
    "collection_name" "text",
    "variant_name" "text",
    "roll_width_m" numeric(12,4),
    "fabric_pricing_mode" "text",
    "drop_m" numeric(12,4),
    "sqm" numeric(12,4),
    "cost_exw" numeric(12,4),
    "labor_pct" numeric(7,4),
    "shipping_pct" numeric(7,4),
    "import_tax_pct" numeric(7,4),
    "default_margin_pct" numeric(7,4),
    "minimum_margin_pct" numeric(7,4),
    "discount_pct" numeric(7,4),
    "material_cost" numeric(12,4),
    "labor_cost" numeric(12,4),
    "shipping_cost" numeric(12,4),
    "import_tax_cost" numeric(12,4),
    "total_cost" numeric(12,4),
    "applied_margin_pct" numeric(7,4),
    "msrp" numeric(12,4),
    "net_price" numeric(12,4),
    "pricing_version" integer DEFAULT 1 NOT NULL,
    "pricing_locked" boolean DEFAULT true NOT NULL,
    "last_priced_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "collection_id" "uuid",
    "variant_id" "uuid",
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
    "bom_msrp_snapshot" numeric
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
    "company_id" "uuid",
    "created_by_portal_user_id" "uuid",
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
    "company_id" "uuid"
);


ALTER TABLE "public"."SalesOrders" OWNER TO "postgres";


COMMENT ON TABLE "public"."SalesOrders" IS 'SalesOrders table - always created from approved Quotes via trigger';



COMMENT ON COLUMN "public"."SalesOrders"."quote_id" IS 'FK to Quotes (1:1 unique). SalesOrder always created from Quote.';



COMMENT ON COLUMN "public"."SalesOrders"."tracking_status" IS 'Tracking status - source of truth. Mirrored to OrderList.';



ALTER TABLE ONLY "public"."BOMComponents"
    ADD CONSTRAINT "BOMComponents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."BOMTemplateSlots"
    ADD CONSTRAINT "BOMTemplateSlots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."BOMTemplates"
    ADD CONSTRAINT "BOMTemplates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."BOMTemplates"
    ADD CONSTRAINT "BOMTemplates_unique_code" UNIQUE ("organization_id", "code");



ALTER TABLE ONLY "public"."BOMInstanceLines"
    ADD CONSTRAINT "BomInstanceLines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."BOMInstances"
    ADD CONSTRAINT "BomInstances_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CatalogCategories"
    ADD CONSTRAINT "CatalogCategories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CatalogItemProductTypes"
    ADD CONSTRAINT "CatalogItemProductTypes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CatalogItemRoles"
    ADD CONSTRAINT "CatalogItemRoles_pkey" PRIMARY KEY ("role_code");



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



ALTER TABLE ONLY "public"."Companies"
    ADD CONSTRAINT "Companies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CostSettings"
    ADD CONSTRAINT "CostSettings_pkey" PRIMARY KEY ("organization_id");



ALTER TABLE ONLY "public"."CompanyPortalUsers"
    ADD CONSTRAINT "CustomerPortalUsers_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."CatalogItemComponents"
    ADD CONSTRAINT "catalogitemcomponents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."CatalogItemsMSRP"
    ADD CONSTRAINT "catalogitemsmsrp_org_item_unique" UNIQUE ("organization_id", "catalog_item_id");



ALTER TABLE ONLY "public"."CategoryMargins"
    ADD CONSTRAINT "categorymargins_org_category_unique" UNIQUE ("organization_id", "category_id");



ALTER TABLE ONLY "public"."Companies"
    ADD CONSTRAINT "companies_org_company_no_uniq" UNIQUE ("organization_id", "company_no");



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



CREATE UNIQUE INDEX "bomcomponents_unique_slot_override" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id", "slot_id") WHERE ("slot_id" IS NOT NULL);



CREATE INDEX "bominstancelines_instance_idx" ON "public"."BOMInstanceLines" USING "btree" ("bom_instance_id");



CREATE INDEX "bominstancelines_org_deleted_idx" ON "public"."BOMInstanceLines" USING "btree" ("organization_id", "deleted") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "bominstances_one_per_quoteline_uq" ON "public"."BOMInstances" USING "btree" ("quote_line_id") WHERE (COALESCE("deleted", false) = false);



CREATE UNIQUE INDEX "bominstances_unique_quote_line" ON "public"."BOMInstances" USING "btree" ("organization_id", "quote_line_id") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "bomtemplates_fingerprint_unique" ON "public"."BOMTemplates" USING "btree" ("organization_id", "product_type", "headbox_type", "system_size", "color", "side_channel_mode", "operating_system") WHERE ("deleted" = false);



CREATE INDEX "bomtemplateslots_role_idx" ON "public"."BOMTemplateSlots" USING "btree" ("item_role");



CREATE INDEX "bomtemplateslots_template_idx" ON "public"."BOMTemplateSlots" USING "btree" ("bom_template_id");



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



CREATE UNIQUE INDEX "companies_org_company_no_unique" ON "public"."Companies" USING "btree" ("organization_id", "company_no") WHERE ("company_no" IS NOT NULL);



COMMENT ON INDEX "public"."companies_org_company_no_unique" IS 'Ensure unique company_no per organization (only when company_no is set)';



CREATE UNIQUE INDEX "companyportal_company_email_uniq" ON "public"."CompanyPortalUsers" USING "btree" ("company_id", "lower"("portal_user_email")) WHERE ("deleted" = false);



CREATE UNIQUE INDEX "companyportalusers_company_email_uniq" ON "public"."CompanyPortalUsers" USING "btree" ("company_id", "portal_user_email");



CREATE UNIQUE INDEX "companyportalusers_org_email_unique" ON "public"."CompanyPortalUsers" USING "btree" ("organization_id", "lower"("portal_user_email")) WHERE ("deleted" = false);



CREATE INDEX "idx_bomcomponents_role" ON "public"."BOMComponents" USING "btree" ("organization_id", "component_role") WHERE (("deleted" = false) AND ("archived" = false));



CREATE INDEX "idx_bomcomponents_template" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id") WHERE (("deleted" = false) AND ("archived" = false));



CREATE INDEX "idx_bominstancelines_instance" ON "public"."BOMInstanceLines" USING "btree" ("bom_instance_id");



CREATE INDEX "idx_bominstancelines_instance_resolved" ON "public"."BOMInstanceLines" USING "btree" ("bom_instance_id", "resolved_part_id") WHERE (("deleted" = false) AND ("resolved_part_id" IS NOT NULL));



CREATE INDEX "idx_bominstancelines_resolved_part" ON "public"."BOMInstanceLines" USING "btree" ("resolved_part_id") WHERE (("deleted" = false) AND ("resolved_part_id" IS NOT NULL));



CREATE INDEX "idx_bomtemplates_org_type" ON "public"."BOMTemplates" USING "btree" ("organization_id", "product_type_id") WHERE (("deleted" = false) AND ("archived" = false) AND ("active" = true));



CREATE INDEX "idx_catalogitemcomponents_child_role" ON "public"."CatalogItemComponents" USING "btree" ("organization_id", "child_role") WHERE ("deleted" = false);



CREATE INDEX "idx_catalogitemcomponents_parent" ON "public"."CatalogItemComponents" USING "btree" ("organization_id", "parent_item_id") WHERE ("deleted" = false);



CREATE INDEX "idx_catalogitems_org_role" ON "public"."CatalogItems" USING "btree" ("organization_id", "item_role") WHERE ("is_active" = true);



CREATE INDEX "idx_catalogitems_org_role_color" ON "public"."CatalogItems" USING "btree" ("organization_id", "item_role", "color") WHERE (("is_active" = true) AND ("is_roll" = false));



CREATE INDEX "idx_catalogitems_roll_lookup" ON "public"."CatalogItems" USING "btree" ("organization_id", "collection_name", "variant_name") WHERE (("is_active" = true) AND ("is_roll" = true));



CREATE INDEX "idx_catalogitemsmsrp_cat" ON "public"."CatalogItemsMSRP" USING "btree" ("category_id");



CREATE INDEX "idx_catalogitemsmsrp_org" ON "public"."CatalogItemsMSRP" USING "btree" ("organization_id");



CREATE INDEX "idx_catalogitemsmsrp_org_item" ON "public"."CatalogItemsMSRP" USING "btree" ("organization_id", "catalog_item_id");



CREATE INDEX "idx_companies_deleted" ON "public"."Companies" USING "btree" ("deleted") WHERE ("deleted" = false);



CREATE INDEX "idx_companies_org" ON "public"."Companies" USING "btree" ("organization_id");



CREATE INDEX "idx_companies_org_company_no" ON "public"."Companies" USING "btree" ("organization_id", "company_no");



CREATE INDEX "idx_companyportalusers_company" ON "public"."CompanyPortalUsers" USING "btree" ("company_id");



CREATE INDEX "idx_companyportalusers_role" ON "public"."CompanyPortalUsers" USING "btree" ("role") WHERE ("deleted" = false);



CREATE INDEX "idx_configuredproducts_config_snapshot" ON "public"."ConfiguredProducts" USING "gin" ("config_snapshot");



CREATE INDEX "idx_configuredproducts_organization" ON "public"."ConfiguredProducts" USING "btree" ("organization_id") WHERE ("deleted" = false);



CREATE INDEX "idx_configuredproducts_product_type" ON "public"."ConfiguredProducts" USING "btree" ("product_type_id") WHERE ("deleted" = false);



CREATE INDEX "idx_configuredproducts_quote" ON "public"."ConfiguredProducts" USING "btree" ("quote_id") WHERE ("deleted" = false);



CREATE INDEX "idx_configuredproducts_template" ON "public"."ConfiguredProducts" USING "btree" ("bom_template_id") WHERE ("deleted" = false);



CREATE INDEX "idx_dircontacts_company" ON "public"."DirectoryContacts" USING "btree" ("company_id");



CREATE INDEX "idx_dircontacts_org" ON "public"."DirectoryContacts" USING "btree" ("organization_id") WHERE ("organization_id" IS NOT NULL);



CREATE INDEX "idx_dircustomers_company" ON "public"."DirectoryCustomers" USING "btree" ("company_id");



CREATE INDEX "idx_dircustomers_country" ON "public"."DirectoryCustomers" USING "btree" ("country") WHERE ("country" IS NOT NULL);



CREATE INDEX "idx_dircustomers_customer_type" ON "public"."DirectoryCustomers" USING "btree" ("customer_type_name") WHERE ("customer_type_name" IS NOT NULL);



CREATE INDEX "idx_dircustomers_org" ON "public"."DirectoryCustomers" USING "btree" ("organization_id") WHERE ("organization_id" IS NOT NULL);



CREATE INDEX "idx_dircustomers_primary_contact" ON "public"."DirectoryCustomers" USING "btree" ("primary_contact_id") WHERE ("primary_contact_id" IS NOT NULL);



CREATE INDEX "idx_directorycontacts_contact_type" ON "public"."DirectoryContacts" USING "btree" ("contact_type");



CREATE INDEX "idx_directorycontacts_customer" ON "public"."DirectoryContacts" USING "btree" ("customer_id");



CREATE INDEX "idx_directorycontacts_org" ON "public"."DirectoryContacts" USING "btree" ("organization_id");



CREATE INDEX "idx_directorycustomers_company_id" ON "public"."DirectoryCustomers" USING "btree" ("company_id");



CREATE INDEX "idx_directorycustomers_org" ON "public"."DirectoryCustomers" USING "btree" ("organization_id");



CREATE INDEX "idx_directorycustomers_org_company" ON "public"."DirectoryCustomers" USING "btree" ("organization_id", "company_id");



CREATE INDEX "idx_mo_company" ON "public"."ManufacturingOrders" USING "btree" ("company_id");



CREATE INDEX "idx_mo_org" ON "public"."ManufacturingOrders" USING "btree" ("organization_id");



CREATE INDEX "idx_mo_so" ON "public"."ManufacturingOrders" USING "btree" ("sales_order_id");



CREATE INDEX "idx_order_list_organization_id" ON "public"."OrderList" USING "btree" ("organization_id") WHERE ("deleted" = false);



CREATE INDEX "idx_order_list_sales_order_id" ON "public"."OrderList" USING "btree" ("sales_order_id") WHERE ("deleted" = false);



CREATE INDEX "idx_order_list_tracking_status" ON "public"."OrderList" USING "btree" ("tracking_status") WHERE ("deleted" = false);



CREATE INDEX "idx_orderlist_company" ON "public"."OrderList" USING "btree" ("company_id");



CREATE INDEX "idx_org_user_permissions_code" ON "public"."OrganizationUserPermissions" USING "btree" ("permission_code");



CREATE INDEX "idx_org_user_permissions_user_id" ON "public"."OrganizationUserPermissions" USING "btree" ("organization_user_id");



CREATE INDEX "idx_organization_users_organization_id" ON "public"."OrganizationUsers" USING "btree" ("organization_id") WHERE ("deleted" = false);



CREATE INDEX "idx_organization_users_status" ON "public"."OrganizationUsers" USING "btree" ("status") WHERE ("deleted" = false);



CREATE INDEX "idx_organization_users_user_email" ON "public"."OrganizationUsers" USING "btree" ("lower"("user_email")) WHERE ("deleted" = false);



CREATE INDEX "idx_organization_users_user_id" ON "public"."OrganizationUsers" USING "btree" ("user_id") WHERE (("user_id" IS NOT NULL) AND ("deleted" = false));



CREATE INDEX "idx_organizations_created_at" ON "public"."Organizations" USING "btree" ("created_at");



CREATE INDEX "idx_permissions_module" ON "public"."Permissions" USING "btree" ("module");



CREATE INDEX "idx_portalusers_org" ON "public"."CompanyPortalUsers" USING "btree" ("organization_id");



CREATE INDEX "idx_portalusers_user" ON "public"."CompanyPortalUsers" USING "btree" ("user_id");



CREATE INDEX "idx_qlc_org_quote_line" ON "public"."QuoteLineComponents" USING "btree" ("organization_id", "quote_line_id") WHERE ("deleted" = false);



CREATE INDEX "idx_qlc_org_quote_line_role" ON "public"."QuoteLineComponents" USING "btree" ("organization_id", "quote_line_id", "component_role") WHERE ("deleted" = false);



CREATE INDEX "idx_quote_lines_bom_template_id" ON "public"."QuoteLines" USING "btree" ("bom_template_id") WHERE ("bom_template_id" IS NOT NULL);



CREATE INDEX "idx_quote_lines_collection_id" ON "public"."QuoteLines" USING "btree" ("collection_id") WHERE ("collection_id" IS NOT NULL);



CREATE INDEX "idx_quote_lines_product_type" ON "public"."QuoteLines" USING "btree" ("product_type") WHERE ("product_type" IS NOT NULL);



CREATE INDEX "idx_quote_lines_variant_id" ON "public"."QuoteLines" USING "btree" ("variant_id") WHERE ("variant_id" IS NOT NULL);



CREATE INDEX "idx_quotelines_catalog_item_id" ON "public"."QuoteLines" USING "btree" ("catalog_item_id");



CREATE INDEX "idx_quotelines_category_id" ON "public"."QuoteLines" USING "btree" ("category_id");



CREATE INDEX "idx_quotelines_company_id" ON "public"."QuoteLines" USING "btree" ("company_id");



CREATE INDEX "idx_quotelines_org_id" ON "public"."QuoteLines" USING "btree" ("organization_id");



CREATE INDEX "idx_quotelines_quote_id" ON "public"."QuoteLines" USING "btree" ("quote_id");



CREATE INDEX "idx_quotes_company" ON "public"."Quotes" USING "btree" ("company_id");



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



CREATE INDEX "idx_salesorders_company" ON "public"."SalesOrders" USING "btree" ("company_id");



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



CREATE UNIQUE INDEX "quotes_org_quote_no_unique" ON "public"."Quotes" USING "btree" ("organization_id", "quote_no") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "quotes_unique_no" ON "public"."Quotes" USING "btree" ("organization_id", "quote_no") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "sales_orders_org_so_no_unique" ON "public"."SalesOrders" USING "btree" ("organization_id", "sales_order_no") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "so_unique_quote" ON "public"."SalesOrders" USING "btree" ("quote_id") WHERE ("deleted" = false);



CREATE UNIQUE INDEX "uq_bomcomponents_template_slot_active" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id", "slot_id") WHERE (("deleted" = false) AND ("archived" = false) AND ("slot_id" IS NOT NULL));



CREATE UNIQUE INDEX "uq_catalogitemcomponents_parent_child_role" ON "public"."CatalogItemComponents" USING "btree" ("organization_id", "parent_item_id", "child_item_id", "child_role");



CREATE UNIQUE INDEX "uq_companies_org_name" ON "public"."Companies" USING "btree" ("organization_id", "lower"("company_name")) WHERE ("deleted" = false);



CREATE UNIQUE INDEX "uq_orguserpermissions_orguser_perm" ON "public"."OrganizationUserPermissions" USING "btree" ("organization_user_id", "permission_code");



CREATE UNIQUE INDEX "ux_bomcomponents_no_duplicate_child_sku" ON "public"."BOMComponents" USING "btree" ("organization_id", "bom_template_id", "parent_component_id", "component_item_id") WHERE (("parent_component_id" IS NOT NULL) AND ("deleted" = false) AND ("archived" = false));



CREATE OR REPLACE TRIGGER "trg_catalog_item_roles_updated_at" BEFORE UPDATE ON "public"."CatalogItemRoles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_catalogitemcomponents_updated_at" BEFORE UPDATE ON "public"."CatalogItemComponents" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_catalogitemroles_updated_at" BEFORE UPDATE ON "public"."CatalogItemRoles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_catalogitems_sync_collection_name" BEFORE INSERT OR UPDATE OF "roll_collection_id" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."sync_catalogitem_collection_name_from_roll_collection"();



CREATE OR REPLACE TRIGGER "trg_catalogitems_sync_manufacturer" BEFORE INSERT OR UPDATE OF "manufacturer", "organization_id" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."sync_catalogitems_manufacturer"();



CREATE OR REPLACE TRIGGER "trg_catalogitemsmsrp_updated_at" BEFORE UPDATE ON "public"."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_categorymargins_updated_at" BEFORE UPDATE ON "public"."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_companies_set_company_no" BEFORE INSERT ON "public"."Companies" FOR EACH ROW EXECUTE FUNCTION "public"."set_company_no"();



COMMENT ON TRIGGER "trg_companies_set_company_no" ON "public"."Companies" IS 'Auto-assigns company_no on insert using next_company_no() function. Only sets if company_no is null/empty.';



CREATE OR REPLACE TRIGGER "trg_companies_updated_at" BEFORE UPDATE ON "public"."Companies" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_companyportalusers_updated_at" BEFORE UPDATE ON "public"."CompanyPortalUsers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_configuredproducts_updated_at" BEFORE UPDATE ON "public"."ConfiguredProducts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_costsettings_updated_at" BEFORE UPDATE ON "public"."CostSettings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_customerportalusers_updated_at" BEFORE UPDATE ON "public"."CompanyPortalUsers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_dircontacts_set_company" BEFORE INSERT ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."tg_set_company_id_from_portal_user"();



CREATE OR REPLACE TRIGGER "trg_dircustomers_set_company" BEFORE INSERT ON "public"."DirectoryCustomers" FOR EACH ROW EXECUTE FUNCTION "public"."tg_set_company_id_from_portal_user"();



CREATE OR REPLACE TRIGGER "trg_directorycontacts_fill_org_id" BEFORE INSERT OR UPDATE OF "company_id", "organization_id" ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."directorycontacts_fill_org_id"();



CREATE OR REPLACE TRIGGER "trg_directorycontacts_updated_at" BEFORE UPDATE ON "public"."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_directorycustomers_set_company" BEFORE INSERT ON "public"."DirectoryCustomers" FOR EACH ROW EXECUTE FUNCTION "public"."tg_set_company_id_from_portal_user"();



CREATE OR REPLACE TRIGGER "trg_directorycustomers_updated_at" BEFORE UPDATE ON "public"."DirectoryCustomers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_enforce_active_item_role" BEFORE INSERT OR UPDATE OF "item_role" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_active_item_role"();



CREATE OR REPLACE TRIGGER "trg_fill_msrp_item_identity" BEFORE INSERT OR UPDATE OF "catalog_item_id", "sku", "name", "collection_name", "variant_name" ON "public"."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION "public"."fill_msrp_item_identity"();



CREATE OR REPLACE TRIGGER "trg_fill_msrp_sku_name" BEFORE INSERT OR UPDATE OF "catalog_item_id", "sku", "name" ON "public"."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION "public"."fill_msrp_sku_name"();



CREATE OR REPLACE TRIGGER "trg_importtaxrules_updated_at" BEFORE UPDATE ON "public"."ImportTaxRules" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_manufacturingorders_updated_at" BEFORE UPDATE ON "public"."ManufacturingOrders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_mo_company_match" BEFORE INSERT OR UPDATE ON "public"."ManufacturingOrders" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_mo_company_matches_salesorder"();



CREATE OR REPLACE TRIGGER "trg_mo_company_match_so" BEFORE INSERT OR UPDATE ON "public"."ManufacturingOrders" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_mo_company_matches_salesorder"();



CREATE OR REPLACE TRIGGER "trg_orderlist_company_match_so" BEFORE INSERT OR UPDATE ON "public"."OrderList" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_orderlist_company_matches_salesorder"();



CREATE OR REPLACE TRIGGER "trg_organizations_updated_at" BEFORE UPDATE ON "public"."Organizations" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_portalusers_updated_at" BEFORE UPDATE ON "public"."CompanyPortalUsers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_producttypes_set_updated_at" BEFORE UPDATE ON "public"."ProductTypes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_quote_approved" AFTER UPDATE OF "status" ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."on_quote_approved_create_sales_order"();



CREATE OR REPLACE TRIGGER "trg_quote_approved_to_sales_order" BEFORE UPDATE ON "public"."Quotes" FOR EACH ROW WHEN (("old"."status" IS DISTINCT FROM "new"."status")) EXECUTE FUNCTION "public"."handle_quote_approved"();



COMMENT ON TRIGGER "trg_quote_approved_to_sales_order" ON "public"."Quotes" IS 'Trigger: Automatically creates SalesOrder and OrderList when Quote is approved. Sets Quote.tracking_status.';



CREATE OR REPLACE TRIGGER "trg_quotes_set_company" BEFORE INSERT ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."tg_set_company_id_from_portal_user"();



CREATE OR REPLACE TRIGGER "trg_quotes_updated_at" BEFORE UPDATE ON "public"."Quotes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_recompute_msrp_on_catalog_item_change" AFTER INSERT OR UPDATE OF "cost_exw", "category_id" ON "public"."CatalogItems" FOR EACH ROW WHEN ((("new"."cost_exw" > (0)::numeric) AND ("new"."organization_id" IS NOT NULL))) EXECUTE FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"();



CREATE OR REPLACE TRIGGER "trg_recompute_msrp_on_category_margin_change" AFTER INSERT OR DELETE OR UPDATE ON "public"."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION "public"."trig_recompute_msrp_on_category_margin_change"();



CREATE OR REPLACE TRIGGER "trg_recompute_msrp_on_cost_settings_change" AFTER INSERT OR UPDATE OF "shipping_pct", "global_import_tax_pct" ON "public"."CostSettings" FOR EACH ROW EXECUTE FUNCTION "public"."trig_recompute_msrp_on_cost_settings_change"();



CREATE OR REPLACE TRIGGER "trg_recompute_msrp_on_import_tax_change" AFTER INSERT OR DELETE OR UPDATE ON "public"."ImportTaxRules" FOR EACH ROW EXECUTE FUNCTION "public"."trig_recompute_msrp_on_import_tax_change"();



CREATE OR REPLACE TRIGGER "trg_salesorder_status" AFTER UPDATE OF "tracking_status" ON "public"."SalesOrders" FOR EACH ROW EXECUTE FUNCTION "public"."on_sales_order_status_mirror"();



CREATE OR REPLACE TRIGGER "trg_salesorders_company_match_quote" BEFORE INSERT OR UPDATE ON "public"."SalesOrders" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_salesorders_company_matches_quote"();



CREATE OR REPLACE TRIGGER "trg_salesorders_updated_at" BEFORE UPDATE ON "public"."SalesOrders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at_product_type_role_rules" BEFORE UPDATE ON "public"."ProductTypeRoleRules" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at_product_type_role_rules"();



CREATE OR REPLACE TRIGGER "trg_sync_bom_template_slot_sku" BEFORE INSERT OR UPDATE OF "catalog_item_id", "fixed_catalog_item_id" ON "public"."BOMTemplateSlots" FOR EACH ROW EXECUTE FUNCTION "public"."sync_bom_template_slot_sku"();



CREATE OR REPLACE TRIGGER "trg_sync_catalogitems_to_msrp" AFTER UPDATE OF "sku", "name", "collection_name", "variant_name" ON "public"."CatalogItems" FOR EACH ROW EXECUTE FUNCTION "public"."sync_catalogitems_to_msrp"();



CREATE OR REPLACE TRIGGER "trg_sync_order_list_tracking" AFTER UPDATE OF "tracking_status" ON "public"."SalesOrders" FOR EACH ROW WHEN (("old"."tracking_status" IS DISTINCT FROM "new"."tracking_status")) EXECUTE FUNCTION "public"."sync_order_list_tracking_status"();



COMMENT ON TRIGGER "trg_sync_order_list_tracking" ON "public"."SalesOrders" IS 'Trigger: Automatically syncs OrderList.tracking_status when SalesOrder.tracking_status changes.';



CREATE OR REPLACE TRIGGER "trig_catmargins_msrp" AFTER INSERT OR UPDATE OF "msrp_pct_sale_in", "msrp_pct_sale_out" ON "public"."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION "public"."trig_catmargins_msrp"();



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



ALTER TABLE ONLY "public"."CatalogItemsMSRP"
    ADD CONSTRAINT "CatalogItemsMSRP_catalog_item_id_fkey" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."CatalogItems"
    ADD CONSTRAINT "CatalogItems_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."CatalogCategories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."CatalogRoleCategoryMap"
    ADD CONSTRAINT "CatalogRoleCategoryMap_role_code_fkey" FOREIGN KEY ("role_code") REFERENCES "public"."CatalogItemRoles"("role_code") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."CatalogRoleCategoryMap"
    ADD CONSTRAINT "CatalogRoleCategoryMap_target_category_id_fkey" FOREIGN KEY ("target_category_id") REFERENCES "public"."CatalogCategories"("id") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."Companies"
    ADD CONSTRAINT "Companies_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."CompanyPortalUsers"
    ADD CONSTRAINT "CompanyPortalUsers_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."Companies"("id");



ALTER TABLE ONLY "public"."CompanyPortalUsers"
    ADD CONSTRAINT "CustomerPortalUsers_invited_by_user_id_fkey" FOREIGN KEY ("invited_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."CompanyPortalUsers"
    ADD CONSTRAINT "CustomerPortalUsers_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."CompanyPortalUsers"
    ADD CONSTRAINT "CustomerPortalUsers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."Companies"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."DirectoryCustomers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."Companies"("id") ON DELETE RESTRICT;



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



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "Quotes_created_by_portal_user_id_fkey" FOREIGN KEY ("created_by_portal_user_id") REFERENCES "public"."CompanyPortalUsers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "Quotes_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "Quotes_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."SalesOrders"
    ADD CONSTRAINT "SalesOrders_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."SalesOrders"
    ADD CONSTRAINT "SalesOrders_quote_id_fkey" FOREIGN KEY ("quote_id") REFERENCES "public"."Quotes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."BOMInstanceLines"
    ADD CONSTRAINT "bil_component_fk" FOREIGN KEY ("bom_component_id") REFERENCES "public"."BOMComponents"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."BOMInstanceLines"
    ADD CONSTRAINT "bil_part_fk" FOREIGN KEY ("resolved_part_id") REFERENCES "public"."CatalogItems"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."BOMComponents"
    ADD CONSTRAINT "bomcomponents_item_fk" FOREIGN KEY ("component_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."BOMComponents"
    ADD CONSTRAINT "bomcomponents_slot_fk" FOREIGN KEY ("slot_id") REFERENCES "public"."BOMTemplateSlots"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."BOMComponents"
    ADD CONSTRAINT "bomcomponents_template_fk" FOREIGN KEY ("bom_template_id") REFERENCES "public"."BOMTemplates"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."BOMInstanceLines"
    ADD CONSTRAINT "bominstancelines_instance_fk" FOREIGN KEY ("bom_instance_id") REFERENCES "public"."BOMInstances"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."BOMInstanceLines"
    ADD CONSTRAINT "bominstancelines_organization_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."Organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."BOMInstances"
    ADD CONSTRAINT "bominstances_quote_line_fk" FOREIGN KEY ("quote_line_id") REFERENCES "public"."QuoteLines"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."BOMInstances"
    ADD CONSTRAINT "bominstances_template_fk" FOREIGN KEY ("bom_template_id") REFERENCES "public"."BOMTemplates"("id") ON DELETE RESTRICT;



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



ALTER TABLE ONLY "public"."DirectoryCustomers"
    ADD CONSTRAINT "directorycustomers_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."Companies"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ManufacturingOrders"
    ADD CONSTRAINT "fk_manufacturingorders_company" FOREIGN KEY ("company_id") REFERENCES "public"."Companies"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."OrderList"
    ADD CONSTRAINT "fk_orderlist_company" FOREIGN KEY ("company_id") REFERENCES "public"."Companies"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."QuoteLines"
    ADD CONSTRAINT "fk_quote_lines_bom_template" FOREIGN KEY ("bom_template_id") REFERENCES "public"."BOMTemplates"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."Quotes"
    ADD CONSTRAINT "fk_quotes_company" FOREIGN KEY ("company_id") REFERENCES "public"."Companies"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."SalesOrders"
    ADD CONSTRAINT "fk_salesorders_company" FOREIGN KEY ("company_id") REFERENCES "public"."Companies"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."QuoteLineComponents"
    ADD CONSTRAINT "qlc_item_fk" FOREIGN KEY ("catalog_item_id") REFERENCES "public"."CatalogItems"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."QuoteLineComponents"
    ADD CONSTRAINT "qlc_quote_line_fk" FOREIGN KEY ("quote_line_id") REFERENCES "public"."QuoteLines"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."QuoteLines"
    ADD CONSTRAINT "quotelines_quote_fk" FOREIGN KEY ("quote_id") REFERENCES "public"."Quotes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."SaleOrderLines"
    ADD CONSTRAINT "saleorderlines_so_fk" FOREIGN KEY ("sales_order_id") REFERENCES "public"."SalesOrders"("id") ON DELETE CASCADE;



CREATE POLICY "Authenticated users can read permissions" ON "public"."Permissions" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."CatalogItemComponents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."Companies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."CompanyPortalUsers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ConfiguredProducts" ENABLE ROW LEVEL SECURITY;


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



CREATE POLICY "companies_insert_own_org" ON "public"."Companies" FOR INSERT WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "companies_select_own_org" ON "public"."Companies" FOR SELECT USING (("public"."is_org_member"("organization_id") AND ("deleted" = false)));



CREATE POLICY "companies_update_own_org" ON "public"."Companies" FOR UPDATE USING ("public"."is_org_owner_or_admin"("organization_id")) WITH CHECK ("public"."is_org_owner_or_admin"("organization_id"));



CREATE POLICY "companyportalusers_insert_own_org" ON "public"."CompanyPortalUsers" FOR INSERT WITH CHECK ("public"."is_company_owner_or_admin"("company_id"));



CREATE POLICY "companyportalusers_select" ON "public"."CompanyPortalUsers" FOR SELECT USING ((("deleted" = false) AND ((("user_id" IS NOT NULL) AND ("user_id" = "auth"."uid"())) OR (("user_id" IS NULL) AND ("portal_user_email" IS NOT NULL) AND ("public"."current_auth_email"() IS NOT NULL) AND ("lower"(TRIM(BOTH FROM "portal_user_email")) = "public"."current_auth_email"())) OR (("organization_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."organization_id" = "CompanyPortalUsers"."organization_id") AND ("ou"."user_id" = "auth"."uid"()) AND ("ou"."deleted" = false) AND ("ou"."status" = ANY (ARRAY['active'::"public"."org_user_status", 'invited'::"public"."org_user_status"])))))))));



CREATE POLICY "companyportalusers_select_stable" ON "public"."CompanyPortalUsers" FOR SELECT USING ((("deleted" = false) AND "public"."can_read_company_portal_user"("id")));



COMMENT ON POLICY "companyportalusers_select_stable" ON "public"."CompanyPortalUsers" IS 'Read portal users if self or internal org member.';



CREATE POLICY "companyportalusers_update_own_org" ON "public"."CompanyPortalUsers" FOR UPDATE USING ("public"."is_company_owner_or_admin"("company_id"));



CREATE POLICY "companyportalusers_update_self" ON "public"."CompanyPortalUsers" FOR UPDATE USING ("public"."is_portal_user_self"("id")) WITH CHECK ("public"."is_portal_user_self"("id"));



COMMENT ON POLICY "companyportalusers_update_self" ON "public"."CompanyPortalUsers" IS 'Portal user can update only their own record (e.g. link user_id).';



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



CREATE POLICY "dircontacts_select_correct" ON "public"."DirectoryContacts" FOR SELECT USING ((("deleted" = false) AND ((("organization_id" IS NOT NULL) AND "public"."is_org_user_superadmin"("organization_id")) OR (("company_id" IS NOT NULL) AND "public"."is_company_portal_user"("company_id")) OR (("organization_id" IS NOT NULL) AND "public"."is_org_user_member"("organization_id")))));



CREATE POLICY "dircontacts_write_correct" ON "public"."DirectoryContacts" USING ((((("organization_id" IS NOT NULL) AND "public"."is_org_user_superadmin"("organization_id")) OR (("company_id" IS NOT NULL) AND "public"."is_company_portal_user"("company_id")) OR (("organization_id" IS NOT NULL) AND "public"."is_org_user_member"("organization_id"))) AND ("deleted" = false))) WITH CHECK (((("organization_id" IS NOT NULL) AND "public"."is_org_user_superadmin"("organization_id")) OR (("company_id" IS NOT NULL) AND "public"."is_company_portal_user"("company_id")) OR (("organization_id" IS NOT NULL) AND "public"."is_org_user_member"("organization_id"))));



CREATE POLICY "dircustomers_select_correct" ON "public"."DirectoryCustomers" FOR SELECT USING ((("deleted" = false) AND ((("organization_id" IS NOT NULL) AND "public"."is_org_user_superadmin"("organization_id")) OR (("company_id" IS NOT NULL) AND "public"."is_company_portal_user"("company_id")) OR (("organization_id" IS NOT NULL) AND "public"."is_org_user_member"("organization_id")))));



CREATE POLICY "dircustomers_write_correct" ON "public"."DirectoryCustomers" USING ((((("organization_id" IS NOT NULL) AND "public"."is_org_user_superadmin"("organization_id")) OR (("company_id" IS NOT NULL) AND "public"."is_company_portal_user"("company_id")) OR (("organization_id" IS NOT NULL) AND "public"."is_org_user_member"("organization_id"))) AND ("deleted" = false))) WITH CHECK (((("organization_id" IS NOT NULL) AND "public"."is_org_user_superadmin"("organization_id")) OR (("company_id" IS NOT NULL) AND "public"."is_company_portal_user"("company_id")) OR (("organization_id" IS NOT NULL) AND "public"."is_org_user_member"("organization_id"))));



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



CREATE POLICY "org_member_select" ON "public"."Organizations" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."organization_id" = "OrganizationUsers"."id") AND ("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."deleted" = false) AND ("OrganizationUsers"."status" = 'active'::"public"."org_user_status")))));



CREATE POLICY "organizations_select_portal_users" ON "public"."Organizations" FOR SELECT USING ((("deleted" = false) AND (EXISTS ( SELECT 1
   FROM "public"."CompanyPortalUsers" "cpu"
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



CREATE POLICY "portal_select_contacts" ON "public"."DirectoryContacts" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."CompanyPortalUsers" "cpu"
  WHERE (("cpu"."company_id" = "DirectoryContacts"."company_id") AND ("cpu"."user_id" = "auth"."uid"()) AND ("cpu"."deleted" = false) AND ("cpu"."status" = 'active'::"public"."portal_user_status")))));



CREATE POLICY "portal_select_customers" ON "public"."DirectoryCustomers" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."CompanyPortalUsers" "cpu"
  WHERE (("cpu"."user_id" = "auth"."uid"()) AND ("cpu"."company_id" = "DirectoryCustomers"."company_id") AND ("cpu"."deleted" = false) AND ("cpu"."status" = 'active'::"public"."portal_user_status")))));



CREATE POLICY "portal_users_write_owner_admin" ON "public"."CompanyPortalUsers" USING ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status") AND ("ou"."role" = ANY (ARRAY['owner'::"public"."org_role", 'admin'::"public"."org_role"]))))));



CREATE POLICY "quotes_access" ON "public"."Quotes" USING (("organization_id" IN ( SELECT "OrganizationUsers"."organization_id"
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."deleted" = false) AND ("OrganizationUsers"."status" = 'active'::"public"."org_user_status"))))) WITH CHECK (true);



CREATE POLICY "quotes_portal_insert" ON "public"."Quotes" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."get_current_portal_user"() "p"("id", "organization_id", "company_id", "portal_user_role", "status")
  WHERE (("p"."company_id" = "Quotes"."company_id") AND ("p"."portal_user_role" = ANY (ARRAY['member'::"text", 'member_manager'::"text"])) AND ("Quotes"."created_by_portal_user_id" = "p"."id")))));



CREATE POLICY "quotes_portal_select" ON "public"."Quotes" FOR SELECT USING ((("deleted" = false) AND (EXISTS ( SELECT 1
   FROM "public"."get_current_portal_user"() "p"("id", "organization_id", "company_id", "portal_user_role", "status")
  WHERE (("p"."company_id" = "Quotes"."company_id") AND (("p"."portal_user_role" = 'member_manager'::"text") OR (("p"."portal_user_role" = 'member'::"text") AND ("Quotes"."created_by_portal_user_id" = "p"."id"))))))));



CREATE POLICY "quotes_portal_update" ON "public"."Quotes" FOR UPDATE USING ((("deleted" = false) AND (EXISTS ( SELECT 1
   FROM "public"."get_current_portal_user"() "p"("id", "organization_id", "company_id", "portal_user_role", "status")
  WHERE (("p"."company_id" = "Quotes"."company_id") AND (("p"."portal_user_role" = 'member_manager'::"text") OR (("p"."portal_user_role" = 'member'::"text") AND ("Quotes"."created_by_portal_user_id" = "p"."id") AND ("Quotes"."status" = 'draft'::"public"."quote_status")))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."get_current_portal_user"() "p"("id", "organization_id", "company_id", "portal_user_role", "status")
  WHERE (("p"."company_id" = "Quotes"."company_id") AND (("p"."portal_user_role" = 'member_manager'::"text") OR (("p"."portal_user_role" = 'member'::"text") AND ("Quotes"."created_by_portal_user_id" = "p"."id") AND ("Quotes"."status" = 'draft'::"public"."quote_status")))))));



CREATE POLICY "quotes_select" ON "public"."Quotes" FOR SELECT USING ((("deleted" = false) AND (EXISTS ( SELECT 1
   FROM "public"."OrganizationUsers" "ou"
  WHERE (("ou"."user_id" = "auth"."uid"()) AND ("ou"."organization_id" = "ou"."organization_id") AND ("ou"."deleted" = false) AND ("ou"."status" = 'active'::"public"."org_user_status"))))));



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



CREATE POLICY "so_access" ON "public"."SalesOrders" USING (("organization_id" IN ( SELECT "OrganizationUsers"."organization_id"
   FROM "public"."OrganizationUsers"
  WHERE (("OrganizationUsers"."user_id" = "auth"."uid"()) AND ("OrganizationUsers"."deleted" = false) AND ("OrganizationUsers"."status" = 'active'::"public"."org_user_status"))))) WITH CHECK (true);





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


REVOKE USAGE ON SCHEMA "public" FROM PUBLIC;
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT ALL ON SCHEMA "public" TO "service_role";

























































































































































REVOKE ALL ON FUNCTION "public"."approve_quote"("p_quote_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."approve_quote"("p_quote_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."approve_quote"("p_quote_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."approve_quote"("p_quote_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."approve_quote_portal"("p_quote_id" "uuid", "p_action" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_configured_product_totals"("p_configured_product_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_read_company_portal_user"("p_portal_row_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_read_company_portal_user"("p_portal_row_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_read_company_portal_user"("p_portal_row_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."catalogitems_set_to_base_factor"() TO "anon";
GRANT ALL ON FUNCTION "public"."catalogitems_set_to_base_factor"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."catalogitems_set_to_base_factor"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."clear_my_must_change_password"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."clear_my_must_change_password"() TO "anon";
GRANT ALL ON FUNCTION "public"."clear_my_must_change_password"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."clear_my_must_change_password"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_bom_instance_for_configured_product"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_bom_instance_for_configured_product"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_bom_instance_for_configured_product"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_configured_product_id" "uuid", "p_product_type_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_configured_product_and_bom_preview"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb", "p_quote_id" "uuid", "p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."current_auth_email"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_auth_email"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_auth_email"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_company_portal_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_company_portal_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_company_portal_user"("p_portal_user_id" "uuid", "p_organization_id" "uuid") TO "service_role";



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



GRANT ALL ON FUNCTION "public"."enforce_mo_company_matches_salesorder"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_mo_company_matches_salesorder"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_mo_company_matches_salesorder"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_orderlist_company_matches_salesorder"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_orderlist_company_matches_salesorder"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_orderlist_company_matches_salesorder"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_salesorders_company_matches_quote"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_salesorders_company_matches_quote"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_salesorders_company_matches_quote"() TO "service_role";



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



GRANT ALL ON FUNCTION "public"."generate_bom_instance_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_bom_instance_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_bom_instance_for_quote_line"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_product_type_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_bom_instance_for_quote_line_v1"("p_org_id" "uuid", "p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_bom_instance_for_quote_line_v1"("p_org_id" "uuid", "p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_bom_instance_for_quote_line_v1"("p_org_id" "uuid", "p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_auth_context"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_auth_context"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_auth_context"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_category_id_by_path"("p_org" "uuid", "p_path" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_category_id_by_path"("p_org" "uuid", "p_path" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_category_id_by_path"("p_org" "uuid", "p_path" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_category_margins_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", OUT "msrp_pct_sale_in" numeric, OUT "msrp_pct_sale_out" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."get_category_margins_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", OUT "msrp_pct_sale_in" numeric, OUT "msrp_pct_sale_out" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_category_margins_for_category"("p_organization_id" "uuid", "p_category_id" "uuid", OUT "msrp_pct_sale_in" numeric, OUT "msrp_pct_sale_out" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_current_portal_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_current_portal_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_current_portal_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_current_portal_user_company_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_current_portal_user_company_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_current_portal_user_company_id"() TO "service_role";



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



GRANT ALL ON FUNCTION "public"."handle_auth_user_created_for_org_users"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created_for_org_users"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created_for_org_users"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_auth_user_created_for_portal_users"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created_for_portal_users"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created_for_portal_users"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_quote_approved"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_quote_approved"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_quote_approved"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_company_member"("p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_company_member"("p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_company_member"("p_company_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_company_owner_or_admin"("p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_company_owner_or_admin"("p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_company_owner_or_admin"("p_company_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_company_portal_user"("p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_company_portal_user"("p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_company_portal_user"("p_company_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_company_portal_user_with_write"("p_company_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_company_portal_user_with_write"("p_company_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_company_portal_user_with_write"("p_company_id" "uuid") TO "service_role";



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



GRANT ALL ON FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_portal_user_self"("p_portal_row_id" "uuid") TO "service_role";



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



GRANT ALL ON FUNCTION "public"."msrp_compute_for_item"("item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."msrp_compute_for_item"("item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."msrp_compute_for_item"("item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."msrp_recompute_for_category"("p_category_id" "uuid", "p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."msrp_recompute_for_category"("p_category_id" "uuid", "p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."msrp_recompute_for_category"("p_category_id" "uuid", "p_organization_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."next_company_no"("p_org_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."next_company_no"("p_org_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."next_company_no"("p_org_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."on_quote_approved_create_sales_order"() TO "anon";
GRANT ALL ON FUNCTION "public"."on_quote_approved_create_sales_order"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."on_quote_approved_create_sales_order"() TO "service_role";



GRANT ALL ON FUNCTION "public"."on_sales_order_status_mirror"() TO "anon";
GRANT ALL ON FUNCTION "public"."on_sales_order_status_mirror"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."on_sales_order_status_mirror"() TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_catalog_item_for_bom_component"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_component_role" "text", "p_component_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_catalog_item_for_bom_component"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_component_role" "text", "p_component_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_catalog_item_for_bom_component"("p_org_id" "uuid", "p_quote_line_id" "uuid", "p_component_role" "text", "p_component_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."resolve_component_item_id"("p_org_id" "uuid", "p_component_role" "text", "p_sku_rule" "text", "p_quote_line_id" "uuid", "p_config" "jsonb", "p_fixed_component_item_id" "uuid", "p_override_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_component_item_id"("p_org_id" "uuid", "p_component_role" "text", "p_sku_rule" "text", "p_quote_line_id" "uuid", "p_config" "jsonb", "p_fixed_component_item_id" "uuid", "p_override_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_component_item_id"("p_org_id" "uuid", "p_component_role" "text", "p_sku_rule" "text", "p_quote_line_id" "uuid", "p_config" "jsonb", "p_fixed_component_item_id" "uuid", "p_override_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."select_best_bom_template"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."select_best_bom_template"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_best_bom_template"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_configured_product"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_configured_product"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_configured_product"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_config_snapshot" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_quote_line"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_quote_line"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_for_quote_line"("p_org_id" "uuid", "p_product_type_id" "uuid", "p_quote_line_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."select_best_bom_template_v2"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_v2"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_v2"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."select_best_bom_template_v2_strict"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_v2_strict"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."select_best_bom_template_v2_strict"("p_org" "uuid", "p_product_type" "uuid", "p_config" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_company_no"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_company_no"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_company_no"() TO "service_role";



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



GRANT ALL ON FUNCTION "public"."sync_order_list_tracking_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_order_list_tracking_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_order_list_tracking_status"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_set_company_id_from_portal_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_set_company_id_from_portal_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_set_company_id_from_portal_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_companies_set_company_no"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_companies_set_company_no"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_companies_set_company_no"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trig_catmargins_msrp"() TO "anon";
GRANT ALL ON FUNCTION "public"."trig_catmargins_msrp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trig_catmargins_msrp"() TO "service_role";



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



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_organization_user"("p_organization_id" "uuid", "p_user_email" "text", "p_role" "public"."org_role", "p_status" "public"."org_user_status", "p_user_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_organization_user"("p_organization_id" "uuid", "p_user_email" "text", "p_role" "public"."org_role", "p_status" "public"."org_user_status", "p_user_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_organization_user"("p_organization_id" "uuid", "p_user_email" "text", "p_role" "public"."org_role", "p_status" "public"."org_user_status", "p_user_name" "text") TO "service_role";


















GRANT SELECT ON TABLE "public"."BOMComponents" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."BOMComponents" TO "authenticated";
GRANT ALL ON TABLE "public"."BOMComponents" TO "service_role";



GRANT SELECT ON TABLE "public"."BOMInstanceLines" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."BOMInstanceLines" TO "authenticated";
GRANT ALL ON TABLE "public"."BOMInstanceLines" TO "service_role";



GRANT SELECT ON TABLE "public"."BOMInstances" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."BOMInstances" TO "authenticated";
GRANT ALL ON TABLE "public"."BOMInstances" TO "service_role";



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



GRANT SELECT ON TABLE "public"."CatalogItemProductTypes" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogItemProductTypes" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogItemProductTypes" TO "service_role";



GRANT SELECT ON TABLE "public"."CatalogItemRoles" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CatalogItemRoles" TO "authenticated";
GRANT ALL ON TABLE "public"."CatalogItemRoles" TO "service_role";



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



GRANT SELECT ON TABLE "public"."Companies" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."Companies" TO "authenticated";
GRANT ALL ON TABLE "public"."Companies" TO "service_role";



GRANT SELECT ON TABLE "public"."CompanyPortalUsers" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CompanyPortalUsers" TO "authenticated";
GRANT ALL ON TABLE "public"."CompanyPortalUsers" TO "service_role";



GRANT SELECT ON TABLE "public"."ConfiguredProducts" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."ConfiguredProducts" TO "authenticated";
GRANT ALL ON TABLE "public"."ConfiguredProducts" TO "service_role";



GRANT SELECT ON TABLE "public"."CostSettings" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."CostSettings" TO "authenticated";
GRANT ALL ON TABLE "public"."CostSettings" TO "service_role";



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




























