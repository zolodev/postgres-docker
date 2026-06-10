#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
BACKUP_DIR="$PROJECT_DIR/backup"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP}.sql"

echo "==> Project dir: $PROJECT_DIR"
echo "==> Backup dir: $BACKUP_DIR"

mkdir -p "$BACKUP_DIR"

echo "==> Creating backup..."

docker exec postgres pg_dumpall -U "$POSTGRES_USER" > "$BACKUP_FILE"

echo "==> Backup saved: $BACKUP_FILE"

echo "==> Stopping stack..."
docker compose down

echo "==> Pulling latest images..."
docker compose pull

echo "==> Starting stack..."
docker compose up -d

echo "==> Waiting for PostgreSQL..."
until docker exec postgres pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; do
  sleep 2
done

echo "==> Restoring backup..."

cat "$BACKUP_FILE" | docker exec -i postgres psql -U "$POSTGRES_USER"

echo "==> Done."
