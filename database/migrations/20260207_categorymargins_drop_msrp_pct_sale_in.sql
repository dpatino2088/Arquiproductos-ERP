-- CategoryMargins: eliminar redundancia msrp_pct_sale_in / minimum_margin_pct
-- En el dump, minimum_margin_pct es GENERATED ALWAYS AS (msrp_pct_sale_in) STORED.
-- Se mantiene solo minimum_margin_pct como columna real; se elimina msrp_pct_sale_in.

-- 1) Quitar triggers que dependen de la columna a eliminar
DROP TRIGGER IF EXISTS "trg_categorymargins_recompute_itemsmsrp" ON "public"."CategoryMargins";
DROP TRIGGER IF EXISTS "trig_catmargins_msrp" ON "public"."CategoryMargins";

-- 2) Eliminar columna generada y renombrar la fuente a minimum_margin_pct
ALTER TABLE "public"."CategoryMargins" DROP COLUMN IF EXISTS "minimum_margin_pct";
ALTER TABLE "public"."CategoryMargins" RENAME COLUMN "msrp_pct_sale_in" TO "minimum_margin_pct";

-- 3) get_category_margins_for_category: leer minimum_margin_pct (OUT sigue siendo msrp_pct_sale_in para compatibilidad)
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

  IF p_category_id IS NULL THEN
    RETURN;
  END IF;

  v_current_category_id := p_category_id;

  WHILE v_current_category_id IS NOT NULL AND NOT v_found LOOP
    SELECT
      COALESCE(cm.minimum_margin_pct, 0.35),
      COALESCE(cm.msrp_pct_sale_out, 0.65)
    INTO msrp_pct_sale_in, msrp_pct_sale_out
    FROM public."CategoryMargins" cm
    WHERE cm.organization_id = p_organization_id
      AND cm.category_id = v_current_category_id
      AND COALESCE(cm.is_active, true) = true
    LIMIT 1;

    IF FOUND THEN
      v_found := true;
    ELSE
      SELECT parent_id INTO v_current_category_id
      FROM public."CatalogCategories"
      WHERE id = v_current_category_id;
    END IF;
  END LOOP;

  IF NOT v_found THEN
    msrp_pct_sale_in := 0.35;
    msrp_pct_sale_out := 0.65;
  END IF;
END;
$$;

COMMENT ON FUNCTION "public"."get_category_margins_for_category"(uuid, uuid, OUT numeric, OUT numeric) IS
  'Busca márgenes (minimum_margin_pct, msrp_pct_sale_out) para una categoría. OUT msrp_pct_sale_in = minimum_margin_pct.';

-- 4) msrp_get_effective_rates: CategoryMargins aporta minimum_margin_pct (alias msrp_pct_sale_in en salida)
CREATE OR REPLACE FUNCTION "public"."msrp_get_effective_rates"(
  "p_org_id" uuid,
  "p_category_id" uuid
) RETURNS TABLE(
  "shipping_pct" numeric,
  "import_tax_pct" numeric,
  "minimum_margin_pct" numeric,
  "msrp_pct_sale_in" numeric,
  "msrp_pct_sale_out" numeric
)
  LANGUAGE sql STABLE
  AS $$
  WITH cs AS (
    SELECT
      COALESCE(shipping_pct, 0)::numeric AS shipping_pct,
      COALESCE(global_import_tax_pct, 0)::numeric AS global_import_tax_pct,
      COALESCE(minimum_margin_pct, 0)::numeric AS minimum_margin_pct,
      COALESCE(default_msrp_pct_sale_out, 0)::numeric AS default_msrp_pct_sale_out
    FROM public."CostSettings"
    WHERE organization_id = p_org_id
    LIMIT 1
  ),
  cm AS (
    SELECT
      minimum_margin_pct::numeric AS msrp_pct_sale_in,
      msrp_pct_sale_out::numeric AS msrp_pct_sale_out
    FROM public."CategoryMargins"
    WHERE organization_id = p_org_id
      AND category_id = p_category_id
      AND is_active = true
    LIMIT 1
  ),
  it AS (
    SELECT import_tax_pct::numeric AS import_tax_pct
    FROM public."ImportTaxRules"
    WHERE organization_id = p_org_id
      AND category_id = p_category_id
      AND is_active = true
    LIMIT 1
  )
  SELECT
    COALESCE((SELECT shipping_pct FROM cs), 0) AS shipping_pct,
    COALESCE((SELECT import_tax_pct FROM it), (SELECT global_import_tax_pct FROM cs), 0) AS import_tax_pct,
    COALESCE((SELECT minimum_margin_pct FROM cs), 0) AS minimum_margin_pct,
    COALESCE((SELECT msrp_pct_sale_in FROM cm),
             (1 - COALESCE((SELECT msrp_pct_sale_out FROM cm),
                           (SELECT default_msrp_pct_sale_out FROM cs),
                           0)
             )
    ) AS msrp_pct_sale_in,
    COALESCE((SELECT msrp_pct_sale_out FROM cm),
             (SELECT default_msrp_pct_sale_out FROM cs),
             0
    ) AS msrp_pct_sale_out
$$;

-- 5) trig_catmargins_msrp: usar minimum_margin_pct en la comparación
CREATE OR REPLACE FUNCTION "public"."trig_catmargins_msrp"() RETURNS trigger
  LANGUAGE plpgsql
  AS $$
DECLARE
  v_item_id uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF (OLD.minimum_margin_pct = NEW.minimum_margin_pct)
       AND (OLD.msrp_pct_sale_out = NEW.msrp_pct_sale_out) THEN
      RETURN NEW;
    END IF;
  END IF;

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

-- 6) Recrear triggers
CREATE TRIGGER "trg_categorymargins_recompute_itemsmsrp"
  AFTER INSERT OR UPDATE OF "minimum_margin_pct", "msrp_pct_sale_out", "is_active"
  ON "public"."CategoryMargins"
  FOR EACH ROW EXECUTE FUNCTION "public"."_trg_categorymargins_recompute_itemsmsrp"();

CREATE TRIGGER "trig_catmargins_msrp"
  AFTER INSERT OR UPDATE OF "minimum_margin_pct", "msrp_pct_sale_out"
  ON "public"."CategoryMargins"
  FOR EACH ROW EXECUTE FUNCTION "public"."trig_catmargins_msrp"();
