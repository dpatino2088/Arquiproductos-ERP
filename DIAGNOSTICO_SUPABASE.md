# Diagnóstico de Conexión con Supabase

## Pasos para Diagnosticar el Problema

### 1. Verificar Variables de Entorno en el Navegador

1. Abre la consola del navegador (F12 > Console)
2. Intenta hacer login
3. Deberías ver estos mensajes:
   - `🔧 Supabase config loaded:` - con información sobre las variables
   - `🌐 Supabase fetch:` - cuando se hace la petición
   - `❌ Supabase fetch failed:` - si falla

### 2. Verificar Errores de CSP (Content Security Policy)

1. Abre la consola del navegador (F12 > Console)
2. Busca errores que mencionen "Content Security Policy" o "CSP"
3. Si ves errores de CSP, significa que el CSP está bloqueando la conexión

### 3. Verificar Errores de CORS

1. Abre la pestaña **Network** en las herramientas de desarrollo (F12 > Network)
2. Intenta hacer login
3. Busca la petición a `https://pxagzvazgbbpbxzaamer.supabase.co/auth/v1/token`
4. Haz clic en la petición y revisa:
   - **Status**: ¿Qué código de estado tiene?
   - **Headers**: ¿Hay algún error de CORS?
   - **Response**: ¿Qué respuesta devuelve?

### 4. Probar Conexión Directa desde la Consola

Abre la consola del navegador (F12 > Console) y ejecuta:

```javascript
fetch('https://pxagzvazgbbpbxzaamer.supabase.co/auth/v1/health', {
  method: 'GET'
})
.then(r => r.text())
.then(console.log)
.catch(console.error);
```

Si esto funciona, el problema no es de red. Si falla, hay un problema de conexión o CSP.

### 5. Verificar que el Proyecto de Supabase esté Activo

1. Ve a [supabase.com](https://supabase.com)
2. Selecciona tu proyecto
3. Verifica que NO esté pausado
4. Si está pausado, haz clic en "Restore" o "Resume"

### 6. Verificar Credenciales

1. Ve a tu proyecto en Supabase
2. Settings > API
3. Verifica que:
   - **Project URL** sea: `https://pxagzvazgbbpbxzaamer.supabase.co`
   - **anon public** key sea la que tienes en `.env.local`

## Soluciones Comunes

### Si el CSP está bloqueando:
- El CSP ya está actualizado en `vite.config.ts`
- Reinicia el servidor después de cambiar `vite.config.ts`

### Si hay errores de CORS:
- Supabase debería permitir CORS automáticamente
- Verifica que la URL sea correcta
- Verifica que no haya un proxy o firewall bloqueando

### Si las variables no se cargan:
- Asegúrate de que `.env.local` esté en la raíz del proyecto
- Reinicia el servidor después de crear/modificar `.env.local`
- Verifica que las variables empiecen con `VITE_`

