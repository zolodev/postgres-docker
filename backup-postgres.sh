#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
BACKUP_DIR="$PROJECT_DIR/backup"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
CONTAINER="postgres"

mkdir -p "$BACKUP_DIR"

# Load .env if exists
if [ -f "$PROJECT_DIR/.env" ]; then
  export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
fi

if [ "${1:-}" == "--backup" ]; then

  BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP}.sql"

  echo "==> Creating backup..."
  echo "==> Output: $BACKUP_FILE"

  docker exec "$CONTAINER" pg_dumpall -U "$POSTGRES_USER" > "$BACKUP_FILE"

  echo "==> Backup completed"
  exit 0
fi

if [ "${1:-}" == "--restore" ]; then

  if [ -z "${2:-}" ]; then
    echo "Usage: $0 --restore <file.sql>"
    exit 1
  fi

  RESTORE_FILE="$2"

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

  cat "$RESTORE_FILE" | docker exec -i "$CONTAINER" psql -U "$POSTGRES_USER"

  echo "==> Starting full stack..."
  docker compose up -d

  echo "==> Restore completed"
  exit 0
fi

echo "Usage:"
echo "  $0 --backup"
echo "  $0 --restore <file.sql>"
exit 1
