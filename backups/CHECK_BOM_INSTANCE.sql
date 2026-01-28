-- Ver si se generó BOMInstance para la última línea

-- Primero obtener el ID de la última línea
WITH last_line AS (
  SELECT id, width_m, height_m, msrp, net_price, created_at
  FROM public."QuoteLines"
  WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
  ORDER BY created_at DESC
  LIMIT 1
)
SELECT 
  ll.id as quote_line_id,
  ll.width_m,
  ll.height_m,
  ll.msrp,
  ll.net_price,
  bi.id as bom_instance_id,
  bt.code as template_code,
  bt.name as template_name,
  COUNT(bil.id) as bom_lines_count,
  STRING_AGG(
    CONCAT(
      bil.part_role, 
      ' (', 
      COALESCE(ci.sku, 'NULL'), 
      ') qty=', 
      bil.qty::text
    ), 
    ', ' 
    ORDER BY bil.created_at
  ) as bom_details
FROM last_line ll
LEFT JOIN public."BOMInstances" bi ON bi.quote_line_id = ll.id AND bi.deleted = false
LEFT JOIN public."BOMTemplates" bt ON bt.id = bi.bom_template_id
LEFT JOIN public."BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
LEFT JOIN public."CatalogItems" ci ON ci.id = bil.resolved_part_id
GROUP BY ll.id, ll.width_m, ll.height_m, ll.msrp, ll.net_price, bi.id, bt.code, bt.name;
