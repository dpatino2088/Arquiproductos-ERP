-- ============================================================================
-- DIAGNÓSTICO: ProductTypes (verificar qué existe y qué falta)
-- Organization ID: 3acbb54c-c71f-4cb2-9fe3-d3ac513babe2
-- ============================================================================

-- 1) Ver qué ProductTypes existen para tu organización
-- NOTA: ProductTypes.organization_id es NOT NULL (no hay registros globales)
-- NOTA: ProductTypes NO tiene columna "deleted" ni "archived"
SELECT 
  id, 
  code, 
  name, 
  organization_id, 
  sort_order,
  created_at,
  updated_at
FROM public."ProductTypes"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
ORDER BY code;

-- 2) Ver específicamente "roller" / "roller_shade" / "roller-shade" para tu org
SELECT 
  id, 
  code, 
  name, 
  organization_id, 
  sort_order
FROM public."ProductTypes"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND (
    LOWER(code) IN ('roller','roller_shade','roller-shade','rollershade')
    OR LOWER(name) LIKE '%roller%'
  )
ORDER BY code;

-- ============================================================================
-- FIXES: Si NO existe Roller Shade, créalo (global)
-- ============================================================================

-- 3) Si NO existe Roller Shade, créalo para tu organización
-- NOTA: ProductTypes.organization_id es NOT NULL, NO puede ser global (NULL)
-- NOTA: ProductTypes NO tiene columnas "deleted" ni "archived"
INSERT INTO public."ProductTypes" (
  id, 
  organization_id, 
  code, 
  name, 
  sort_order,
  created_at, 
  updated_at
)
VALUES (
  gen_random_uuid(), 
  '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid, 
  'roller', 
  'Roller Shade', 
  0,
  now(), 
  now()
)
ON CONFLICT DO NOTHING;

-- 4) Si existe "roller" con otro code (ej. roller_shade), estandarizarlo
-- NOTA: ProductTypes.organization_id es NOT NULL, así que no hay registros globales
-- Esta query actualiza el code si existe con otro nombre
UPDATE public."ProductTypes"
SET code = 'roller',
    name = 'Roller Shade',
    updated_at = now()
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND LOWER(code) IN ('roller_shade','roller-shade','rollershade')
  AND code != 'roller';

-- 5) (Ya manejado en query #4 arriba)
-- El frontend ya maneja aliases, así que si el code es diferente pero existe, funcionará.

-- Opción B (mejor): deja el code como está y el frontend busca con aliases (ya lo estás haciendo).
-- No hacer nada, el frontend ya maneja aliases.

-- ============================================================================
-- VERIFICACIÓN FINAL
-- ============================================================================

-- Verificar que ahora existe "roller" para tu organización
-- NOTA: ProductTypes NO tiene columna "deleted"
SELECT 
  id, 
  code, 
  name, 
  organization_id, 
  sort_order,
  created_at
FROM public."ProductTypes"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND code = 'roller';
