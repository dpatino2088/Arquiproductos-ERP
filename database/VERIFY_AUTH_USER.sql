-- ====================================================
-- VERIFICAR USUARIO EN auth.users
-- ====================================================
-- Este script verifica si el usuario existe en auth.users
-- y muestra información relevante
-- ====================================================

DO $$
DECLARE
    user_email_1 TEXT := 'dpatino@arquiluz.studio';
    user_email_2 TEXT := 'dpatino@grupo927.com';
    user_record RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'VERIFICACIÓN DE USUARIOS EN auth.users';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';

    -- Buscar primer email
    RAISE NOTICE '1. Buscando usuario: %', user_email_1;
    SELECT 
        id,
        email,
        created_at,
        email_confirmed_at,
        last_sign_in_at,
        raw_user_meta_data
    INTO user_record
    FROM auth.users
    WHERE email = user_email_1
    LIMIT 1;

    IF user_record IS NOT NULL THEN
        RAISE NOTICE '   ✅ Usuario encontrado:';
        RAISE NOTICE '      ID: %', user_record.id;
        RAISE NOTICE '      Email: %', user_record.email;
        RAISE NOTICE '      Creado: %', user_record.created_at;
        RAISE NOTICE '      Email confirmado: %', COALESCE(user_record.email_confirmed_at::text, 'NO');
        RAISE NOTICE '      Último login: %', COALESCE(user_record.last_sign_in_at::text, 'Nunca');
        RAISE NOTICE '      Metadata: %', user_record.raw_user_meta_data;
    ELSE
        RAISE NOTICE '   ❌ Usuario NO encontrado con email: %', user_email_1;
    END IF;

    RAISE NOTICE '';

    -- Buscar segundo email
    RAISE NOTICE '2. Buscando usuario: %', user_email_2;
    SELECT 
        id,
        email,
        created_at,
        email_confirmed_at,
        last_sign_in_at,
        raw_user_meta_data
    INTO user_record
    FROM auth.users
    WHERE email = user_email_2
    LIMIT 1;

    IF user_record IS NOT NULL THEN
        RAISE NOTICE '   ✅ Usuario encontrado:';
        RAISE NOTICE '      ID: %', user_record.id;
        RAISE NOTICE '      Email: %', user_record.email;
        RAISE NOTICE '      Creado: %', user_record.created_at;
        RAISE NOTICE '      Email confirmado: %', COALESCE(user_record.email_confirmed_at::text, 'NO');
        RAISE NOTICE '      Último login: %', COALESCE(user_record.last_sign_in_at::text, 'Nunca');
        RAISE NOTICE '      Metadata: %', user_record.raw_user_meta_data;
    ELSE
        RAISE NOTICE '   ❌ Usuario NO encontrado con email: %', user_email_2;
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'NOTA:';
    RAISE NOTICE 'Si el usuario NO existe, necesitas crearlo primero.';
    RAISE NOTICE 'Si el usuario existe pero no puede hacer login,';
    RAISE NOTICE 'puede ser que la contraseña sea incorrecta o';
    RAISE NOTICE 'que el email no esté confirmado.';
    RAISE NOTICE '==============================================';

END $$;

-- ====================================================
-- Listar todos los usuarios en auth.users (últimos 10)
-- ====================================================
SELECT 
    id,
    email,
    created_at,
    email_confirmed_at,
    last_sign_in_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 10;

