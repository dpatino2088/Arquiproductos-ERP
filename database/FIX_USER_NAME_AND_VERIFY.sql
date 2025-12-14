-- ====================================================
-- CORREGIR NOMBRE DE USUARIO Y VERIFICAR VISIBILIDAD
-- ====================================================
-- Este script corrige el nombre del usuario y verifica
-- que pueda ver su organización aunque tenga is_system = true
-- 
-- IMPORTANTE: Ejecuta primero FIX_RLS_FOR_SYSTEM_USERS.sql
-- para corregir la política RLS
-- ====================================================

DO $$
DECLARE
    user_email TEXT := 'dpatino@arquiluz.studio';
    user_id_from_auth uuid;
    org_id uuid;
    org_user_id uuid;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'CORRIGIENDO NOMBRE Y VERIFICANDO VISIBILIDAD';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';

    -- Buscar user_id
    SELECT id INTO user_id_from_auth
    FROM auth.users
    WHERE email = user_email
    LIMIT 1;

    IF user_id_from_auth IS NULL THEN
        RAISE EXCEPTION '❌ Usuario no encontrado';
    END IF;

    RAISE NOTICE '✅ Usuario encontrado: % (ID: %)', user_email, user_id_from_auth;

    -- Buscar organización
    SELECT id INTO org_id
    FROM "Organizations"
    WHERE organization_name ILIKE '%Arquiproductos%'
      AND deleted = false
    LIMIT 1;

    IF org_id IS NULL THEN
        RAISE EXCEPTION '❌ Organización no encontrada';
    END IF;

    RAISE NOTICE '✅ Organización encontrada: Arquiproductos (ID: %)', org_id;
    RAISE NOTICE '';

    -- Buscar registro existente
    SELECT id INTO org_user_id
    FROM "OrganizationUsers"
    WHERE user_id = user_id_from_auth
      AND organization_id = org_id
    LIMIT 1;

    IF org_user_id IS NULL THEN
        RAISE EXCEPTION '❌ Registro en OrganizationUsers no encontrado';
    END IF;

    RAISE NOTICE '✅ Registro encontrado (ID: %)', org_user_id;
    RAISE NOTICE '';

    -- Obtener nombre correcto del usuario desde auth.users
    DECLARE
        correct_name TEXT;
        raw_user_meta JSONB;
    BEGIN
        SELECT raw_user_meta_data INTO raw_user_meta
        FROM auth.users
        WHERE id = user_id_from_auth;
        
        -- Intentar obtener nombre de raw_user_meta_data
        correct_name := COALESCE(
            raw_user_meta->>'full_name',
            raw_user_meta->>'name',
            raw_user_meta->>'display_name',
            'Diomedes Patino' -- Fallback
        );
        
        IF correct_name IS NULL OR correct_name = '' THEN
            correct_name := 'Diomedes Patino';
        END IF;
        
        RAISE NOTICE '📝 Nombre a usar: %', correct_name;
        RAISE NOTICE '';

        -- Actualizar nombre y asegurar que is_system no impida ver la organización
        UPDATE "OrganizationUsers"
        SET 
            name = correct_name,
            -- Mantener is_system = true para que no aparezca en listas
            -- pero el OrganizationContext debe poder verlo para cargar la organización
            updated_at = now()
        WHERE id = org_user_id;
        
        RAISE NOTICE '✅ Nombre actualizado a: %', correct_name;
    END;

    RAISE NOTICE '';

    -- Verificar resultado
    DECLARE
        final_check RECORD;
    BEGIN
        SELECT 
            id,
            email,
            name,
            role,
            deleted,
            is_system,
            contact_id,
            customer_id
        INTO final_check
        FROM "OrganizationUsers"
        WHERE id = org_user_id;
        
        RAISE NOTICE '==============================================';
        RAISE NOTICE 'VERIFICACIÓN FINAL:';
        RAISE NOTICE '==============================================';
        RAISE NOTICE 'ID: %', final_check.id;
        RAISE NOTICE 'Email: %', final_check.email;
        RAISE NOTICE 'Name: %', final_check.name;
        RAISE NOTICE 'Role: %', final_check.role;
        RAISE NOTICE 'Deleted: %', final_check.deleted;
        RAISE NOTICE 'Is System: %', final_check.is_system;
        RAISE NOTICE 'Contact ID: %', final_check.contact_id;
        RAISE NOTICE 'Customer ID: %', final_check.customer_id;
        RAISE NOTICE '==============================================';
        RAISE NOTICE '';
        RAISE NOTICE 'NOTA IMPORTANTE:';
        RAISE NOTICE 'is_system = true significa que NO aparecerás en las listas';
        RAISE NOTICE 'de usuarios, pero DEBES poder ver tu organización.';
        RAISE NOTICE '';
        RAISE NOTICE 'Si aún no ves la organización, puede ser:';
        RAISE NOTICE '1. Problema de caché - recarga la aplicación (Ctrl/Cmd + Shift + R)';
        RAISE NOTICE '2. El OrganizationContext está filtrando por is_system (revisar código)';
        RAISE NOTICE '3. Problema de RLS bloqueando la query';
        RAISE NOTICE '==============================================';
    END;

END $$;

-- ====================================================
-- Query para verificar que el registro es visible
-- ====================================================
-- Esta query simula lo que hace OrganizationContext
SELECT 
    ou.organization_id,
    ou.role,
    o.id as org_id,
    o.organization_name,
    ou.is_system,
    ou.deleted
FROM "OrganizationUsers" ou
JOIN "Organizations" o ON o.id = ou.organization_id
WHERE ou.email = 'dpatino@arquiluz.studio'
  AND ou.deleted = false
  -- NOTA: No filtramos por is_system aquí porque el usuario necesita ver su organización
ORDER BY ou.created_at DESC;

