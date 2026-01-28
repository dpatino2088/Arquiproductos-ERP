-- Agregar slots faltantes al template ROLLER_SHADE_BASE

INSERT INTO public."BOMTemplateSlots" (
  organization_id,
  bom_template_id,
  item_role,
  required,
  catalog_item_id,
  qty,
  notes
)
SELECT
  '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid,
  bt.id,
  role_data.item_role,
  role_data.required,
  NULL,  -- Usuario elige
  role_data.qty,
  role_data.notes
FROM public."BOMTemplates" bt,
LATERAL (VALUES
  ('headbox', false, 1, 'Cassette/Headbox (opcional)'),
  ('side_channel', false, 1, 'Side channel (opcional)'),
  ('bottom_channel', false, 1, 'Bottom channel (opcional)')
) AS role_data(item_role, required, qty, notes)
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
  AND bt.code = 'ROLLER_SHADE_BASE'
  AND NOT EXISTS (
    SELECT 1 FROM public."BOMTemplateSlots" bts
    WHERE bts.bom_template_id = bt.id
      AND bts.item_role = role_data.item_role
  );

-- Verificar
SELECT 
  bt.code,
  bts.item_role,
  bts.required,
  bts.catalog_item_id IS NOT NULL as has_fixed_sku,
  bts.qty
FROM public."BOMTemplateSlots" bts
JOIN public."BOMTemplates" bt ON bt.id = bts.bom_template_id
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
  AND bt.code = 'ROLLER_SHADE_BASE'
ORDER BY bts.item_role;
