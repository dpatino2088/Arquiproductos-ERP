-- Verificar si hay BOMTemplates que puedan matchear

SELECT 
  bt.id,
  bt.code,
  bt.name,
  bt.product_type,
  bt.headbox_type,
  bt.system_size,
  bt.color,
  bt.side_channel_mode,
  bt.operating_system,
  bt.active,
  bt.deleted,
  (SELECT COUNT(*) FROM public."BOMTemplateSlots" WHERE bom_template_id = bt.id) as slots_count
FROM public."BOMTemplates" bt
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
  AND bt.deleted = false
ORDER BY bt.code;

-- Ver qué debería matchear con las opciones guardadas:
-- hardware_color: "White"
-- drive_type: "manual" 
-- cassette: false
-- side_channel: false

-- Templates que podrían matchear:
SELECT 
  'Should match' as status,
  bt.code,
  bt.operating_system,
  bt.color,
  bt.headbox_type,
  bt.side_channel_mode
FROM public."BOMTemplates" bt
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
  AND bt.deleted = false
  AND bt.operating_system = 'manual'  -- drive_type="manual"
ORDER BY bt.code;
