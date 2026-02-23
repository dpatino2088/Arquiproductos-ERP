#!/usr/bin/env bash
# Descarga un DUMP completo de la base Supabase local (Docker).
# Requiere: Supabase local levantado (supabase start) o contenedor postgres corriendo.
#
# Uso (desde la raíz del proyecto):
#   ./scripts/download-dump-supabase-local.sh
#
# El dump se guarda en: backups/YYYY-MM-DD_HHMM_full.sql

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

OUTPUT_DIR="${OUTPUT_DIR:-backups}"
TIMESTAMP=$(date +%Y-%m-%d_%H%M)
DUMP_FILE="${OUTPUT_DIR}/${TIMESTAMP}_full.sql"
mkdir -p "$OUTPUT_DIR"

# URL de la DB local de Supabase (por defecto)
LOCAL_DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"

dump_via_pg_dump() {
  local url="$1"
  echo "Descargando dump con pg_dump..."
  pg_dump "$url" --no-owner --no-acl -F p -f "$DUMP_FILE"
}

dump_via_docker() {
  local container="$1"
  echo "Descargando dump desde contenedor Docker: $container"
  docker exec "$container" pg_dump -U postgres -d postgres --no-owner --no-acl -F p -f /tmp/dump.sql
  docker cp "$container:/tmp/dump.sql" "$DUMP_FILE"
  docker exec "$container" rm -f /tmp/dump.sql
}

# 1) Intentar con Supabase CLI (dump local): esquema + datos en un solo archivo
if command -v supabase &>/dev/null; then
  if supabase status &>/dev/null; then
    echo "Supabase local detectado. Generando dump (esquema + datos)..."
    TMP_SCHEMA="${OUTPUT_DIR}/.tmp_schema_${TIMESTAMP}.sql"
    TMP_DATA="${OUTPUT_DIR}/.tmp_data_${TIMESTAMP}.sql"
    supabase db dump --local -f "$TMP_SCHEMA" 2>/dev/null || true
    supabase db dump --local --data-only -f "$TMP_DATA" 2>/dev/null || true
    if [[ -f "$TMP_SCHEMA" && -s "$TMP_SCHEMA" ]]; then
      cat "$TMP_SCHEMA" > "$DUMP_FILE"
      [[ -f "$TMP_DATA" && -s "$TMP_DATA" ]] && cat "$TMP_DATA" >> "$DUMP_FILE"
      rm -f "$TMP_SCHEMA" "$TMP_DATA"
      echo "Dump guardado en: $DUMP_FILE"
      exit 0
    fi
    rm -f "$TMP_SCHEMA" "$TMP_DATA"
  fi
fi

# 2) Intentar pg_dump por red (DB local en 54322)
if command -v pg_dump &>/dev/null; then
  if pg_isready -h 127.0.0.1 -p 54322 -U postgres &>/dev/null; then
    dump_via_pg_dump "$LOCAL_DB_URL"
    echo "Dump guardado en: $DUMP_FILE"
    exit 0
  fi
fi

# 3) Buscar contenedor Postgres de Supabase y hacer dump desde dentro
CONTAINER=""
# Por volumen (tu volumen en Docker Desktop)
CONTAINER=$(docker ps -q --filter "volume=supabase_db_adaptio_erp" --format "{{.Names}}" 2>/dev/null | head -1)
if [[ -z "$CONTAINER" ]]; then
  # Por nombre típico
  for name in supabase_db_adaptio_erp supabase-db db adaptio_erp-db-1; do
    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
      CONTAINER="$name"
      break
    fi
  done
fi
if [[ -z "$CONTAINER" ]]; then
  # Cualquier contenedor que exponga 5432 y tenga postgres
  CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'db|postgres' | head -1)
fi

if [[ -n "$CONTAINER" ]]; then
  dump_via_docker "$CONTAINER"
  echo "Dump guardado en: $DUMP_FILE"
  exit 0
fi

echo "Error: No se pudo conectar a la base de datos."
echo "  - Asegúrate de tener Supabase local levantado: supabase start"
echo "  - O que el contenedor de Postgres esté corriendo (volumen supabase_db_adaptio_erp)."
echo "  - Si tienes pg_dump instalado, la DB debe estar en 127.0.0.1:54322"
exit 1
