# Cómo Verificar la Clave Correcta de Supabase

## ⚠️ IMPORTANTE: Formato de Claves

**Supabase** usa claves JWT que empiezan con `eyJ` (son tokens muy largos)
**Stripe** usa claves que empiezan con `sk_` o `pk_` o `sb_publishable_`

## Pasos para Obtener la Clave Correcta de Supabase:

1. Ve a [supabase.com](https://supabase.com) e inicia sesión
2. Selecciona tu proyecto: `pxagzvazgbbpbxzaamer`
3. Ve a **Settings** (⚙️) en el menú lateral
4. Haz clic en **API** en el submenú
5. Busca la sección de **API Keys**

### En la sección de API Keys deberías ver:

#### Opción 1: Si ves "anon" y "service_role"
- **anon public** key → Es un JWT largo que empieza con `eyJ...` ← **USA ESTA**
- **service_role** key → NO uses esta (es secreta)

#### Opción 2: Si ves "publishable" y "secret"
- **publishable** key → Debería ser un JWT largo que empieza con `eyJ...` ← **USA ESTA**
- **secret** key → NO uses esta (es secreta)

### ⚠️ Si la clave "publishable" empieza con `sb_publishable_`:

Esa NO es una clave de Supabase, es de **Stripe**. 

**Verifica:**
- ¿Estás en el proyecto correcto de Supabase?
- ¿Estás en la sección correcta (Settings > API)?
- ¿Hay otra clave que sea un JWT largo (empieza con `eyJ`)?

## La Clave Actual en .env.local:

Tu `.env.local` actualmente tiene:
```
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

Esta es una clave válida de Supabase (formato JWT). Si esta no funciona, el problema probablemente NO es la clave, sino:
- CSP bloqueando la conexión
- Proyecto pausado
- Problema de red/CORS

## Prueba Rápida:

1. Abre la consola del navegador (F12 > Console)
2. Intenta hacer login
3. Revisa los mensajes:
   - `🔧 Supabase config loaded:` - ¿Qué clave muestra?
   - `🌐 Supabase fetch:` - ¿Se hace la petición?
   - `❌ Supabase fetch failed:` - ¿Qué error muestra?

