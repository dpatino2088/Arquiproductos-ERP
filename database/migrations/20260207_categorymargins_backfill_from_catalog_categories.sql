-- Asegurar que CategoryMargins tenga una fila por cada categoría de CatalogCategories (por organización).
-- La UI muestra todas las categorías (CatalogCategories) pero solo había filas en CategoryMargins cuando
-- el usuario guardaba un margen; así faltaban categorías. Con este backfill, cada categoría tiene su fila
-- con valores por defecto de CostSettings; el usuario puede editarlos después.

-- 1) Backfill: insertar (organization_id, category_id) para cada categoría de CatalogCategories
--    que no tenga ya fila en CategoryMargins, usando defaults de CostSettings.
INSERT INTO public."CategoryMargins" (
  organization_id,
  category_id,
  minimum_margin_pct,
  msrp_pct,
  is_active,
  created_at,
  updated_at
)
SELECT
  cc.organization_id,
  cc.id AS category_id,
  COALESCE(cs.minimum_margin_pct, 0.35),
  COALESCE(cs.default_msrp_pct, 0.65),
  true,
  now(),
  now()
FROM public."CatalogCategories" cc
INNER JOIN public."CostSettings" cs ON cs.organization_id = cc.organization_id
WHERE NOT EXISTS (
  SELECT 1 FROM public."CategoryMargins" cm
  WHERE cm.organization_id = cc.organization_id AND cm.category_id = cc.id
)
ON CONFLICT (organization_id, category_id) DO NOTHING;

-- 2) Trigger: al insertar una nueva categoría en CatalogCategories, crear fila en CategoryMargins
--    con defaults de CostSettings para esa organización.
CREATE OR REPLACE FUNCTION "public"."trg_catalogcategories_insert_category_margin"() RETURNS trigger
  LANGUAGE plpgsql
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

DROP TRIGGER IF EXISTS "trg_catalogcategories_insert_category_margin" ON "public"."CatalogCategories";
CREATE TRIGGER "trg_catalogcategories_insert_category_margin"
  AFTER INSERT ON "public"."CatalogCategories"
  FOR EACH ROW
  EXECUTE FUNCTION "public"."trg_catalogcategories_insert_category_margin"();

COMMENT ON FUNCTION "public"."trg_catalogcategories_insert_category_margin"() IS 'Crea fila en CategoryMargins con defaults de CostSettings cuando se inserta una categoría en CatalogCategories.';
