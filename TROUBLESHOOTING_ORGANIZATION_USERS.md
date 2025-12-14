# 🔧 Troubleshooting: Creación de Usuarios en OrganizationUsers

## Problema
No se pueden crear usuarios en la organización. Los usuarios no se guardan correctamente.

## Checklist de Diagnóstico

### 1. Verificar que tienes permisos adecuados
```sql
-- Verificar tu rol en la organización
SELECT 
    ou.name,
    ou.email,
    ou.role,
    o.organization_name
FROM "OrganizationUsers" ou
JOIN "Organizations" o ON o.id = ou.organization_id
WHERE ou.email = 'TU_EMAIL_AQUI'
  AND ou.deleted = false
  AND o.deleted = false;
```

**Resultado esperado**: Deberías tener rol `owner` o `admin`.

### 2. Verificar que las políticas RLS están correctas
```sql
-- Ver todas las políticas de OrganizationUsers
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'OrganizationUsers';
```

**Resultado esperado**: Deberías ver al menos estas políticas:
- `organizationusers_insert_owners_admins` (para INSERT)
- `organizationusers_select_own` (para SELECT)
- `organizationusers_select_org_admins` (para SELECT)

### 3. Verificar que los Customers y Contacts existen
```sql
-- Ver Customers disponibles
SELECT 
    id,
    company_name,
    email,
    created_at
FROM "DirectoryCustomers"
WHERE organization_id = 'TU_ORGANIZATION_ID_AQUI'
  AND deleted = false
ORDER BY created_at DESC;

-- Ver Contacts con customer_id asignado
SELECT 
    dc.id as contact_id,
    dc.customer_name,
    dc.email,
    dcu.id as customer_id,
    dcu.company_name
FROM "DirectoryContacts" dc
INNER JOIN "DirectoryCustomers" dcu ON dcu.id = dc.customer_id
WHERE dc.organization_id = 'TU_ORGANIZATION_ID_AQUI'
  AND dc.deleted = false
  AND dcu.deleted = false
ORDER BY dc.created_at DESC;
```

### 4. Verificar que la columna is_system existe
```sql
-- Verificar que la columna is_system existe
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'OrganizationUsers'
  AND column_name = 'is_system';
```

**Resultado esperado**: Debería mostrar la columna `is_system` de tipo `boolean`.

Si no existe, ejecuta:
```sql
ALTER TABLE "OrganizationUsers"
  ADD COLUMN IF NOT EXISTS is_system BOOLEAN DEFAULT false;
```

### 5. Probar inserción manual
```sql
-- Intentar crear un usuario manualmente
-- Reemplaza los valores con datos reales
INSERT INTO "OrganizationUsers" (
    id,
    organization_id,
    user_id,
    role,
    name,
    email,
    contact_id,
    customer_id,
    invited_by,
    deleted,
    is_system
) VALUES (
    gen_random_uuid(),
    'TU_ORGANIZATION_ID',  -- Reemplaza con tu organization_id
    gen_random_uuid(),      -- user_id temporal
    'member',
    'Test User',
    'test@example.com',
    'TU_CONTACT_ID',        -- Reemplaza con un contact_id real
    'TU_CUSTOMER_ID',       -- Reemplaza con un customer_id real
    'TU_USER_ID',           -- Tu user_id (auth.uid())
    false,
    false
);
```

Si este INSERT falla, revisa el mensaje de error:
- **"violates foreign key constraint"**: El customer_id o contact_id no existen
- **"permission denied"**: Tu usuario no tiene permisos de INSERT (problema de RLS)
- **"violates check constraint"**: El trigger de validación está bloqueando la inserción

### 6. Verificar el trigger de validación
```sql
-- Ver si el trigger está activo
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'OrganizationUsers'
  AND trigger_name = 'check_organization_user_customer_contact';
```

### 7. Ver logs de errores en la aplicación
Abre la consola del navegador (F12) y busca:
- Mensajes de error en la pestaña "Console"
- Peticiones fallidas en la pestaña "Network"
- Busca específicamente errores con código 400, 403, 404, 500

## Soluciones Comunes

### Solución 1: No tienes rol owner/admin
```sql
-- Actualizar tu rol a owner
UPDATE "OrganizationUsers"
SET role = 'owner'
WHERE email = 'TU_EMAIL'
  AND organization_id = 'TU_ORGANIZATION_ID'
  AND deleted = false;
```

### Solución 2: El Contact no pertenece al Customer
Verifica que el Contact tenga el `customer_id` correcto:
```sql
-- Ver la relación Customer-Contact
SELECT 
    dc.id as contact_id,
    dc.customer_name,
    dc.customer_id,
    dcu.company_name as customer_name
FROM "DirectoryContacts" dc
LEFT JOIN "DirectoryCustomers" dcu ON dcu.id = dc.customer_id
WHERE dc.id = 'TU_CONTACT_ID';
```

Si `customer_id` es NULL o incorrecto:
```sql
-- Actualizar el customer_id del Contact
UPDATE "DirectoryContacts"
SET customer_id = 'TU_CUSTOMER_ID'
WHERE id = 'TU_CONTACT_ID';
```

### Solución 3: La columna is_system no existe
```sql
-- Ejecutar la migración
ALTER TABLE "OrganizationUsers"
  ADD COLUMN IF NOT EXISTS is_system BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_organization_users_is_system 
ON "OrganizationUsers"(is_system) 
WHERE is_system = true AND deleted = false;
```

### Solución 4: Políticas RLS bloqueando INSERT
```sql
-- Verificar que la función helper existe
SELECT 
    proname,
    prosrc
FROM pg_proc
WHERE proname = 'org_is_owner_or_admin';
```

Si no existe, ejecuta las migraciones RLS en orden:
1. `add_rls_helper_functions.sql`
2. `FINAL_FIX_RLS_RECURSION.sql`

## Información de Contacto para Debug

Cuando reportes el problema, incluye:
1. Tu email de usuario
2. El rol que tienes en la organización
3. El mensaje de error exacto de la consola
4. Los resultados de las queries de verificación arriba


