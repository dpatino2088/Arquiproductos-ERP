-- Diagnóstico completo del estado actual
-- Ejecuta y copia TODO el resultado

-- 1. Verificar QuoteLines columns
SELECT 'QuoteLines columns' as check_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'QuoteLines'
  AND column_name IN ('area', 'position', 'product_type', 'hardware_color', 'cassette', 'side_channel', 'drive_type', 'bom_template_id')
ORDER BY column_name;

-- 2. Verificar QuoteLineComponents constraint
SELECT 'QuoteLineComponents constraint' as check_name, 
       conname as constraint_name,
       pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'public."QuoteLineComponents"'::regclass
  AND conname LIKE '%role%';

-- 3. Verificar si existe SaleOrderLines
SELECT 'SaleOrderLines exists' as check_name,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'SaleOrderLines')
         THEN 'YES' ELSE 'NO' END as result;

-- 4. Verificar BOMComponents columns
SELECT 'BOMComponents has is_required' as check_name,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'BOMComponents' AND column_name = 'is_required')
         THEN 'YES' ELSE 'NO' END as result;

-- 5. Verificar última QuoteLine creada
SELECT 'Last QuoteLine' as check_name, id, width_m, height_m, msrp, net_price
FROM public."QuoteLines"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
ORDER BY created_at DESC
LIMIT 1;

-- 6. Verificar QuoteLineComponents de última línea
SELECT 'QuoteLineComponents for last line' as check_name,
       qlc.component_role,
       qlc.kind,
       qlc.catalog_item_id IS NOT NULL as has_item,
       qlc.payload
FROM public."QuoteLineComponents" qlc
WHERE qlc.quote_line_id = (
  SELECT id FROM public."QuoteLines"
  WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
  ORDER BY created_at DESC LIMIT 1
)
  AND qlc.deleted = false
ORDER BY qlc.created_at;

-- 7. Verificar BOMInstance
SELECT 'BOMInstance for last line' as check_name,
       bi.id,
       bt.code as template_code,
       COUNT(bil.id) as bom_lines_count
FROM public."BOMInstances" bi
LEFT JOIN public."BOMTemplates" bt ON bt.id = bi.bom_template_id
LEFT JOIN public."BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE bi.quote_line_id = (
  SELECT id FROM public."QuoteLines"
  WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
  ORDER BY created_at DESC LIMIT 1
)
  AND bi.deleted = false
GROUP BY bi.id, bt.code;
