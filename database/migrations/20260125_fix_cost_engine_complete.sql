-- ====================================================
-- MIGRATION: Corrección completa del CostEngine
-- Date: 2026-01-25
-- Description: 
--  1. Corrige fórmula de import_tax_cost: (cost_exw + shipping_cost) * import_tax_pct
--  2. Corrige fórmula de msrp_sale_out: total_cost / (1 - msrp_pct_sale_out)
--  3. Agrega soporte para jerarquía de categorías (parent_category_id)
--  4. Crea triggers para recalcular automáticamente
--  5. Crea función para recompute masivo por categoría
-- ====================================================

BEGIN;

-- ====================================================
-- 1. Función auxiliar: Buscar import_tax_pct con jerarquía de categorías
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."get_import_tax_pct_for_category"(
  p_organization_id uuid,
  p_category_id uuid,
  p_fallback_pct numeric DEFAULT 0
) RETURNS numeric
LANGUAGE plpgsql
STABLE
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

COMMENT ON FUNCTION "public"."get_import_tax_pct_for_category" IS 
'Busca import_tax_pct para una categoría, subiendo por la jerarquía (parent_category_id) hasta encontrar una regla activa. Si no encuentra, retorna el fallback.';

-- ====================================================
-- 2. Función auxiliar: Buscar márgenes con jerarquía de categorías
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."get_category_margins_for_category"(
  p_organization_id uuid,
  p_category_id uuid,
  OUT msrp_pct_sale_in numeric,
  OUT msrp_pct_sale_out numeric
)
LANGUAGE plpgsql
STABLE
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

COMMENT ON FUNCTION "public"."get_category_margins_for_category" IS 
'Busca márgenes (msrp_pct_sale_in, msrp_pct_sale_out) para una categoría, subiendo por la jerarquía hasta encontrar una regla activa. Si no encuentra, retorna defaults (35%, 65%).';

-- ====================================================
-- 3. Función principal: msrp_compute_for_item (CORREGIDA)
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."msrp_compute_for_item"("item_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_org_id uuid;
  v_cat_id uuid;
  v_cost numeric(12,4);
  
  v_ship_pct numeric(7,4);
  v_tax_pct numeric(7,4);
  v_sale_in_pct numeric(7,4);
  v_sale_out_pct numeric(7,4);
  
  v_tax_cost numeric(12,4);
  v_ship_cost numeric(12,4);
  v_total numeric(12,4);
  v_sale_in numeric(12,4);
  v_sale_out numeric(12,4);
BEGIN
  -- Get item
  SELECT organization_id, category_id, COALESCE(cost_exw, 0)
    INTO v_org_id, v_cat_id, v_cost
  FROM public."CatalogItems"
  WHERE id = item_id;

  IF v_org_id IS NULL THEN RETURN; END IF;

  -- Initialize with defaults
  v_ship_pct := 0;
  v_tax_pct := 0;
  v_sale_in_pct := 0.35;
  v_sale_out_pct := 0.65;

  -- ✅ Get shipping from CostSettings
  SELECT COALESCE(shipping_pct, 0)
    INTO v_ship_pct
  FROM public."CostSettings"
  WHERE organization_id = v_org_id;

  v_ship_pct := COALESCE(v_ship_pct, 0);

  -- ✅ Get import_tax_pct con jerarquía de categorías
  -- Primero obtener fallback global
  SELECT COALESCE(global_import_tax_pct, 0)
    INTO v_tax_pct
  FROM public."CostSettings"
  WHERE organization_id = v_org_id;

  v_tax_pct := COALESCE(v_tax_pct, 0);

  -- Buscar regla específica por categoría (con jerarquía)
  IF v_cat_id IS NOT NULL THEN
    v_tax_pct := public.get_import_tax_pct_for_category(v_org_id, v_cat_id, v_tax_pct);
  END IF;

  -- ✅ Get márgenes con jerarquía de categorías
  IF v_cat_id IS NOT NULL THEN
    SELECT msrp_pct_sale_in, msrp_pct_sale_out
      INTO v_sale_in_pct, v_sale_out_pct
    FROM public.get_category_margins_for_category(v_org_id, v_cat_id);
  END IF;

  -- Fallback a CostSettings si no se encontraron márgenes
  IF v_sale_in_pct IS NULL THEN
    SELECT COALESCE(minimum_margin_pct, 0.35)
      INTO v_sale_in_pct
    FROM public."CostSettings"
    WHERE organization_id = v_org_id;
  END IF;

  IF v_sale_out_pct IS NULL THEN
    SELECT COALESCE(default_msrp_pct_sale_out, 0.65)
      INTO v_sale_out_pct
    FROM public."CostSettings"
    WHERE organization_id = v_org_id;
  END IF;

  -- Final fallback
  v_sale_in_pct := COALESCE(v_sale_in_pct, 0.35);
  v_sale_out_pct := COALESCE(v_sale_out_pct, 0.65);

  -- ✅ CORRECCIÓN CRÍTICA: Calcular costs con fórmula correcta
  -- shipping_cost = cost_exw * shipping_pct
  v_ship_cost := COALESCE(v_cost, 0) * COALESCE(v_ship_pct, 0);
  
  -- ✅ CORRECCIÓN: import_tax_cost = (cost_exw + shipping_cost) * import_tax_pct
  -- (NO cost_exw * import_tax_pct)
  v_tax_cost := (COALESCE(v_cost, 0) + COALESCE(v_ship_cost, 0)) * COALESCE(v_tax_pct, 0);
  
  -- total_cost = cost_exw + shipping_cost + import_tax_cost
  v_total := COALESCE(v_cost, 0) + COALESCE(v_ship_cost, 0) + COALESCE(v_tax_cost, 0);

  -- Validate percentages before division
  IF (1 - COALESCE(v_sale_in_pct, 0.35)) <= 0 THEN 
    v_sale_in_pct := 0.35;
  END IF;
  
  IF (1 - COALESCE(v_sale_out_pct, 0.65)) <= 0 THEN 
    v_sale_out_pct := 0.65;
  END IF;

  -- ✅ Calcular MSRP Sale-In y Sale-Out
  -- Fórmula: Precio = Costo Total / (1 - Margen%)
  v_sale_in := v_total / (1 - v_sale_in_pct);
  v_sale_out := v_total / (1 - v_sale_out_pct);

  -- Ensure all calculated values are NOT NULL
  v_tax_cost := COALESCE(v_tax_cost, 0);
  v_ship_cost := COALESCE(v_ship_cost, 0);
  v_total := COALESCE(v_total, 0);
  v_sale_in := COALESCE(v_sale_in, 0);
  v_sale_out := COALESCE(v_sale_out, 0);

  -- Save to CatalogItemsMSRP
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id, cost_exw,
    import_tax_cost, shipping_cost, total_cost,
    msrp_sale_in, msrp_sale_out
  ) VALUES (
    item_id, v_org_id, v_cat_id, COALESCE(v_cost, 0),
    v_tax_cost, v_ship_cost, v_total,
    v_sale_in, v_sale_out
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    category_id = EXCLUDED.category_id,
    cost_exw = EXCLUDED.cost_exw,
    import_tax_cost = EXCLUDED.import_tax_cost,
    shipping_cost = EXCLUDED.shipping_cost,
    total_cost = EXCLUDED.total_cost,
    msrp_sale_in = EXCLUDED.msrp_sale_in,
    msrp_sale_out = EXCLUDED.msrp_sale_out;
END;
$$;

COMMENT ON FUNCTION "public"."msrp_compute_for_item"("item_id" "uuid") IS 
'Calcula MSRP para un CatalogItem con fórmulas corregidas:
- shipping_cost = cost_exw * shipping_pct
- import_tax_cost = (cost_exw + shipping_cost) * import_tax_pct  ✅ CORREGIDO
- total_cost = cost_exw + shipping_cost + import_tax_cost
- msrp_sale_in = total_cost / (1 - msrp_pct_sale_in)
- msrp_sale_out = total_cost / (1 - msrp_pct_sale_out)  ✅ CORREGIDO

Soporta jerarquía de categorías: busca reglas subiendo por parent_category_id.';

-- ====================================================
-- 4. Función para recompute masivo por categoría
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."msrp_recompute_for_category"(
  p_category_id uuid,
  p_organization_id uuid DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

COMMENT ON FUNCTION "public"."msrp_recompute_for_category" IS 
'Recalcula MSRP para todos los CatalogItems de una categoría. Útil cuando cambian ImportTaxRules o CategoryMargins.';

-- ====================================================
-- 5. Trigger: Recalcular cuando cambia CatalogItems
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"()
RETURNS trigger
LANGUAGE plpgsql
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

-- Eliminar trigger si existe y recrearlo
DROP TRIGGER IF EXISTS "trg_recompute_msrp_on_catalog_item_change" ON public."CatalogItems";

CREATE TRIGGER "trg_recompute_msrp_on_catalog_item_change"
  AFTER INSERT OR UPDATE OF cost_exw, category_id ON public."CatalogItems"
  FOR EACH ROW
  WHEN (NEW.cost_exw > 0 AND NEW.organization_id IS NOT NULL)
  EXECUTE FUNCTION "public"."trig_recompute_msrp_on_catalog_item_change"();

-- ====================================================
-- 6. Trigger: Recalcular cuando cambia ImportTaxRules
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."trig_recompute_msrp_on_import_tax_change"()
RETURNS trigger
LANGUAGE plpgsql
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

-- Eliminar trigger si existe y recrearlo
DROP TRIGGER IF EXISTS "trg_recompute_msrp_on_import_tax_change" ON public."ImportTaxRules";

CREATE TRIGGER "trg_recompute_msrp_on_import_tax_change"
  AFTER INSERT OR UPDATE OR DELETE ON public."ImportTaxRules"
  FOR EACH ROW
  EXECUTE FUNCTION "public"."trig_recompute_msrp_on_import_tax_change"();

-- ====================================================
-- 7. Trigger: Recalcular cuando cambia CategoryMargins
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."trig_recompute_msrp_on_category_margin_change"()
RETURNS trigger
LANGUAGE plpgsql
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

-- Eliminar trigger si existe y recrearlo
DROP TRIGGER IF EXISTS "trg_recompute_msrp_on_category_margin_change" ON public."CategoryMargins";

CREATE TRIGGER "trg_recompute_msrp_on_category_margin_change"
  AFTER INSERT OR UPDATE OR DELETE ON public."CategoryMargins"
  FOR EACH ROW
  EXECUTE FUNCTION "public"."trig_recompute_msrp_on_category_margin_change"();

-- ====================================================
-- 8. Trigger: Recalcular cuando cambia CostSettings.shipping_pct
-- ====================================================
CREATE OR REPLACE FUNCTION "public"."trig_recompute_msrp_on_cost_settings_change"()
RETURNS trigger
LANGUAGE plpgsql
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

-- Eliminar trigger si existe y recrearlo
DROP TRIGGER IF EXISTS "trg_recompute_msrp_on_cost_settings_change" ON public."CostSettings";

CREATE TRIGGER "trg_recompute_msrp_on_cost_settings_change"
  AFTER INSERT OR UPDATE OF shipping_pct, global_import_tax_pct ON public."CostSettings"
  FOR EACH ROW
  EXECUTE FUNCTION "public"."trig_recompute_msrp_on_cost_settings_change"();

COMMIT;
