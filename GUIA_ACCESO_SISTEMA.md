# 🔐 Guía de Acceso al Sistema Adaptio ERP

## 📋 Opciones para Acceder al Sistema

Tienes **3 formas** de acceder al sistema:

---

## ✅ Opción 1: Crear Usuario Directo (Recomendado para Desarrollo)

Esta es la forma más simple para empezar a usar el sistema sin necesidad de crear una Organization primero.

### Pasos:

1. **Navega a la página de registro:**
   ```
   http://localhost:5173/signup
   ```
   O desde la página de login, haz clic en "Sign up" o "Crear cuenta"

2. **Completa el formulario:**
   - **Nombre**: Tu nombre completo
   - **Email**: Tu email (ej: `tu@email.com`)
   - **Teléfono**: (Opcional)
   - **Contraseña**: Mínimo 6 caracteres
   - **Confirmar Contraseña**: Debe coincidir

3. **Haz clic en "Sign Up"**

4. **Inicia sesión:**
   - Ve a `/login`
   - Ingresa el email y contraseña que acabas de crear
   - Serás redirigido al Dashboard

### ⚠️ Nota sobre Verificación de Email:

- Si Supabase tiene **verificación de email habilitada**, recibirás un email de confirmación
- Si **NO** está habilitada, el usuario se crea automáticamente y puedes iniciar sesión de inmediato

---

## ✅ Opción 2: Crear Organization (Para Producción)

Esta es la forma recomendada para producción, ya que crea una Organization y un usuario owner automáticamente.

### Pasos:

1. **Accede a Settings > Organization Profile:**
   - Necesitas estar autenticado primero (usa Opción 1 para crear un usuario admin inicial)
   - O si ya tienes acceso, ve a: `/settings/organization-profile`

2. **Completa el formulario de Organization:**
   - Organization Name (requerido)
   - Main Email (requerido) - Este será el email del owner
   - ID Number (requerido)
   - Country, Address, etc.

3. **Haz clic en "Save Changes"**

4. **Se mostrará un modal con:**
   - Email del owner
   - Contraseña temporal generada automáticamente
   - **IMPORTANTE**: Copia esta contraseña, solo se muestra una vez

5. **El owner puede iniciar sesión:**
   - Ve a `/login`
   - Email: El `main_email` de la Organization
   - Password: La contraseña temporal mostrada en el modal

---

## ✅ Opción 3: Crear Usuario desde Supabase Dashboard

Si prefieres crear usuarios directamente desde Supabase:

### Pasos:

1. **Ve al Dashboard de Supabase:**
   - Abre tu proyecto en [supabase.com](https://supabase.com)
   - Navega a **Authentication** → **Users**

2. **Agrega un nuevo usuario:**
   - Haz clic en **"Add User"** o **"Invite User"**
   - Completa:
     - **Email**: El email del usuario
     - **Password**: Una contraseña segura
     - **Auto-confirm email**: ✅ (marca esta opción para que no necesite verificación)

3. **Inicia sesión:**
   - Ve a `/login`
   - Usa el email y contraseña que configuraste

---

## 🚀 Flujo Recomendado para Empezar

### Para Desarrollo/Testing:

1. **Crea un usuario admin inicial:**
   - Ve a `/signup`
   - Crea tu cuenta con email y contraseña
   - Inicia sesión en `/login`

2. **Crea una Organization:**
   - Una vez dentro, ve a **Settings > Organization Profile**
   - Crea tu primera Organization
   - Anota la contraseña temporal del owner

3. **Usa el owner para futuros accesos:**
   - El owner de la Organization puede iniciar sesión con su email y contraseña temporal

### Para Producción:

1. **Crea la primera Organization:**
   - Un administrador del sistema crea la Organization
   - Se genera automáticamente el usuario owner
   - Se muestra la contraseña temporal (solo una vez)

2. **El owner inicia sesión:**
   - Usa el email y contraseña temporal
   - **Recomendación**: Cambiar la contraseña después del primer login

---

## 🔧 Configuración de Supabase

### Verificación de Email:

Para desarrollo, es recomendable **deshabilitar** la verificación de email:

1. Ve a Supabase Dashboard
2. **Authentication** → **Settings** → **Email Auth**
3. Desmarca **"Enable email confirmations"** (o configúralo según necesites)

### Si el Email ya está Registrado:

Si intentas crear un usuario y el email ya existe:
- Ve a `/login` e inicia sesión con ese email
- O usa "Forgot password?" para resetear la contraseña

---

## 📝 Resumen de URLs

- **Login**: `/login` o `http://localhost:5173/login`
- **Signup**: `/signup` o `http://localhost:5173/signup`
- **Organization Profile**: `/settings/organization-profile` (requiere autenticación)
- **Dashboard**: `/dashboard` (requiere autenticación)

---

## ❓ Problemas Comunes

### "No puedo crear un usuario"
- Verifica que Supabase esté configurado (variables de entorno)
- Verifica que el proyecto de Supabase esté activo (no pausado)
- Revisa la consola del navegador para ver errores

### "El email ya está registrado"
- Ve a `/login` e inicia sesión
- O usa "Forgot password?" para resetear

### "No recibo el email de confirmación"
- Verifica la carpeta de spam
- O deshabilita la verificación de email en Supabase Dashboard

---

## 🎯 Recomendación Inicial

**Para empezar rápidamente:**

1. Ve a `http://localhost:5173/signup`
2. Crea tu cuenta
3. Inicia sesión en `http://localhost:5173/login`
4. Ya estarás dentro del sistema y podrás crear Organizations

