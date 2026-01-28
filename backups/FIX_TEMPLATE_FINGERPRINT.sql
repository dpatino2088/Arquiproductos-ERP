-- Actualizar template ROLLER_SHADE_BASE con fingerprint correcto
-- Para que matchee con las opciones: manual, White, cassette=false, side_channel=false

UPDATE public."BOMTemplates"
SET 
  product_type = 'roller',
  operating_system = 'manual',  -- Porque drive_type="manual"
  color = 'white',
  headbox_type = 'none',        -- Porque cassette=false
  side_channel_mode = 'none',   -- Porque side_channel=false
  system_size = 'm',            -- Medium (default)
  updated_at = now()
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
  AND code = 'ROLLER_SHADE_BASE';

-- Verificar
SELECT 
  code,
  name,
  product_type,
  operating_system,
  color,
  headbox_type,
  side_channel_mode,
  system_size
FROM public."BOMTemplates"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
  AND code = 'ROLLER_SHADE_BASE';
