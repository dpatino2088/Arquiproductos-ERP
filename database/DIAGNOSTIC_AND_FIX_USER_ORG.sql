-- ====================================================
-- DIAGNÓSTICO Y REPARACIÓN COMPLETA DE ASOCIACIÓN USUARIO-ORGANIZACIÓN
-- ====================================================
-- Este script diagnostica y repara la asociación del usuario
-- con la organización, trabajando directamente sin depender de RLS
-- ====================================================

DO $$
DECLARE
    user_email_1 TEXT := 'dpatino@arquiluz.studio';
    user_email_2 TEXT := 'dpatino@grupo927.com';
    user_id_from_auth uuid;
    org_id uuid;
    existing_org_user_id uuid;
    v_customer_id uuid;
    v_contact_id uuid;
    contact_name TEXT;
    contact_email TEXT;
    found_user_email TEXT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'DIAGNÓSTICO Y REPARACIÓN DE ASOCIACIÓN';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';

    -- ====================================================
    -- PASO 1: Buscar usuario en auth.users
    -- ====================================================
    RAISE NOTICE '1. BUSCANDO USUARIO EN auth.users...';
    
    -- Intentar con el primer email
    SELECT id INTO user_id_from_auth
    FROM auth.users
    WHERE email = user_email_1
    LIMIT 1;
    
    IF user_id_from_auth IS NOT NULL THEN
        found_user_email := user_email_1;
        RAISE NOTICE '   ✅ Usuario encontrado: % (ID: %)', user_email_1, user_id_from_auth;
    ELSE
        -- Intentar con el segundo email
        SELECT id INTO user_id_from_auth
        FROM auth.users
        WHERE email = user_email_2
        LIMIT 1;
        
        IF user_id_from_auth IS NOT NULL THEN
            found_user_email := user_email_2;
            RAISE NOTICE '   ✅ Usuario encontrado: % (ID: %)', user_email_2, user_id_from_auth;
        ELSE
            RAISE NOTICE '   ❌ ERROR: Usuario no encontrado con ninguno de los emails';
            RAISE NOTICE '      Intentados: %, %', user_email_1, user_email_2;
            RAISE NOTICE '';
            RAISE NOTICE '   Verificando todos los usuarios en auth.users...';
            FOR user_id_from_auth IN
                SELECT id FROM auth.users LIMIT 5
            LOOP
                RAISE NOTICE '      Usuario encontrado (ID): %', user_id_from_auth;
            END LOOP;
            RETURN;
        END IF;
    END IF;
    
    RAISE NOTICE '';

    -- ====================================================
    -- PASO 2: Buscar organización Arquiproductos
    -- ====================================================
    RAISE NOTICE '2. BUSCANDO ORGANIZACIÓN...';
    
    SELECT id INTO org_id
    FROM "Organizations"
    WHERE organization_name ILIKE '%Arquiproductos%'
      AND deleted = false
    LIMIT 1;

    IF org_id IS NULL THEN
        RAISE NOTICE '   ❌ ERROR: Organización "Arquiproductos" no encontrada';
        RAISE NOTICE '';
        RAISE NOTICE '   Verificando todas las organizaciones...';
        FOR org_id IN
            SELECT id FROM "Organizations" WHERE deleted = false LIMIT 5
        LOOP
            RAISE NOTICE '      Organización encontrada (ID): %', org_id;
        END LOOP;
        RETURN;
    END IF;

    RAISE NOTICE '   ✅ Organización encontrada: Arquiproductos (ID: %)', org_id;
    RAISE NOTICE '';

    -- ====================================================
    -- PASO 3: Verificar registro existente en OrganizationUsers
    -- ====================================================
    RAISE NOTICE '3. VERIFICANDO REGISTRO EXISTENTE...';
    
    SELECT id INTO existing_org_user_id
    FROM "OrganizationUsers"
    WHERE user_id = user_id_from_auth
      AND organization_id = org_id
    LIMIT 1;

    IF existing_org_user_id IS NOT NULL THEN
        RAISE NOTICE '   ⚠️ Registro existente encontrado (ID: %)', existing_org_user_id;
        RAISE NOTICE '   Verificando estado del registro...';
        
        DECLARE
            v_deleted BOOLEAN;
            v_is_system BOOLEAN;
            v_role TEXT;
            v_contact_id_check uuid;
            v_customer_id_check uuid;
        BEGIN
            SELECT deleted, is_system, role, contact_id, customer_id
            INTO v_deleted, v_is_system, v_role, v_contact_id_check, v_customer_id_check
            FROM "OrganizationUsers"
            WHERE id = existing_org_user_id;
            
            RAISE NOTICE '      deleted: %', v_deleted;
            RAISE NOTICE '      is_system: %', v_is_system;
            RAISE NOTICE '      role: %', v_role;
            RAISE NOTICE '      contact_id: %', v_contact_id_check;
            RAISE NOTICE '      customer_id: %', v_customer_id_check;
            
            IF v_deleted = true THEN
                RAISE NOTICE '   ⚠️ El registro está marcado como deleted = true';
            END IF;
            
            IF v_contact_id_check IS NULL OR v_customer_id_check IS NULL THEN
                RAISE NOTICE '   ⚠️ El registro NO tiene contact_id o customer_id';
            END IF;
        END;
    ELSE
        RAISE NOTICE '   ℹ️ No existe registro en OrganizationUsers';
    END IF;
    
    RAISE NOTICE '';

    -- ====================================================
    -- PASO 4: Buscar Customer y Contact para asociar
    -- ====================================================
    RAISE NOTICE '4. BUSCANDO CUSTOMER-CONTACT PAIR...';
    
    SELECT 
        dc.id,
        dcon.id,
        COALESCE(dcon.customer_name, 'Contact ' || dcon.id::text) as name,
        COALESCE(dcon.email, 'contact' || dcon.id::text || '@arquiproductos.com') as email
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
        RAISE NOTICE '   ❌ ERROR: No se encontró un Customer-Contact pair';
        RAISE NOTICE '';
        RAISE NOTICE '   Verificando datos disponibles...';
        
        DECLARE
            customers_count INTEGER;
            contacts_count INTEGER;
        BEGIN
            SELECT COUNT(*) INTO customers_count
            FROM "DirectoryCustomers"
            WHERE organization_id = org_id AND deleted = false;
            
            SELECT COUNT(*) INTO contacts_count
            FROM "DirectoryContacts"
            WHERE organization_id = org_id AND deleted = false;
            
            RAISE NOTICE '      Customers disponibles: %', customers_count;
            RAISE NOTICE '      Contacts disponibles: %', contacts_count;
            
            IF customers_count = 0 THEN
                RAISE NOTICE '   ⚠️ No hay Customers. Crea al menos un Customer primero.';
            END IF;
            
            IF contacts_count = 0 THEN
                RAISE NOTICE '   ⚠️ No hay Contacts. Crea al menos un Contact primero.';
            END IF;
        END;
        
        RETURN;
    END IF;

    RAISE NOTICE '   ✅ Customer-Contact encontrado:';
    RAISE NOTICE '      Customer ID: %', v_customer_id;
    RAISE NOTICE '      Contact ID: %', v_contact_id;
    RAISE NOTICE '      Contact Name: %', contact_name;
    RAISE NOTICE '      Contact Email: %', contact_email;
    RAISE NOTICE '';

    -- ====================================================
    -- PASO 5: Crear o actualizar registro
    -- ====================================================
    RAISE NOTICE '5. CREANDO/ACTUALIZANDO REGISTRO...';
    
    IF existing_org_user_id IS NOT NULL THEN
        -- Actualizar registro existente
        UPDATE "OrganizationUsers"
        SET 
            role = 'owner',
            name = contact_name,
            email = found_user_email,
            contact_id = v_contact_id,
            customer_id = v_customer_id,
            deleted = false,
            is_system = true,
            updated_at = now()
        WHERE id = existing_org_user_id;
        
        RAISE NOTICE '   ✅ Registro actualizado exitosamente';
    ELSE
        -- Crear nuevo registro
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
            contact_name,
            found_user_email,
            v_contact_id,
            v_customer_id,
            false,
            true,
            now(),
            now()
        );
        
        RAISE NOTICE '   ✅ Registro creado exitosamente';
    END IF;

    RAISE NOTICE '';

    -- ====================================================
    -- PASO 6: Verificar resultado final
    -- ====================================================
    RAISE NOTICE '6. VERIFICANDO RESULTADO FINAL...';
    
    DECLARE
        final_check RECORD;
    BEGIN
        SELECT 
            id,
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
            RAISE NOTICE '   ✅ Verificación exitosa:';
            RAISE NOTICE '      ID: %', final_check.id;
            RAISE NOTICE '      Role: %', final_check.role;
            RAISE NOTICE '      Deleted: %', final_check.deleted;
            RAISE NOTICE '      Is System: %', final_check.is_system;
            RAISE NOTICE '      Contact ID: %', final_check.contact_id;
            RAISE NOTICE '      Customer ID: %', final_check.customer_id;
        ELSE
            RAISE NOTICE '   ❌ ERROR: No se pudo verificar el registro creado';
        END IF;
    END;

    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '✅ PROCESO COMPLETADO';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Próximos pasos:';
    RAISE NOTICE '1. Recarga la aplicación (Ctrl/Cmd + R)';
    RAISE NOTICE '2. Deberías ver "Arquiproductos" en lugar de "No organizations available"';
    RAISE NOTICE '3. Deberías poder acceder a Settings → Organization User';
    RAISE NOTICE '==============================================';

END $$;

-- ====================================================
-- Verificar el resultado con una query directa
-- ====================================================
SELECT 
    ou.id,
    ou.email,
    ou.role,
    ou.name,
    ou.deleted,
    ou.is_system,
    ou.contact_id,
    ou.customer_id,
    o.organization_name,
    dc.company_name as customer_name,
    dcon.customer_name as contact_name
FROM "OrganizationUsers" ou
JOIN "Organizations" o ON o.id = ou.organization_id
LEFT JOIN "DirectoryCustomers" dc ON dc.id = ou.customer_id
LEFT JOIN "DirectoryContacts" dcon ON dcon.id = ou.contact_id
WHERE ou.email IN ('dpatino@arquiluz.studio', 'dpatino@grupo927.com')
  AND o.organization_name ILIKE '%Arquiproductos%'
ORDER BY ou.created_at DESC;

