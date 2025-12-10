# Arquiproductos ERP

Next.js 14 (App Router) + TypeScript + Supabase + Tailwind ERP skeleton for multi-empresa operation. Sigue las reglas de nombres y metadata descritas en el master prompt.

## Estructura
- `app/(auth)/login`: pantalla de acceso usando Supabase Auth.
- `app/(dashboard)`: layout con sidebar/topbar y páginas de núcleo, directorio, inventario, finanzas y configuración.
- `components/ui`: librería de UI reusable (botones, inputs, tablas, tarjetas).
- `components/layout`: shell principal, sidebar y encabezados de página.
- `lib`: clientes Supabase y helpers de auth/RLS.
- `supabase/schema.sql`: definición inicial de tablas con `company_id` y columnas de metadata.

## Configuración rápida
1) Copia `env.sample` a `.env.local` y rellena `NEXT_PUBLIC_SUPABASE_URL` y `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
2) Instala dependencias:
   ```bash
   pnpm install # o npm install / yarn
   pnpm dev
   ```
3) Aplica `supabase/schema.sql` en tu proyecto Supabase y configura RLS para restringir `company_id`.

## Reglas clave
- Tablas en PascalCase, columnas snake_case.
- Columnas metadata: `deleted`, `archived`, `created_date`, `modified_date`, `creator`, `modifier`.
- Multi-empresa: todas las tablas de negocio tienen `company_id` FK a `Companies`.
- Roles en `UserProfiles.role`: `ADMIN`, `MANAGER`, `INTERNAL_USER`, `DISTRIBUTOR_USER`, `VIEW_ONLY`.

## Seguridad
No subas llaves privadas al repo. Se añadieron entradas en `.gitignore` para evitarlo. Mueve cualquier clave de `Enter passphrase (empty for no passphrase):` fuera del proyecto.

