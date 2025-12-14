-- ====================================================
-- Script: Verificar asociación de usuario con organizaciones
-- ====================================================
-- Este script verifica si el usuario está correctamente asociado
-- a la organización "Arquiproductos" en OrganizationUsers
-- ====================================================

-- ============================================================================
-- PASO 1: Buscar el usuario por email
-- ============================================================================
DO $$
DECLARE
    user_email TEXT := 'dpatino@arquiluz.studio';
    user_id_from_auth uuid;
    org_id uuid;
    org_user_record RECORD;
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'VERIFICACIÓN DE ASOCIACIÓN USUARIO-ORGANIZACIÓN';
    RAISE NOTICE '============================`==================';
    RAISE NOTICE '';

    -- Buscar user_id en auth.users
    SELECT id INTO user_id_from_auth
    FROM auth.users
    WHERE email = user_email
    LIMIT 1;

    IF user_id_from_auth IS NULL THEN
        RAISE NOTICE '❌ ERROR: Usuario % no encontrado en auth.users', user_email;
        RAISE NOTICE '   Verifica que el email sea correcto';
        RETURN;
    END IF;

    RAISE NOTICE '✅ Usuario encontrado en auth.users:';
    RAISE NOTICE '   Email: %', user_email;
    RAISE NOTICE '   User ID: %', user_id_from_auth;
    RAISE NOTICE '';

    -- Buscar organización Arquiproductos
    SELECT id INTO org_id
    FROM "Organizations"
    WHERE organization_name ILIKE '%Arquiproductos%'
      AND deleted = false
    LIMIT 1;

    IF org_id IS NULL THEN
        RAISE NOTICE '❌ ERROR: Organización "Arquiproductos" no encontrada';
        RETURN;
    END IF;

    RAISE NOTICE '✅ Organización encontrada:';
    RAISE NOTICE '   Nombre: Arquiproductos';
    RAISE NOTICE '   Organization ID: %', org_id;
    RAISE NOTICE '';

    -- Buscar registro en OrganizationUsers
    SELECT 
        ou.id,
        ou.organization_id,
        ou.user_id,
        ou.role,
        ou.name,
        ou.email,
        ou.is_system,
        ou.deleted,
        o.organization_name
    INTO org_user_record
    FROM "OrganizationUsers" ou
    JOIN "Organizations" o ON o.id = ou.organization_id
    WHERE ou.user_id = user_id_from_auth
      AND ou.organization_id = org_id
      AND ou.deleted = false
    LIMIT 1;

    IF org_user_record IS NULL THEN
        RAISE NOTICE '❌ PROBLEMA ENCONTRADO:';
        RAISE NOTICE '   El usuario NO está asociado a la organización Arquiproductos';
        RAISE NOTICE '';
        RAISE NOTICE '   Verificando si existe algún registro (incluso eliminado):';
        
        SELECT 
            ou.id,
            ou.deleted,
            ou.is_system,
            ou.role
        INTO org_user_record
        FROM "OrganizationUsers" ou
        WHERE ou.user_id = user_id_from_auth
          AND ou.organization_id = org_id
        LIMIT 1;
        
        IF org_user_record IS NOT NULL THEN
            RAISE NOTICE '   ⚠️ Existe un registro pero está marcado como:';
            RAISE NOTICE '      deleted: %', org_user_record.deleted;
            RAISE NOTICE '      is_system: %', org_user_record.is_system;
            RAISE NOTICE '      role: %', org_user_record.role;
        ELSE
            RAISE NOTICE '   ⚠️ No existe ningún registro en OrganizationUsers';
        END IF;
        
        RAISE NOTICE '';
        RAISE NOTICE '==============================================';
        RAISE NOTICE 'SOLUCIÓN:';
        RAISE NOTICE '   Ejecuta el script FIX_USER_ORGANIZATION_ASSOCIATION.sql';
        RAISE NOTICE '   para crear la asociación correcta.';
        RAISE NOTICE '==============================================';
    ELSE
        RAISE NOTICE '✅ ASOCIACIÓN ENCONTRADA:';
        RAISE NOTICE '   OrganizationUser ID: %', org_user_record.id;
        RAISE NOTICE '   Organization: %', org_user_record.organization_name;
        RAISE NOTICE '   Role: %', org_user_record.role;
        RAISE NOTICE '   Name: %', org_user_record.name;
        RAISE NOTICE '   Email: %', org_user_record.email;
        RAISE NOTICE '   is_system: %', org_user_record.is_system;
        RAISE NOTICE '   deleted: %', org_user_record.deleted;
        RAISE NOTICE '';
        
        IF org_user_record.deleted = true THEN
            RAISE NOTICE '   ⚠️ ADVERTENCIA: El registro está marcado como deleted = true';
            RAISE NOTICE '   Esto impedirá que aparezca en las consultas.';
        END IF;
        
        IF org_user_record.is_system = true THEN
            RAISE NOTICE '   ℹ️ INFO: El usuario está marcado como is_system = true';
            RAISE NOTICE '   Esto está bien - el usuario no aparecerá en listas pero puede ver su organización.';
        END IF;
        
        RAISE NOTICE '';
        RAISE NOTICE '==============================================';
        RAISE NOTICE 'DIAGNÓSTICO:';
        RAISE NOTICE '   Si aún ves "No Company", el problema podría ser:';
        RAISE NOTICE '   1. El query en OrganizationContext está fallando';
        RAISE NOTICE '   2. RLS está bloqueando la consulta';
        RAISE NOTICE '   3. El frontend no está recargando el contexto';
        RAISE NOTICE '==============================================';
    END IF;

    -- Mostrar TODAS las organizaciones del usuario
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'TODAS LAS ORGANIZACIONES DEL USUARIO:';
    RAISE NOTICE '==============================================';
    
    FOR org_user_record IN
        SELECT 
            ou.id,
            ou.organization_id,
            ou.role,
            ou.deleted,
            ou.is_system,
            o.organization_name
        FROM "OrganizationUsers" ou
        JOIN "Organizations" o ON o.id = ou.organization_id
        WHERE ou.user_id = user_id_from_auth
        ORDER BY ou.deleted, ou.role
    LOOP
        RAISE NOTICE '   - % (Role: %, deleted: %, is_system: %)', 
            org_user_record.organization_name,
            org_user_record.role,
            org_user_record.deleted,
            org_user_record.is_system;
    END LOOP;
    
    RAISE NOTICE '==============================================';

END $$;

-- ============================================================================
-- PASO 2: Verificar RLS en OrganizationUsers
-- ============================================================================
DO $$
DECLARE
    rls_enabled BOOLEAN;
    policy_count INTEGER;
BEGIN
    SELECT relrowsecurity INTO rls_enabled 
    FROM pg_class 
    WHERE relname = 'OrganizationUsers';
    
    SELECT COUNT(*) INTO policy_count 
    FROM pg_policies 
    WHERE tablename = 'OrganizationUsers';
    
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'ESTADO DE RLS EN ORGANIZATIONUSERS:';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'RLS Habilitado: %', rls_enabled;
    RAISE NOTICE 'Total Políticas: %', policy_count;
    RAISE NOTICE '==============================================';
    
    IF rls_enabled THEN
        RAISE NOTICE '⚠️ RLS está HABILITADO';
        RAISE NOTICE '   Si las políticas están mal configuradas,';
        RAISE NOTICE '   el usuario podría no ver sus organizaciones.';
    ELSE
        RAISE NOTICE '✅ RLS está DESHABILITADO';
        RAISE NOTICE '   Esto debería permitir ver todas las organizaciones.';
    END IF;
END $$;

