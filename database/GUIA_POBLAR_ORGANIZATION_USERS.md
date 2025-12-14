# 📋 Guía Paso a Paso: Poblar OrganizationUsers

## ✅ Requisitos Previos

Antes de ejecutar el script, asegúrate de tener:

1. ✅ **Organización creada**: "Arquiproductos" debe existir en `Organizations`
2. ✅ **Al menos 1 Customer**: En `DirectoryCustomers` con `deleted = false`
3. ✅ **Al menos 1 Contact**: En `DirectoryContacts` con:
   - `deleted = false`
   - `customer_id` asignado (NO NULL)
   - Vinculado a un Customer existente

---

## 📝 Paso 1: Verificar Datos Existentes (Opcional pero Recomendado)

1. Abre **Supabase Dashboard** → **SQL Editor**
2. Abre el archivo: `database/verify_data_before_populate.sql`
3. Copia y pega el contenido completo
4. Ejecuta el script (botón "Run" o `Cmd/Ctrl + Enter`)
5. Revisa los resultados:
   - Deberías ver tu organización "Arquiproductos"
   - Deberías ver al menos 1 Customer
   - Deberías ver al menos 1 Contact con `customer_id` asignado

**Si no ves Customers o Contacts**, ve a la aplicación y créalos primero:
- **Directory > Customers**: Crea un Customer
- **Directory > Contacts**: Crea un Contact y selecciona el Customer en "Customer Related"

---

## 🚀 Paso 2: Ejecutar Script Principal

1. En **Supabase Dashboard** → **SQL Editor**
2. Abre el archivo: `database/populate_arquiproductos_organization_users.sql`
3. Copia y pega el contenido completo
4. Ejecuta el script (botón "Run" o `Cmd/Ctrl + Enter`)

### ✅ Mensajes de Éxito Esperados:

Deberías ver en la consola:
```
✅ Organización encontrada: ID = [uuid]
✅ Customer encontrado: ID = [uuid]
✅ Contact encontrado: ID = [uuid]
✅ Usando Customer ID: [uuid] y Contact ID: [uuid]
✅ Owner creado/verificado
✅ Admins creados/verificados
✅ Members creados/verificados
✅ Viewers creados/verificados
✅ OrganizationUsers creados exitosamente!
```

### ❌ Si ves errores:

- **"Organización Arquiproductos no encontrada"**: 
  - Ve a Settings > Organization Profile y crea la organización

- **"No hay Customers"**: 
  - Ve a Directory > Customers y crea al menos un Customer

- **"No hay Contacts"** o **"Contact no tiene Customer asignado"**: 
  - Ve a Directory > Contacts
  - Crea o edita un Contact
  - Selecciona un Customer en "Customer Related"
  - Guarda

---

## 🔍 Paso 3: Verificar Resultados

Al final del script hay una query de verificación que se ejecuta automáticamente. Deberías ver una tabla con:

- `name`: Nombre del usuario
- `email`: Email del usuario
- `role`: owner, admin, member, o viewer
- `customer`: Nombre del Customer asignado
- `contact`: Nombre del Contact asignado
- `created_at`: Fecha de creación

**Deberías ver 10 usuarios creados:**
- 1 Owner
- 2 Admins
- 4 Members
- 3 Viewers

---

## 🎯 Paso 4: Probar en la Aplicación

1. Ve a **Settings > Organization User**
2. Deberías poder:
   - ✅ Ver la lista de usuarios creados
   - ✅ Crear nuevos usuarios seleccionando Customer y Contact
   - ✅ Los usuarios solo verán datos de su Customer (RLS)

---

## 📌 Notas Importantes

### ⚠️ User IDs son Dummy

Los `user_id` creados son UUIDs aleatorios (dummy). Para usar estos usuarios en producción:

**Opción 1: Usar Edge Function (Recomendado)**
- Usa la Edge Function `invite-user-to-organization`
- Esto crea el usuario en `auth.users` y actualiza `OrganizationUsers`

**Opción 2: Actualizar Manualmente**
- Crea usuarios en `auth.users` primero
- Luego actualiza los `user_id` en `OrganizationUsers` con los UUIDs reales

### 🔒 Permisos y RLS

- Los usuarios solo verán datos de su `customer_id`
- Un Contact puede VER datos de su Customer
- Un Contact NO puede BORRAR datos que no sean de su Customer
- Esto se controla con RLS policies en la base de datos

### 📊 Columnas Usadas

El script solo usa columnas **esenciales**:
- `id`, `organization_id`, `user_id`
- `name`, `email`, `role`
- `contact_id`, `customer_id` (REQUERIDOS)
- `invited_by`, `created_at`, `updated_at`, `deleted`

**NO se crean columnas nuevas** - solo se usan las existentes.

---

## 🆘 Solución de Problemas

### Error: "null value in column contact_id violates not-null constraint"

**Causa**: El script intentó crear un OrganizationUser sin `contact_id` o `customer_id`.

**Solución**: 
1. Verifica que el script encontró un Contact y Customer válidos (revisa los mensajes)
2. Asegúrate de que al menos un Contact tenga `customer_id` asignado
3. Ejecuta el script de verificación primero

### Error: "The selected Contact must belong to the selected Customer"

**Causa**: El trigger de validación detectó que el Contact no pertenece al Customer.

**Solución**:
1. Ve a Directory > Contacts
2. Edita el Contact
3. Asegúrate de que "Customer Related" esté seleccionado correctamente
4. Guarda

### No se ven usuarios en Settings > Organization User

**Causa**: Puede ser un problema de permisos o RLS.

**Solución**:
1. Verifica que estás logueado como un usuario con rol `owner` o `admin`
2. Verifica que la organización esté seleccionada correctamente
3. Revisa la consola del navegador para errores

---

## ✅ Checklist Final

- [ ] Organización "Arquiproductos" existe
- [ ] Al menos 1 Customer creado
- [ ] Al menos 1 Contact creado y asignado a un Customer
- [ ] Script de verificación ejecutado exitosamente
- [ ] Script principal ejecutado exitosamente
- [ ] 10 OrganizationUsers creados (verificado en query final)
- [ ] Puedo ver usuarios en Settings > Organization User
- [ ] Puedo crear nuevos usuarios desde la aplicación

---

**¿Problemas?** Revisa los mensajes de error en la consola de Supabase SQL Editor y compártelos para diagnóstico.

