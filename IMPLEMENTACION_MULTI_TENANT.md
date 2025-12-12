# 🏢 Implementación Sistema Multi-Tenant

## Resumen

Se ha implementado un sistema completo de usuarios multi-tenant con las siguientes características:

1. ✅ Tabla `OrganizationUsers` creada
2. ✅ Helpers de roles (`isAppAdmin`, `getDefaultOrganizationId`)
3. ✅ Integración en `create-organization-with-user` Edge Function
4. ✅ Edge Function `invite-user-to-organization` para invitar usuarios
5. ✅ Edge Function `get-organization-users` para listar usuarios con emails
6. ✅ Componente UI `OrganizationUsers` para gestionar usuarios
7. ✅ Tab "Users" agregado en `OrganizationProfile`

## Archivos Creados/Modificados

### Migraciones SQL
- `database/migrations/create_organization_users.sql` - Tabla OrganizationUsers

### Helpers
- `src/lib/auth/roles.ts` - Funciones helper para roles y permisos

### Edge Functions
- `supabase/functions/create-organization-with-user/index.ts` - Actualizado para crear OrganizationUsers entry
- `supabase/functions/invite-user-to-organization/index.ts` - Nueva función para invitar usuarios
- `supabase/functions/get-organization-users/index.ts` - Nueva función para obtener usuarios con emails

### Componentes UI
- `src/pages/settings/OrganizationUsers.tsx` - Componente principal para gestionar usuarios
- `src/pages/settings/OrganizationProfile.tsx` - Actualizado con tab "Users"
- `src/hooks/useOrganizationUsers.ts` - Hook para cargar usuarios (opcional, no usado actualmente)

### Routing
- `src/App.tsx` - Agregadas rutas para `/settings/organization-users` y `/settings/organization/users`

## Estructura de Datos

### OrganizationUsers Table
```sql
- id uuid PK
- organization_id uuid FK → Organizations(id)
- user_id uuid (referencia a auth.users.id)
- role text ('owner' | 'admin' | 'member' | 'viewer')
- invited_by uuid NULL
- created_at timestamptz
- updated_at timestamptz
- deleted boolean
```

### user_metadata en Supabase Auth

**Para app_admin:**
```json
{
  "global_role": "app_admin"
}
```

**Para org_user:**
```json
{
  "global_role": "org_user",
  "default_organization_id": "<organization.id>"
}
```

## Flujo de Uso

### 1. Crear Organization con Owner

Cuando se crea una nueva Organization:
1. Se crea el registro en `Organizations`
2. Se crea un usuario en `auth.users` con `user_metadata`:
   - `global_role: 'org_user'`
   - `default_organization_id: <organization.id>`
3. Se crea una entrada en `OrganizationUsers` con `role: 'owner'`
4. Se actualiza `Organizations.owner_user_id` con el `user.id`

### 2. Invitar Usuario a Organization

1. Owner o Admin llama a `invite-user-to-organization` Edge Function
2. La función verifica permisos (solo owner/admin pueden invitar)
3. Si el usuario ya existe en `auth.users`:
   - Se actualiza `user_metadata` si es necesario
   - Se crea entrada en `OrganizationUsers`
4. Si el usuario NO existe:
   - Se crea usuario con contraseña temporal
   - Se crea entrada en `OrganizationUsers`
   - Se devuelve `initialPassword` para mostrar una sola vez

### 3. Gestionar Usuarios

En la pantalla "Users" dentro de Organization Profile:
- Ver lista de usuarios con sus roles
- Invitar nuevos usuarios (modal)
- Cambiar roles de usuarios existentes
- Ver fecha de ingreso

## Permisos

### Roles y Jerarquía
- `app_admin` (nivel 5) - Dueño/programador de la app
- `owner` (nivel 4) - Dueño de la organización
- `admin` (nivel 3) - Administrador
- `member` (nivel 2) - Miembro
- `viewer` (nivel 1) - Solo lectura

### Acciones Permitidas

**Invitar usuarios:**
- Solo `owner` y `admin` pueden invitar

**Cambiar roles:**
- Solo `owner` y `admin` pueden cambiar roles
- Un usuario no puede cambiar su propio rol

**Crear Organization:**
- Cualquier usuario autenticado puede crear una Organization
- El creador se convierte automáticamente en `owner`

## Próximos Pasos

### 1. Ejecutar Migración
```sql
-- Ejecutar en Supabase SQL Editor
\i database/migrations/create_organization_users.sql
```

### 2. Desplegar Edge Functions
```bash
# Desde la raíz del proyecto
supabase functions deploy create-organization-with-user
supabase functions deploy invite-user-to-organization
supabase functions deploy get-organization-users
```

### 3. Configurar RLS (Futuro)
Cuando estés listo, configura Row Level Security en `OrganizationUsers`:
```sql
-- Ejemplo de política (ajustar según necesidades)
CREATE POLICY "Users can view their own organization users"
  ON "OrganizationUsers"
  FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM "OrganizationUsers" 
      WHERE user_id = auth.uid() 
      AND deleted = false
    )
  );
```

### 4. Testing
1. Crear una nueva Organization desde Organization Profile
2. Verificar que el owner se crea correctamente
3. Ir al tab "Users" y verificar que el owner aparece
4. Invitar un nuevo usuario
5. Verificar que se muestra el modal con contraseña temporal
6. Cambiar el rol de un usuario
7. Verificar que los cambios se guardan

## Notas Importantes

1. **Contraseñas Temporales**: Solo se muestran una vez en el modal. No se guardan en la base de datos.

2. **User Metadata**: Se actualiza automáticamente cuando se invita a un usuario a una organización.

3. **Soft Delete**: Los usuarios se marcan como `deleted = true` en lugar de borrarse físicamente.

4. **Validación de Roles**: El rol `owner` solo puede ser asignado por `app_admin` o durante la creación de la Organization.

5. **Emails**: Los emails se obtienen desde `auth.users` usando la Edge Function `get-organization-users` porque no se puede acceder directamente desde el cliente.

## Troubleshooting

### Error: "Inviter does not have access"
- Verificar que el usuario actual tiene rol `owner` o `admin` en la Organization
- Verificar que `OrganizationUsers` tiene una entrada activa (`deleted = false`)

### Error: "User is already a member"
- El usuario ya está en la Organization
- Verificar en `OrganizationUsers` si hay una entrada con `deleted = true` que se puede reactivar

### No se muestran emails en la lista
- Verificar que la Edge Function `get-organization-users` está desplegada
- Verificar permisos de la función para acceder a `auth.users`

