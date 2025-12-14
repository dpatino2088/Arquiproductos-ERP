-- ====================================================
-- SOLUCIÓN COMPLETA: AUTENTICACIÓN Y ORGANIZACIÓN
-- ====================================================
-- Este script verifica y repara TODO de una vez:
-- 1. Verifica si el usuario existe en auth.users
-- 2. Si no existe, lo crea
-- 3. Verifica y repara la asociación con la organización
-- ====================================================

DO $$
DECLARE
    user_email TEXT := 'dpatino@arquiluz.studio';
    user_password TEXT := 'TempPassword123!'; -- Cambiar después del primer login
    user_id_from_auth uuid;
    org_id uuid;
    existing_org_user_id uuid;
    v_customer_id uuid;
    v_contact_id uuid;
    contact_name TEXT;
    contact_email TEXT;
    user_exists BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'SOLUCIÓN COMPLETA: AUTENTICACIÓN Y ORGANIZACIÓN';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';

    -- ====================================================
    -- PASO 1: Verificar si el usuario existe en auth.users
    -- ====================================================
    RAISE NOTICE 'PASO 1: Verificando usuario en auth.users...';
    
    SELECT id INTO user_id_from_auth
    FROM auth.users
    WHERE email = user_email
    LIMIT 1;

    IF user_id_from_auth IS NULL THEN
        RAISE NOTICE '   ❌ Usuario NO existe en auth.users';
        RAISE NOTICE '   ⚠️  NOTA: No puedo crear usuarios en auth.users desde SQL';
        RAISE NOTICE '   ⚠️  Debes crear el usuario manualmente desde Supabase Dashboard';
        RAISE NOTICE '';
        RAISE NOTICE '   INSTRUCCIONES:';
        RAISE NOTICE '   1. Ve a Supabase Dashboard → Authentication → Users';
        RAISE NOTICE '   2. Click en "Add User" → "Create new user"';
        RAISE NOTICE '   3. Email: %', user_email;
        RAISE NOTICE '   4. Password: (elige una contraseña)';
        RAISE NOTICE '   5. Marca "Auto Confirm User"';
        RAISE NOTICE '   6. Click "Create User"';
        RAISE NOTICE '   7. Ejecuta este script nuevamente';
        RAISE NOTICE '';
        RETURN;
    ELSE
        RAISE NOTICE '   ✅ Usuario existe en auth.users';
        RAISE NOTICE '      ID: %', user_id_from_auth;
        RAISE NOTICE '      Email: %', user_email;
    END IF;

    RAISE NOTICE '';

    -- ====================================================
    -- PASO 2: Buscar organización Arquiproductos
    -- ====================================================
    RAISE NOTICE 'PASO 2: Buscando organización...';
    
    SELECT id INTO org_id
    FROM "Organizations"
    WHERE organization_name ILIKE '%Arquiproductos%'
      AND deleted = false
    LIMIT 1;

    IF org_id IS NULL THEN
        RAISE EXCEPTION '❌ ERROR: Organización "Arquiproductos" no encontrada';
    END IF;

    RAISE NOTICE '   ✅ Organización encontrada: Arquiproductos (ID: %)', org_id;
    RAISE NOTICE '';

    -- ====================================================
    -- PASO 3: Buscar Customer y Contact
    -- ====================================================
    RAISE NOTICE 'PASO 3: Buscando Customer-Contact pair...';
    
    SELECT 
        dc.id,
        dcon.id,
        COALESCE(dcon.customer_name, 'Contact ' || dcon.id::text) as name,
        COALESCE(dcon.email, user_email) as email
    INTO v_customer_id, v_contact_id, contact_name, contact_email
    FROM "DirectoryCustomers" dc
    INNER JOIN "DirectoryContacts" dcon ON dcon.customer_id = dc.id
    WHERE dc.organization_id = org_id
      AND dc.deleted = false
      AND dcon.deleted = false
      AND dcon.customer_id IS NOT NULL
    ORDER BY dc.created_at, dcon.created_at
    LIMIT 1;

    IF v_customer_id IS NULL OR v_contact_id IS NULL THEN
        RAISE NOTICE '   ❌ No se encontró Customer-Contact pair';
        RAISE NOTICE '   ⚠️  Crea al menos un Customer con un Contact relacionado primero';
        RAISE NOTICE '';
        RETURN;
    END IF;

    RAISE NOTICE '   ✅ Customer-Contact encontrado:';
    RAISE NOTICE '      Customer ID: %', v_customer_id;
    RAISE NOTICE '      Contact ID: %', v_contact_id;
    RAISE NOTICE '';

    -- ====================================================
    -- PASO 4: Verificar/Crear registro en OrganizationUsers
    -- ====================================================
    RAISE NOTICE 'PASO 4: Verificando registro en OrganizationUsers...';
    
    SELECT id INTO existing_org_user_id
    FROM "OrganizationUsers"
    WHERE user_id = user_id_from_auth
      AND organization_id = org_id
    LIMIT 1;

    IF existing_org_user_id IS NOT NULL THEN
        RAISE NOTICE '   ⚠️  Registro existente encontrado, actualizando...';
        
        UPDATE "OrganizationUsers"
        SET 
            role = 'owner',
            name = 'Diomedes Patino',
            email = user_email,
            contact_id = v_contact_id,
            customer_id = v_customer_id,
            deleted = false,
            is_system = true,
            updated_at = now()
        WHERE id = existing_org_user_id;
        
        RAISE NOTICE '   ✅ Registro actualizado';
    ELSE
        RAISE NOTICE '   📝 Creando nuevo registro...';
        
        INSERT INTO "OrganizationUsers" (
            id,
            organization_id,
            user_id,
            role,
            name,
            email,
            contact_id,
            customer_id,
            deleted,
            is_system,
            created_at,
            updated_at
        ) VALUES (
            gen_random_uuid(),
            org_id,
            user_id_from_auth,
            'owner',
            'Diomedes Patino',
            user_email,
            v_contact_id,
            v_customer_id,
            false,
            true,
            now(),
            now()
        );
        
        RAISE NOTICE '   ✅ Registro creado';
    END IF;

    RAISE NOTICE '';

    -- ====================================================
    -- PASO 5: Verificación final
    -- ====================================================
    RAISE NOTICE 'PASO 5: Verificación final...';
    
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
        WHERE user_id = user_id_from_auth
          AND organization_id = org_id
        LIMIT 1;
        
        IF final_check IS NOT NULL THEN
            RAISE NOTICE '   ✅ TODO CORRECTO:';
            RAISE NOTICE '      ID: %', final_check.id;
            RAISE NOTICE '      Email: %', final_check.email;
            RAISE NOTICE '      Name: %', final_check.name;
            RAISE NOTICE '      Role: %', final_check.role;
            RAISE NOTICE '      Deleted: %', final_check.deleted;
            RAISE NOTICE '      Is System: %', final_check.is_system;
            RAISE NOTICE '      Contact ID: %', final_check.contact_id;
            RAISE NOTICE '      Customer ID: %', final_check.customer_id;
        ELSE
            RAISE NOTICE '   ❌ ERROR: No se pudo verificar el registro';
        END IF;
    END;

    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '✅ PROCESO COMPLETADO';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'PRÓXIMOS PASOS:';
    RAISE NOTICE '1. Si el usuario NO existía, créalo en Supabase Dashboard';
    RAISE NOTICE '2. Haz login en la aplicación con tu email y contraseña';
    RAISE NOTICE '3. Recarga la aplicación (Ctrl/Cmd + Shift + R)';
    RAISE NOTICE '4. Deberías ver "Arquiproductos" en lugar de "No organizations available"';
    RAISE NOTICE '==============================================';

END $$;

-- ====================================================
-- Query final para verificar
-- ====================================================
SELECT 
    ou.id,
    ou.email,
    ou.name,
    ou.role,
    ou.deleted,
    ou.is_system,
    o.organization_name,
    dc.company_name as customer_name,
    dcon.customer_name as contact_name
FROM "OrganizationUsers" ou
JOIN "Organizations" o ON o.id = ou.organization_id
LEFT JOIN "DirectoryCustomers" dc ON dc.id = ou.customer_id
LEFT JOIN "DirectoryContacts" dcon ON dcon.id = ou.contact_id
WHERE ou.email = 'dpatino@arquiluz.studio'
  AND o.organization_name ILIKE '%Arquiproductos%'
ORDER BY ou.created_at DESC;

