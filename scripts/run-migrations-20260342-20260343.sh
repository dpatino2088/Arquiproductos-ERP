#!/usr/bin/env bash
# Ejecuta migraciones 20260342 y 20260343 en Supabase
#
# Opción 1 - Supabase remoto (recomendado):
#   supabase login
#   supabase db push
#   (Las migraciones están en supabase/migrations/)
#
# Opción 2 - Supabase SQL Editor (Dashboard):
#   Copia el contenido de database/migrations/20260342_*.sql y 20260343_*.sql
#   y ejecútalo en orden en el SQL Editor del proyecto.
#
# Opción 3 - Via psql:
#   SUPABASE_DB_URL="postgresql://postgres.[ref]:[password]@...pooler.supabase.com:6543/postgres" \
#   bash -c 'psql "$SUPABASE_DB_URL" -f database/migrations/20260342_*.sql && psql "$SUPABASE_DB_URL" -f database/migrations/20260343_*.sql'
#
# Opción 4 - Supabase local (DB con schema completo):
#   docker exec -i supabase_db_adaptio_erp psql -U postgres -d postgres < database/migrations/20260342_*.sql
#   docker exec -i supabase_db_adaptio_erp psql -U postgres -d postgres < database/migrations/20260343_*.sql

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if [ -n "$SUPABASE_DB_URL" ] && command -v psql &>/dev/null; then
  echo "Ejecutando migración 20260342..."
  psql "$SUPABASE_DB_URL" -f database/migrations/20260342_is_org_user_member_strict_and_portal_in_org.sql
  echo "Ejecutando migración 20260343..."
  psql "$SUPABASE_DB_URL" -f database/migrations/20260343_dealer_users_role_dealer_member_dealer_manager.sql
  echo "Migraciones completadas."
else
  echo "Para ejecutar migraciones:"
  echo "  1. supabase login && supabase db push"
  echo "  2. O copia/pega en Supabase Dashboard > SQL Editor"
  echo "  3. O: SUPABASE_DB_URL=... psql ... -f database/migrations/20260342_*.sql"
fi
