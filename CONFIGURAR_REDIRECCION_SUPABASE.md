# 🔧 Configurar URL de Redirección en Supabase

## Problema
Supabase está enviando los enlaces de confirmación de email a `localhost:3000` pero tu aplicación corre en `localhost:5173`.

## Solución: Actualizar URL de Redirección en Supabase

### Pasos:

1. **Ve al Dashboard de Supabase:**
   - Abre [supabase.com](https://supabase.com)
   - Inicia sesión
   - Selecciona tu proyecto

2. **Navega a Authentication Settings:**
   - En el menú lateral, haz clic en **Authentication** (o **Auth**)
   - Luego haz clic en **URL Configuration** (o **URLs**)

3. **Actualiza las URLs de redirección:**

   En la sección **Redirect URLs**, agrega estas URLs (una por línea):
   
   ```
   http://localhost:5173
   http://localhost:5173/
   http://localhost:5173/dashboard
   http://localhost:5173/login
   http://localhost:5173/signup
   ```

   **Para producción**, también agrega tu dominio:
   ```
   https://tu-dominio.com
   https://tu-dominio.com/
   https://tu-dominio.com/dashboard
   ```

4. **Actualiza Site URL:**
   - En la sección **Site URL**, cambia de:
     ```
     http://localhost:3000
     ```
   - A:
     ```
     http://localhost:5173
     ```

5. **Guarda los cambios:**
   - Haz clic en **Save** o **Update**

6. **Verifica Email Templates (opcional):**
   - Ve a **Authentication** > **Email Templates**
   - Revisa que las plantillas de email usen la variable `{{ .SiteURL }}` en lugar de URLs hardcodeadas
   - Esto asegura que los emails usen la URL correcta automáticamente

## URLs Importantes a Configurar

### Site URL (URL Principal):
```
http://localhost:5173
```

### Redirect URLs (URLs Permitidas):
```
http://localhost:5173
http://localhost:5173/
http://localhost:5173/dashboard
http://localhost:5173/login
http://localhost:5173/signup
http://localhost:5173/reset-password
http://localhost:5173/new-password
```

## Notas Importantes

1. **No uses `localhost:3000`** - Esta es la URL antigua que causa el problema
2. **Asegúrate de guardar** los cambios después de actualizar
3. **Los cambios son inmediatos** - No necesitas reiniciar nada
4. **Para desarrollo local**, usa `localhost:5173` (puerto de Vite)
5. **Para producción**, usa tu dominio real con `https://`

## Verificación

Después de actualizar:

1. Intenta crear un nuevo usuario o solicitar un reset de contraseña
2. Revisa el email que recibes
3. El enlace debería apuntar a `localhost:5173` en lugar de `localhost:3000`

## Si el Problema Persiste

1. **Limpia la caché del navegador**
2. **Verifica que la app esté corriendo en el puerto 5173:**
   ```bash
   npm run dev
   ```
   Deberías ver: `Local: http://localhost:5173`

3. **Revisa la consola del navegador** para ver si hay errores

4. **Verifica las variables de entorno:**
   - Asegúrate de que `.env.local` tenga:
     ```
     VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
     VITE_SUPABASE_ANON_KEY=tu-clave-anon
     ```

## Configuración Adicional (Opcional)

Si quieres que Supabase también redirija a otros puertos durante desarrollo, puedes agregar:

```
http://localhost:5173
http://localhost:3000
http://localhost:5174
```

Pero es mejor usar solo el puerto correcto para evitar confusión.

