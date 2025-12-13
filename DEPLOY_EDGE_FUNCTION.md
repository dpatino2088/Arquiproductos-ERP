# 🚀 Cómo Desplegar la Edge Function `invite-user-to-organization`

## Problema Actual
Los errores de CORS indican que la Edge Function no está desplegada o no está respondiendo correctamente.

## Solución: Desplegar la Edge Function

### Opción 1: Usando Supabase CLI (Recomendado)

1. **Instalar Supabase CLI** (si no lo tienes):
   ```bash
   npm install -g supabase
   ```

2. **Iniciar sesión en Supabase CLI**:
   ```bash
   supabase login
   ```

3. **Vincular tu proyecto**:
   ```bash
   supabase link --project-ref gfanmftbdztyifagpmfn
   ```
   (Reemplaza `gfanmftbdztyifagpmfn` con tu project ref si es diferente)

4. **Desplegar la función**:
   ```bash
   supabase functions deploy invite-user-to-organization
   ```

### Opción 2: Desde el Dashboard de Supabase

1. Ve a tu proyecto en [supabase.com](https://supabase.com)
2. Navega a **Edge Functions** en el menú lateral
3. Haz clic en **"Create a new function"** o busca `invite-user-to-organization`
4. Si la función existe pero no está desplegada, haz clic en **"Deploy"**
5. Si no existe, crea una nueva función y copia el contenido de `supabase/functions/invite-user-to-organization/index.ts`

### Opción 3: Verificar Variables de Entorno

La Edge Function necesita estas variables de entorno en Supabase:

1. Ve a **Edge Functions** → **invite-user-to-organization** → **Settings**
2. Verifica que estén configuradas:
   - `SUPABASE_URL` - Debería ser `https://gfanmftbdztyifagpmfn.supabase.co`
   - `SUPABASE_SERVICE_ROLE_KEY` - Tu service role key (no la anon key)

### Verificar que la Función Está Desplegada

1. Ve a **Edge Functions** en el Dashboard
2. Busca `invite-user-to-organization`
3. Debería aparecer como **"Active"** o **"Deployed"**
4. Haz clic en la función para ver los logs

### Probar la Función Manualmente

Puedes probar la función desde el Dashboard:

1. Ve a **Edge Functions** → **invite-user-to-organization**
2. Haz clic en **"Invoke"** o **"Test"**
3. Usa este JSON de prueba:
   ```json
   {
     "organizationId": "TU_ORGANIZATION_ID",
     "name": "Test User",
     "email": "test@example.com",
     "role": "member",
     "invitedByUserId": "TU_USER_ID"
   }
   ```

## Si el Error Persiste

### Verificar la URL de la Función

En la consola del navegador, verifica que la URL sea correcta:
```
https://gfanmftbdztyifagpmfn.supabase.co/functions/v1/invite-user-to-organization
```

### Verificar Logs de la Función

1. Ve a **Edge Functions** → **invite-user-to-organization** → **Logs**
2. Busca errores relacionados con:
   - Variables de entorno faltantes
   - Errores de autenticación
   - Errores de base de datos

### Verificar CORS en Supabase

1. Ve a **Settings** → **API**
2. Verifica que **"CORS"** esté configurado para permitir `http://localhost:5173`
3. O usa `*` para desarrollo (no recomendado para producción)

## Comandos Rápidos

```bash
# Verificar funciones desplegadas
supabase functions list

# Ver logs de la función
supabase functions logs invite-user-to-organization

# Redesplegar la función
supabase functions deploy invite-user-to-organization --no-verify-jwt
```

## Nota Importante

Si la función no está desplegada, **NO funcionará** independientemente de los cambios en el código. El error de CORS es un síntoma de que la función no existe o no está respondiendo.

