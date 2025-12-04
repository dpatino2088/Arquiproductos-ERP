# Guía de Migración a Supabase

## Paso 1: Crear Proyecto en Supabase

1. Ve a [supabase.com](https://supabase.com) y crea una cuenta
2. Crea un nuevo proyecto
3. Anota las siguientes credenciales (las encontrarás en Settings > API):
   - Project URL
   - Anon/Public Key
   - Service Role Key (mantén esto secreto)

## Paso 2: Instalar Dependencias

```bash
npm install @supabase/supabase-js
```

## Paso 3: Configurar Variables de Entorno

Crea un archivo `.env.local` en la raíz del proyecto:

```env
VITE_SUPABASE_URL=tu-project-url
VITE_SUPABASE_ANON_KEY=tu-anon-key
```

## Paso 4: Configurar Base de Datos en Supabase

### 4.1 Crear Tabla de Usuarios (si necesitas datos adicionales)

En el SQL Editor de Supabase, ejecuta:

```sql
-- Tabla de perfiles de usuario (extiende auth.users)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT,
  name TEXT,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  department TEXT,
  position TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Habilitar Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Política: Los usuarios pueden ver su propio perfil
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Política: Los usuarios pueden actualizar su propio perfil
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Función para crear perfil automáticamente cuando se registra un usuario
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'name', NEW.email));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para crear perfil al registrarse
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### 4.2 Configurar Autenticación en Supabase Dashboard

1. Ve a Authentication > Providers
2. Habilita los proveedores que necesites:
   - Email (ya está habilitado por defecto)
   - Google (opcional)
   - Microsoft/Azure (opcional)

## Paso 5: Configurar el Cliente de Supabase

El archivo `src/lib/supabase.ts` ya está creado con la configuración básica.

## Paso 6: Actualizar Autenticación

Los archivos de autenticación han sido actualizados para usar Supabase:
- `src/lib/supabase.ts` - Cliente de Supabase
- `src/stores/auth-store.ts` - Store actualizado para Supabase
- `src/hooks/useAuth.ts` - Hook actualizado
- `src/pages/auth/Login.tsx` - Login con Supabase
- `src/pages/auth/Signup.tsx` - Signup con Supabase

## Paso 7: Probar la Integración

1. Inicia el servidor de desarrollo: `npm run dev`
2. Ve a `/signup` y crea una cuenta
3. Verifica que puedas iniciar sesión en `/login`
4. Revisa en Supabase Dashboard > Authentication > Users que el usuario se haya creado

## Paso 8: Configurar Row Level Security (RLS)

Para cada tabla que crees en Supabase, asegúrate de:
1. Habilitar RLS
2. Crear políticas apropiadas
3. Probar que las políticas funcionan correctamente

## Notas Importantes

- **Nunca expongas el Service Role Key** en el frontend
- Usa el Anon Key solo en el frontend
- El Service Role Key solo debe usarse en el backend
- Configura políticas RLS apropiadas para cada tabla
- Considera usar Supabase Edge Functions para lógica del servidor

## Recursos Adicionales

- [Documentación de Supabase Auth](https://supabase.com/docs/guides/auth)
- [Row Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [Supabase JavaScript Client](https://supabase.com/docs/reference/javascript/introduction)

