#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
BACKUP_DIR="$PROJECT_DIR/backup"
CONTAINER="postgres"
LOCK_FILE="/tmp/update-postgres.lock"

mkdir -p "$BACKUP_DIR"

# -----------------------------
# LOCK (prevent parallel runs)
# -----------------------------
if [ -f "$LOCK_FILE" ]; then
  echo "ERROR: update already running (lock exists: $LOCK_FILE)"
  exit 1
fi

trap "rm -f $LOCK_FILE" EXIT
touch "$LOCK_FILE"

# -----------------------------
# ENV LOAD (safe + simple)
# -----------------------------
if [ ! -f .env ]; then
  echo "ERROR: .env not found in $PROJECT_DIR"
  exit 1
fi

set -a
source .env
set +a

if [ -z "${POSTGRES_USER:-}" ]; then
  echo "ERROR: POSTGRES_USER not set in .env"
  exit 1
fi

# -----------------------------
# WAIT FOR POSTGRES (pre-check)
# -----------------------------
echo "==> Waiting for PostgreSQL..."
until docker exec "$CONTAINER" pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; do
  sleep 2
done

# -----------------------------
# BACKUP
# -----------------------------
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP}.sql.gz"

echo "==> Creating backup: $BACKUP_FILE"

docker exec "$CONTAINER" pg_dumpall -U "$POSTGRES_USER" \
  | gzip > "$BACKUP_FILE"

echo "==> Backup created"

# -----------------------------
# RETENTION POLICY
# -----------------------------
MAX_BACKUPS=7

echo "==> Keeping last $MAX_BACKUPS backups"

ls -1t "$BACKUP_DIR"/backup_*.sql.gz 2>/dev/null \
  | tail -n +$((MAX_BACKUPS+1)) \
  | xargs -r rm -f

# -----------------------------
# UPDATE STACK
# -----------------------------
echo "==> Stopping stack"
docker compose down

echo "==> Pulling images"
docker compose pull

echo "==> Starting stack"
docker compose up -d

# -----------------------------
# WAIT FOR POSTGRES AFTER START
# -----------------------------
echo "==> Waiting for PostgreSQL after restart..."
until docker exec "$CONTAINER" pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; do
  sleep 2
done

# -----------------------------
# RESTORE
# -----------------------------
echo "==> Restoring backup"

gunzip -c "$BACKUP_FILE" \
  | docker exec -i "$CONTAINER" psql -U "$POSTGRES_USER"

# -----------------------------
# VERIFY RESTORE (basic check)
# -----------------------------
echo "==> Verifying database health"

docker exec "$CONTAINER" pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1 || {
  echo "ERROR: Postgres is not healthy after restore"
  exit 1
}

echo "==> Update completed successfully"
echo "==> Backup used: $BACKUP_FILE"
