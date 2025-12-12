# 🔐 Sistema de Roles y Permisos

Este documento describe el sistema de roles implementado para controlar el acceso y permisos de los usuarios en la aplicación.

## 📋 Estructura de Roles

El sistema soporta los siguientes roles:

- **`superadmin`**: Administrador de la plataforma (tabla `PlatformAdmins`)
- **`owner`**: Propietario de la organización
- **`admin`**: Administrador de la organización
- **`member`**: Miembro de la organización
- **`viewer`**: Solo lectura

## 🎯 Matriz de Permisos por Rol

| Acción | superadmin | owner | admin | member | viewer |
|--------|-----------|-------|-------|--------|--------|
| **Gestionar Organización** | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Gestionar Usuarios** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Invitar Usuarios** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Cambiar Roles de Usuarios** | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Crear Cotizaciones** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Ver Cotizaciones** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Editar Customers** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Ver Customers** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Crear Contacts** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Editar Contacts** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Ver Contacts** | ✅ | ✅ | ✅ | ✅ | ✅ |

## 🎯 Hook `useCurrentOrgRole`

El hook principal para obtener el rol y permisos del usuario actual.

### Uso Básico

```typescript
import { useCurrentOrgRole } from '@/hooks/useCurrentOrgRole';

function MyComponent({ organizationId }: { organizationId: string }) {
  const {
    role,
    loading,
    error,
    isSuperAdmin,
    isOwner,
    isAdmin,
    isMember,
    isViewer,
    canManageOrganization,
    canManageUsers,
    canCreateQuotes,
    canViewQuotes,
    canEditCustomers,
  } = useCurrentOrgRole({ organizationId });

  if (loading) return <div>Loading permissions...</div>;
  if (error) return <div>Error: {error}</div>;

  // Usar los flags y permisos...
}
```

### Propiedades Retornadas

#### Flags de Rol
- `isSuperAdmin`: `true` si el usuario es superadmin
- `isOwner`: `true` si el usuario es owner o superadmin
- `isAdmin`: `true` si el usuario es admin, owner o superadmin
- `isMember`: `true` si el usuario es member
- `isViewer`: `true` si el usuario es viewer

#### Permisos Derivados
- `canManageOrganization`: Solo `owner` y `superadmin`
- `canManageUsers`: `owner`, `admin` y `superadmin`
- `canCreateQuotes`: `owner`, `admin`, `member` y `superadmin`
- `canViewQuotes`: Cualquier rol (incluyendo `viewer`)
- `canEditCustomers`: `owner`, `admin`, `member` y `superadmin` (no `viewer`)

## 📝 Ejemplos de Uso

### 1. Ocultar/Mostrar Botón "Invite User"

```typescript
import { useCurrentOrgRole } from '@/hooks/useCurrentOrgRole';

function OrganizationUsersSection({ organizationId }: { organizationId: string }) {
  const { canManageUsers, loading } = useCurrentOrgRole({ organizationId });

  if (loading) return <p>Loading permissions…</p>;

  return (
    <div>
      <h2>Users</h2>
      {canManageUsers ? (
        <button onClick={openInviteModal}>
          + Invite User
        </button>
      ) : (
        <span>You don't have permission to manage users.</span>
      )}
    </div>
  );
}
```

### 2. Deshabilitar Botón "Nueva Cotización"

```typescript
import { useCurrentOrgRole } from '@/hooks/useCurrentOrgRole';

function NewQuoteButton({ organizationId }: { organizationId: string }) {
  const { canCreateQuotes } = useCurrentOrgRole({ organizationId });

  return (
    <button
      disabled={!canCreateQuotes}
      title={!canCreateQuotes ? 'No tienes permisos para crear cotizaciones' : undefined}
    >
      Nueva Cotización
    </button>
  );
}
```

### 3. Solo Lectura para Viewer

```typescript
import { useCurrentOrgRole } from '@/hooks/useCurrentOrgRole';

function ContactForm({ organizationId }: { organizationId: string }) {
  const { canEditCustomers, isViewer } = useCurrentOrgRole({ organizationId });
  const isReadOnly = isViewer || !canEditCustomers;

  return (
    <form>
      <Input
        {...register('customer_name')}
        disabled={isReadOnly}
      />
      <button
        type="submit"
        disabled={isReadOnly}
        title={isReadOnly ? 'You only have read permissions (viewer role)' : undefined}
      >
        {isReadOnly ? 'Read Only' : 'Save'}
      </button>
    </form>
  );
}
```

### 4. Condicionar Acciones de Customer

```typescript
import { useCurrentOrgRole } from '@/hooks/useCurrentOrgRole';

function CustomerActions({ organizationId }: { organizationId: string }) {
  const { canEditCustomers, isViewer } = useCurrentOrgRole({ organizationId });
  const canEdit = canEditCustomers && !isViewer;

  return (
    <div className="flex gap-2">
      {canEdit && (
        <button onClick={handleEdit}>
          Editar Customer
        </button>
      )}
      <button onClick={handleView}>
        Ver Detalle
      </button>
      {isViewer && (
        <span className="text-xs text-gray-500 italic">
          (Solo lectura)
        </span>
      )}
    </div>
  );
}
```

## 🗄️ Estructura de Base de Datos

### Tabla `PlatformAdmins`
```sql
CREATE TABLE IF NOT EXISTS PlatformAdmins (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Tabla `OrganizationUsers`
```sql
CREATE TABLE IF NOT EXISTS OrganizationUsers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES Organizations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
  invited_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted BOOLEAN DEFAULT FALSE,
  UNIQUE(organization_id, user_id)
);
```

## 🔒 Política de Permisos

### Jerarquía de Roles
```
superadmin > owner > admin > member > viewer
```

### Descripción Detallada de Capacidades

#### **superadmin**
- Control total sobre todas las organizaciones
- Puede gestionar cualquier organización y sus usuarios
- Acceso completo a todas las funcionalidades
- Puede cambiar roles de cualquier usuario

#### **owner**
- Control total sobre su organización
- Puede editar perfil de la organización
- Puede invitar usuarios y cambiarles el rol
- Puede eliminar usuarios de la organización
- Acceso completo a todas las funcionalidades de su organización

#### **admin**
- Puede gestionar usuarios (invitar, pero no cambiar roles)
- Puede crear y editar cotizaciones
- Puede crear y editar customers y contacts
- No puede cambiar roles de otros usuarios
- No puede gestionar la organización (configuración)

#### **member**
- Puede crear cotizaciones y clientes
- Puede editar customers y contacts
- No puede invitar usuarios
- No puede ver/editar configuración de organización

#### **viewer**
- Solo puede ver datos (cotizaciones, contactos, customers, etc.)
- Todo en modo read-only
- No puede crear, editar o eliminar nada

## 📦 Archivos Creados

1. **`src/types/roles.ts`**: Tipo TypeScript para roles
2. **`src/hooks/useCurrentOrgRole.ts`**: Hook principal para obtener rol y permisos
3. **`src/components/examples/NewQuoteButton.tsx`**: Ejemplo de botón con permisos
4. **`src/components/examples/CustomerActions.tsx`**: Ejemplo de acciones condicionadas

## 🗄️ Migraciones SQL Creadas

1. **`database/migrations/add_org_role_enum_and_constraints.sql`**
   - Crea enum `org_role` (opcional)
   - Agrega CHECK constraint a `OrganizationUsers.role`

2. **`database/migrations/add_rls_helper_functions.sql`**
   - `public.org_user_role(p_user_id, p_org_id)`: Obtiene el rol de un usuario
   - `public.org_is_owner_or_admin(p_user_id, p_org_id)`: Verifica si es owner/admin/superadmin
   - `public.org_is_owner_or_superadmin(p_user_id, p_org_id)`: Verifica si es owner/superadmin

3. **`database/migrations/add_organization_users_rls_policies.sql`**
   - Policies RLS para SELECT, INSERT, UPDATE, DELETE en `OrganizationUsers`
   - Usa las funciones helper para simplificar las policies
   - Implementa la seguridad basada en roles

## 🚀 Implementación Actual

El sistema ya está implementado en:

### Componentes con Permisos Aplicados

1. **`src/pages/settings/OrganizationUsers.tsx`**
   - Botón "Invite User" se oculta si `!canManageUsers`
   - Muestra mensaje informativo cuando no hay permisos
   - Usa el hook `useCurrentOrgRole` para validar permisos
   - El backend (RLS) valida los permisos reales

2. **`src/pages/directory/ContactNew.tsx`**
   - Formulario en modo solo lectura para `viewer`
   - Todos los campos se deshabilitan cuando `isReadOnly` es `true`
   - Botón "Save" se deshabilita y muestra "Read Only" para viewers
   - Usa `canEditCustomers` y `isViewer` del hook

3. **`src/pages/directory/Customers.tsx`**
   - Botón "Add Customer" se oculta si `!canEditCustomers`
   - Botones de edición solo se muestran si `canEditCustomers`
   - Usa `canEditCustomers` del hook

4. **`src/pages/directory/CustomerNew.tsx`**
   - Formulario en modo solo lectura para `viewer`
   - Todos los campos se deshabilitan cuando `isReadOnly` es `true`
   - Botón "Save and Close" se deshabilita para viewers
   - Usa `canEditCustomers` y `isViewer` del hook

### Módulo de Quotes (Pendiente)

El módulo de Quotes aún no existe en la aplicación. Cuando se implemente, debe usar:
- `canCreateQuotes` para habilitar/deshabilitar el botón "Nueva Cotización"
- `canViewQuotes` para proteger la vista de listado

## 🔒 Row Level Security (RLS)

Las políticas RLS en `OrganizationUsers` están configuradas para:

### SELECT
- Los usuarios pueden ver sus propias filas (`user_id = auth.uid()`)
- Owners, admins y superadmins pueden ver todas las filas de su organización

### INSERT
- Solo owners, admins y superadmins pueden invitar/crear usuarios
- El `organization_id` debe coincidir con una organización donde el usuario tiene permisos

### UPDATE
- Solo owners y superadmins pueden cambiar roles de otros usuarios
- Los usuarios pueden actualizar su propio registro (excepto el rol)

### DELETE
- Solo owners y superadmins pueden eliminar registros de `OrganizationUsers`

Las policies usan las funciones helper (`org_user_role`, `org_is_owner_or_admin`, `org_is_owner_or_superadmin`) para simplificar la lógica.

## 🔄 Flujo de Invite User

El flujo completo de invitación funciona así:

1. **Frontend (`OrganizationUsers.tsx`)**:
   - Valida permisos usando `canManageUsers` del hook
   - Si no tiene permisos, oculta el botón "Invite User"
   - Al hacer clic, abre el modal con email y rol

2. **Edge Function (`invite-user-to-organization`)**:
   - Valida que el inviter tenga permisos (owner/admin)
   - Verifica si el usuario ya existe en `auth.users`
   - Si no existe: envía invitación por email usando `inviteUserByEmail`
   - Si existe: reutiliza el `user_id`
   - Inserta/actualiza fila en `OrganizationUsers`
   - Las RLS policies validan que el insert sea permitido

3. **Manejo de Errores**:
   - Si falla por RLS (403): muestra "No tienes permisos para invitar usuarios"
   - Si el usuario ya es miembro (409): muestra mensaje apropiado
   - Si hay error de conexión: muestra mensaje de error de red

## ⚠️ Solución de Problemas

### Error "Failed to fetch" o CORS

Si ves errores de CORS al invitar usuarios:

1. **Verifica que el edge function esté desplegado**:
   ```bash
   supabase functions deploy invite-user-to-organization
   ```

2. **Verifica las variables de entorno** en Supabase:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `APP_URL` (opcional, para redirects)

3. **Verifica la configuración de CORS** en el edge function (ya está configurado)

4. **Verifica que el usuario tenga permisos**:
   - Debe ser owner o admin en la organización
   - O superadmin en `PlatformAdmins`

### Error "No tienes permisos"

Si el usuario ve "No tienes permisos para invitar usuarios":
- Verifica que el usuario tenga rol `owner` o `admin` en `OrganizationUsers`
- Verifica que `deleted = false` en su registro
- Verifica que las RLS policies estén aplicadas correctamente

## 🌐 Organization Context y Switcher

### OrganizationContext

El sistema incluye un contexto global (`OrganizationContext`) que gestiona la organización activa del usuario:

- **Ubicación**: `src/context/OrganizationContext.tsx`
- **Funcionalidad**:
  - Carga todas las organizaciones donde el usuario pertenece (desde `OrganizationUsers`)
  - Mantiene la organización activa en estado y localStorage
  - Proporciona un hook `useOrganizationContext()` para acceder a la organización activa

**Uso del Contexto**:

```typescript
import { useOrganizationContext } from '@/context/OrganizationContext';

function MyComponent() {
  const {
    organizations,           // Lista de todas las organizaciones del usuario
    activeOrganization,      // Organización activa (con id, name, role)
    activeOrganizationId,    // ID de la organización activa
    setActiveOrganizationId, // Función para cambiar la organización activa
    loading,                // Estado de carga
    error,                  // Error si existe
  } = useOrganizationContext();

  // Usar activeOrganizationId para queries, etc.
}
```

**Selección de Organización Activa**:

1. Si hay un valor en `localStorage` (`activeOrganizationId`) y aún existe en la lista, se usa ese.
2. Si no, se usa la primera organización de la lista.
3. Si no hay organizaciones, `activeOrganizationId` es `null`.

**Persistencia**:

- La organización activa se guarda en `localStorage` con la clave `activeOrganizationId`
- Se actualiza automáticamente cuando el usuario cambia de organización
- Se restaura al recargar la página

### OrganizationSwitcher

Componente visual tipo Slack para cambiar entre organizaciones:

- **Ubicación**: `src/components/layout/OrganizationSwitcher.tsx`
- **Ubicación en UI**: Header principal (barra superior)
- **Funcionalidad**:
  - Muestra el nombre de la organización activa
  - Al hacer clic, abre un dropdown con todas las organizaciones
  - Muestra el rol del usuario en cada organización (owner/admin/member/viewer)
  - Muestra badge "SuperAdmin" si el usuario es superadmin
  - Permite cambiar de organización con un clic

**Estados del Switcher**:

- **Loading**: Muestra "Loading orgs…" con spinner
- **Error**: Muestra icono de alerta y mensaje de error
- **Sin organizaciones**: Muestra "No organizations"
- **Normal**: Muestra botón con nombre de organización activa y dropdown

### Integración con useCurrentOrgRole

El hook `useCurrentOrgRole` ahora puede funcionar de dos formas:

1. **Sin parámetros** (recomendado): Usa automáticamente la organización activa del contexto
   ```typescript
   const { canEditCustomers } = useCurrentOrgRole();
   ```

2. **Con organizationId explícito**: Para casos especiales donde necesitas un ID específico
   ```typescript
   const { canEditCustomers } = useCurrentOrgRole({ organizationId: 'some-id' });
   ```

**Resolución de organizationId**:

```typescript
// Dentro de useCurrentOrgRole
const { activeOrganizationId } = useOrganizationContext();
const effectiveOrgId = options.organizationId ?? activeOrganizationId ?? null;
```

Esto significa que:
- Si pasas `organizationId` explícitamente, se usa ese
- Si no, se usa `activeOrganizationId` del contexto
- Si ambos son `null`, el hook retorna `role = null` y todos los permisos en `false`

### Componentes Actualizados

Todos los componentes ahora usan la organización activa automáticamente:

- ✅ **OrganizationUsers.tsx**: Usa `activeOrganizationId` del contexto
- ✅ **Customers.tsx**: Usa `useCurrentOrgRole()` sin parámetros
- ✅ **CustomerNew.tsx**: Usa `activeOrganizationId` para queries y `useCurrentOrgRole()` sin parámetros
- ✅ **ContactNew.tsx**: Usa `activeOrganizationId` para queries y `useCurrentOrgRole()` sin parámetros

**Manejo de "No Organization Selected"**:

Los componentes que requieren una organización muestran un mensaje cuando `activeOrganizationId === null`:

```typescript
if (!activeOrganizationId) {
  return (
    <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
      <p className="text-sm text-yellow-800">
        Select an organization to continue.
      </p>
    </div>
  );
}
```

## 🔧 Personalización

Para ajustar los permisos, edita el hook `useCurrentOrgRole.ts` en la sección de "permisos derivados":

```typescript
// Ejemplo: Permitir que admin también gestione organización
const canManageOrganization = isOwner || isAdmin || isSuperAdmin;
```

Para ajustar las políticas RLS, edita `database/migrations/add_organization_users_rls_policies.sql` y vuelve a ejecutar la migración.
