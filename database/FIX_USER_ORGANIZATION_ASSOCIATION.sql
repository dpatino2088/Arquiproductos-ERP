-- ====================================================
-- Script: Crear/Reparar asociación usuario-organización
-- ====================================================
-- Este script crea o repara la asociación del usuario
-- con la organización "Arquiproductos" en OrganizationUsers
-- ====================================================

DO $$
DECLARE
    user_email TEXT := 'dpatino@arquiluz.studio';
    user_id_from_auth uuid;
    org_id uuid;
    existing_org_user_id uuid;
    v_customer_id uuid;
    v_contact_id uuid;
    contact_name TEXT;
    contact_email TEXT;
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'CREANDO/REPARANDO ASOCIACIÓN USUARIO-ORGANIZACIÓN';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';

    -- ====================================================
    -- STEP 1: Buscar user_id en auth.users
    -- ====================================================
    SELECT id INTO user_id_from_auth
    FROM auth.users
    WHERE email = user_email
    LIMIT 1;

    IF user_id_from_auth IS NULL THEN
        RAISE EXCEPTION '❌ ERROR: Usuario % no encontrado en auth.users', user_email;
    END IF;

    RAISE NOTICE '✅ Usuario encontrado: % (ID: %)', user_email, user_id_from_auth;

    -- ====================================================
    -- STEP 2: Buscar organización Arquiproductos
    -- ====================================================
    SELECT id INTO org_id
    FROM "Organizations"
    WHERE organization_name ILIKE '%Arquiproductos%'
      AND deleted = false
    LIMIT 1;

    IF org_id IS NULL THEN
        RAISE EXCEPTION '❌ ERROR: Organización "Arquiproductos" no encontrada';
    END IF;

    RAISE NOTICE '✅ Organización encontrada: Arquiproductos (ID: %)', org_id;

    -- ====================================================
    -- STEP 3: Buscar Customer y Contact para asociar
    -- ====================================================
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
        RAISE EXCEPTION '❌ ERROR: No se encontró un Customer-Contact pair para asociar. Crea al menos un Customer con un Contact relacionado primero.';
    END IF;

    RAISE NOTICE '✅ Customer-Contact encontrado:';
    RAISE NOTICE '   Customer ID: %', v_customer_id;
    RAISE NOTICE '   Contact ID: %', v_contact_id;
    RAISE NOTICE '   Contact Name: %', contact_name;
    RAISE NOTICE '   Contact Email: %', contact_email;

    -- ====================================================
    -- STEP 4: Verificar si ya existe un registro
    -- ====================================================
    SELECT id INTO existing_org_user_id
    FROM "OrganizationUsers"
    WHERE user_id = user_id_from_auth
      AND organization_id = org_id
    LIMIT 1;

    IF existing_org_user_id IS NOT NULL THEN
        -- Actualizar registro existente
        RAISE NOTICE '';
        RAISE NOTICE '⚠️ Registro existente encontrado. Actualizando...';
        
        UPDATE "OrganizationUsers"
        SET 
            role = 'owner',
            name = contact_name,
            email = contact_email,
            contact_id = v_contact_id,
            customer_id = v_customer_id,
            deleted = false,
            is_system = true, -- Marcar como sistema para que no aparezca en listas
            updated_at = now()
        WHERE id = existing_org_user_id;
        
        RAISE NOTICE '✅ Registro actualizado exitosamente';
    ELSE
        -- Crear nuevo registro
        RAISE NOTICE '';
        RAISE NOTICE '📝 Creando nuevo registro en OrganizationUsers...';
        
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
            contact_email,
            v_contact_id,
            v_customer_id,
            false,
            true, -- Marcar como sistema para que no aparezca en listas
            now(),
            now()
        );
        
        RAISE NOTICE '✅ Registro creado exitosamente';
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '✅ ASOCIACIÓN COMPLETADA';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Próximos pasos:';
    RAISE NOTICE '1. Recarga la aplicación (Ctrl/Cmd + R)';
    RAISE NOTICE '2. Deberías ver "Arquiproductos" en lugar de "No Company"';
    RAISE NOTICE '3. Deberías poder ver los Customers en el dropdown';
    RAISE NOTICE '==============================================';

END $$;

-- ====================================================
-- Verificar el resultado
-- ====================================================
SELECT 
    ou.id,
    o.organization_name,
    ou.role,
    ou.name,
    ou.email,
    ou.is_system,
    ou.deleted,
    dc.company_name as customer,
    dcon.customer_name as contact
FROM "OrganizationUsers" ou
JOIN "Organizations" o ON o.id = ou.organization_id
LEFT JOIN "DirectoryCustomers" dc ON dc.id = ou.customer_id
LEFT JOIN "DirectoryContacts" dcon ON dcon.id = ou.contact_id
WHERE ou.email = 'dpatino@arquiluz.studio'
  AND o.organization_name ILIKE '%Arquiproductos%'
ORDER BY ou.created_at DESC;

