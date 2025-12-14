-- ====================================================
-- Migration: Agregar columna is_system para ocultar usuarios del sistema
-- ====================================================
-- Esta columna permite marcar usuarios como "sistema" (ej: superadmin)
-- que no deben aparecer en las listas regulares de usuarios
-- ====================================================

-- Step 1: Agregar columna
ALTER TABLE "OrganizationUsers"
  ADD COLUMN IF NOT EXISTS is_system BOOLEAN DEFAULT false;

-- Step 2: Marcar usuarios del sistema existentes
UPDATE "OrganizationUsers"
SET is_system = true
WHERE email = 'dpatino@arquiluz.studio'
  AND deleted = false;

-- Step 3: Crear índice para mejor rendimiento
CREATE INDEX IF NOT EXISTS idx_organization_users_is_system 
ON "OrganizationUsers"(is_system) 
WHERE is_system = true AND deleted = false;

-- Step 4: Agregar comentario
COMMENT ON COLUMN "OrganizationUsers".is_system IS 'If true, this user is a system user (e.g., superadmin) and should be hidden from regular user lists.';

-- Step 5: Verificar resultado
SELECT 
    id,
    name,
    email,
    role,
    is_system,
    deleted
FROM "OrganizationUsers"
WHERE email = 'dpatino@arquiluz.studio'
  AND deleted = false;

