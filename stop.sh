#!/usr/bin/env bash
# Script to stop Docker Compose services
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"

# Change to project root
cd "$ROOT_DIR"

# Load environment variables from .env if it exists
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

# Flag -r: Remove Docker-managed named volumes and delete data folders
if [[ "${1:-}" == "-r" ]]; then
  echo "🛑 Stopping Docker Compose services and removing named volumes..."
  docker compose --profile "*" down -v
  
  # Delete MariaDB and Exasol data folders
  MARIADB_DATA_MOUNT="${MARIADB_DATA_MOUNT:-./mariadb/mariadb-data}"
  EXASOL_DATA_MOUNT="${EXASOL_DATA_MOUNT:-./exa-data}"
  
  if [[ -d "$MARIADB_DATA_MOUNT" ]]; then
    echo "🗑️  Deleting MariaDB data folder: $MARIADB_DATA_MOUNT"
    rm -rf "$MARIADB_DATA_MOUNT"
  fi
  
  if [[ -d "$EXASOL_DATA_MOUNT" ]]; then
    echo "🗑️  Deleting Exasol data folder: $EXASOL_DATA_MOUNT"
    rm -rf "$EXASOL_DATA_MOUNT"
  fi
else
  echo "🛑 Stopping Services..."
  docker compose --profile "*" down
fi

# stop sales-simulator if running
if ps aux | grep "scripts/sales-simulator.sh"; then
  echo "Stopping sales-simulator..."
  pkill -f "scripts/sales-simulator.sh"
fi

echo "✅ All services stopped!"
