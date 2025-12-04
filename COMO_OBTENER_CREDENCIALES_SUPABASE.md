# Cómo Obtener las Credenciales de Supabase

Las credenciales que me diste (`sb_publishable_...`) parecen ser de **Stripe**, no de Supabase.

## Para Supabase necesitas:

### 1. Project URL
- Formato: `https://xxxxx.supabase.co`
- Ejemplo: `https://abcdefghijklmnop.supabase.co`

### 2. Anon/Public Key
- Formato: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (un JWT token largo)
- Es una cadena muy larga que comienza con `eyJ`

## Pasos para obtenerlas:

1. Ve a [supabase.com](https://supabase.com) e inicia sesión
2. Si no tienes un proyecto, crea uno nuevo (New Project)
3. Una vez creado, ve a **Settings** (⚙️) en el menú lateral
4. Haz clic en **API** en el submenú
5. Ahí encontrarás:
   - **Project URL** → Copia este valor
   - **anon public** key → Copia este valor (es el que dice "public" o "anon")

## Configuración:

Crea un archivo `.env.local` en la raíz del proyecto con:

```env
VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**⚠️ IMPORTANTE:**
- NO uses el "service_role" key en el frontend (es secreto)
- Solo usa el "anon" o "public" key
- El Project URL debe comenzar con `https://` y terminar con `.supabase.co`

## Mientras tanto:

La aplicación ahora funciona en **modo demo** sin necesidad de Supabase. Puedes usarla normalmente y cuando tengas las credenciales correctas, solo agrega el archivo `.env.local` y reinicia el servidor.

