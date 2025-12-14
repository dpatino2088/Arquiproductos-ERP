-- ====================================================
-- ACTUALIZACIÓN: Cambiar de 5 roles a 3 roles
-- ====================================================
-- Este script actualiza el sistema de roles para usar solo:
-- - superadmin: Puede hacer todo
-- - admin: Puede ver todas las cotizaciones y hacer todo, excepto crear/borrar usuarios
-- - member: Solo puede ver/editar/borrar sus propias cotizaciones
-- ====================================================

-- PASO 1: Buscar y eliminar TODOS los constraints relacionados con el rol
DO $$
DECLARE
  constraint_name text;
  constraint_def text;
  table_oid oid;
BEGIN
  -- Obtener el OID de la tabla usando pg_class (respeta mayúsculas/minúsculas)
  SELECT oid INTO table_oid
  FROM pg_class
  WHERE relname = 'OrganizationUsers'
    AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
  
  IF table_oid IS NULL THEN
    RAISE EXCEPTION 'No se encontró la tabla OrganizationUsers';
  END IF;
  
  -- Buscar todos los CHECK constraints que mencionan 'role' en su definición
  FOR constraint_name, constraint_def IN
    SELECT conname, pg_get_constraintdef(oid)
    FROM pg_constraint
    WHERE conrelid = table_oid
      AND contype = 'c'
      AND (
        conname LIKE '%role%' 
        OR pg_get_constraintdef(oid) ILIKE '%role%'
      )
  LOOP
    EXECUTE format('ALTER TABLE "OrganizationUsers" DROP CONSTRAINT IF EXISTS %I', constraint_name);
    RAISE NOTICE '✅ Eliminado constraint: % (definición: %)', constraint_name, constraint_def;
  END LOOP;
  
  -- También eliminar por nombres conocidos (por si acaso)
  ALTER TABLE "OrganizationUsers" DROP CONSTRAINT IF EXISTS organizationusers_role_check;
  ALTER TABLE "OrganizationUsers" DROP CONSTRAINT IF EXISTS orgusers_role_check;
  ALTER TABLE "OrganizationUsers" DROP CONSTRAINT IF EXISTS role_check;
  ALTER TABLE "OrganizationUsers" DROP CONSTRAINT IF EXISTS OrganizationUsers_role_check;
  
  RAISE NOTICE '✅ Todos los constraints de rol han sido eliminados';
END $$;

-- PASO 2: Verificar qué roles inválidos existen antes de actualizar
DO $$
DECLARE
  owner_count integer;
  viewer_count integer;
  other_invalid_count integer;
BEGIN
  SELECT COUNT(*) INTO owner_count FROM "OrganizationUsers" WHERE role = 'owner';
  SELECT COUNT(*) INTO viewer_count FROM "OrganizationUsers" WHERE role = 'viewer';
  SELECT COUNT(*) INTO other_invalid_count 
  FROM "OrganizationUsers" 
  WHERE role NOT IN ('superadmin', 'admin', 'member', 'owner', 'viewer');
  
  RAISE NOTICE '📊 Roles encontrados antes de la migración:';
  RAISE NOTICE '   - owner: % registros', owner_count;
  RAISE NOTICE '   - viewer: % registros', viewer_count;
  RAISE NOTICE '   - otros inválidos: % registros', other_invalid_count;
END $$;

-- PASO 3: Actualizar TODOS los roles existentes 'owner' a 'superadmin' (incluyendo deleted)
UPDATE "OrganizationUsers"
SET role = 'superadmin',
    updated_at = NOW()
WHERE role = 'owner';

-- PASO 4: Actualizar TODOS los roles existentes 'viewer' a 'member' (incluyendo deleted)
UPDATE "OrganizationUsers"
SET role = 'member',
    updated_at = NOW()
WHERE role = 'viewer';

-- PASO 5: Actualizar cualquier otro rol inválido a 'member' (por seguridad)
UPDATE "OrganizationUsers"
SET role = 'member',
    updated_at = NOW()
WHERE role NOT IN ('superadmin', 'admin', 'member');

-- PASO 6: Verificar que no queden roles inválidos
DO $$
DECLARE
  invalid_roles_count integer;
  invalid_roles_list text;
BEGIN
  SELECT COUNT(*), string_agg(DISTINCT role::text, ', ') 
  INTO invalid_roles_count, invalid_roles_list
  FROM "OrganizationUsers"
  WHERE role NOT IN ('superadmin', 'admin', 'member');
  
  IF invalid_roles_count > 0 THEN
    RAISE EXCEPTION '❌ Aún existen % registros con roles inválidos: %. Revisa manualmente antes de continuar.', 
      invalid_roles_count, invalid_roles_list;
  ELSE
    RAISE NOTICE '✅ Todos los roles son válidos (superadmin, admin, member)';
  END IF;
END $$;

-- PASO 7: Ahora sí, crear el nuevo CHECK constraint
ALTER TABLE "OrganizationUsers" 
ADD CONSTRAINT organizationusers_role_check 
CHECK (role IN ('superadmin', 'admin', 'member'));

-- PASO 4: Verificar que no queden roles inválidos
DO $$
DECLARE
  invalid_roles_count integer;
BEGIN
  SELECT COUNT(*) INTO invalid_roles_count
  FROM "OrganizationUsers"
  WHERE role NOT IN ('superadmin', 'admin', 'member')
    AND deleted = false;
  
  IF invalid_roles_count > 0 THEN
    RAISE WARNING '⚠️ Se encontraron % registros con roles inválidos. Revisa manualmente.', invalid_roles_count;
  ELSE
    RAISE NOTICE '✅ Todos los roles son válidos (superadmin, admin, member)';
  END IF;
END $$;

-- PASO 5: Añadir comentario descriptivo
COMMENT ON COLUMN "OrganizationUsers".role IS 
  'Rol del usuario: superadmin (puede hacer todo), admin (puede hacer todo excepto crear/borrar usuarios), member (solo puede ver/editar/borrar sus propias cotizaciones)';

-- PASO 6: Verificación final
DO $$ 
DECLARE
  v_constraint_exists boolean;
  v_superadmin_count integer;
  v_admin_count integer;
  v_member_count integer;
BEGIN
  -- Verificar que el constraint existe
  SELECT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'organizationusers_role_check'
  ) INTO v_constraint_exists;
  
  -- Contar usuarios por rol
  SELECT COUNT(*) INTO v_superadmin_count FROM "OrganizationUsers" WHERE role = 'superadmin' AND deleted = false;
  SELECT COUNT(*) INTO v_admin_count FROM "OrganizationUsers" WHERE role = 'admin' AND deleted = false;
  SELECT COUNT(*) INTO v_member_count FROM "OrganizationUsers" WHERE role = 'member' AND deleted = false;
  
  IF v_constraint_exists THEN
    RAISE NOTICE '✅ Migración completada exitosamente';
    RAISE NOTICE '✅ Constraint actualizado: solo permite superadmin, admin, member';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Distribución de roles:';
    RAISE NOTICE '   - Superadmin: % usuarios', v_superadmin_count;
    RAISE NOTICE '   - Admin: % usuarios', v_admin_count;
    RAISE NOTICE '   - Member: % usuarios', v_member_count;
  ELSE
    RAISE WARNING '⚠️ El constraint no se creó correctamente';
  END IF;
END $$;

