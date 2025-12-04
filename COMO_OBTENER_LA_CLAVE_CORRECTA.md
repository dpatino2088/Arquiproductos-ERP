# ⚠️ IMPORTANTE: Necesitas la Clave Correcta de Supabase

Las claves que me diste (`sb_publishable_...` y `sb_secret_...`) **NO son de Supabase**. Son de otro servicio (probablemente Stripe).

## ✅ Lo que tienes correcto:
- **Project URL**: `https://pxagzvazgbbpbxzaamer.supabase.co` ✅

## ❌ Lo que necesitas cambiar:
Necesitas obtener el **"anon public" key** de Supabase, que es diferente.

## 📋 Pasos para obtener la clave correcta:

1. Ve a [supabase.com](https://supabase.com) e inicia sesión
2. Selecciona tu proyecto (el que tiene la URL `pxagzvazgbbpbxzaamer`)
3. En el menú lateral, haz clic en **Settings** (⚙️)
4. Haz clic en **API** en el submenú
5. Busca la sección **Project API keys**
6. Ahí verás varias claves:
   - **anon public** ← **ESTA ES LA QUE NECESITAS** ✅
   - service_role (secret) ← NO uses esta en el frontend
   - service_role key ← NO uses esta en el frontend

7. Copia el **anon public** key (es un token JWT muy largo que empieza con `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`)

## 🔧 Cómo actualizar el archivo .env.local:

1. Abre el archivo `.env.local` que acabo de crear
2. Reemplaza `REPLACE_WITH_YOUR_ANON_PUBLIC_KEY_FROM_SUPABASE` con el **anon public** key que copiaste
3. Debería verse así:

```env
VITE_SUPABASE_URL=https://pxagzvazgbbpbxzaamer.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4YWd6dmF6Z2JicGJ4emFhbWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTIzNDU2NzgsImV4cCI6MjAyNzk0MTY3OH0.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

4. **Reinicia el servidor de desarrollo** después de guardar el archivo:
   - Detén el servidor (Ctrl+C)
   - Ejecuta `npm run dev` de nuevo

## 🔍 ¿Cómo saber si es la clave correcta?

La clave **anon public** de Supabase:
- ✅ Es un JWT token muy largo (cientos de caracteres)
- ✅ Empieza con `eyJ` (son las primeras letras de un JWT codificado en base64)
- ✅ Está en la sección "Project API keys" > "anon public"
- ✅ Dice "public" o "anon" en el nombre

Las claves que me diste (`sb_publishable_...`):
- ❌ Son más cortas
- ❌ Empiezan con `sb_`
- ❌ Son de otro servicio (probablemente Stripe)

## 🆘 Si no encuentras la clave:

1. Asegúrate de estar en el proyecto correcto de Supabase
2. Verifica que estés en Settings > API
3. Busca específicamente "anon public" o "anon" en la lista de claves
4. Si aún no la encuentras, toma una captura de pantalla de la página Settings > API y te ayudo a identificarla

