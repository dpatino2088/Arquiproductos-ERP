# Troubleshooting: Error al Crear Organization Users

## Problema: "Failed to fetch" al intentar crear un Organization User

Este error generalmente indica que la Edge Function no está respondiendo correctamente.

## Pasos para Diagnosticar y Resolver

### 1. Verificar que la Edge Function esté desplegada

**Opción A: Desde Supabase Dashboard**
1. Ve a tu proyecto en [supabase.com](https://supabase.com)
2. Navega a **Edge Functions** en el menú lateral
3. Verifica que `invite-user-to-organization` esté en la lista
4. Si no está, necesitas desplegarla

**Opción B: Desde la terminal**
```bash
# Verificar funciones desplegadas
supabase functions list

# Si no está desplegada, desplegarla
supabase functions deploy invite-user-to-organization
```

### 2. Verificar Variables de Entorno de la Edge Function

1. En Supabase Dashboard > **Edge Functions** > `invite-user-to-organization`
2. Haz clic en **Settings** (⚙️)
3. Verifica que estas variables estén configuradas:
   - `SUPABASE_URL` - Debe ser tu Project URL (ej: `https://xxxxx.supabase.co`)
   - `SUPABASE_SERVICE_ROLE_KEY` - Debe ser tu Service Role Key (la clave secreta)

**Para obtener el Service Role Key:**
- Ve a **Settings** > **API**
- Busca **service_role** key (es la clave secreta, NO la uses en el frontend)
- Cópiala y agrégala como variable de entorno en la Edge Function

### 3. Verificar Logs de la Edge Function

1. En Supabase Dashboard > **Edge Functions** > `invite-user-to-organization`
2. Haz clic en **Logs**
3. Intenta crear un usuario nuevamente
4. Revisa los logs para ver qué error está ocurriendo

**Errores comunes:**
- `Missing Supabase environment variables` → Las variables de entorno no están configuradas
- `Inviter does not have access` → Problema con permisos (verifica políticas RLS)
- `User is already a member` → El usuario ya existe en la organización

### 4. Verificar Políticas RLS

Ejecuta este SQL en Supabase SQL Editor:

```sql
-- Verificar que la política INSERT existe y permite a SuperAdmins
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'OrganizationUsers' 
AND policyname = 'organizationusers_insert_owners_admins';
```

Si la política no existe o no permite SuperAdmins, ejecuta:

```sql
\i database/migrations/fix_superadmin_insert_permissions.sql
```

### 5. Probar la Edge Function directamente

Puedes probar la función usando curl o Postman:

```bash
curl -X POST 'https://TU_PROYECTO.supabase.co/functions/v1/invite-user-to-organization' \
  -H "Authorization: Bearer TU_ACCESS_TOKEN" \
  -H "apikey: TU_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "organizationId": "TU_ORG_ID",
    "name": "Test User",
    "email": "test@example.com",
    "role": "member",
    "invitedByUserId": "TU_USER_ID"
  }'
```

### 6. Verificar CORS

Si ves errores de CORS, verifica que la Edge Function tenga estos headers:

```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
```

### 7. Solución Rápida: Usar Consulta Directa (Temporal)

Si la Edge Function no funciona, puedes crear usuarios directamente desde SQL (solo para testing):

```sql
-- Crear usuario en auth.users primero (requiere Service Role)
-- Luego crear OrganizationUser
INSERT INTO "OrganizationUsers" (
  organization_id,
  user_id,
  name,
  email,
  role,
  invited_by,
  deleted
) VALUES (
  'TU_ORGANIZATION_ID'::uuid,
  'USER_ID_FROM_AUTH_USERS'::uuid,
  'Nombre Usuario',
  'email@example.com',
  'member',
  NULL,
  false
);
```

## Checklist de Verificación

- [ ] Edge Function `invite-user-to-organization` está desplegada
- [ ] Variables de entorno `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` están configuradas
- [ ] Política RLS `organizationusers_insert_owners_admins` permite a SuperAdmins
- [ ] El usuario tiene un token de acceso válido
- [ ] La organización existe y el `organizationId` es correcto
- [ ] No hay errores en los logs de la Edge Function

## Si el Problema Persiste

1. **Revisa los logs de la Edge Function** en Supabase Dashboard
2. **Verifica la consola del navegador** para ver el error exacto
3. **Prueba crear un usuario desde SQL** para verificar que las políticas RLS funcionan
4. **Verifica que el usuario sea realmente SuperAdmin** consultando la tabla `PlatformAdmins`

