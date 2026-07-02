#!/usr/bin/env bash
set -euo pipefail

# This script is used to simulate sales data in the database.
# Help 
if [[ -n "${1:-}" && "${1:-}" == "--help" ]]; then
  echo "Usage: ./scripts/sales-simulator.sh [sales_per_minute] [batch_size] [worker_count]"
  echo "  sales_per_minute: The number of sales to simulate per minute. Default is 100000."
  echo "  batch_size: The number of orders to simulate per batch. Default is 500."
  echo "  worker_count: The number of workers to use to simulate the sales. Default is 10."
  exit 0
fi

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

DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_NAME="${DB_NAME:-}"
MARIADB_CONTAINER="${MARIADB_CONTAINER:-mariadb}"

SALES_PER_MINUTE="${SALES_PER_MINUTE:-100000}"
BATCH_SIZE="${BATCH_SIZE:-500}"
WORKER_COUNT="${WORKER_COUNT:-10}"
LOG_ALL="${LOG_ALL:-false}"

# if 3rd argument is provided, use it as the worker count
if [[ -n "${3:-}" ]]; then
  WORKER_COUNT="$3"
  echo "Worker count set to ${WORKER_COUNT}"
  sleep 1;
fi

# if a 2nd argument is provided, use it as the batch size
if [[ -n "${2:-}" ]]; then
  BATCH_SIZE="$2"
  echo "Batch size set to ${BATCH_SIZE}"
  sleep 1;
fi

# if an argument is provided, use it as the sales per minute
if [[ -n "${1:-}" ]]; then
  # Sales per minute cannot be smaller than batch size * worker count
  if (( "$1" < BATCH_SIZE * WORKER_COUNT )); then
    echo "Sales per minute cannot be smaller than batch size * worker count"
    echo "Setting sales per minute to $((BATCH_SIZE * WORKER_COUNT))"
    SALES_PER_MINUTE="$((BATCH_SIZE * WORKER_COUNT))"
    sleep 1;
  else
    SALES_PER_MINUTE="$1"
    echo "Sales per minute set to ${SALES_PER_MINUTE}"
    sleep 1;
  fi
fi

require_env() {
  local name="$1"
  if [[ -z "${!name}" ]]; then
    echo "Missing required env var: ${name}" >&2
    exit 1
  fi
}

require_env DB_PASSWORD
require_env DB_NAME

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to run simulator inside the MariaDB container." >&2
  exit 1
fi
if ! docker ps --format '{{.Names}}' | grep -qx "${MARIADB_CONTAINER}"; then
  echo "MariaDB container not running: ${MARIADB_CONTAINER}" >&2
  exit 1
fi

if (( SALES_PER_MINUTE <= 0 )) || (( BATCH_SIZE <= 0 )) || (( WORKER_COUNT <= 0 )); then
  echo "SALES_PER_MINUTE, BATCH_SIZE, and WORKER_COUNT must be > 0" >&2
  exit 1
fi

BATCH_INTERVAL_SEC="$(awk "BEGIN {printf \"%.4f\", (60 * ${BATCH_SIZE}) / ${SALES_PER_MINUTE}}")"

customer_count="$(docker exec -i -e MYSQL_PWD="$DB_PASSWORD" "${MARIADB_CONTAINER}" \
  mariadb -u root -D "$DB_NAME" -N -s -e "SELECT COUNT(*) FROM customers")"
product_count="$(docker exec -i -e MYSQL_PWD="$DB_PASSWORD" "${MARIADB_CONTAINER}" \
  mariadb -u root -D "$DB_NAME" -N -s -e "SELECT COUNT(*) FROM products")"

customer_min_max="$(docker exec -i -e MYSQL_PWD="$DB_PASSWORD" "${MARIADB_CONTAINER}" \
  mariadb -u root -D "$DB_NAME" -N -s -e "SELECT MIN(id), MAX(id) FROM customers")"
read -r CUSTOMER_MIN_ID CUSTOMER_MAX_ID <<<"${customer_min_max}"

product_min_max="$(docker exec -i -e MYSQL_PWD="$DB_PASSWORD" "${MARIADB_CONTAINER}" \
  mariadb -u root -D "$DB_NAME" -N -s -e "SELECT MIN(id), MAX(id) FROM products")"
read -r PRODUCT_MIN_ID PRODUCT_MAX_ID <<<"${product_min_max}"

if [[ -z "${CUSTOMER_MIN_ID:-}" || -z "${CUSTOMER_MAX_ID:-}" || -z "${PRODUCT_MIN_ID:-}" || -z "${PRODUCT_MAX_ID:-}" ]]; then
  echo "Failed to read min/max ids from customers/products" >&2
  exit 1
fi

if [[ "${customer_count:-0}" == "0" || "${product_count:-0}" == "0" ]]; then
  echo "No customers or products found. Run ./scripts/init.sh first." >&2
  exit 1
fi

echo "Sales Simulator Starting..."
echo "Target: ${SALES_PER_MINUTE} sales per minute"
echo "Batch size: ${BATCH_SIZE} orders per batch"
echo "Workers: ${WORKER_COUNT}"
echo "Batch interval: ${BATCH_INTERVAL_SEC}s"
echo "Database: ${MARIADB_CONTAINER}/${DB_NAME}"

RUNNING=1
start_time=$SECONDS

run_batch() {
  local worker_id="$1"

  # Build a batch SQL script that does NOT assume contiguous auto-inc ids.
  # We insert orders one-by-one, capturing LAST_INSERT_ID() into a TEMPORARY table.
  # This stays correct under concurrency without changing schemas.
  local sql
  sql=$(cat <<SQL
START TRANSACTION;

CREATE TEMPORARY TABLE IF NOT EXISTS tmp_new_orders (
  id BIGINT UNSIGNED NOT NULL PRIMARY KEY
) ENGINE=MEMORY;
TRUNCATE TABLE tmp_new_orders;

-- Seed vars
SET @cmin := ${CUSTOMER_MIN_ID};
SET @crange := (${CUSTOMER_MAX_ID} - ${CUSTOMER_MIN_ID}) + 1;
SET @pmin := ${PRODUCT_MIN_ID};
SET @prange := (${PRODUCT_MAX_ID} - ${PRODUCT_MIN_ID}) + 1;

SQL
)

  # Insert BATCH_SIZE orders and record their ids.
  for ((k=0; k<BATCH_SIZE; k++)); do
    sql+=$'INSERT INTO orders (customer_id, total_amount, status, created_at)\n'
    sql+=$'VALUES (@cmin + FLOOR(RAND() * @crange), 0, \'completed\', NOW());\n'
    sql+=$'INSERT IGNORE INTO tmp_new_orders (id) VALUES (LAST_INSERT_ID());\n'
  done

  # Insert items (1-3) per new order using tmp_new_orders as the driving set.
  # Pick a random product id per row and join to get base_price.
  sql+=$(cat <<'SQL'

SET @orders_inserted := (SELECT COUNT(*) FROM tmp_new_orders);

INSERT INTO order_items (order_id, product_id, quantity, price, created_at)
SELECT
  o.id AS order_id,
  p.id AS product_id,
  1 + FLOOR(RAND() * 3) AS quantity,
  p.base_price * (0.85 + RAND() * 0.3) AS price,
  NOW() AS created_at
FROM tmp_new_orders o
JOIN (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3) n
JOIN products p
  ON p.id = (@pmin + FLOOR(RAND() * @prange))
WHERE n.n <= 1 + FLOOR(RAND() * 3);

UPDATE orders
JOIN (
  SELECT order_id, SUM(quantity * price) AS total
  FROM order_items
  WHERE order_id IN (SELECT id FROM tmp_new_orders)
  GROUP BY order_id
) t ON orders.id = t.order_id
SET orders.total_amount = t.total
WHERE orders.id IN (SELECT id FROM tmp_new_orders);

SELECT
  @orders_inserted AS orders,
  (SELECT COUNT(*) FROM order_items WHERE order_id IN (SELECT id FROM tmp_new_orders)) AS items,
  (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE id IN (SELECT id FROM tmp_new_orders)) AS revenue;

COMMIT;
SQL
)

  docker exec -i -e MYSQL_PWD="$DB_PASSWORD" "${MARIADB_CONTAINER}" \
    mariadb -u root -D "$DB_NAME" -N -s -e "$sql"
}

worker() {
  local worker_id="$1"
  while (( RUNNING )); do
    local start=$SECONDS
    local output
    #echo "[Worker ${worker_id}] Starting batch..."
    if ! output="$(run_batch "${worker_id}")"; then
      echo "[Worker ${worker_id}] batch error" >&2
    else
      local orders items revenue duration
      read -r orders items revenue <<< "${output:-0 0 0}"
      duration=$((SECONDS - start))
      if [[ "${LOG_ALL}" == "true" || "${worker_id}" == "1" ]]; then
        printf '[Worker %s] Batch: %s orders, %s items, $%.2f revenue, %ss\n' \
          "${worker_id}" "${orders:-0}" "${items:-0}" "${revenue:-0}" "${duration}"
      fi
    fi

    if (( RUNNING )); then
      sleep "${BATCH_INTERVAL_SEC}"
    fi
  done
}

shutdown() {
  echo
  echo "Shutting down simulator..."
  RUNNING=0
}

trap shutdown SIGINT SIGTERM

pids=()
for ((i = 1; i <= WORKER_COUNT; i++)); do
  #echo "Starting worker ${i}..."
  worker "$i" &
  pids+=("$!")
done

while (( RUNNING )); do
  sleep 10
  elapsed=$((SECONDS - start_time))
  if (( RUNNING )); then
    echo "Runtime: ${elapsed}s @ ${SALES_PER_MINUTE} sales per minute"
  fi
done

for pid in "${pids[@]}"; do
  wait "$pid" || true
done

echo "Simulator stopped."
