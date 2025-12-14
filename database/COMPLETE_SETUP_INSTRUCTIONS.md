# 🎯 Sistema Completo de Organization Users - Instrucciones de Instalación

## 📋 Resumen

Este documento describe cómo instalar y configurar el sistema completo de Organization Users con roles y permisos correctos.

## 🔐 Roles y Permisos

### 1. **Super Admin** (`superadmin`)
- ✅ Ve y hace TODO
- ✅ Puede crear/editar/eliminar cualquier usuario
- ✅ Puede ver todas las organizaciones
- ✅ Acceso total a todas las tablas

### 2. **Owner** (`owner`)
- ✅ Ve y hace TODO en su organización
- ✅ Puede crear/editar/eliminar usuarios (admin, member, viewer)
- ✅ Puede ver todos los usuarios de su organización
- ✅ Puede crear/editar/eliminar customers, contacts, vendors
- ✅ Puede crear quotes

### 3. **Admin** (`admin`)
- ✅ Ve TODO de su propio Customer (asignado en `customer_id`)
- ✅ Puede crear usuarios (member, viewer) de su mismo Customer
- ✅ Puede editar usuarios de su mismo Customer
- ✅ Puede crear/editar customers, contacts, vendors (de su Customer)
- ✅ Puede crear quotes

### 4. **Member** (`member`)
- ✅ Puede crear quotes
- ✅ Puede ver sus propias cuentas solamente (su Customer asignado)
- ❌ NO puede editar customers, contacts, vendors

### 5. **Viewer** (`viewer`)
- ✅ Puede ver sus propias cuentas solamente (su Customer asignado)
- ❌ NO puede crear/editar nada

## 📝 Pasos de Instalación

### Paso 1: Ejecutar Script Principal de OrganizationUsers

```sql
-- Ejecutar en Supabase SQL Editor
-- Archivo: database/COMPLETE_ORGANIZATION_USERS_SYSTEM.sql
```

Este script:
- ✅ Verifica la estructura de la tabla `OrganizationUsers`
- ✅ Crea funciones helper RLS (sin recursión)
- ✅ Crea políticas RLS para `OrganizationUsers`
- ✅ Configura permisos por rol

### Paso 2: Ejecutar Políticas RLS para Tablas Directory

```sql
-- Ejecutar en Supabase SQL Editor
-- Archivo: database/RLS_POLICIES_FOR_DIRECTORY_TABLES.sql
```

Este script:
- ✅ Crea funciones helper para Directory tables
- ✅ Crea políticas RLS para `DirectoryCustomers`
- ✅ Crea políticas RLS para `DirectoryContacts`
- ✅ Crea políticas RLS para `DirectoryVendors`
- ✅ Asegura que Admin solo vea su Customer

### Paso 3: Verificar Instalación

Después de ejecutar ambos scripts, verifica:

1. **Funciones creadas:**
   - `is_super_admin(uuid)`
   - `is_owner(uuid, uuid)`
   - `is_admin(uuid, uuid)`
   - `get_user_customer_id(uuid, uuid)`
   - `can_manage_organization_users(uuid, uuid)`
   - `can_insert_organization_user(uuid, uuid, text)`
   - `can_view_organization_user(uuid, uuid, uuid, uuid)`
   - `get_current_user_customer_id(uuid)`
   - `can_access_customer(uuid, uuid)`

2. **Políticas RLS:**
   - `OrganizationUsers`: 9 políticas
   - `DirectoryCustomers`: 6 políticas
   - `DirectoryContacts`: 6 políticas
   - `DirectoryVendors`: 6 políticas

3. **RLS habilitado:**
   - Todas las tablas deben tener `relrowsecurity = true`

## 🔧 Estructura de OrganizationUsers

La tabla `OrganizationUsers` debe tener estas columnas:

```sql
- id (uuid, PK)
- organization_id (uuid, FK → Organizations)
- user_id (uuid, FK → auth.users)
- role (text: 'owner' | 'admin' | 'member' | 'viewer')
- name (text)
- email (text)
- contact_id (uuid, FK → DirectoryContacts, NOT NULL)
- customer_id (uuid, FK → DirectoryCustomers, NOT NULL)
- invited_by (uuid, FK → OrganizationUsers, nullable)
- is_system (boolean, default false)
- deleted (boolean, default false)
- created_at (timestamptz)
- updated_at (timestamptz)
```

**IMPORTANTE:**
- `contact_id` y `customer_id` son **OBLIGATORIOS** para todos los roles
- `is_system = true` oculta usuarios del sistema de las listas regulares
- `deleted = true` marca soft delete

## 🎯 Casos de Uso

### Crear un Owner

```sql
INSERT INTO "OrganizationUsers" (
    id, organization_id, user_id, role, name, email,
    contact_id, customer_id, deleted, is_system
) VALUES (
    gen_random_uuid(),
    'org-id-here',
    'user-id-here',
    'owner',
    'Owner Name',
    'owner@example.com',
    'contact-id-here',
    'customer-id-here',
    false,
    false
);
```

### Crear un Admin (debe tener customer_id)

```sql
INSERT INTO "OrganizationUsers" (
    id, organization_id, user_id, role, name, email,
    contact_id, customer_id, deleted, is_system
) VALUES (
    gen_random_uuid(),
    'org-id-here',
    'user-id-here',
    'admin',
    'Admin Name',
    'admin@example.com',
    'contact-id-here',
    'customer-id-here', -- Este Customer es el que el Admin puede ver/editar
    false,
    false
);
```

### Crear un Member

```sql
INSERT INTO "OrganizationUsers" (
    id, organization_id, user_id, role, name, email,
    contact_id, customer_id, deleted, is_system
) VALUES (
    gen_random_uuid(),
    'org-id-here',
    'user-id-here',
    'member',
    'Member Name',
    'member@example.com',
    'contact-id-here',
    'customer-id-here', -- Este Customer es el que el Member puede ver
    false,
    false
);
```

## ⚠️ Notas Importantes

1. **Admin solo ve su Customer:**
   - Un Admin con `customer_id = 'abc-123'` solo puede ver/editar Customers, Contacts y Vendors relacionados con `customer_id = 'abc-123'`
   - Esto se controla mediante las políticas RLS

2. **Member NO puede editar:**
   - Member puede crear quotes
   - Member puede ver sus cuentas (su Customer)
   - Member NO puede editar customers, contacts, vendors

3. **Owner puede hacer todo:**
   - Owner puede ver/editar todos los Customers, Contacts, Vendors de su organización
   - Owner puede crear usuarios con roles: admin, member, viewer
   - Owner NO puede crear otro Owner (solo Super Admin puede)

4. **Super Admin:**
   - Super Admin se determina por la tabla `PlatformAdmins`
   - Super Admin no necesita `customer_id` (ve todo)

## 🐛 Troubleshooting

### Error: "column contact_id does not exist"
- Ejecuta las migraciones necesarias para agregar `contact_id` y `customer_id` a `OrganizationUsers`

### Error: "function does not exist"
- Verifica que todas las funciones helper estén creadas
- Ejecuta `COMPLETE_ORGANIZATION_USERS_SYSTEM.sql` nuevamente

### Admin no puede ver sus Customers
- Verifica que el Admin tenga `customer_id` asignado
- Verifica que las políticas RLS estén creadas correctamente
- Verifica que RLS esté habilitado en `DirectoryCustomers`

### Usuario no aparece en la lista
- Verifica que `is_system = false`
- Verifica que `deleted = false`
- Verifica que el usuario tenga un registro en `OrganizationUsers` con `organization_id` correcto

## ✅ Checklist de Verificación

- [ ] Script `COMPLETE_ORGANIZATION_USERS_SYSTEM.sql` ejecutado sin errores
- [ ] Script `RLS_POLICIES_FOR_DIRECTORY_TABLES.sql` ejecutado sin errores
- [ ] Todas las funciones helper creadas (9 funciones)
- [ ] Todas las políticas RLS creadas (27 políticas totales)
- [ ] RLS habilitado en todas las tablas
- [ ] Usuario de prueba creado con cada rol
- [ ] Permisos verificados para cada rol
- [ ] Admin solo ve su Customer asignado
- [ ] Member puede crear quotes pero no editar customers/contacts/vendors
- [ ] Owner puede ver/editar todo en su organización

