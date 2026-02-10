-- CatalogItemsMSRP debe ser espejo de CategoryMargins según CatalogCategories:
--   minimum_margin_pct y msrp_pct en CatalogItemsMSRP = márgenes efectivos de CategoryMargins
--   resueltos por la jerarquía (categoría + ancestros en CatalogCategories). CostSettings es fallback.
--
-- Cambios:
-- 1) msrp_get_effective_rates: resuelve CategoryMargins por jerarquía (como get_category_margins_for_category).
-- 2) recompute_catalogitems_msrp_for_category: incluye ítems de la categoría y de todas las subcategorías.
-- 3) Trigger en CatalogItemsMSRP: antes de INSERT/UPDATE, fuerza minimum_margin_pct y msrp_pct desde msrp_get_effective_rates (espejo).

-- 1) msrp_get_effective_rates: resolver CategoryMargins por jerarquía (categoría + ancestros)
CREATE OR REPLACE FUNCTION "public"."msrp_get_effective_rates"("p_org_id" uuid, "p_category_id" uuid)
  RETURNS TABLE("shipping_pct" numeric, "import_tax_pct" numeric, "minimum_margin_pct" numeric, "msrp_pct_sale_in" numeric, "msrp_pct" numeric)
  LANGUAGE sql STABLE
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

-- 2) recompute_catalogitems_msrp_for_category: incluir ítems de la categoría Y de todas las subcategorías
CREATE OR REPLACE FUNCTION "public"."recompute_catalogitems_msrp_for_category"("p_org_id" uuid, "p_category_id" uuid) RETURNS void
  LANGUAGE sql
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

COMMENT ON FUNCTION "public"."msrp_get_effective_rates"(uuid, uuid) IS 'Rates for MSRP: CostSettings + CategoryMargins (resolved by category hierarchy) + ImportTaxRules.';
COMMENT ON FUNCTION "public"."recompute_catalogitems_msrp_for_category"(uuid, uuid) IS 'Recompute CatalogItemsMSRP for a category and all its descendant categories (trigger on CategoryMargins). Uses msrp_pct.';

-- 3) Espejo: trigger en CatalogItemsMSRP para que minimum_margin_pct y msrp_pct vengan siempre de CategoryMargins (jerarquía)
-- La función trig_enforce_msrp_sources ya existe (migración rename_msrp_sale_out_to_msrp_pct); asigna NEW desde msrp_get_effective_rates.
DROP TRIGGER IF EXISTS "trg_catalogitemsmsrp_enforce_rates" ON "public"."CatalogItemsMSRP";
CREATE TRIGGER "trg_catalogitemsmsrp_enforce_rates"
  BEFORE INSERT OR UPDATE
  ON "public"."CatalogItemsMSRP"
  FOR EACH ROW
  EXECUTE FUNCTION "public"."trig_enforce_msrp_sources"();

-- Opcional: si los cambios aún no se reflejan, ejecutar para forzar recompute de todas las categorías con margen:
-- DO $$
-- DECLARE r record;
-- BEGIN
--   FOR r IN SELECT organization_id, category_id FROM public."CategoryMargins" WHERE is_active = true
--   LOOP
--     PERFORM public.recompute_catalogitems_msrp_for_category(r.organization_id, r.category_id);
--   END LOOP;
-- END $$;
