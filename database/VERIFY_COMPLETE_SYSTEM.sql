-- ====================================================
-- SCRIPT DE VERIFICACIÓN DEL SISTEMA COMPLETO
-- ====================================================
-- Este script verifica que todo el sistema de Organization Users
-- esté configurado correctamente después de ejecutar los scripts principales
-- ====================================================

DO $$
DECLARE
    rls_enabled_ou BOOLEAN;
    rls_enabled_customers BOOLEAN;
    rls_enabled_contacts BOOLEAN;
    rls_enabled_vendors BOOLEAN;
    
    policies_ou INTEGER;
    policies_customers INTEGER;
    policies_contacts INTEGER;
    policies_vendors INTEGER;
    
    functions_count INTEGER;
    
    has_is_system BOOLEAN;
    has_contact_id BOOLEAN;
    has_customer_id BOOLEAN;
    has_primary_contact_id_vendors BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'VERIFICACIÓN DEL SISTEMA DE ORGANIZATION USERS';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';

    -- ====================================================
    -- 1. Verificar estructura de OrganizationUsers
    -- ====================================================
    RAISE NOTICE '1. VERIFICANDO ESTRUCTURA DE TABLAS...';
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'OrganizationUsers' 
        AND column_name = 'is_system'
    ) INTO has_is_system;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'OrganizationUsers' 
        AND column_name = 'contact_id'
    ) INTO has_contact_id;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'OrganizationUsers' 
        AND column_name = 'customer_id'
    ) INTO has_customer_id;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'DirectoryVendors' 
        AND column_name = 'primary_contact_id'
    ) INTO has_primary_contact_id_vendors;
    
    IF has_is_system AND has_contact_id AND has_customer_id THEN
        RAISE NOTICE '   ✅ OrganizationUsers: Estructura correcta';
    ELSE
        RAISE NOTICE '   ❌ OrganizationUsers: Faltan columnas';
        RAISE NOTICE '      is_system: %', has_is_system;
        RAISE NOTICE '      contact_id: %', has_contact_id;
        RAISE NOTICE '      customer_id: %', has_customer_id;
    END IF;
    
    IF has_primary_contact_id_vendors THEN
        RAISE NOTICE '   ✅ DirectoryVendors: primary_contact_id existe';
    ELSE
        RAISE NOTICE '   ❌ DirectoryVendors: primary_contact_id NO existe';
    END IF;
    
    RAISE NOTICE '';

    -- ====================================================
    -- 2. Verificar RLS habilitado
    -- ====================================================
    RAISE NOTICE '2. VERIFICANDO RLS...';
    
    SELECT relrowsecurity INTO rls_enabled_ou 
    FROM pg_class WHERE relname = 'OrganizationUsers';
    
    SELECT relrowsecurity INTO rls_enabled_customers 
    FROM pg_class WHERE relname = 'DirectoryCustomers';
    
    SELECT relrowsecurity INTO rls_enabled_contacts 
    FROM pg_class WHERE relname = 'DirectoryContacts';
    
    SELECT relrowsecurity INTO rls_enabled_vendors 
    FROM pg_class WHERE relname = 'DirectoryVendors';
    
    IF rls_enabled_ou THEN
        RAISE NOTICE '   ✅ OrganizationUsers: RLS habilitado';
    ELSE
        RAISE NOTICE '   ❌ OrganizationUsers: RLS NO habilitado';
    END IF;
    
    IF rls_enabled_customers THEN
        RAISE NOTICE '   ✅ DirectoryCustomers: RLS habilitado';
    ELSE
        RAISE NOTICE '   ❌ DirectoryCustomers: RLS NO habilitado';
    END IF;
    
    IF rls_enabled_contacts THEN
        RAISE NOTICE '   ✅ DirectoryContacts: RLS habilitado';
    ELSE
        RAISE NOTICE '   ❌ DirectoryContacts: RLS NO habilitado';
    END IF;
    
    IF rls_enabled_vendors THEN
        RAISE NOTICE '   ✅ DirectoryVendors: RLS habilitado';
    ELSE
        RAISE NOTICE '   ❌ DirectoryVendors: RLS NO habilitado';
    END IF;
    
    RAISE NOTICE '';

    -- ====================================================
    -- 3. Verificar políticas RLS
    -- ====================================================
    RAISE NOTICE '3. VERIFICANDO POLÍTICAS RLS...';
    
    SELECT COUNT(*) INTO policies_ou 
    FROM pg_policies 
    WHERE tablename = 'OrganizationUsers';
    
    SELECT COUNT(*) INTO policies_customers 
    FROM pg_policies 
    WHERE tablename = 'DirectoryCustomers';
    
    SELECT COUNT(*) INTO policies_contacts 
    FROM pg_policies 
    WHERE tablename = 'DirectoryContacts';
    
    SELECT COUNT(*) INTO policies_vendors 
    FROM pg_policies 
    WHERE tablename = 'DirectoryVendors';
    
    RAISE NOTICE '   OrganizationUsers: % políticas', policies_ou;
    IF policies_ou >= 9 THEN
        RAISE NOTICE '      ✅ Políticas suficientes (esperado: 9+)';
    ELSE
        RAISE NOTICE '      ⚠️ Políticas insuficientes (esperado: 9+)';
    END IF;
    
    RAISE NOTICE '   DirectoryCustomers: % políticas', policies_customers;
    IF policies_customers >= 6 THEN
        RAISE NOTICE '      ✅ Políticas suficientes (esperado: 6+)';
    ELSE
        RAISE NOTICE '      ⚠️ Políticas insuficientes (esperado: 6+)';
    END IF;
    
    RAISE NOTICE '   DirectoryContacts: % políticas', policies_contacts;
    IF policies_contacts >= 6 THEN
        RAISE NOTICE '      ✅ Políticas suficientes (esperado: 6+)';
    ELSE
        RAISE NOTICE '      ⚠️ Políticas insuficientes (esperado: 6+)';
    END IF;
    
    RAISE NOTICE '   DirectoryVendors: % políticas', policies_vendors;
    IF policies_vendors >= 6 THEN
        RAISE NOTICE '      ✅ Políticas suficientes (esperado: 6+)';
    ELSE
        RAISE NOTICE '      ⚠️ Políticas insuficientes (esperado: 6+)';
    END IF;
    
    RAISE NOTICE '';

    -- ====================================================
    -- 4. Verificar funciones helper
    -- ====================================================
    RAISE NOTICE '4. VERIFICANDO FUNCIONES HELPER...';
    
    SELECT COUNT(*) INTO functions_count
    FROM pg_proc
    WHERE proname IN (
        'is_super_admin',
        'is_owner',
        'is_admin',
        'get_user_customer_id',
        'can_manage_organization_users',
        'can_insert_organization_user',
        'can_view_organization_user',
        'get_current_user_customer_id',
        'can_access_customer'
    )
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
    
    RAISE NOTICE '   Funciones helper encontradas: %', functions_count;
    IF functions_count >= 7 THEN
        RAISE NOTICE '      ✅ Funciones suficientes (esperado: 7+)';
    ELSE
        RAISE NOTICE '      ⚠️ Funciones insuficientes (esperado: 7+)';
    END IF;
    
    RAISE NOTICE '';

    -- ====================================================
    -- 5. Verificar usuarios existentes
    -- ====================================================
    RAISE NOTICE '5. VERIFICANDO USUARIOS EXISTENTES...';
    
    DECLARE
        total_users INTEGER;
        users_with_contact INTEGER;
        users_with_customer INTEGER;
        users_by_role RECORD;
    BEGIN
        SELECT COUNT(*) INTO total_users
        FROM "OrganizationUsers"
        WHERE deleted = false;
        
        SELECT COUNT(*) INTO users_with_contact
        FROM "OrganizationUsers"
        WHERE deleted = false
          AND contact_id IS NOT NULL;
        
        SELECT COUNT(*) INTO users_with_customer
        FROM "OrganizationUsers"
        WHERE deleted = false
          AND customer_id IS NOT NULL;
        
        RAISE NOTICE '   Total usuarios activos: %', total_users;
        RAISE NOTICE '   Usuarios con contact_id: %', users_with_contact;
        RAISE NOTICE '   Usuarios con customer_id: %', users_with_customer;
        
        IF users_with_contact = total_users AND users_with_customer = total_users THEN
            RAISE NOTICE '      ✅ Todos los usuarios tienen contact_id y customer_id';
        ELSE
            RAISE NOTICE '      ⚠️ Algunos usuarios no tienen contact_id o customer_id';
        END IF;
        
        RAISE NOTICE '';
        RAISE NOTICE '   Distribución por rol:';
        FOR users_by_role IN
            SELECT role, COUNT(*) as count
            FROM "OrganizationUsers"
            WHERE deleted = false
            GROUP BY role
            ORDER BY 
                CASE role
                    WHEN 'owner' THEN 1
                    WHEN 'admin' THEN 2
                    WHEN 'member' THEN 3
                    WHEN 'viewer' THEN 4
                    ELSE 5
                END
        LOOP
            RAISE NOTICE '      %: % usuarios', users_by_role.role, users_by_role.count;
        END LOOP;
    END;
    
    RAISE NOTICE '';

    -- ====================================================
    -- RESUMEN FINAL
    -- ====================================================
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'RESUMEN FINAL:';
    RAISE NOTICE '==============================================';
    
    IF has_is_system AND has_contact_id AND has_customer_id 
       AND rls_enabled_ou AND rls_enabled_customers AND rls_enabled_contacts AND rls_enabled_vendors
       AND policies_ou >= 9 AND policies_customers >= 6 AND policies_contacts >= 6 AND policies_vendors >= 6
       AND functions_count >= 7 THEN
        RAISE NOTICE '✅ SISTEMA CONFIGURADO CORRECTAMENTE';
        RAISE NOTICE '';
        RAISE NOTICE 'Próximos pasos:';
        RAISE NOTICE '1. Recargar la aplicación (Ctrl/Cmd + R)';
        RAISE NOTICE '2. Verificar que puedes ver tu organización';
        RAISE NOTICE '3. Probar crear un usuario con rol "admin"';
        RAISE NOTICE '4. Verificar que Admin solo ve su Customer asignado';
        RAISE NOTICE '5. Probar crear un usuario con rol "member"';
        RAISE NOTICE '6. Verificar que Member puede crear quotes pero no editar customers';
    ELSE
        RAISE NOTICE '❌ CONFIGURACIÓN INCOMPLETA';
        RAISE NOTICE '';
        RAISE NOTICE 'Revisa los errores arriba y ejecuta los scripts necesarios:';
        RAISE NOTICE '- COMPLETE_ORGANIZATION_USERS_SYSTEM.sql';
        RAISE NOTICE '- RLS_POLICIES_FOR_DIRECTORY_TABLES.sql';
    END IF;
    
    RAISE NOTICE '==============================================';
    
END $$;

