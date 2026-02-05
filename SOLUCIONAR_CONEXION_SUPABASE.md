# Solucionar "Failed to fetch" / no conectar con Supabase

## 1. Permitir tu origen en Supabase (CORS)

1. Entra al [Dashboard de Supabase](https://supabase.com/dashboard) y abre tu proyecto.
2. Ve a **Project Settings** (icono de engranaje en el menú lateral).
3. En el menú izquierdo, entra a **API** (o **Authentication**).
4. Busca una de estas opciones (depende de la versión del dashboard):
   - **Site URL**: pon `http://localhost:5173` (o añádelo si ya hay otra).
   - **Redirect URLs** / **Additional Redirect URLs**: añade `http://localhost:5173` y `http://localhost:5173/**`.
   - **CORS / Allowed origins** (si aparece): añade `http://localhost:5173`.
5. Guarda los cambios (Save).

## 2. Comprobar que el proyecto no está pausado

- En el dashboard, si el proyecto está en pausa (proyectos gratis se pausan por inactividad), haz clic en **Restore project** / **Resume**.
- Espera unos segundos a que esté activo.

## 3. Reiniciar Vite

Si cambiaste algo en `.env.local`:

```bash
# Detén el servidor (Ctrl+C) y vuelve a arrancar
npm run dev
```

## 4. Probar de nuevo en el navegador

1. Abre (o recarga con fuerza) `http://localhost:5173/login`.
2. Usa el botón **"Probar conexión a Supabase"** para comprobar solo la conexión.
3. Si eso responde OK, prueba **Sign In** con tu email y contraseña.

## 5. Si sigue fallando

- Abre las **DevTools** (F12) → pestaña **Network**.
- Intenta iniciar sesión y mira la petición que falla (en rojo).
  - Si el error es **CORS**: vuelve al paso 1 y asegúrate de tener `http://localhost:5173` en Site URL / Redirect URLs / Allowed origins.
  - Si es **Failed to fetch** sin detalle: puede ser red, firewall o proyecto pausado (paso 2).

Tu `.env.local` está correcto; no hace falta cambiar la URL ni la anon key si no las has regenerado en Supabase.
