-- Renombrar columnas MSRP: quitar "Sale Out" (redundante).
-- CostSettings: default_msrp_pct_sale_out → default_msrp_pct
-- CategoryMargins: msrp_pct_sale_out → msrp_pct
-- CatalogItemsMSRP: msrp_pct_sale_out → msrp_pct
-- Ejecutar después de 20260207_costsettings_drop_redundant_columns y 20260207_categorymargins_drop_msrp_pct_sale_in.

-- 1) Triggers que referencian las columnas
DROP TRIGGER IF EXISTS "trg_costsettings_recompute_itemsmsrp" ON "public"."CostSettings";
DROP TRIGGER IF EXISTS "trg_categorymargins_recompute_itemsmsrp" ON "public"."CategoryMargins";
DROP TRIGGER IF EXISTS "trig_catmargins_msrp" ON "public"."CategoryMargins";

-- 2) Renombrar columnas (idempotente: solo si existe la columna antigua)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'CostSettings' AND column_name = 'default_msrp_pct_sale_out') THEN
    ALTER TABLE "public"."CostSettings" RENAME COLUMN "default_msrp_pct_sale_out" TO "default_msrp_pct";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'CategoryMargins' AND column_name = 'msrp_pct_sale_out') THEN
    ALTER TABLE "public"."CategoryMargins" RENAME COLUMN "msrp_pct_sale_out" TO "msrp_pct";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'CatalogItemsMSRP' AND column_name = 'msrp_pct_sale_out') THEN
    ALTER TABLE "public"."CatalogItemsMSRP" RENAME COLUMN "msrp_pct_sale_out" TO "msrp_pct";
  END IF;
END $$;

-- 3) get_category_margins_for_category: leer cm.msrp_pct (OUT sigue siendo msrp_pct_sale_out por compat)
CREATE OR REPLACE FUNCTION "public"."get_category_margins_for_category"(
  "p_organization_id" uuid,
  "p_category_id" uuid,
  OUT "msrp_pct_sale_in" numeric,
  OUT "msrp_pct_sale_out" numeric
) RETURNS record
  LANGUAGE plpgsql STABLE
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

-- 4) msrp_get_effective_rates: cambiar tipo de retorno (msrp_pct_sale_out → msrp_pct) requiere DROP
DROP FUNCTION IF EXISTS "public"."msrp_get_effective_rates"(uuid, uuid);

CREATE OR REPLACE FUNCTION "public"."msrp_get_effective_rates"(
  "p_org_id" uuid,
  "p_category_id" uuid
) RETURNS TABLE(
  "shipping_pct" numeric,
  "import_tax_pct" numeric,
  "minimum_margin_pct" numeric,
  "msrp_pct_sale_in" numeric,
  "msrp_pct" numeric
)
  LANGUAGE sql STABLE
  AS $$
  WITH cs AS (
    SELECT
      COALESCE(shipping_pct, 0)::numeric AS shipping_pct,
      COALESCE(global_import_tax_pct, 0)::numeric AS global_import_tax_pct,
      COALESCE(minimum_margin_pct, 0)::numeric AS minimum_margin_pct,
      COALESCE(default_msrp_pct, 0)::numeric AS default_msrp_pct
    FROM public."CostSettings" WHERE organization_id = p_org_id LIMIT 1
  ),
  cm AS (
    SELECT minimum_margin_pct::numeric AS msrp_pct_sale_in, msrp_pct::numeric AS msrp_pct
    FROM public."CategoryMargins"
    WHERE organization_id = p_org_id AND category_id = p_category_id AND is_active = true LIMIT 1
  ),
  it AS (
    SELECT import_tax_pct::numeric AS import_tax_pct
    FROM public."ImportTaxRules"
    WHERE organization_id = p_org_id AND category_id = p_category_id AND is_active = true LIMIT 1
  )
  SELECT
    COALESCE((SELECT shipping_pct FROM cs), 0),
    COALESCE((SELECT import_tax_pct FROM it), (SELECT global_import_tax_pct FROM cs), 0),
    COALESCE((SELECT minimum_margin_pct FROM cs), 0),
    COALESCE((SELECT msrp_pct_sale_in FROM cm), (1 - COALESCE((SELECT msrp_pct FROM cm), (SELECT default_msrp_pct FROM cs), 0))) AS msrp_pct_sale_in,
    COALESCE((SELECT msrp_pct FROM cm), (SELECT default_msrp_pct FROM cs), 0) AS msrp_pct
$$;

-- 5) msrp_compute_for_item: leer r.msrp_pct y escribir CatalogItemsMSRP.msrp_pct
CREATE OR REPLACE FUNCTION "public"."msrp_compute_for_item"("p_item_id" uuid) RETURNS void
  LANGUAGE plpgsql
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

-- 6) trig_enforce_msrp_sources: asignar NEW.msrp_pct desde r.msrp_pct
CREATE OR REPLACE FUNCTION "public"."trig_enforce_msrp_sources"() RETURNS trigger
  LANGUAGE plpgsql
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

-- 7) trig_catmargins_msrp: comparar OLD.msrp_pct = NEW.msrp_pct
CREATE OR REPLACE FUNCTION "public"."trig_catmargins_msrp"() RETURNS trigger
  LANGUAGE plpgsql
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

-- 8) recompute_catalog_item_msrp: usar default_msrp_pct, cm.msrp_pct, CatalogItemsMSRP.msrp_pct
CREATE OR REPLACE FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" uuid, "p_catalog_item_id" uuid) RETURNS void
  LANGUAGE plpgsql
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

-- 9) recompute_catalogitems_msrp_for_org: usar default_msrp_pct, cm.msrp_pct, msrp_pct en INSERT/UPDATE
CREATE OR REPLACE FUNCTION "public"."recompute_catalogitems_msrp_for_org"("p_org" uuid) RETURNS void
  LANGUAGE plpgsql
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

-- 9b) recompute_catalogitems_msrp_for_category: usada por el trigger al cambiar CategoryMargins; debe usar msrp_pct
CREATE OR REPLACE FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" uuid, "p_category_id" uuid) RETURNS void
  LANGUAGE sql
  AS $$
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
  WHERE ci.organization_id = p_org_id AND ci.category_id = p_category_id AND ci.is_active = true
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    cost_exw = EXCLUDED.cost_exw, shipping_pct = EXCLUDED.shipping_pct, import_tax_pct = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct, msrp_pct = EXCLUDED.msrp_pct,
    shipping_cost = EXCLUDED.shipping_cost, import_tax_cost = EXCLUDED.import_tax_cost,
    total_cost = EXCLUDED.total_cost, dealer_price = EXCLUDED.dealer_price, msrp = EXCLUDED.msrp, updated_at = now();
$$;

-- 10) Recrear triggers
CREATE TRIGGER "trg_costsettings_recompute_itemsmsrp"
  AFTER UPDATE OF "shipping_pct", "global_import_tax_pct", "minimum_margin_pct", "default_msrp_pct"
  ON "public"."CostSettings" FOR EACH ROW EXECUTE FUNCTION "public"."_trg_costsettings_recompute_itemsmsrp"();

CREATE TRIGGER "trg_categorymargins_recompute_itemsmsrp"
  AFTER INSERT OR UPDATE OF "minimum_margin_pct", "msrp_pct", "is_active"
  ON "public"."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION "public"."_trg_categorymargins_recompute_itemsmsrp"();

CREATE TRIGGER "trig_catmargins_msrp"
  AFTER INSERT OR UPDATE OF "minimum_margin_pct", "msrp_pct"
  ON "public"."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION "public"."trig_catmargins_msrp"();

COMMENT ON FUNCTION "public"."recompute_catalog_item_msrp"(uuid, uuid) IS 'Recompute CatalogItemsMSRP. CostSettings: minimum_margin_pct, default_msrp_pct.';
COMMENT ON FUNCTION "public"."recompute_catalogitems_msrp_for_category"(uuid, uuid) IS 'Recompute CatalogItemsMSRP for a category (trigger on CategoryMargins). Uses msrp_pct.';
COMMENT ON FUNCTION "public"."recompute_catalogitems_msrp_for_org"(uuid) IS 'Recompute CatalogItemsMSRP for org. CostSettings: minimum_margin_pct, default_msrp_pct.';
