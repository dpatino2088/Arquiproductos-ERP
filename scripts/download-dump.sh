#!/usr/bin/env bash
# Descarga un dump de la base de datos (Supabase / PostgreSQL).
#
# Supabase LOCAL (Docker): usa ./scripts/download-dump-supabase-local.sh
#
# Uso remoto / genérico:
#   1. Configura DATABASE_URL en .env.local o exporta:
#      export DATABASE_URL="postgresql://postgres:[PASSWORD]@db.[PROJECT_REF].supabase.co:5432/postgres"
#   2. Ejecuta: ./scripts/download-dump.sh
#   O con Docker (postgres en contenedor):
#      ./scripts/download-dump.sh docker CONTAINER_NAME

set -e
OUTPUT_DIR="${OUTPUT_DIR:-backups}"
TIMESTAMP=$(date +%Y-%m-%d_%H%M)
DUMP_FILE="${OUTPUT_DIR}/dump_${TIMESTAMP}.sql"

mkdir -p "$OUTPUT_DIR"

if [[ "${1:-}" == "docker" ]]; then
  CONTAINER="${2:-postgres}"
  echo "Descargando dump desde contenedor Docker: $CONTAINER"
  docker exec "$CONTAINER" pg_dump -U postgres -d postgres --no-owner --no-acl -F p -f /tmp/dump.sql
  docker cp "$CONTAINER:/tmp/dump.sql" "$DUMP_FILE"
  docker exec "$CONTAINER" rm -f /tmp/dump.sql
  echo "Dump guardado en: $DUMP_FILE"
  exit 0
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  if [[ -f .env.local ]]; then
    set -a
    source .env.local
    set +a
  fi
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "Error: DATABASE_URL no está definida."
  echo "  Opción 1: export DATABASE_URL='postgresql://postgres:PASSWORD@db.XXX.supabase.co:5432/postgres'"
  echo "  Opción 2: Añade DATABASE_URL en .env.local"
  echo "  Opción 3: Dump desde Docker: $0 docker <nombre_contenedor>"
  exit 1
fi

echo "Descargando dump desde DATABASE_URL..."
pg_dump "$DATABASE_URL" --no-owner --no-acl -F p -f "$DUMP_FILE"
echo "Dump guardado en: $DUMP_FILE"
