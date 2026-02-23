-- ============================================================================
-- CatalogItemsMSRP: deduplicación + UNIQUE(organization_id, catalog_item_id)
-- Fecha: 2026-03-10
--
-- Problema:
-- Pueden existir múltiples filas por (organization_id, catalog_item_id).
-- Sin ORDER BY updated_at, se lee fila incorrecta (ej. msrp=0).
--
-- Solución:
-- 1) Detectar duplicados
-- 2) Borrar duplicados dejando el más reciente por updated_at
-- 3) Crear UNIQUE (organization_id, catalog_item_id)
-- ============================================================================

-- 1) Query para detectar duplicados (ejecutar antes para diagnóstico)
-- SELECT organization_id, catalog_item_id, COUNT(*) AS cnt
-- FROM public."CatalogItemsMSRP"
-- GROUP BY organization_id, catalog_item_id
-- HAVING COUNT(*) > 1;

-- 2) Borrar duplicados, conservando la fila más reciente por updated_at
WITH ranked AS (
  SELECT ctid,
         ROW_NUMBER() OVER (
           PARTITION BY organization_id, catalog_item_id
           ORDER BY updated_at DESC NULLS LAST, ctid
         ) AS rn
  FROM public."CatalogItemsMSRP"
)
DELETE FROM public."CatalogItemsMSRP"
WHERE ctid IN (SELECT ctid FROM ranked WHERE rn > 1);

-- 3) Crear UNIQUE constraint (o índice único si no existe)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'catalogitemsmsrp_org_catalog_item_unique'
      AND conrelid = 'public."CatalogItemsMSRP"'::regclass
  ) THEN
    ALTER TABLE public."CatalogItemsMSRP"
      ADD CONSTRAINT catalogitemsmsrp_org_catalog_item_unique
      UNIQUE (organization_id, catalog_item_id);
    RAISE NOTICE '✅ UNIQUE(organization_id, catalog_item_id) creado';
  ELSE
    RAISE NOTICE 'ℹ️ Constraint catalogitemsmsrp_org_catalog_item_unique ya existe';
  END IF;
END $$;
