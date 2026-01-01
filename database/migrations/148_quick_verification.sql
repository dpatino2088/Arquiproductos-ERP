-- ====================================================
-- Quick Verification Script
-- ====================================================
-- Shows what was created in migration 146
-- ====================================================

-- 1) Products
SELECT 
  'Products' as table_name,
  COUNT(*) as total_records,
  COUNT(*) FILTER (WHERE deleted = false) as active_records
FROM "Products";

-- 2) ProductOptions with their values
SELECT 
  po.option_code,
  po.name as option_name,
  po.input_type,
  po.is_required,
  COUNT(pov.id) as value_count,
  STRING_AGG(pov.value_code, ', ' ORDER BY pov.sort_order) as values_list
FROM "ProductOptions" po
LEFT JOIN "ProductOptionValues" pov ON pov.option_id = po.id AND pov.deleted = false
WHERE po.deleted = false
GROUP BY po.id, po.option_code, po.name, po.input_type, po.is_required, po.sort_order
ORDER BY po.sort_order;

-- 3) Check if new columns exist in BOMComponents
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'BOMComponents'
AND column_name IN ('qty_type', 'qty_value', 'select_rule')
ORDER BY column_name;

-- 4) Check if new tables exist
SELECT 
  table_name,
  (SELECT COUNT(*) 
   FROM information_schema.columns 
   WHERE table_schema = 'public' 
   AND table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
AND table_name IN (
  'Products',
  'ProductOptions',
  'ProductOptionValues',
  'ConfiguredProducts',
  'ConfiguredProductOptions',
  'MotorTubeCompatibility',
  'CassettePartsMapping',
  'HardwareColorMapping',
  'BomInstances',
  'BomInstanceLines'
)
ORDER BY table_name;

-- 5) Check unique indexes
SELECT 
  indexname,
  tablename,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
AND indexname LIKE 'uq_%'
ORDER BY tablename, indexname;









