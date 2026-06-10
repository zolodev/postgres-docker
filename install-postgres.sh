#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$(pwd)"

# Defaults
POSTGRES_DB="appdb"
POSTGRES_USER="appuser"

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)
      POSTGRES_DB="$2"
      shift 2
      ;;
    --user)
      POSTGRES_USER="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [--db name] [--user name]"
      exit 1
      ;;
  esac
done

# Random password
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '\n' | tr '+/' 'Aa')

echo "Installing PostgreSQL in: $INSTALL_DIR"
echo "DB: $POSTGRES_DB"
echo "USER: $POSTGRES_USER"

echo "Writing .env..."
cat > "$INSTALL_DIR/.env" <<EOF
POSTGRES_DB=$POSTGRES_DB
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
EOF

echo "Writing docker-compose.yml..."
cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
services:
  postgres:
    image: postgres:17
    container_name: postgres
    restart: unless-stopped

    environment:
      POSTGRES_DB: \${POSTGRES_DB}
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}

    ports:
      - "5432:5432"

    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
EOF

echo "Starting stack..."
docker compose up -d

echo "Done."
echo "Credentials saved in: $INSTALL_DIR/.env"
