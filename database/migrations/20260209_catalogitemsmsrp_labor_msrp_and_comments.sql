-- CatalogItemsMSRP: añadir labor_msrp y comentarios de auditoría
-- Regla: msrp = MSRP base (landed sin mano de obra); labor_msrp = parte labor; unit_msrp_total = msrp + labor_msrp.
-- total_cost = landed sin labor (BOM + Roll + Shipping + ImportTax). Labor se aplica a nivel ConfiguredProduct/QuoteLine.

-- 1. Añadir columna labor_msrp (a nivel ítem de catálogo suele ser 0)
ALTER TABLE public."CatalogItemsMSRP"
  ADD COLUMN IF NOT EXISTS labor_msrp numeric(12,4) NULL DEFAULT 0;

-- 2. Comentarios de columnas para auditoría
COMMENT ON COLUMN public."CatalogItemsMSRP".msrp IS
  'MSRP base por unidad: landed sin mano de obra (BOM + Roll + Shipping + ImportTax). unit_msrp_total = msrp + labor_msrp.';
COMMENT ON COLUMN public."CatalogItemsMSRP".total_cost IS
  'Costo landed por unidad sin mano de obra (material + shipping + import_tax).';
COMMENT ON COLUMN public."CatalogItemsMSRP".labor_msrp IS
  'Parte MSRP correspondiente a mano de obra por unidad. A nivel catálogo suele ser 0; labor se aplica en ConfiguredProduct/QuoteLine. unit_msrp_total = msrp + labor_msrp.';
