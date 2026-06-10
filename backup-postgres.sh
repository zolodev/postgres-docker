#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
CONTAINER="postgres"

mkdir -p "$BACKUP_DIR"

# -----------------------------
# LOAD .env (safe)
# -----------------------------
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  source "$PROJECT_DIR/.env"
  set +a
fi

if [ -z "${POSTGRES_USER:-}" ]; then
  echo "ERROR: POSTGRES_USER is not set"
  exit 1
fi

# -----------------------------
# BACKUP
# -----------------------------
if [ "${1:-}" == "--backup" ]; then

  BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP}.sql.gz"

  echo "==> Creating backup..."
  echo "==> Output: $BACKUP_FILE"

  docker exec "$CONTAINER" pg_dumpall -U "$POSTGRES_USER" \
    | gzip > "$BACKUP_FILE"

  echo "==> Backup completed"
  exit 0
fi

# -----------------------------
# RESTORE
# -----------------------------
if [ "${1:-}" == "--restore" ]; then

  RESTORE_FILE="${2:-}"

  if [ -z "$RESTORE_FILE" ]; then
    echo "Usage: $0 --restore <file.sql|file.sql.gz>"
    exit 1
  fi

  if [ ! -f "$RESTORE_FILE" ]; then
    echo "Backup file not found: $RESTORE_FILE"
    exit 1
  fi

  echo "==> Stopping containers..."
  docker compose down

  echo "==> Starting PostgreSQL only..."
  docker compose up -d postgres

  echo "==> Waiting for DB..."
  until docker exec "$CONTAINER" pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; do
    sleep 2
  done

  echo "==> Restoring backup: $RESTORE_FILE"

  # -----------------------------
  # HANDLE .sql vs .gz
  # -----------------------------
  if [[ "$RESTORE_FILE" == *.gz ]]; then
    gunzip -c "$RESTORE_FILE" \
      | docker exec -i "$CONTAINER" psql -U "$POSTGRES_USER" -d postgres
  else
    cat "$RESTORE_FILE" \
      | docker exec -i "$CONTAINER" psql -U "$POSTGRES_USER" -d postgres
  fi

  echo "==> Starting full stack..."
  docker compose up -d

  echo "==> Restore completed"
  exit 0
fi

# -----------------------------
# HELP
# -----------------------------
echo "Usage:"
echo "  $0 --backup"
echo "  $0 --restore <file.sql|file.sql.gz>"
exit 1
