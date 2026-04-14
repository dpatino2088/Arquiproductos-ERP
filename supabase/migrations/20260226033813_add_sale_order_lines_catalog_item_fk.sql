-- Allow PostgREST to resolve embed: CatalogItems:catalog_item_id (name, sku)
-- Only add if column exists and FK does not exist.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'SaleOrderLines' AND column_name = 'catalog_item_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
    WHERE tc.table_schema = 'public' AND tc.table_name = 'SaleOrderLines'
      AND tc.constraint_type = 'FOREIGN KEY' AND kcu.column_name = 'catalog_item_id'
  ) THEN
    ALTER TABLE public."SaleOrderLines"
    ADD CONSTRAINT saleorderlines_catalog_item_id_fkey
    FOREIGN KEY (catalog_item_id) REFERENCES public."CatalogItems"(id) ON DELETE SET NULL;
    RAISE NOTICE 'Added FK SaleOrderLines.catalog_item_id -> CatalogItems(id)';
  ELSE
    RAISE NOTICE 'FK already exists or catalog_item_id column missing, skipping';
  END IF;
END $$;;
