-- Migration: Update CatalogItemComponents.child_role CHECK constraint
-- Date: 2026-01-20
-- Description: Agrega todos los nuevos child roles canónicos según requerimiento del usuario
-- 
-- Lista completa de child roles:
-- - Roles originales: adapter, end_cap, fastener, idler, chain_stop, chain_tensioner, filler
-- - Nuevos roles: chain, belt, belt_connector, hem_weight, brush, accessory, carrier, consumable, hook
-- - Nuevos roles: mounting_clip, bearing, connector, end_plug, guide, rail_connector, spring, stopper

BEGIN;

-- Eliminar el constraint existente
ALTER TABLE "public"."CatalogItemComponents"
DROP CONSTRAINT IF EXISTS "catalogitemcomponents_child_role_check";

-- Crear el nuevo constraint con todos los child roles válidos
ALTER TABLE "public"."CatalogItemComponents"
ADD CONSTRAINT "catalogitemcomponents_child_role_check" 
CHECK (("child_role" = ANY (ARRAY[
  -- Roles originales
  'adapter'::text,
  'end_cap'::text,
  'fastener'::text,
  'idler'::text,
  'chain_stop'::text,
  'chain_tensioner'::text,
  'filler'::text,
  -- Nuevos child roles (según requerimiento del usuario)
  'chain'::text,
  'belt'::text,
  'belt_connector'::text,
  'hem_weight'::text,
  'brush'::text,
  'accessory'::text,
  'carrier'::text,
  'consumable'::text,
  'hook'::text,
  'mounting_clip'::text,
  'bearing'::text,
  'connector'::text,
  'end_plug'::text,
  'guide'::text,
  'rail_connector'::text,
  'spring'::text,
  'stopper'::text
])));

-- Agregar comentario al constraint (si existe)
DO $$
BEGIN
  EXECUTE 'COMMENT ON CONSTRAINT "catalogitemcomponents_child_role_check" ON "public"."CatalogItemComponents" IS 
    ''Validates that child_role is one of the canonical child roles. Updated 2026-01-20 to include all required child roles: adapter, end_cap, fastener, idler, chain_stop, chain_tensioner, filler, chain, belt, belt_connector, hem_weight, brush, accessory, carrier, consumable, hook, mounting_clip, bearing, connector, end_plug, guide, rail_connector, spring, stopper''';
EXCEPTION
  WHEN undefined_object THEN
    RAISE NOTICE 'Could not add comment (constraint may not exist yet)';
END $$;

COMMIT;
