# Actualizar Credenciales de Supabase

## ⚠️ IMPORTANTE: Usa la Clave "Publishable"

Supabase ahora recomienda usar la clave **"publishable"** en lugar de "anon" (aunque ambas funcionan igual).

## Pasos para Obtener la Clave Publishable:

1. Ve a tu proyecto en [supabase.com](https://supabase.com)
2. Ve a **Settings** (⚙️) > **API**
3. Busca la sección de **API Keys**
4. Verás dos tipos de claves:
   - **Publishable key** ← **USA ESTA** ✅ (es la que dice "publishable" o "public")
   - **Secret key** ← NO uses esta en el frontend ❌

## Actualizar .env.local:

Abre el archivo `.env.local` y actualiza con la clave **publishable**:

```env
VITE_SUPABASE_URL=https://pxagzvazgbbpbxzaamer.supabase.co
VITE_SUPABASE_ANON_KEY=tu-publishable-key-aqui
```

**Nota:** Aunque la variable se llama `VITE_SUPABASE_ANON_KEY`, puedes usar la clave "publishable" - funcionan igual.

## Después de Actualizar:

1. **REINICIA el servidor de desarrollo:**
   - Detén el servidor (Ctrl+C)
   - Ejecuta: `npm run dev`

2. **Verifica en la consola del navegador:**
   - Abre F12 > Console
   - Deberías ver las variables cargadas correctamente

## Si Sigue Fallando:

1. **Verifica que el proyecto esté activo:**
   - En Supabase Dashboard, verifica que el proyecto no esté pausado
   - Si está pausado, haz clic en "Restore"

2. **Verifica la clave:**
   - La clave "publishable" es un JWT token largo que empieza con `eyJ`
   - NO uses la clave "secret" (esa es para backend)

3. **Prueba la conexión:**
   - Abre la consola del navegador
   - Intenta hacer login/signup
   - Revisa qué error exacto aparece

