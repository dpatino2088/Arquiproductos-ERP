# Solución para "Failed to fetch" en Login

## Posibles Causas y Soluciones

### 1. El servidor de desarrollo no se reinició
**Solución:**
- Detén el servidor (Ctrl+C)
- Ejecuta de nuevo: `npm run dev`
- Las variables de `.env.local` solo se cargan al iniciar el servidor

### 2. No hay usuarios creados en Supabase
**Solución:**
Tienes dos opciones:

**Opción A: Crear usuario desde Signup**
1. Ve a `/signup` en tu aplicación
2. Crea una cuenta nueva
3. Luego podrás hacer login con esa cuenta

**Opción B: Crear usuario desde Supabase Dashboard**
1. Ve a tu proyecto en [supabase.com](https://supabase.com)
2. Ve a **Authentication** > **Users**
3. Haz clic en **Add user** > **Create new user**
4. Ingresa email y contraseña
5. Luego podrás hacer login con esas credenciales

### 3. El proyecto de Supabase está pausado
**Solución:**
1. Ve a tu proyecto en [supabase.com](https://supabase.com)
2. Si está pausado, haz clic en **Restore** o **Resume**
3. Espera a que el proyecto se reactive (puede tomar unos minutos)

### 4. Problema de CORS o red
**Solución:**
1. Abre la consola del navegador (F12)
2. Ve a la pestaña **Network**
3. Intenta hacer login de nuevo
4. Busca la petición a Supabase (debería ser algo como `https://pxagzvazgbbpbxzaamer.supabase.co/auth/v1/token`)
5. Revisa si hay algún error de CORS o red

### 5. Verificar que las credenciales sean correctas
**Solución:**
1. Ve a tu proyecto en Supabase
2. Settings > API
3. Verifica que:
   - **Project URL** sea exactamente: `https://pxagzvazgbbpbxzaamer.supabase.co`
   - **anon public** key sea la que tienes en `.env.local`
4. Si son diferentes, actualiza `.env.local` y reinicia el servidor

## Verificación Rápida

Abre la consola del navegador (F12) y revisa:
1. ¿Aparece algún error en rojo?
2. ¿Ves el mensaje "Attempting to sign in with Supabase..." cuando haces login?
3. ¿Qué dice el error exacto?

## Próximos Pasos

1. **Primero, crea un usuario** usando la página de Signup (`/signup`)
2. Luego intenta hacer login con ese usuario
3. Si sigue fallando, comparte el error exacto de la consola del navegador

