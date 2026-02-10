# Directory INSERT Fix - Resumen y Debug

## ✅ Archivos modificados (en esta conversación)

### 1. `src/hooks/useDirectoryContacts.ts` (línea 417-501)

**Cambios aplicados:**
- ✅ Validación `activeOrganizationId` antes de insert (línea 418-420)
- ✅ Obtención de `dealer_id` del portal user (línea 430: `select('id, dealer_id')`)
- ✅ Cálculo de `effectiveDealerId` (línea 443-445):
  - Portal user o activeDealerId presente → usa `input.dealer_id ?? activeDealerId ?? portalUserDealerId ?? null`
  - Sino → `input.dealer_id ?? null`
- ✅ Payload con `organization_id` SIEMPRE (línea 451)
- ✅ Payload con `dealer_id` calculado (línea 450)
- ✅ Log DEV antes de insert (línea 472-479)

**Código del payload:**
```typescript
const payload: any = {
  dealer_id: effectiveDealerId,
  organization_id: activeOrganizationId, // ← SIEMPRE presente
  created_by_user_id: createdByUserId,
  created_by_portal_user_id: createdByPortalUserId,
  // ... resto de campos
};

if (import.meta.env.DEV) {
  console.log('[useDirectoryContacts] Insert payload (pre-insert):', {
    organization_id: payload.organization_id,
    dealer_id: payload.dealer_id,
    contact_name: payload.contact_name,
    contact_email: payload.contact_email,
  });
}

const { data, error: insertError } = await supabase
  .from('DirectoryContacts')
  .insert(payload)
```

### 2. `src/hooks/useDirectoryCustomers.ts` (línea 267-356)

**Cambios aplicados (mismo patrón):**
- ✅ Validación `activeOrganizationId` (línea 268-270)
- ✅ Obtención de `dealer_id` del portal user (línea 280: `select('id, dealer_id')`)
- ✅ Cálculo de `effectiveDealerId` (línea 293-295)
- ✅ Payload con `organization_id` (línea 298) y `dealer_id` (línea 299)
- ✅ Log DEV antes de insert (línea 327-334)

---

## 🔍 Si sigue fallando: Checklist de debug

### 1. ¿Los archivos están guardados?
- Guarda ambos archivos (`useDirectoryContacts.ts` y `useDirectoryCustomers.ts`)
- Reinicia el dev server: `npm run dev` o `vite`
- Hard refresh en browser: **Cmd+Shift+R** (Mac) o **Ctrl+Shift+F5** (Windows)

### 2. ¿El contexto `activeOrganizationId` está poblado?

Añade este log temporal en **`ContactNew.tsx`** (después de `const { activeOrganizationId } = useOrganizationContext();`):

```typescript
useEffect(() => {
  console.log('[ContactNew] OrganizationContext:', {
    activeOrganizationId,
    isNull: activeOrganizationId === null,
    isUndefined: activeOrganizationId === undefined,
  });
}, [activeOrganizationId]);
```

Si `activeOrganizationId` es `null` o `undefined`, el problema está en el contexto, **no en el hook**.

**Verificar:**
- ¿El usuario está autenticado?
- ¿El usuario tiene una organización asignada en `OrganizationUsers` o `DealerUsers`?
- ¿El componente `OrganizationContext` se inicializó correctamente?

### 3. ¿La migración SQL está aplicada?

Ejecuta en **Supabase SQL Editor**:

```sql
-- Verificar que la policy permite dealer_id IS NULL
SELECT polname, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polrelid = 'public."DirectoryContacts"'::regclass
  AND polname = 'dircontacts_insert';
```

**Debe incluir:**
```
dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)
```

Si no está, aplica: **`database/migrations/20260209_fix_directory_insert_rls_portal.sql`** (recomendada; permite `dealer_id IS NULL`). No uses `20260218_directory_rls_insert_fix_portal.sql` como sustituto: esa migración exige `dealer_id = current_dealer_id(...)` y no acepta NULL.

### 4. ¿El log aparece en consola?

En modo DEV, al guardar un contacto deberías ver en consola:

```
[useDirectoryContacts] Insert payload (pre-insert): {
  organization_id: "3ecbb8dc-c7ff-4a5e-9fc3-...",
  dealer_id: "2ccdd701-15b0-4d5e-9c7f-...",
  contact_name: "Test Contact",
  contact_email: "test@example.com"
}
```

Si `organization_id` aparece como `null` en este log → el problema es el contexto.
Si `organization_id` aparece correcto pero el INSERT falla → el problema es RLS/migración.

### 5. ¿Qué dice el error exacto?

En Network tab (DevTools), al hacer el INSERT:
- Request URL: `https://[project].supabase.co/rest/v1/DirectoryContacts`
- Request Method: POST
- Request Body: debe incluir `"organization_id": "<uuid>"`

Si el body NO tiene `organization_id` → caché del browser o build no actualizado.
Si el body tiene `organization_id` pero falla → RLS/permisos backend.

---

## 📋 Verificación manual en SQL

Simula el contexto del usuario portal y prueba las funciones RLS:

```sql
-- 1. Sustituir <AUTH_USER_ID> por el auth.users.id del usuario que falla
-- 2. Sustituir <ORG_ID> por el organization_id esperado
SELECT set_config('request.jwt.claims', '{"sub":"<AUTH_USER_ID>"}', true);

-- Debe devolver true
SELECT public.is_org_user_member('<ORG_ID>'::uuid);

-- Debe devolver el dealer_id del portal user (uuid) o NULL si no es portal
SELECT public.current_dealer_id('<ORG_ID>'::uuid);
```

Si `is_org_user_member` devuelve `false` → el usuario no está en `DealerUsers` ni `OrganizationUsers` para esa org.
Si `current_dealer_id` devuelve `NULL` para un portal user → el registro `DealerUsers` no tiene `dealer_id` o `status`/`deleted` no cumplen.

---

## 🎯 Mensaje de commit (cuando confirmes que funciona)

```
fix(directory): ensure organization_id and dealer_id in DirectoryContacts/Customers inserts

- useDirectoryContacts: validate activeOrganizationId before insert; fetch dealer_id from DealerUsers; calculate effectiveDealerId from portal user or activeDealerId; always include organization_id in payload
- useDirectoryCustomers: same pattern for customers
- Add DEV logging before insert to debug RLS issues (organization_id, dealer_id, name, email)
- Fixes "new row violates row-level security policy" for portal users creating contacts/customers

Related: migration 20260209_fix_directory_insert_rls_portal.sql
```

---

## ⚠️ Nota importante

Los cambios en los hooks **YA ESTÁN APLICADOS** en esta conversación. Si el error persiste:

1. **Verificar que los archivos están guardados** (editor puede tener cambios sin guardar)
2. **Reiniciar dev server** (hot reload no siempre aplica cambios en hooks)
3. **Hard refresh del browser** (caché puede tener versión vieja del bundle)
4. **Verificar OrganizationContext** (el `activeOrganizationId` debe estar poblado)
5. **Aplicar migración SQL** si no está aplicada

El código de inserción está correcto. El problema más probable es que `activeOrganizationId` llega como `null` en runtime.
