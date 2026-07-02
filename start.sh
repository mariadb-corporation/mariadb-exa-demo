#!/usr/bin/env bash
# Wrapper script to start Docker/Podman Compose and run initialization
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
MARIADB_ONLY=0
REBUILD_CONTAINERS=0

# Change to project root
cd "$ROOT_DIR"

# if no .env file, copy from .env.example
if [[ ! -f .env ]]; then
  echo "No .env file found, copying from .env.example to .env..."
  cp .env.example .env
fi

# Load environment variables from .env if it exists
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

show_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  -h, --help              Show this help and exit
  -m, --mariadb-only      Only run initialization for MariaDB
  -r, --rebuild           Rebuild containers without cache (docker compose build --no-cache)
  -ci, --connection-info  Show connection information for the containers (MariaDB, Exasol, MaxScale)

Examples:
  $0
  $0 --mariadb-only
  $0 -r
EOF
}

connection_info() {
  determine_compose_command
  echo ""
  echo "To view logs: "
  echo "  $COMPOSE_CMD --profile \"*\" logs -f"
  echo ""
  echo "Explore:"
  if [[ "${ENABLE_VUE_APP_AND_API:-false}" == "true" ]]; then
    echo "  - Vue APP: http://${PUBLIC_HOST:-localhost}:8988"
    echo "  - API: http://${PUBLIC_HOST:-localhost}:${API_PORT:-3000}/health"
  fi
  echo "  - Sales Simulator: bash ./scripts/sales-simulator.sh 3000 50 10"
  echo ""
  echo "Access your databases:"
  echo "  - MariaDB Exa: docker exec -it $MARIADB_CONTAINER_NAME mariadb --skip-ssl -h $MAXSCALE_CONTAINER_NAME -P $MAXSCALE_MARIADB_EXA_PORT -p$DB_PASSWORD -u $DB_USER $DB_NAME"
  echo "  - MariaDB:     docker exec -it $MARIADB_CONTAINER_NAME mariadb -p$DB_PASSWORD -u $DB_USER $DB_NAME"
  echo "  - Exasol:      docker exec -it $EXASOL_CONTAINER_NAME exaplus -c 127.0.0.1/nocertcheck:8563 -u $SERVICE_EXA_USER -p $SERVICE_EXA_PASSWORD -s $DB_NAME"
  echo ""
}

determine_compose_command() {
  # Detect compose command (docker or podman)
  if [[ -n "${COMPOSE_CMD:-}" ]]; then
    # Allow users to override via environment variable
    :
  elif docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
  elif podman compose version >/dev/null 2>&1; then
    COMPOSE_CMD="podman compose"
  elif command -v podman-compose >/dev/null 2>&1; then
    COMPOSE_CMD="podman-compose"
  # if podman is installed but not podman-compose, install podman-compose
  elif podman --version >/dev/null 2>&1; then
    echo "Podman is installed but podman-compose is not. Trying to automatically install podman-compose..."
    OSTYPE=$(uname -s)
    PACKAGE_MANAGER=$(which yum || which apt-get || which brew)
    $PACKAGE_MANAGER install -y podman-compose >/dev/null 2>&1
  else
    echo "Error: could not find a compose command. Please install Docker (docker compose / docker-compose) or Podman (podman compose / podman-compose)." >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -m|--mariadb-only)
      MARIADB_ONLY=1
      shift
      ;;
    -r|--rebuild)
      REBUILD_CONTAINERS=1
      shift
      ;;
    -ci|--connection-info)
      connection_info
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      show_help
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

echo ""
echo "[+] Prechecks"

determine_compose_command
echo " - Found compose command: $COMPOSE_CMD"

if (( MARIADB_ONLY == 1 )); then
  echo ""
  echo "[+] Starting MariaDB container services"
  if (( REBUILD_CONTAINERS == 1 )); then
    $COMPOSE_CMD build mariadb --no-cache
  else
    $COMPOSE_CMD build mariadb
  fi
  $COMPOSE_CMD up -d mariadb
  echo "[+] MariaDB container services started!"
  echo "  - MariaDB:     docker exec -it $MARIADB_CONTAINER_NAME mariadb -p$DB_PASSWORD -u $DB_USER $DB_NAME"

  exit 0
fi

# Check if custom CDC_DATABASES is set and update Debezium database include list - has to be done before starting the containers
if [[ "${CDC_DATABASES}" != "mariadb_exa_demo" ]]; then
  echo " - Updating CDC list to: ${CDC_DATABASES}"
  echo "Not implemented"
  sleep 2
  #sed -i "s/^database.include.list=.*/database.include.list=${CDC_DATABASES}/g" mounts/debezium/mariadb-exa-cdc.properties
fi

# confirm mount dir is 777 or 775
if [[ ! -d "$MARIADB_DATA_MOUNT" ]]; then
  echo " - MariaDB data mount directory not found, creating... $MARIADB_DATA_MOUNT"
  mkdir -p "$MARIADB_DATA_MOUNT"
  chmod 777 "$MARIADB_DATA_MOUNT"
  chmod 0444 "$ROOT_DIR/mounts/mariadb/my.cnf"
fi
if [[ ! -d "$EXASOL_DATA_MOUNT" ]]; then
  echo " - Exasol data mount directory not found, creating... $EXASOL_DATA_MOUNT"
  mkdir -p "$EXASOL_DATA_MOUNT"
  chmod 777 "$EXASOL_DATA_MOUNT"
fi

# Pull the latest mariadb-compat files: https://raw.githubusercontent.com/mariadb-corporation/exasol-mariadb-compat/refs/heads/main/dist/mariadb-compat.sql
if (( REBUILD_CONTAINERS == 1 )); then
  echo " - Pulling latest mariadb-compat.sql and maria_preprocessor.sql from https://github.com/mariadb-corporation/exasol-mariadb-compat"
  curl -sSL https://raw.githubusercontent.com/mariadb-corporation/exasol-mariadb-compat/refs/heads/main/dist/mariadb-compat.sql -o "$ROOT_DIR/sql/mariadb-compat.sql" 
  curl -sSL https://raw.githubusercontent.com/mariadb-corporation/exasol-mariadb-compat/refs/heads/main/preprocessor/maria_preprocessor.sql -o "$ROOT_DIR/mounts/maxscale/sqlglot.custom.udf"
  # MaxScale runs this as pure Python, so strip the Exasol "CREATE ... SCRIPT ... AS" wrapper on the first line.
  # Only remove it if present, in case the upstream file drops the wrapper in the future.
  if head -n 1 "$ROOT_DIR/mounts/maxscale/sqlglot.custom.udf" | grep -qi '^CREATE OR REPLACE'; then
    sed -i '1d' "$ROOT_DIR/mounts/maxscale/sqlglot.custom.udf"
  fi
fi

PROFILES="--profile db"
if [[ "${ENABLE_VUE_APP_AND_API:-false}" == "true" ]]; then
  PROFILES="$PROFILES --profile application"
fi

# Only the application profile has services to build; skip the build step otherwise.
if [[ "${ENABLE_VUE_APP_AND_API:-false}" == "true" ]]; then
  echo -e "\n[+] Container Build:"
  # if -r flag, rebuild without cache
  if (( REBUILD_CONTAINERS == 1 )); then
    $COMPOSE_CMD $PROFILES build --no-cache
  else
    $COMPOSE_CMD $PROFILES build
  fi
fi

echo -e "\n[+] Starting DB container services"
$COMPOSE_CMD --profile db up -d

echo "[+] Running initialization script..."
"${ROOT_DIR}/scripts/init.sh"

if [[ "${ENABLE_VUE_APP_AND_API:-false}" == "true" ]]; then
  echo "[+] Starting demo application services..."
  $COMPOSE_CMD --profile application up -d
fi


echo "✅ Startup Complete!"
connection_info

