-- ====================================================
-- Script SQL para poblar OrganizationUsers
-- Distribuye usuarios entre diferentes Customers y Contacts
-- ====================================================

DO $$
DECLARE
    org_id uuid;
    owner_user_id uuid;
    admin_user_id uuid;
    
    -- Variables para obtener Customer-Contact pairs
    customer_contact_pair RECORD;
    pair_index INTEGER;
    total_pairs INTEGER;
    current_customer_id uuid;
    current_contact_id uuid;
    
BEGIN
    -- ====================================================
    -- STEP 1: Buscar organización Arquiproductos
    -- ====================================================
    SELECT id INTO org_id
    FROM "Organizations"
    WHERE organization_name ILIKE '%Arquiproductos%'
      AND deleted = false
    LIMIT 1;

    IF org_id IS NULL THEN
        RAISE EXCEPTION '❌ ERROR: Organización Arquiproductos no encontrada.';
    END IF;

    -- Contar pares disponibles
    SELECT COUNT(*) INTO total_pairs
    FROM (
        SELECT DISTINCT dc.id, dcon.id
        FROM "DirectoryCustomers" dc
        INNER JOIN "DirectoryContacts" dcon ON dcon.customer_id = dc.id
        WHERE dc.organization_id = org_id
          AND dc.deleted = false
          AND dcon.deleted = false
          AND dcon.customer_id IS NOT NULL
    ) pairs;

    IF total_pairs = 0 THEN
        RAISE EXCEPTION '❌ ERROR: No hay Customers con Contacts asignados.';
    END IF;

    RAISE NOTICE '✅ Encontrados % pares Customer-Contact', total_pairs;

    -- Función helper inline para obtener pair por índice
    -- Owner (índice 1)
    SELECT 
        ranked.customer_id,
        ranked.contact_id
    INTO current_customer_id, current_contact_id
    FROM (
        SELECT DISTINCT
            dc.id as customer_id,
            dcon.id as contact_id,
            ROW_NUMBER() OVER (ORDER BY dc.created_at, dcon.created_at) as row_num
        FROM "DirectoryCustomers" dc
        INNER JOIN "DirectoryContacts" dcon ON dcon.customer_id = dc.id
        WHERE dc.organization_id = org_id
          AND dc.deleted = false
          AND dcon.deleted = false
          AND dcon.customer_id IS NOT NULL
    ) ranked
    WHERE ranked.row_num = ((1 - 1) % total_pairs) + 1
    LIMIT 1;

    owner_user_id := gen_random_uuid();
    
    INSERT INTO "OrganizationUsers" (
        id, organization_id, user_id, name, email, role,
        contact_id, customer_id, created_at, updated_at, deleted
        ) VALUES (
        gen_random_uuid(), org_id, owner_user_id,
        'Carlos Arquitecto', 'carlos.arquitecto@arquiproductos.com', 'owner',
        current_contact_id, current_customer_id,
        now() - INTERVAL '365 days', now() - INTERVAL '365 days', false
    )
    ON CONFLICT DO NOTHING;

    SELECT user_id INTO owner_user_id
    FROM "OrganizationUsers"
    WHERE organization_id = org_id AND role = 'owner' AND deleted = false
    LIMIT 1;

    -- Admins (índices 2 y 3)
    FOR pair_index IN 2..3 LOOP
        SELECT 
            ranked.customer_id,
            ranked.contact_id
        INTO current_customer_id, current_contact_id
        FROM (
            SELECT DISTINCT
                dc.id as customer_id,
                dcon.id as contact_id,
                ROW_NUMBER() OVER (ORDER BY dc.created_at, dcon.created_at) as row_num
            FROM "DirectoryCustomers" dc
            INNER JOIN "DirectoryContacts" dcon ON dcon.customer_id = dc.id
            WHERE dc.organization_id = org_id
              AND dc.deleted = false
              AND dcon.deleted = false
              AND dcon.customer_id IS NOT NULL
        ) ranked
        WHERE ranked.row_num = ((pair_index - 1) % total_pairs) + 1
        LIMIT 1;

        IF pair_index = 2 THEN
    admin_user_id := gen_random_uuid();
    INSERT INTO "OrganizationUsers" (
                id, organization_id, user_id, name, email, role,
                contact_id, customer_id, invited_by,
                created_at, updated_at, deleted
            ) VALUES (
                gen_random_uuid(), org_id, admin_user_id,
                'María González', 'maria.gonzalez@arquiproductos.com', 'admin',
                current_contact_id, current_customer_id,
            owner_user_id,
                now() - INTERVAL '300 days', now() - INTERVAL '300 days', false
            )
            ON CONFLICT DO NOTHING;
        ELSE
            INSERT INTO "OrganizationUsers" (
                id, organization_id, user_id, name, email, role,
                contact_id, customer_id, invited_by,
                created_at, updated_at, deleted
            ) VALUES (
                gen_random_uuid(), org_id, gen_random_uuid(),
                'Juan Pérez', 'juan.perez@arquiproductos.com', 'admin',
                current_contact_id, current_customer_id,
            owner_user_id,
                now() - INTERVAL '250 days', now() - INTERVAL '250 days', false
    )
    ON CONFLICT DO NOTHING;
        END IF;
    END LOOP;

    SELECT user_id INTO admin_user_id
    FROM "OrganizationUsers"
    WHERE organization_id = org_id AND role = 'admin' AND deleted = false
    LIMIT 1;

    -- Members (índices 4-7)
    FOR pair_index IN 4..7 LOOP
        SELECT 
            ranked.customer_id,
            ranked.contact_id
        INTO current_customer_id, current_contact_id
        FROM (
            SELECT DISTINCT
                dc.id as customer_id,
                dcon.id as contact_id,
                ROW_NUMBER() OVER (ORDER BY dc.created_at, dcon.created_at) as row_num
            FROM "DirectoryCustomers" dc
            INNER JOIN "DirectoryContacts" dcon ON dcon.customer_id = dc.id
            WHERE dc.organization_id = org_id
              AND dc.deleted = false
              AND dcon.deleted = false
              AND dcon.customer_id IS NOT NULL
        ) ranked
        WHERE ranked.row_num = ((pair_index - 1) % total_pairs) + 1
        LIMIT 1;

    INSERT INTO "OrganizationUsers" (
            id, organization_id, user_id, name, email, role,
            contact_id, customer_id, invited_by,
            created_at, updated_at, deleted
        ) VALUES (
            gen_random_uuid(), org_id, gen_random_uuid(),
            CASE pair_index
                WHEN 4 THEN 'Ana Martínez'
                WHEN 5 THEN 'Luis Rodríguez'
                WHEN 6 THEN 'Sofía Hernández'
                WHEN 7 THEN 'Roberto Sánchez'
            END,
            CASE pair_index
                WHEN 4 THEN 'ana.martinez@arquiproductos.com'
                WHEN 5 THEN 'luis.rodriguez@arquiproductos.com'
                WHEN 6 THEN 'sofia.hernandez@arquiproductos.com'
                WHEN 7 THEN 'roberto.sanchez@arquiproductos.com'
            END,
            'member',
            current_contact_id, current_customer_id,
            admin_user_id,
            now() - INTERVAL '1 day' * (200 - (pair_index - 4) * 20),
            now() - INTERVAL '1 day' * (200 - (pair_index - 4) * 20),
            false
    )
    ON CONFLICT DO NOTHING;
    END LOOP;

    -- Viewers (índices 8-10)
    FOR pair_index IN 8..10 LOOP
        SELECT 
            ranked.customer_id,
            ranked.contact_id
        INTO current_customer_id, current_contact_id
        FROM (
            SELECT DISTINCT
                dc.id as customer_id,
                dcon.id as contact_id,
                ROW_NUMBER() OVER (ORDER BY dc.created_at, dcon.created_at) as row_num
            FROM "DirectoryCustomers" dc
            INNER JOIN "DirectoryContacts" dcon ON dcon.customer_id = dc.id
            WHERE dc.organization_id = org_id
              AND dc.deleted = false
              AND dcon.deleted = false
              AND dcon.customer_id IS NOT NULL
        ) ranked
        WHERE ranked.row_num = ((pair_index - 1) % total_pairs) + 1
        LIMIT 1;

    INSERT INTO "OrganizationUsers" (
            id, organization_id, user_id, name, email, role,
            contact_id, customer_id, invited_by,
            created_at, updated_at, deleted
        ) VALUES (
            gen_random_uuid(), org_id, gen_random_uuid(),
            CASE pair_index
                WHEN 8 THEN 'Carmen López'
                WHEN 9 THEN 'Diego Morales'
                WHEN 10 THEN 'Patricia Ramírez'
            END,
            CASE pair_index
                WHEN 8 THEN 'carmen.lopez@arquiproductos.com'
                WHEN 9 THEN 'diego.morales@arquiproductos.com'
                WHEN 10 THEN 'patricia.ramirez@arquiproductos.com'
            END,
            'viewer',
            current_contact_id, current_customer_id,
            admin_user_id,
            now() - INTERVAL '1 day' * (90 - (pair_index - 8) * 30),
            now() - INTERVAL '1 day' * (90 - (pair_index - 8) * 30),
            false
    )
    ON CONFLICT DO NOTHING;
    END LOOP;

    RAISE NOTICE '✅ OrganizationUsers creados distribuyendo entre % pares Customer-Contact', total_pairs;

END $$;

-- Verificar resultados
SELECT 
    ou.name,
    ou.email,
    ou.role,
    dc.company_name as customer,
    dcon.customer_name as contact,
    ou.created_at
FROM "OrganizationUsers" ou
JOIN "Organizations" o ON o.id = ou.organization_id
LEFT JOIN "DirectoryCustomers" dc ON dc.id = ou.customer_id
LEFT JOIN "DirectoryContacts" dcon ON dcon.id = ou.contact_id
WHERE o.organization_name ILIKE '%Arquiproductos%'
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
