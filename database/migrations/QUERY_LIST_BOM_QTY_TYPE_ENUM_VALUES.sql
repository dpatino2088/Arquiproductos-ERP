-- ====================================================
-- Query: Listar Valores Válidos del Enum bom_qty_type
-- ====================================================
-- Helper para verificar qué valores son válidos en el enum
-- ====================================================

SELECT 
  unnest(enum_range(NULL::bom_qty_type)) AS bom_qty_type_value
ORDER BY bom_qty_type_value;

-- ====================================================
-- Optional: Check if uom is an enum (if it exists)
-- ====================================================
-- Uncomment if uom is an enum type:
-- SELECT 
--   unnest(enum_range(NULL::uom_code)) AS bom_uom_value
-- ORDER BY bom_uom_value;

-- ====================================================
-- Optional: Check if sku_resolution_rule is an enum (if it exists)
-- ====================================================
-- Note: sku_resolution_rule is currently TEXT, not an enum
-- If it becomes an enum in the future, uncomment:
-- SELECT 
--   unnest(enum_range(NULL::sku_resolution_rule)) AS sku_resolution_rule_value
-- ORDER BY sku_resolution_rule_value;

