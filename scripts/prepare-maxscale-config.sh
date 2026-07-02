#!/usr/bin/env bash
set -euo pipefail

# TODO: refactor for maxscale-cdc
# Auto-configure MariaDB MaxScale with Exasol Router + Smart Router.
# Generates config for volume-mount and stages Exasol ODBC driver locally.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
if [[ -f "$ENV_FILE" ]]; then
  echo " - Loaded ${ENV_FILE}"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

MAXSCALE_CONF_PATH="${MAXSCALE_CONF_PATH:-${ROOT_DIR}/mounts/maxscale/maxscale.cnf}"
MAXSCALE_THREADS="${MAXSCALE_THREADS:-1}"
MAXSCALE_LOG_DEBUG="${MAXSCALE_LOG_DEBUG:-true}"
MAXSCALE_LOG_INFO="${MAXSCALE_LOG_INFO:-true}"

MARIADB_HOST="${DB_HOST}"
MARIADB_PORT="${DB_PORT}"

MAXSCALE_MONITOR_USER="${MAXSCALE_MONITOR_USER:-maxuser}"
MAXSCALE_MONITOR_PASSWORD="${MAXSCALE_MONITOR_PASSWORD:-aBcd123%}"

EXASOL_ODBC_URL="${EXASOL_ODBC_URL:-https://x-up.s3.amazonaws.com/7.x/25.2.4/Exasol_ODBC-25.2.4-Linux_x86_64.tar.gz}"
EXASOL_ODBC_LIB="${EXASOL_ODBC_LIB:-/opt/maxscale/exasol/lib/libexaodbc.so}"

EXASOL_HOST="${EXA_HOST}"
# if 127.0.0.1, then use the container name
if [[ "${EXASOL_HOST}" == "127.0.0.1" ]] || [[ "${EXASOL_HOST}" == "localhost" ]]; then
  EXASOL_HOST="${EXASOL_CONTAINER_NAME:-exasoldb}"
fi
EXASOL_PORT="${EXA_PORT}"
EXASOL_USER="${SERVICE_EXA_USER}"
EXASOL_PASSWORD="${SERVICE_EXA_PASSWORD}"
EXASOL_FINGERPRINT="${EXA_FINGERPRINT:-NOCERTCHECK}"

MAXSCALE_MARIADB_EXA_PORT="${MAXSCALE_MARIADB_EXA_PORT:-3308}"
MAXSCALE_EXASOL_ONLY_PORT="${MAXSCALE_EXASOL_ONLY_PORT:-3309}"

mkdir -p "$(dirname "${MAXSCALE_CONF_PATH}")"
cat > "${MAXSCALE_CONF_PATH}" <<EOF
[maxscale]
threads=${MAXSCALE_THREADS}
admin_host=0.0.0.0
admin_secure_gui=false
log_debug=${MAXSCALE_LOG_DEBUG}
log_info=${MAXSCALE_LOG_INFO}

[mariadb1]
type=server
address=${MARIADB_HOST}
port=${MARIADB_PORT}
protocol=MariaDBBackend

[mariadb_monitor]
type=monitor
module=mariadbmon
servers=mariadb1
user=${MAXSCALE_MONITOR_USER}
password=${MAXSCALE_MONITOR_PASSWORD}
monitor_interval=1s
auto_failover=false
auto_rejoin=false

[mariadb_exasolrouter]
type=service
router=exasolrouter
user=${MAXSCALE_MONITOR_USER}
password=${MAXSCALE_MONITOR_PASSWORD}
preprocessor=auto
connection_string=DRIVER=${EXASOL_ODBC_LIB};EXAHOST=${EXASOL_HOST}:${EXASOL_PORT};UID=${EXASOL_USER};PWD=${EXASOL_PASSWORD};FINGERPRINT=${EXASOL_FINGERPRINT}

[mariadb_smartrouter]
type=service
router=smartrouter
user=${MAXSCALE_MONITOR_USER}
password=${MAXSCALE_MONITOR_PASSWORD}
targets=mariadb1,mariadb_exasolrouter
master=mariadb1

[mariadb_rw_split]
type=service
router=readwritesplit
user=${MAXSCALE_MONITOR_USER}
password=${MAXSCALE_MONITOR_PASSWORD}
servers=mariadb1

[mariadb_exa_listener]
type=listener
service=mariadb_smartrouter
protocol=MariaDBClient
port=${MAXSCALE_MARIADB_EXA_PORT}

[mariadb_listener]
type=listener
service=mariadb_rw_split
protocol=MariaDBClient
port=${MAXSCALE_MARIADB_PORT}

[exasol_listener]
type=listener
service=mariadb_exasolrouter
protocol=MariaDBClient
port=${MAXSCALE_EXASOL_ONLY_PORT}

EOF

echo " + Wrote MaxScale config: ${MAXSCALE_CONF_PATH}"
echo " + Downloaded ${EXASOL_ODBC_HOST_DIR}"