#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${PWD}"

echo "==> Uninstalling PostgreSQL stack in: $INSTALL_DIR"

# Safety check
if [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
  echo "ERROR: docker-compose.yml not found in $INSTALL_DIR"
  echo "Aborting to avoid deleting wrong directory."
  exit 1
fi

echo "==> Stopping and removing Docker resources..."
docker compose down -v --rmi all --remove-orphans || true

echo "==> Removing project files..."
rm -f "$INSTALL_DIR/.env" \
      "$INSTALL_DIR/docker-compose.yml" \
      "$INSTALL_DIR/backup.sh" \
      "$INSTALL_DIR/update.sh"

echo "==> Removing data directory (if any)..."
rm -rf "$INSTALL_DIR/data"

echo "==> Done."
echo "PostgreSQL installation fully removed from: $INSTALL_DIR"
