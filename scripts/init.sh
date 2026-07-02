#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
else
  echo "Env file not found at ${ENV_FILE}" >&2
  exit 1
fi

SQL_FILE="${SQL_FILE:-${ROOT_DIR}/sql/init.sql}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_NAME="${DB_NAME:-}"

MAXSCALE_MONITOR_USER="${MAXSCALE_MONITOR_USER:-maxuser}"
MAXSCALE_MONITOR_PASSWORD="${MAXSCALE_MONITOR_PASSWORD:-aBcd123%}"

# capture control-c to exit 
trap 'echo " ✘ Exiting"; exit 1' INT

require_env() {
  local name="$1"
  if [[ -z "${!name}" ]]; then
    echo "Missing required env var: ${name}" >&2
    exit 1
  fi
}

prechecks() {
  require_env DB_HOST
  require_env DB_USER
  require_env DB_PASSWORD
  require_env DB_NAME

  if ! command -v docker >/dev/null 2>&1; then
    echo "docker is required to run init inside containers." >&2
    exit 1
  fi

  if [[ ! -f "$SQL_FILE" ]]; then
    echo "SQL file not found at ${SQL_FILE}" >&2
    exit 1
  fi
}

wait_for_mariadb_connection() {
  # check for mariadb container
  if ! docker ps --format '{{.Names}}' | grep -qx "${MARIADB_CONTAINER_NAME}"; then
    echo "MariaDB container not running: ${MARIADB_CONTAINER_NAME}" >&2
    exit 1
  fi

  # check for mariadb connection
  echo " - Waiting for database connection in container ${MARIADB_CONTAINER_NAME}"
  attempts=0
  max_attempts=30

  while (( attempts < max_attempts )); do
    if docker exec -i -e MYSQL_PWD="$DB_PASSWORD" "${MARIADB_CONTAINER_NAME}" \
      mariadb -u "$DB_USER" -D "$DB_NAME" -e "SELECT 1" >/dev/null 2>&1; then
      echo " ✔ MariaDB is ready!"
      break
    fi
    attempts=$((attempts + 1))
    echo " ---  Attempt ${attempts}/${max_attempts}: Waiting for MariaDB"
    sleep 2
  done

  if (( attempts >= max_attempts )); then
    echo " ✘ Failed to connect to MariaDB after maximum attempts" >&2
    exit 1
  fi
}

wait_for_exasol_connection() {
  # check for exasol container
  if ! docker ps --format '{{.Names}}' | grep -qx "${EXASOL_CONTAINER_NAME}"; then
    echo " ✘ Exasol container not running: ${EXASOL_CONTAINER_NAME}" >&2
    exit 1
  fi

  # check for exasol connection
  echo " - Waiting for exasol connection in container ${EXASOL_CONTAINER_NAME}"
  attempts=0
  max_attempts=50
  while (( attempts < max_attempts )); do
    if docker exec -i "${EXASOL_CONTAINER_NAME}" \
      bash -lc "exaplus -c 127.0.0.1/${EXA_FINGERPRINT}:${EXA_PORT} -u ${SERVICE_EXA_USER} -p ${SERVICE_EXA_PASSWORD} --sql \"SELECT 1\" >/dev/null 2>&1"; then
      echo " ✔ Exasol is ready!"
      break
    fi
    attempts=$((attempts + 1))
    echo " ---  Attempt ${attempts}/${max_attempts}: Waiting for Exasol"
    sleep 3
  done

  if (( attempts >= max_attempts )); then
    echo " ✘ Failed to connect to Exasol after maximum attempts" >&2
    exit 1
  fi
}

wait_for_maxscale_connection() {
  # check for maxscale container
  if ! docker ps --format '{{.Names}}' | grep -qx "${MAXSCALE_CONTAINER_NAME}"; then
    echo " ✘ Maxscale container not running: ${MAXSCALE_CONTAINER_NAME}" >&2
    exit 1
  fi
  # check for maxscale connection
  echo " - Waiting for maxscale connection "
  attempts=0
  max_attempts=10
  while (( attempts < max_attempts )); do
    if docker exec -i "${MARIADB_CONTAINER_NAME}" \
      mariadb --skip-ssl -h "${MAXSCALE_CONTAINER_NAME}" -P "${MAXSCALE_MARIADB_EXA_PORT}" -u "${DB_USER}" -p"${DB_PASSWORD}" -e "SELECT 1 as connected" >/dev/null 2>&1; then
      echo " ✔ Maxscale is ready!"
      break
    fi
    attempts=$((attempts + 1))
    echo " ---  Attempt ${attempts}/${max_attempts}: Waiting for Maxscale"
    sleep 3
  done

  if (( attempts >= max_attempts )); then
    echo " ✘ Failed to connect to Maxscale after maximum attempts" >&2
    echo "Example: docker exec -it $MARIADB_CONTAINER_NAME mariadb --skip-ssl -h \"${MAXSCALE_CONTAINER_NAME}\" -P \"${MAXSCALE_MARIADB_EXA_PORT}\" -u \"${DB_USER}\" -p\"${DB_PASSWORD}\" -e \"SELECT 1 as connected\""
    exit 1
  fi
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

count_query() {
  local table="$1"
  local sql="SELECT COUNT(*) FROM ${table}"
  # if DB_HOST=$MARIADB_CONTAINER_NAME, user is root, otherwise use DB_USER, DB_HOST, DB_PORT
  if [[ "$DB_HOST" == "$MARIADB_CONTAINER_NAME" ]]; then
    docker exec -i -e MYSQL_PWD="$DB_PASSWORD" "${MARIADB_CONTAINER_NAME}" \
      mariadb -u root -D "$DB_NAME" -N -s -e "$sql"
  else
    docker exec -i -e "${MARIADB_CONTAINER_NAME}" \
      mariadb -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -D "$DB_NAME" -N -s -e "$sql"
  fi
}

run_mariadb_sql() {
  # if DB_HOST=$MARIADB_CONTAINER_NAME, user is root, otherwise use DB_USER, DB_HOST, DB_PORT
  if [[ "$DB_HOST" == "$MARIADB_CONTAINER_NAME" ]]; then
    docker exec -i -e MYSQL_PWD="$DB_PASSWORD" "${MARIADB_CONTAINER_NAME}" \
      mariadb -u root -e "$1"
  else
    docker exec -i -e "${MARIADB_CONTAINER_NAME}" \
      mariadb -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -e "$1"
  fi
}

import_file_exasol() {
  docker cp "$1" "${EXASOL_CONTAINER_NAME}:/tmp/$(basename "$1")"
  docker exec -i "${EXASOL_CONTAINER_NAME}" \
    bash -lc "exaplus -c $EXA_HOST/${EXA_FINGERPRINT}:${EXA_PORT} -u ${SERVICE_EXA_USER} -p ${SERVICE_EXA_PASSWORD} -q -f \"/tmp/$(basename "$1")\""
}

run_exasol_sql() {
  docker exec -i "${EXASOL_CONTAINER_NAME}" \
    bash -lc "exaplus -c $EXA_HOST/${EXA_FINGERPRINT}:${EXA_PORT} -u ${SERVICE_EXA_USER} -p ${SERVICE_EXA_PASSWORD} -q --sql \"$1\""
}

run_exasol_pipe_sql() {
  echo -e "SET HEADING OFF; \n $1" | docker exec -i "${EXASOL_CONTAINER_NAME}" \
    bash -lc "exaplus -c $EXA_HOST/${EXA_FINGERPRINT}:${EXA_PORT} -u ${SERVICE_EXA_USER} -p ${SERVICE_EXA_PASSWORD} -q -pipe | xargs"
}

# MAIN SCRIPT
prechecks
determine_compose_command
wait_for_mariadb_connection
wait_for_exasol_connection

# MariaDB users setup
echo ""
echo "[+] MariaDB"
echo " - Creating users (if not exists) "
run_mariadb_sql "CREATE USER IF NOT EXISTS ${MAXSCALE_MONITOR_USER}@'%' IDENTIFIED BY '${MAXSCALE_MONITOR_PASSWORD}';"
run_mariadb_sql "GRANT SUPER, READ_ONLY ADMIN, RELOAD, REPLICATION CLIENT, SLAVE MONITOR, REPLICATION SLAVE, SHOW DATABASES ON *.* TO ${MAXSCALE_MONITOR_USER}@'%';"
run_mariadb_sql "GRANT SELECT ON mysql.db TO ${MAXSCALE_MONITOR_USER}@'%';"
run_mariadb_sql "GRANT SELECT ON mysql.user TO ${MAXSCALE_MONITOR_USER}@'%';"
run_mariadb_sql "GRANT SELECT ON mysql.roles_mapping TO ${MAXSCALE_MONITOR_USER}@'%';"
run_mariadb_sql "GRANT SELECT ON mysql.tables_priv TO ${MAXSCALE_MONITOR_USER}@'%';"
run_mariadb_sql "GRANT SELECT ON mysql.columns_priv TO ${MAXSCALE_MONITOR_USER}@'%';"
run_mariadb_sql "GRANT SELECT ON mysql.proxies_priv TO ${MAXSCALE_MONITOR_USER}@'%';"
run_mariadb_sql "GRANT SELECT ON mysql.procs_priv TO ${MAXSCALE_MONITOR_USER}@'%';"
run_mariadb_sql "GRANT SELECT ON mysql.global_priv TO ${MAXSCALE_MONITOR_USER}@'%';"
run_mariadb_sql "CREATE USER IF NOT EXISTS ${DB_USER}@'%' IDENTIFIED BY '${DB_PASSWORD}';"
run_mariadb_sql "GRANT ALL ON *.* TO ${DB_USER}@'%';"
run_mariadb_sql "CREATE USER IF NOT EXISTS ${CDC_EXA_USER}@'%' IDENTIFIED BY '${CDC_EXA_PASSWORD}';"
run_mariadb_sql "GRANT READ_ONLY ADMIN, REPLICATION CLIENT, REPLICATION SLAVE, LOCK TABLES, RELOAD, SELECT ON *.* TO ${CDC_EXA_USER}@'%';"

# if CDC_DATABASES is not equal to mariadb_exa_demo, then create each database in the list on Exasol
if [[ "${CDC_DATABASES}" != "mariadb_exa_demo" ]]; then
  for database in $(echo "${CDC_DATABASES}" | tr ',' ' '); do
    echo " - Creating database ${database} (if not exists)"
    run_mariadb_sql "CREATE DATABASE IF NOT EXISTS ${database};"
  done
fi

# Import demo data into MariaDB if CDC_DATABASES is equal to mariadb_exa_demo
if [[ "${CDC_DATABASES}" == "mariadb_exa_demo" ]]; then
  echo " - Running demo data import SQL: ${SQL_FILE}"
  had_errors=0
  set +e
  docker exec -i -e MYSQL_PWD="$DB_PASSWORD" "${MARIADB_CONTAINER_NAME}" \
    mariadb -u root -D "$DB_NAME" --force < "$SQL_FILE"
  exit_code=$?
  set -e
  if (( exit_code != 0 )); then
    had_errors=1
  fi
fi

# Exasol users setup
if docker ps --format '{{.Names}}' | grep -qx "${EXASOL_CONTAINER_NAME}" && [[ -n "${EXA_HOST}" && -n "${SERVICE_EXA_PASSWORD}" ]]; then
  echo ""
  echo "[+] Exasol"

  # if EXA_HOST is 127.0.0.1 or localhost, then use 127.0.0.1
  if [[ "${EXA_HOST}" == "127.0.0.1" ]] || [[ "${EXA_HOST}" == "localhost" ]] || [[ "${EXA_HOST}" == "exasoldb" ]]; then
    EXA_HOST="127.0.0.1"
  fi
  echo " - Configuring SQL_IDENTIFIER_COMPARISON to IGNORE CASE"
  if ! run_exasol_sql "alter system set SQL_IDENTIFIER_COMPARISON = 'IGNORE CASE';" > /dev/null 2>&1; then
    echo "Failed to set SQL_IDENTIFIER_COMPARISON = 'IGNORE CASE'" >&2
    exit 1
  fi
  echo " - Creating Exasol user (if not exists)"
  if ! run_exasol_sql "CREATE USER ${CDC_EXA_USER} IDENTIFIED BY \\\"${CDC_EXA_PASSWORD}\\\";" > /dev/null 2>&1; then
    echo "Failed to create Exasol user ${CDC_EXA_USER}" >&2
    exit 1
  fi
  if ! run_exasol_sql "GRANT CREATE SESSION, CREATE SCHEMA, CREATE ANY SCRIPT,EXECUTE ANY SCRIPT, CREATE ANY TABLE, ALTER ANY TABLE, SELECT ANY TABLE, INSERT ANY TABLE, UPDATE ANY TABLE, DELETE ANY TABLE, DROP ANY TABLE, DROP ANY SCHEMA, ALTER SYSTEM TO ${CDC_EXA_USER};" > /dev/null 2>&1; then
    echo "Failed to grant Exasol user ${CDC_EXA_USER}" >&2
    exit 1
  fi
  if ! run_exasol_sql "CREATE USER ${DB_USER} IDENTIFIED BY \\\"${DB_PASSWORD}\\\";" > /dev/null 2>&1; then
    echo "Failed to create Exasol user ${DB_USER}" >&2
    exit 1
  fi
  if ! run_exasol_sql "GRANT CREATE SESSION, CREATE SCHEMA, CREATE ANY SCRIPT,EXECUTE ANY SCRIPT, CREATE ANY TABLE, ALTER ANY TABLE, SELECT ANY TABLE, INSERT ANY TABLE, UPDATE ANY TABLE, DELETE ANY TABLE, DROP ANY TABLE, DROP ANY SCHEMA TO ${DB_USER};" > /dev/null 2>&1; then
    echo "Failed to grant Exasol user ${DB_USER}" >&2
    exit 1
  fi
  # not needed with maxscale-cdc ?
  # echo " - Creating database $DB_NAME (if not exists)"
  # if ! run_exasol_sql "CREATE SCHEMA IF NOT EXISTS \"${DB_NAME}\";" > /dev/null 2>&1; then
  #   echo "Failed to create Exasol schema ${DB_NAME}" >&2
  #   exit 1
  # fi
  # Create UTIL schema if not exists for preprocessor script
  echo " - Creating UTIL schema (if not exists)"
  if ! run_exasol_sql "CREATE SCHEMA IF NOT EXISTS UTIL;" > /dev/null 2>&1; then
    echo "Failed to create Exasol schema UTIL" >&2
    exit 1
  fi

  # if file not found, print warning but continue 
  if [[ ! -f "$ROOT_DIR/sql/mariadb-compat.sql" ]]; then
    echo "[!] $ROOT_DIR/sql/mariadb-compat.sql not found. Skipping UDF import." >&2
  else
    # Import UTIL.<UDFs> for preprocessor script and sqlglot transformations
    echo " - Importing UTIL UDFs: mariadb-compat.sql"
    if ! import_file_exasol "$ROOT_DIR/sql/mariadb-compat.sql" > /dev/null 2>&1; then
      echo "Failed to import mariadb-compat.sql into Exasol" >&2
      exit 1
    fi
  fi  

  # # TODO: check if maxscale-cdc needs this?
  # # if CDC_DATABASES is not equal to mariadb_exa_demo, then create each database in the list on Exasol
  # if [[ "${CDC_DATABASES}" != "mariadb_exa_demo" ]]; then
  #   for database in $(echo "${CDC_DATABASES}" | tr ',' ' '); do
  #     echo " - Creating schema ${database} (if not exists)"
  #     if ! run_exasol_sql "CREATE SCHEMA IF NOT EXISTS \"${database}\";" > /dev/null 2>&1; then
  #       echo "Failed to create Exasol schema ${database}" >&2
  #       exit 1
  #     fi
  #   done
  # fi

  # Set time to UTC
  echo " - Setting time zone to UTC"
  if ! run_exasol_sql "ALTER SYSTEM SET TIME_ZONE = 'UTC';" > /dev/null 2>&1; then
    echo "Failed to set Exasol time zone to UTC" >&2
    exit 1
  fi

else
  echo " ✘ Skipping Exasol user setup (exasol container not running or EXA_HOST/SERVICE_EXA_PASSWORD not set)." >&2
fi

# Starting Maxscale CDC
echo ""
echo "[+] Maxscale CDC"
$COMPOSE_CMD up maxscale -d
sleep 2
wait_for_maxscale_connection

# Only wait for Exasol tables if CDC_DATABASES is equal to mariadb_exa_demo
if [[ "${CDC_DATABASES}" == "mariadb_exa_demo" ]]; then
  echo " - Waiting for Exasol tables (CDC sync) for up to 60 seconds"

  CDC_TABLES=(regions customers products orders order_items)
  pending=( "${CDC_TABLES[@]}" )
  cdc_attempts=0
  cdc_max_attempts=1
  cdc_interval=3

  while (( cdc_attempts < cdc_max_attempts )) && (( ${#pending[@]} > 0 )); do
    new_pending=()
    for table in "${pending[@]}"; do
      cdc_output="$(run_exasol_pipe_sql "SELECT 1 FROM \"${DB_NAME}\".\"${table}\" LIMIT 1;" 2>&1)"
      cdc_exit=$?
      if [[ $cdc_exit -ne 0 ]] || echo "$cdc_output" | grep -qi error; then
        new_pending+=( "$table" )
        echo " ---  Attempt $((cdc_attempts + 1))/${cdc_max_attempts}: ${table} not ready yet"
      fi
    done
    pending=( "${new_pending[@]}" )
    if (( ${#pending[@]} == 0 )); then
      echo " ✔ All Exasol tables (${CDC_TABLES[*]}) ready."
      break
    fi
    cdc_attempts=$((cdc_attempts + 1))
    if (( cdc_attempts < cdc_max_attempts )); then
      sleep "$cdc_interval"
    fi
  done

  if (( ${#pending[@]} > 0 )); then
    echo "WARNING: Exasol tables still pending after ${cdc_max_attempts} attempts (~60s): ${pending[*]} - continuing" >&2
  fi
fi

# Only verify data insertions if CDC_DATABASES is equal to mariadb_exa_demo
if [[ "${CDC_DATABASES}" == "mariadb_exa_demo" ]]; then
  echo ""
  echo "[+] Verifying data insertions in MariaDB"
  regions_count="$(count_query regions)"
  customers_count="$(count_query customers)"
  products_count="$(count_query products)"
  orders_count="$(count_query orders)"
  order_items_count="$(count_query order_items)"
  echo " ✔ Regions: ${regions_count}"
  echo " ✔ Customers: ${customers_count}"
  echo " ✔ Products: ${products_count}"
  echo " ✔ Orders: ${orders_count}"
  echo " ✔ Order Items: ${order_items_count}"

  echo ""
  echo "[+] Verifying data insertions in Exasol"
  sql="SELECT COUNT(*) FROM \"${DB_NAME}\""
  regions_count="$(run_exasol_pipe_sql "${sql}.\"regions\";")"
  customers_count="$(run_exasol_pipe_sql "${sql}.\"customers\";")"
  products_count="$(run_exasol_pipe_sql "${sql}.\"products\";")"
  orders_count="$(run_exasol_pipe_sql "${sql}.\"orders\";")"
  order_items_count="$(run_exasol_pipe_sql "${sql}.\"order_items\";")"
  echo " ✔ Regions: ${regions_count}"
  echo " ✔ Customers: ${customers_count}"
  echo " ✔ Products: ${products_count}"
  echo " ✔ Orders: ${orders_count}"
  echo " ✔ Order Items: ${order_items_count}"

  if [[ "$regions_count" == "0" ]]; then
    echo "WARNING: No regions found after initialization!" >&2
  fi
  if [[ "$customers_count" == "0" ]]; then
    echo "WARNING: No customers found after initialization!" >&2
  fi
  if [[ "$products_count" == "0" ]]; then
    echo "WARNING: No products found after initialization!" >&2
  fi
  if [[ "$orders_count" == "0" ]]; then
    echo "WARNING: No orders found after initialization!" >&2
    echo "This might be expected if orders table already had data (idempotent check)" >&2
  fi
  if (( had_errors == 1 )); then
    echo "WARNING: SQL execution reported errors. Check output above." >&2
  fi
fi
echo ""
