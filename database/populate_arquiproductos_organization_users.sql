-- ====================================================
-- Script SQL para poblar datos dummy de OrganizationUsers
-- para la organización Arquiproductos, S.A.
-- ====================================================

-- ====================================================
-- STEP 1: Crear o verificar la organización Arquiproductos, S.A.
-- ====================================================

-- Primero, verificar si la organización ya existe
DO $$
DECLARE
    org_id uuid;
    owner_user_id uuid;
    admin_user_id uuid;
BEGIN
    -- Buscar organización existente por nombre o tax_id
    -- Nota: La columna puede ser "name" o "organization_name", ajustar según tu esquema
    SELECT id INTO org_id
    FROM "Organizations"
    WHERE (
        (organization_name ILIKE '%Arquiproductos%' OR name ILIKE '%Arquiproductos%')
        OR tax_id = '1234567890-DV10'
    )
      AND deleted = false
    LIMIT 1;

    -- Si no existe, crearla
    IF org_id IS NULL THEN
        -- Crear la organización
        INSERT INTO "Organizations" (
            id,
            organization_name,
            legal_name,
            tax_id,
            country,
            main_email,
            phone_number,
            address_line_1,
            city,
            state,
            zip_code,
            tier,
            status,
            default_currency,
            default_locale,
            created_at,
            updated_at,
            deleted,
            archived
        ) VALUES (
            gen_random_uuid(),
            'Arquiproductos',
            'Arquiproductos, S.A.',
            '1234567890-DV10',
            'Panama',
            'info@arquiproductos.com',
            '+507 1234-5678',
            'Calle Principal 123',
            'Panama City',
            'Panama',
            '0801',
            'pro',
            'active',
            'USD',
            'es-PA',
            now(),
            now(),
            false,
            false
        )
        RETURNING id INTO org_id;
        
        RAISE NOTICE 'Organización Arquiproductos, S.A. creada con ID: %', org_id;
    ELSE
        RAISE NOTICE 'Organización Arquiproductos, S.A. ya existe con ID: %', org_id;
    END IF;

    -- ====================================================
    -- STEP 2: Crear OrganizationUsers dummy
    -- Nota: Estos user_ids son UUIDs dummy. 
    -- Necesitarás crear los usuarios reales en auth.users
    -- o usar la Edge Function invite-user-to-organization
    -- ====================================================

    -- Limpiar OrganizationUsers existentes para esta organización (opcional, comentar si no quieres borrar)
    -- DELETE FROM "OrganizationUsers" WHERE organization_id = org_id;

    -- Primero crear el Owner
    owner_user_id := gen_random_uuid();
    
    INSERT INTO "OrganizationUsers" (
            id,
            organization_id,
            user_id,
            name,
            email,
            role,
            invited_by,
            created_at,
            updated_at,
            deleted
        ) VALUES (
            gen_random_uuid(),
            org_id,
            owner_user_id,
            'Carlos Arquitecto',
            'carlos.arquitecto@arquiproductos.com',
            'owner',
            NULL,
            now() - INTERVAL '365 days',
            now() - INTERVAL '365 days',
            false
    )
    ON CONFLICT DO NOTHING;

    -- Obtener el owner_user_id real si ya existía
    SELECT user_id INTO owner_user_id
    FROM "OrganizationUsers"
    WHERE organization_id = org_id AND role = 'owner' AND deleted = false
    LIMIT 1;

    -- Crear Admins
    admin_user_id := gen_random_uuid();
    
    INSERT INTO "OrganizationUsers" (
            id,
            organization_id,
            user_id,
            name,
            email,
            role,
            invited_by,
            created_at,
            updated_at,
            deleted
        ) VALUES
        (
            gen_random_uuid(),
            org_id,
            admin_user_id,
            'María González',
            'maria.gonzalez@arquiproductos.com',
            'admin',
            owner_user_id,
            now() - INTERVAL '300 days',
            now() - INTERVAL '300 days',
            false
        ),
        (
            gen_random_uuid(),
            org_id,
            gen_random_uuid(),
            'Juan Pérez',
            'juan.perez@arquiproductos.com',
            'admin',
            owner_user_id,
            now() - INTERVAL '250 days',
            now() - INTERVAL '250 days',
            false
    )
    ON CONFLICT DO NOTHING;

    -- Obtener un admin_user_id para usar como invited_by
    SELECT user_id INTO admin_user_id
    FROM "OrganizationUsers"
    WHERE organization_id = org_id AND role = 'admin' AND deleted = false
    LIMIT 1;

    -- Crear Members
    INSERT INTO "OrganizationUsers" (
            id,
            organization_id,
            user_id,
            name,
            email,
            role,
            invited_by,
            created_at,
            updated_at,
            deleted
        ) VALUES
        (
            gen_random_uuid(),
            org_id,
            gen_random_uuid(),
            'Ana Martínez',
            'ana.martinez@arquiproductos.com',
            'member',
            admin_user_id,
            now() - INTERVAL '200 days',
            now() - INTERVAL '200 days',
            false
        ),
        (
            gen_random_uuid(),
            org_id,
            gen_random_uuid(),
            'Luis Rodríguez',
            'luis.rodriguez@arquiproductos.com',
            'member',
            admin_user_id,
            now() - INTERVAL '180 days',
            now() - INTERVAL '180 days',
            false
        ),
        (
            gen_random_uuid(),
            org_id,
            gen_random_uuid(),
            'Sofía Hernández',
            'sofia.hernandez@arquiproductos.com',
            'member',
            admin_user_id,
            now() - INTERVAL '150 days',
            now() - INTERVAL '150 days',
            false
        ),
        (
            gen_random_uuid(),
            org_id,
            gen_random_uuid(),
            'Roberto Sánchez',
            'roberto.sanchez@arquiproductos.com',
            'member',
            admin_user_id,
            now() - INTERVAL '120 days',
            now() - INTERVAL '120 days',
            false
    )
    ON CONFLICT DO NOTHING;

    -- Crear Viewers
    INSERT INTO "OrganizationUsers" (
            id,
            organization_id,
            user_id,
            name,
            email,
            role,
            invited_by,
            created_at,
            updated_at,
            deleted
        ) VALUES
        (
            gen_random_uuid(),
            org_id,
            gen_random_uuid(),
            'Carmen López',
            'carmen.lopez@arquiproductos.com',
            'viewer',
            admin_user_id,
            now() - INTERVAL '90 days',
            now() - INTERVAL '90 days',
            false
        ),
        (
            gen_random_uuid(),
            org_id,
            gen_random_uuid(),
            'Diego Morales',
            'diego.morales@arquiproductos.com',
            'viewer',
            admin_user_id,
            now() - INTERVAL '60 days',
            now() - INTERVAL '60 days',
            false
        ),
        (
            gen_random_uuid(),
            org_id,
            gen_random_uuid(),
            'Patricia Ramírez',
            'patricia.ramirez@arquiproductos.com',
            'viewer',
            admin_user_id,
            now() - INTERVAL '30 days',
            now() - INTERVAL '30 days',
            false
    )
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'OrganizationUsers creados para Arquiproductos, S.A.';
    RAISE NOTICE 'IMPORTANTE: Los user_ids son UUIDs dummy. Necesitas:';
    RAISE NOTICE '1. Crear los usuarios reales en auth.users usando la Edge Function invite-user-to-organization';
    RAISE NOTICE '2. O actualizar los user_ids en OrganizationUsers con los UUIDs reales de auth.users';

END $$;

-- ====================================================
-- STEP 3: Verificar los datos creados
-- ====================================================

SELECT 
    COALESCE(o.organization_name, o.name) as organization_name,
    o.legal_name,
    o.tax_id,
    COUNT(ou.id) as total_users,
    COUNT(CASE WHEN ou.role = 'owner' THEN 1 END) as owners,
    COUNT(CASE WHEN ou.role = 'admin' THEN 1 END) as admins,
    COUNT(CASE WHEN ou.role = 'member' THEN 1 END) as members,
    COUNT(CASE WHEN ou.role = 'viewer' THEN 1 END) as viewers
FROM "Organizations" o
LEFT JOIN "OrganizationUsers" ou ON ou.organization_id = o.id AND ou.deleted = false
WHERE (COALESCE(o.organization_name, o.name) = 'Arquiproductos' OR o.tax_id = '1234567890-DV10')
  AND o.deleted = false
GROUP BY o.id, COALESCE(o.organization_name, o.name), o.legal_name, o.tax_id;

-- Mostrar los OrganizationUsers creados
SELECT 
    ou.name,
    ou.email,
    ou.role,
    ou.created_at,
    CASE 
        WHEN EXISTS (SELECT 1 FROM auth.users WHERE id = ou.user_id) THEN 'Usuario existe en auth.users'
        ELSE '⚠️ Usuario NO existe en auth.users (user_id dummy)'
    END as user_status
FROM "OrganizationUsers" ou
JOIN "Organizations" o ON o.id = ou.organization_id
WHERE (COALESCE(o.organization_name, o.name) = 'Arquiproductos' OR o.tax_id = '1234567890-DV10')
  AND ou.deleted = false
  AND o.deleted = false
ORDER BY 
    CASE ou.role 
        WHEN 'owner' THEN 1
        WHEN 'admin' THEN 2
        WHEN 'member' THEN 3
        WHEN 'viewer' THEN 4
    END,
    ou.created_at;

