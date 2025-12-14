-- ====================================================
-- DIAGNÓSTICO COMPLETO: VISIBILIDAD DE ORGANIZACIONES
-- ====================================================
-- Este script verifica TODO lo necesario para que
-- el usuario pueda ver su organización
-- ====================================================

DO $$
DECLARE
    user_email TEXT := 'dpatino@arquiluz.studio';
    user_id_from_auth uuid;
    org_id uuid;
    org_user_record RECORD;
    rls_enabled BOOLEAN;
    policy_count INTEGER;
    has_own_policy BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'DIAGNÓSTICO: VISIBILIDAD DE ORGANIZACIONES';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';

    -- ====================================================
    -- 1. Verificar usuario en auth.users
    -- ====================================================
    RAISE NOTICE '1. VERIFICANDO USUARIO EN auth.users...';
    
    SELECT id INTO user_id_from_auth
    FROM auth.users
    WHERE email = user_email
    LIMIT 1;

    IF user_id_from_auth IS NULL THEN
        RAISE NOTICE '   ❌ Usuario NO existe en auth.users';
        RAISE NOTICE '   ⚠️  Crea el usuario desde Supabase Dashboard primero';
        RETURN;
    END IF;

    RAISE NOTICE '   ✅ Usuario existe: %', user_id_from_auth;
    RAISE NOTICE '';

    -- ====================================================
    -- 2. Verificar organización
    -- ====================================================
    RAISE NOTICE '2. VERIFICANDO ORGANIZACIÓN...';
    
    SELECT id INTO org_id
    FROM "Organizations"
    WHERE organization_name ILIKE '%Arquiproductos%'
      AND deleted = false
    LIMIT 1;

    IF org_id IS NULL THEN
        RAISE NOTICE '   ❌ Organización NO encontrada';
        RETURN;
    END IF;

    RAISE NOTICE '   ✅ Organización encontrada: %', org_id;
    RAISE NOTICE '';

    -- ====================================================
    -- 3. Verificar registro en OrganizationUsers
    -- ====================================================
    RAISE NOTICE '3. VERIFICANDO REGISTRO EN OrganizationUsers...';
    
    SELECT 
        id,
        role,
        name,
        email,
        deleted,
        is_system,
        contact_id,
        customer_id
    INTO org_user_record
    FROM "OrganizationUsers"
    WHERE user_id = user_id_from_auth
      AND organization_id = org_id
    LIMIT 1;

    IF org_user_record IS NULL THEN
        RAISE NOTICE '   ❌ Registro NO existe en OrganizationUsers';
        RAISE NOTICE '   ⚠️  Ejecuta COMPLETE_FIX_AUTH_AND_ORG.sql para crearlo';
        RETURN;
    END IF;

    RAISE NOTICE '   ✅ Registro encontrado:';
    RAISE NOTICE '      ID: %', org_user_record.id;
    RAISE NOTICE '      Role: %', org_user_record.role;
    RAISE NOTICE '      Name: %', org_user_record.name;
    RAISE NOTICE '      Email: %', org_user_record.email;
    RAISE NOTICE '      Deleted: %', org_user_record.deleted;
    RAISE NOTICE '      Is System: %', org_user_record.is_system;
    RAISE NOTICE '      Contact ID: %', org_user_record.contact_id;
    RAISE NOTICE '      Customer ID: %', org_user_record.customer_id;
    RAISE NOTICE '';

    -- Verificar problemas potenciales
    IF org_user_record.deleted = true THEN
        RAISE NOTICE '   ⚠️  PROBLEMA: deleted = true (debe ser false)';
    END IF;

    IF org_user_record.contact_id IS NULL THEN
        RAISE NOTICE '   ⚠️  PROBLEMA: contact_id es NULL (debe tener valor)';
    END IF;

    IF org_user_record.customer_id IS NULL THEN
        RAISE NOTICE '   ⚠️  PROBLEMA: customer_id es NULL (debe tener valor)';
    END IF;

    RAISE NOTICE '';

    -- ====================================================
    -- 4. Verificar RLS y políticas
    -- ====================================================
    RAISE NOTICE '4. VERIFICANDO RLS Y POLÍTICAS...';
    
    SELECT relrowsecurity INTO rls_enabled 
    FROM pg_class 
    WHERE relname = 'OrganizationUsers';
    
    SELECT COUNT(*) INTO policy_count 
    FROM pg_policies 
    WHERE tablename = 'OrganizationUsers';
    
    SELECT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'OrganizationUsers' 
        AND policyname = 'organizationusers_select_own'
    ) INTO has_own_policy;

    RAISE NOTICE '   RLS Habilitado: %', rls_enabled;
    RAISE NOTICE '   Total Políticas: %', policy_count;
    RAISE NOTICE '   Política "organizationusers_select_own": %', has_own_policy;
    RAISE NOTICE '';

    IF NOT rls_enabled THEN
        RAISE NOTICE '   ⚠️  PROBLEMA: RLS NO está habilitado';
    END IF;

    IF NOT has_own_policy THEN
        RAISE NOTICE '   ⚠️  PROBLEMA: Falta política "organizationusers_select_own"';
        RAISE NOTICE '   ⚠️  Ejecuta FIX_RLS_FOR_SYSTEM_USERS.sql';
    END IF;

    RAISE NOTICE '';

    -- ====================================================
    -- 5. Simular query que hace OrganizationContext
    -- ====================================================
    RAISE NOTICE '5. SIMULANDO QUERY DE OrganizationContext...';
    RAISE NOTICE '   (Esta es la query que hace el frontend)';
    RAISE NOTICE '';

    DECLARE
        query_result RECORD;
        result_count INTEGER;
    BEGIN
        -- Simular la query exacta que hace OrganizationContext
        SELECT COUNT(*) INTO result_count
        FROM "OrganizationUsers" ou
        WHERE ou.user_id = user_id_from_auth
          AND ou.deleted = false;
          -- NOTA: No filtra por is_system (correcto)

        RAISE NOTICE '   Resultados encontrados: %', result_count;

        IF result_count = 0 THEN
            RAISE NOTICE '   ❌ PROBLEMA: La query NO devuelve resultados';
            RAISE NOTICE '   ⚠️  Esto significa que RLS está bloqueando el acceso';
            RAISE NOTICE '   ⚠️  Verifica que la política "organizationusers_select_own"';
            RAISE NOTICE '      NO filtre por is_system = false';
        ELSE
            RAISE NOTICE '   ✅ La query devuelve resultados';
            
            -- Mostrar el resultado
            FOR query_result IN
                SELECT 
                    ou.id,
                    ou.role,
                    o.id as org_id,
                    o.organization_name
                FROM "OrganizationUsers" ou
                JOIN "Organizations" o ON o.id = ou.organization_id
                WHERE ou.user_id = user_id_from_auth
                  AND ou.deleted = false
                LIMIT 5
            LOOP
                RAISE NOTICE '      - Organización: % (Role: %)', 
                    query_result.organization_name, 
                    query_result.role;
            END LOOP;
        END IF;
    END;

    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'RESUMEN:';
    RAISE NOTICE '==============================================';
    
    IF org_user_record IS NOT NULL 
       AND org_user_record.deleted = false 
       AND org_user_record.contact_id IS NOT NULL 
       AND org_user_record.customer_id IS NOT NULL
       AND rls_enabled = true
       AND has_own_policy = true THEN
        RAISE NOTICE '✅ TODO PARECE CORRECTO EN LA BASE DE DATOS';
        RAISE NOTICE '';
        RAISE NOTICE 'Si aún no ves la organización, el problema puede ser:';
        RAISE NOTICE '1. La sesión de autenticación no está activa';
        RAISE NOTICE '2. El frontend está usando datos en caché';
        RAISE NOTICE '3. Hay un error en el código del frontend';
        RAISE NOTICE '';
        RAISE NOTICE 'SOLUCIÓN:';
        RAISE NOTICE '1. Verifica en la consola del navegador (F12) los logs de OrganizationContext';
        RAISE NOTICE '2. Busca el log: "📊 OrganizationContext - Resultado query"';
        RAISE NOTICE '3. Si no hay sesión, haz logout y login nuevamente';
        RAISE NOTICE '4. Recarga con caché limpio (Ctrl/Cmd + Shift + R)';
    ELSE
        RAISE NOTICE '❌ HAY PROBLEMAS QUE DEBEN CORREGIRSE';
        RAISE NOTICE '   Revisa los problemas marcados arriba';
    END IF;
    
    RAISE NOTICE '==============================================';

END $$;

-- ====================================================
-- Query directa para verificar (sin RLS)
-- ====================================================
-- Esta query simula lo que debería ver el usuario
SELECT 
    ou.id,
    ou.email,
    ou.role,
    ou.name,
    ou.deleted,
    ou.is_system,
    o.id as org_id,
    o.organization_name
FROM "OrganizationUsers" ou
JOIN "Organizations" o ON o.id = ou.organization_id
WHERE ou.email = 'dpatino@arquiluz.studio'
  AND ou.deleted = false
ORDER BY ou.created_at DESC;

