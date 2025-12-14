-- ====================================================
-- CORREGIR POLÍTICA RLS PARA USUARIOS DEL SISTEMA
-- ====================================================
-- Este script corrige la política RLS para que los usuarios
-- con is_system = true puedan ver su propio registro y su organización
-- ====================================================

-- Eliminar política antigua
DROP POLICY IF EXISTS "organizationusers_select_own" ON "OrganizationUsers";

-- Crear política nueva que permite ver el registro propio incluso si is_system = true
CREATE POLICY "organizationusers_select_own"
ON "OrganizationUsers"
FOR SELECT
USING (
    user_id = auth.uid()
    -- NO filtramos por is_system aquí porque el usuario necesita ver su organización
    -- El filtro is_system solo se usa para ocultar usuarios en las LISTAS, no para ocultar organizaciones
);

DO $$ BEGIN
    RAISE NOTICE '✅ Política RLS corregida: Los usuarios pueden ver su propio registro incluso si is_system = true';
    RAISE NOTICE '';
    RAISE NOTICE 'Ahora ejecuta: FIX_USER_NAME_AND_VERIFY.sql para corregir el nombre';
END $$;

