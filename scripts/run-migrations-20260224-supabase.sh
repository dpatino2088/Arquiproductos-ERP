#!/usr/bin/env bash
# Ejecuta las migraciones del plan Estabilización Dealers, Acting-As y RLS (20260224_*)
# en Supabase, en el orden correcto: 1 → 2 → 3 → 6 → 4 → 5 → 8
#
# Uso:
#   SUPABASE_DB_URL="postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres" \
#   ./scripts/run-migrations-20260224-supabase.sh
#
# La URL la obtienes en: Supabase Dashboard → Project Settings → Database → Connection string (URI, mode Session)
#
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

MIGRATIONS=(
  "database/migrations/20260224_001_create_appusers_if_not_exists.sql"
  "database/migrations/20260224_002_integrity_constraints_org_dealer_users.sql"
  "database/migrations/20260224_003_sync_triggers_appusers.sql"
  "database/migrations/20260224_006_fix_orphan_data.sql"
  "database/migrations/20260224_004_acting_as_session_variable.sql"
  "database/migrations/20260224_005_rewrite_rls_quotes_proposals_directory.sql"
  "database/migrations/20260224_008_deprecate_legacy_functions.sql"
)

if [ "${1:-}" = "--cat" ]; then
  for f in "${MIGRATIONS[@]}"; do
    [ -f "$f" ] && echo "-- === $f ===" && cat "$f" && echo ""
  done
  exit 0
fi

if [ -z "$SUPABASE_DB_URL" ]; then
  echo "Uso: SUPABASE_DB_URL='postgresql://...' $0"
  echo ""
  echo "O ejecuta en Supabase Dashboard → SQL Editor, en este orden:"
  for f in "${MIGRATIONS[@]}"; do
    echo "  - $f"
  done
  echo ""
  echo "También puedes usar el archivo concatenado:"
  echo "  scripts/run-migrations-20260224-supabase.sh --cat > /tmp/all_20260224.sql"
  echo "  y pegar /tmp/all_20260224.sql en el SQL Editor."
  exit 1
fi

if ! command -v psql &>/dev/null; then
  echo "Se necesita 'psql' instalado. Instala el cliente PostgreSQL o usa Supabase SQL Editor."
  exit 1
fi

for f in "${MIGRATIONS[@]}"; do
  if [ ! -f "$f" ]; then
    echo "No encontrado: $f"
    exit 1
  fi
  echo "Ejecutando: $f"
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$f"
done

echo "Migraciones 20260224 completadas."
