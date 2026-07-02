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

echo "Not Implemented"
# removed debezium 
# run_debezium_cmd() {
#   docker exec -i "${DEBEZIUM_CONTAINER_NAME}" bash -lc "$1"
# }

# if docker ps --format '{{.Names}}' | grep -qx "${DEBEZIUM_CONTAINER_NAME}"; then
#   # restart container if running
#   echo "Rebuilding Debezium container: ${DEBEZIUM_CONTAINER_NAME}."
#   $COMPOSE_CMD down "${DEBEZIUM_CONTAINER_NAME}"
#   $COMPOSE_CMD up -d "${DEBEZIUM_CONTAINER_NAME}"
#   run_debezium_cmd "rm -f /debezium/lib/antlr4-runtime-4.13.0.jar"
#   run_debezium_cmd "rm -f /debezium/lib/slf4j-jboss-logmanager-2.0.0.Final.jar"
#   sleep 2

#   echo "Restarting Debezium CDC connector in container: -Xmx${CDC_MEMORY} "
#   # Start CDC
#   run_debezium_cmd "java -Xmx${CDC_MEMORY} -cp \"lib/*\" com.exasol.debezium.engine.sink.Main config/mariadb-exa-cdc.properties >> /proc/1/fd/1 2>> /proc/1/fd/2 &"
#   sleep 5
# else
#   echo "Skipping Debezium setup (container not running: ${DEBEZIUM_CONTAINER_NAME})." >&2
# fi

echo "Logs: docker logs -f ${DEBEZIUM_CONTAINER_NAME}"