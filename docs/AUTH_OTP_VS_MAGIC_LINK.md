# OTP vs Magic Link en el login

## Qué está pasando

Al pedir "código OTP" en el login, el correo que llega es **"Your Magic Link"** con un enlace para iniciar sesión, en lugar de un **código de 6 dígitos** que el usuario escribe en la app.

## Causa

En Supabase, **el mismo flujo** (`signInWithOtp`) puede enviar:

- **Magic link**: el email usa la variable `{{ .ConfirmationURL }}` en la plantilla → el usuario recibe un enlace y hace clic.
- **Código OTP**: el email usa la variable `{{ .Token }}` en la plantilla → el usuario recibe un código de 6 dígitos y lo escribe en la app.

Lo que se envía **no** se decide en el código del front (no hay opción tipo “enviar OTP en vez de magic link”). Lo define la **plantilla de email** configurada en el proyecto de Supabase.

## Solución: cambiar la plantilla en Supabase

1. Entra al **Dashboard** de Supabase del proyecto.
2. Ve a **Authentication** → **Email Templates**.
3. Abre la plantilla **"Magic Link"**.
4. Sustituye (o complementa) el contenido para que el email muestre el **código de 6 dígitos** en lugar de (o además de) el enlace.

**Ejemplo de plantilla para OTP (código):**

- **Subject:** por ejemplo `Tu código de acceso` (o el que prefieras).
- **Body (HTML):** algo como:

```html
<h2>Código de acceso</h2>
<p>Tu código de un solo uso es: <strong>{{ .Token }}</strong></p>
<p>Introduce este código en la aplicación para iniciar sesión. El código caduca en unos minutos.</p>
```

Si quieres seguir ofreciendo también el enlace (por si alguien prefiere hacer clic), puedes incluir ambas cosas:

```html
<h2>Código de acceso</h2>
<p>Tu código de 6 dígitos: <strong>{{ .Token }}</strong></p>
<p>O haz clic en el enlace para iniciar sesión:</p>
<p><a href="{{ .ConfirmationURL }}">Iniciar sesión</a></p>
```

5. Guarda la plantilla.

A partir de ahí, los correos enviados al usar “Enviar código” mostrarán `{{ .Token }}` (el OTP de 6 dígitos) y los usuarios podrán copiarlo y pegarlo en la pantalla de login.

## Referencia

- [Supabase – Email Templates](https://supabase.com/docs/guides/auth/auth-email-templates): variables `{{ .Token }}` (OTP) y `{{ .ConfirmationURL }}` (magic link).
- En la app, el flujo de verificación ya está preparado para OTP: `verifyOtp({ email, token: otpCode, type: 'email' })` en `Login.tsx` y `ResetPassword.tsx`.
