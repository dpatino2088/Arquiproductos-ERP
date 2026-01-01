# 🔧 Solución: localhost no está funcionando

## Diagnóstico Rápido

### 1. Verificar que Node.js esté instalado

```bash
node --version
npm --version
```

**Si no está instalado:**
- Instala Node.js desde [nodejs.org](https://nodejs.org/) (versión 18 o superior)

### 2. Instalar dependencias (si no lo has hecho)

```bash
cd "/Users/diomedespatino/Documents/6.PROGRAMACION/adaptio erp"
npm install
```

### 3. Verificar archivo .env.local

El servidor necesita las credenciales de Supabase. Crea o verifica el archivo `.env.local` en la raíz del proyecto:

```bash
# Verificar si existe
ls -la .env.local
```

**Si NO existe, créalo:**

```env
VITE_SUPABASE_URL=https://gfanmftbdztyifagpmfn.supabase.co
VITE_SUPABASE_ANON_KEY=tu-anon-public-key-aqui
```

**Para obtener la clave:**
1. Ve a [supabase.com](https://supabase.com)
2. Selecciona tu proyecto
3. Settings > API
4. Copia la clave **"anon public"** o **"publishable"**

### 4. Iniciar el servidor de desarrollo

```bash
cd "/Users/diomedespatino/Documents/6.PROGRAMACION/adaptio erp"
npm run dev
```

**Deberías ver algo como:**
```
  VITE v7.x.x  ready in xxx ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
```

### 5. Verificar que el puerto 5173 esté libre

```bash
lsof -ti:5173
```

**Si hay un proceso usando el puerto:**
```bash
# Matar el proceso
kill -9 $(lsof -ti:5173)
# Luego iniciar de nuevo
npm run dev
```

### 6. Si sigue sin funcionar

**Verifica errores en la consola:**
- Abre la terminal donde ejecutaste `npm run dev`
- Busca mensajes de error en rojo

**Errores comunes:**
- `EADDRINUSE: address already in use` → El puerto está ocupado
- `Cannot find module` → Falta `npm install`
- `Failed to load .env.local` → Problema con las credenciales de Supabase

### 7. Alternativa: Usar otro puerto

Si el puerto 5173 está ocupado, puedes usar otro:

```bash
npm run dev -- --port 3000
```

Luego accede a: `http://localhost:3000`

---

## Comandos Rápidos (Copia y Pega)

```bash
# 1. Ir al directorio
cd "/Users/diomedespatino/Documents/6.PROGRAMACION/adaptio erp"

# 2. Instalar dependencias (si es necesario)
npm install

# 3. Verificar puerto
lsof -ti:5173 && echo "Puerto ocupado" || echo "Puerto libre"

# 4. Matar proceso en puerto 5173 (si está ocupado)
kill -9 $(lsof -ti:5173) 2>/dev/null

# 5. Iniciar servidor
npm run dev
```

---

## ¿Qué deberías ver cuando funciona?

1. **En la terminal:**
   ```
   VITE v7.x.x  ready in xxx ms
   ➜  Local:   http://localhost:5173/
   ```

2. **En el navegador (http://localhost:5173):**
   - Deberías ver la aplicación cargando
   - Si hay errores, aparecerán en la consola del navegador (F12)

---

## Si el problema persiste

Comparte:
1. El output completo de `npm run dev`
2. Cualquier error que veas en la terminal
3. Cualquier error en la consola del navegador (F12 > Console)


