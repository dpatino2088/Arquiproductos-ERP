# 🔐 FLUJO DE PASSWORD TEMPORAL - Instrucciones

**Fecha:** 2026-01-12  
**Objetivo:** Crear usuarios con password temporal + forzar cambio en primer login

---

## ✅ Cambios Implementados

### 1. Migración SQL
**Archivo:** `database/migrations/541_temp_password_flow.sql`

**Qué hace:**
- Agrega columnas `must_change_password` y `temp_password_set_at` a OrganizationUsers
- Agrega las mismas columnas a CompanyPortalUsers
- Crea unique constraints
- Crea función RPC `get_must_change_password()`

### 2. Edge Function
**Archivo:** `supabase/functions/create-temp-user/index.ts`

**Qué hace:**
- Crea auth user con password temporal segura (16 chars)
- Crea membership con `status='active'` y `must_change_password=true`
- Envía email vía Resend con credenciales
- Usa `getAppOrigin(req)` para soportar local + Vercel sin cambiar secrets

### 3. Frontend
**Archivos modificados:**
- `src/pages/settings/OrganizationUserNew.tsx` - Usa `create-temp-user`
- `src/pages/settings/CompanyPortalUsers.tsx` - Usa `create-temp-user`
- `src/pages/auth/Login.tsx` - Guard para forzar cambio de password
- `src/pages/auth/SetPassword.tsx` - Marca `must_change_password=false`

---

## 🚀 Pasos para Deployar

### Paso 1: Configurar secrets en Supabase

```
Ve a: Supabase Dashboard → Edge Functions → Secrets

Verifica/crea estos secrets:
- SUPABASE_URL (ya existe ✅)
- SUPABASE_SERVICE_ROLE_KEY (ya existe ✅)
- FROM_EMAIL = onboarding@resend.dev (o tu email verificado)
- RESEND_API_KEY = tu API key de Resend
- APP_ORIGIN = http://localhost:5173 (opcional, se auto-detecta)
```

**⚠️ IMPORTANTE sobre FROM_EMAIL:**
- ✅ Correcto: `onboarding@resend.dev`, `noreply@adaptio.app`
- ❌ Incorrecto: URLs como `https://arquiproductos-erp.vercel.app`

### Paso 2: Ejecutar migración SQL

```sql
-- Supabase Dashboard → SQL Editor
-- Copiar y pegar: database/migrations/541_temp_password_flow.sql
-- Ejecutar
```

### Paso 3: Deploy Edge Function

```bash
cd "/Users/diomedespatino/Documents/6.PROGRAMACION/adaptio erp"
npx supabase functions deploy create-temp-user
```

O si la función ya existe en Supabase (como mencionaste), re-deployarla con la nueva versión.

### Paso 4: Verificar deployment

```
Supabase Dashboard → Edge Functions → create-temp-user
- Debe aparecer en la lista
- Verificar que los secrets están configurados
```

---

## 🧪 Testing del Flujo Completo

### Test 1: Crear Organization User

1. Ve a Settings → Organization Users → New
2. Completa el formulario:
   - Name: `Test User`
   - Email: `test@example.com`
   - Role: `operator`
3. Click "Crear Usuario"
4. Deberías ver:
   - ✅ Notificación: "Usuario Creado. Se envió email con credenciales temporales"
   - ✅ Tab "Permissions" activado automáticamente
   - ✅ Puedes asignar permisos

5. Revisa el email enviado:
   - Subject: "Tu acceso a Adaptio - Credenciales temporales"
   - Contiene: email + password temporal + link a /login

6. Haz login con las credenciales temporales
7. Debes ser redirigido automáticamente a `/set-password`
8. Cambia la contraseña
9. Debes llegar al `/dashboard` ✅

### Test 2: Crear Portal User

1. Ve a Settings → Company Portal Users → New
2. Completa el formulario:
   - Email: `portal@example.com`
   - Role: `member`
   - Company: Selecciona una
3. Click "Crear Usuario"
4. Mismo flujo que Test 1

---

## 🔍 Debugging

### En Console (DevTools)

Después de crear un usuario, busca:

```javascript
[OrganizationUserNew] User created: { ok: true, user_id: "...", email: "..." }
[OrganizationUserNew] Found created user ID: ...
```

### En Supabase Dashboard

1. Ve a Edge Functions → create-temp-user → Logs
2. Busca invocaciones recientes
3. Deberías ver status 200 (OK)

### Si el email no llega

1. Verifica en Supabase Logs que no haya error de Resend
2. Verifica que `FROM_EMAIL` sea un email válido
3. Verifica que `RESEND_API_KEY` esté configurado
4. Revisa spam/junk en tu email

---

## 📊 Flujo Completo

```
1. Admin crea usuario desde UI
   ↓
2. Frontend llama create-temp-user Edge Function
   ↓
3. Edge Function:
   - Crea/actualiza auth.users con temp password
   - Crea membership (status=active, must_change_password=true)
   - Envía email con credenciales
   ↓
4. Usuario recibe email con:
   - Email
   - Password temporal
   - Link a /login
   ↓
5. Usuario hace login (signInWithPassword)
   ↓
6. Frontend llama get_must_change_password()
   ↓
7. Si must_change_password=true → redirect a /set-password
   ↓
8. Usuario cambia password
   ↓
9. Frontend marca must_change_password=false
   ↓
10. Redirect a /dashboard ✅
```

---

## ✅ Ventajas de Este Flujo

- ✅ No depende de magic links/invites complicados
- ✅ No depende de PKCE/OAuth flows
- ✅ Login normal con email+password
- ✅ Forzar cambio de password en primer login
- ✅ Admin puede crear usuarios inmediatamente
- ✅ Funciona en local + Vercel sin cambiar secrets
- ✅ Email personalizado con credenciales

---

## 📝 Secretos Necesarios

| Secret | Ejemplo | Descripción |
|--------|---------|-------------|
| `FROM_EMAIL` | `onboarding@resend.dev` | Email válido (NO URL) |
| `RESEND_API_KEY` | `re_xxx` | API key de Resend |
| `APP_ORIGIN` | `http://localhost:5173` | Opcional (se auto-detecta) |

---

**¿Listo para deployar? Ejecuta la migración SQL primero, luego deploy de la Edge Function.**
