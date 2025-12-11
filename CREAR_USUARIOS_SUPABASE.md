# 🔐 Guía para Crear Usuarios Autenticados en Supabase

## Opción 1: Crear Usuario desde la Aplicación (Recomendado)

1. **Inicia el servidor de desarrollo:**
   ```bash
   npm run dev
   ```

2. **Navega a la página de registro:**
   - Abre `http://localhost:5173/signup` en tu navegador
   - Completa el formulario con:
     - Nombre
     - Email
     - Teléfono (opcional)
     - Contraseña (mínimo 6 caracteres)
     - Confirmar contraseña

3. **Verifica el usuario:**
   - Si tienes habilitada la verificación de email en Supabase, recibirás un email de confirmación
   - Si no, el usuario se creará automáticamente

## Opción 2: Crear Usuario desde el Dashboard de Supabase

1. **Ve al Dashboard de Supabase:**
   - Abre tu proyecto en [supabase.com](https://supabase.com)
   - Navega a **Authentication** → **Users**

2. **Agrega un nuevo usuario:**
   - Haz clic en **"Add User"** o **"Invite User"**
   - Completa:
     - Email
     - Contraseña (o deja que Supabase genere una)
     - Auto-confirm email: ✅ (para que no necesite verificación)

3. **El usuario recibirá un email de invitación** (si usas "Invite User")

## Opción 3: Crear Usuario con SQL (Para Testing)

Ejecuta este SQL en el **SQL Editor** de Supabase:

```sql
-- Crear un usuario de prueba
-- NOTA: Esto crea el usuario en auth.users pero necesitas la contraseña hasheada
-- Es mejor usar la API o el Dashboard

-- Alternativa: Usar la función de Supabase para crear usuario
-- Esto requiere usar la API o el Dashboard, no se puede hacer directamente con SQL
```

**Mejor opción con SQL - Usar la función de Supabase:**

```sql
-- Esto NO funciona directamente, necesitas usar la API
-- Pero puedes verificar usuarios existentes:

-- Ver todos los usuarios
SELECT id, email, created_at, email_confirmed_at 
FROM auth.users 
ORDER BY created_at DESC;

-- Ver perfiles de usuarios
SELECT * FROM public.profiles;
```

## Opción 4: Crear Usuario con Script de Node.js

Crea un archivo temporal `create-user.js` en la raíz del proyecto:

```javascript
import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import { readFileSync } from 'fs';

// Cargar variables de entorno
const env = readFileSync('.env.local', 'utf-8');
const urlMatch = env.match(/VITE_SUPABASE_URL=(.+)/);
const keyMatch = env.match(/VITE_SUPABASE_ANON_KEY=(.+)/);

const supabaseUrl = urlMatch?.[1] || '';
const supabaseKey = keyMatch?.[1] || '';

// IMPORTANTE: Para crear usuarios necesitas el SERVICE_ROLE_KEY, no el ANON_KEY
// Obtén el SERVICE_ROLE_KEY de: Supabase Dashboard > Settings > API > service_role key

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function createUser(email, password, name) {
  const { data, error } = await supabase.auth.admin.createUser({
    email: email,
    password: password,
    email_confirm: true, // Auto-confirmar email
    user_metadata: {
      name: name
    }
  });

  if (error) {
    console.error('Error creando usuario:', error);
    return;
  }

  console.log('✅ Usuario creado exitosamente:');
  console.log('ID:', data.user.id);
  console.log('Email:', data.user.email);
  console.log('Name:', data.user.user_metadata.name);
}

// Ejemplo de uso
createUser('usuario@ejemplo.com', 'password123', 'Nombre Usuario');
```

**⚠️ IMPORTANTE:** Este script requiere el **SERVICE_ROLE_KEY**, no el ANON_KEY. El SERVICE_ROLE_KEY solo debe usarse en el backend, nunca en el frontend.

## Opción 5: Usar la API REST de Supabase

Puedes crear usuarios usando curl o Postman:

```bash
curl -X POST 'https://TU_PROYECTO.supabase.co/auth/v1/admin/users' \
  -H "apikey: TU_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer TU_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "usuario@ejemplo.com",
    "password": "password123",
    "email_confirm": true,
    "user_metadata": {
      "name": "Nombre Usuario"
    }
  }'
```

## Verificar que el Usuario se Creó Correctamente

1. **En el Dashboard de Supabase:**
   - Ve a **Authentication** → **Users**
   - Deberías ver el nuevo usuario en la lista

2. **Verificar la tabla de perfiles:**
   - Ve a **Table Editor** → **profiles**
   - Debería existir un registro con el mismo `id` que el usuario en `auth.users`

3. **Probar el login:**
   - Ve a `http://localhost:5173/login`
   - Intenta iniciar sesión con el email y contraseña creados

## Configuración Importante en Supabase

### 1. Deshabilitar Verificación de Email (Para Desarrollo)

Si quieres que los usuarios se creen sin verificación de email:

1. Ve a **Authentication** → **Providers** → **Email**
2. Desactiva **"Confirm email"** (solo para desarrollo/testing)
3. ⚠️ **NO hagas esto en producción**

### 2. Configurar Políticas RLS

Asegúrate de que las políticas RLS estén configuradas correctamente:

```sql
-- Verificar que la tabla profiles existe y tiene RLS habilitado
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'profiles';

-- Ver políticas existentes
SELECT * FROM pg_policies WHERE tablename = 'profiles';
```

## Troubleshooting

### El usuario se crea pero no puede iniciar sesión
- Verifica que el email esté confirmado
- Verifica que la contraseña sea correcta
- Revisa la consola del navegador para errores

### El perfil no se crea automáticamente
- Verifica que el trigger `on_auth_user_created` exista
- Ejecuta el SQL de creación de trigger del archivo `SUPABASE_SETUP.md`

### Error de permisos
- Verifica que las políticas RLS estén configuradas
- Verifica que estés usando las credenciales correctas

## Próximos Pasos

Una vez que tengas usuarios creados, puedes:
1. Asignarlos a empresas en la tabla `company_users`
2. Crear empleados asociados en la tabla `employees`
3. Configurar roles y permisos

