# MariaDB Exa Demo

Test MariaDB Exa with sample data & users preloaded. New tables in mariadb_exa_demo will automatically use the existing CDC to be copied into exasol

# Quick Start

Clone Repo & Start up community images
```bash
git clone git@github.com:mariadb-corporation/mariadb-exa-demo.git
cd mariadb-exa-demo
./start.sh -r
```
Note: `.env.example` is automatically copied as `.env` on first startup if no .env exists

To stop everything (and optionally remove volumes and data):

```bash
./stop.sh        # stop only
./stop.sh -a     # stop and remove volumes/data
```

### Configure Environment Variables 

The default `.env.example` is set up for the containerized stack (MariaDB, Exasol, MaxScale) based on community images

Here are some key variables you can adjust:
  - docker images to test other versions & to match your cpu architecture
    - IMAGE_EXASOL=
    - IMAGE_MARIADB=
    - IMAGE_MAXSCALE=
  - IP/URL where vue app & API served from
    - PUBLIC_HOST=YOUR_EC2_PUBLIC_IP or localhost
  - Mounted volumes where data resides on your computer
    - MARIADB_DATA_MOUNT=./mounts/mariadb/mariadb-data
    - EXASOL_DATA_MOUNT=./mounts/exa-data

### Docker Images (3 Options)

Community Trial:
```bash
docker pull mariadb:11.8
docker pull mariadb/maxscale-trial:25.10.3 
docker pull exasol/docker-db:latest
```

Enterprise users:
```bash
echo "<ENTERPRISE_TOKEN>" | docker login docker.mariadb.com -u <your-mariadb.id-email> --password-stdin
docker pull docker.mariadb.com/enterprise-server:latest
docker pull docker.mariadb.com/maxscale:latest
docker pull exasol/docker-db:latest
```

Custom Image builds:
```bash
docker load -i maxscale_25-10-x_custom_image.tar
```

## Architecture

Core
- **MariaDB**: Source database (port 3306)
- **Exasol**: Analytics database (port 8653)
- **MaxScale**: Proxy/router between MariaDB and Exasol and CDC ( port 3307 - 3309, 8989)

Optional
- **Express API Server**: RESTful API with Server-Sent Events for real-time updates (port 3000)
- **Vue.js App**: Modern dashboard with charts and KPIs (port 8988)
- **Sales Simulator**: Optional script to generate fake sales data

### Access the Application

- **APP Dashboard**: http://localhost:8988 (or `http://PUBLIC_HOST:8988` when set)
- **API Health Check**: http://localhost:3000/health (or `http://PUBLIC_HOST:API_PORT/health` when set)
- **API Base URL**: http://localhost:3000/api

When running on EC2, set `PUBLIC_HOST=YOUR_EC2_PUBLIC_IP` in `.env` before building so the Vue app and `start.sh` links use the correct host.
Note: Requires ENABLE_VUE_APP_AND_API=true in your .env

### Access the databases
MariaDB Exa
```bash
docker exec -it mariadb mariadb --skip-ssl -h maxscale -P 3310 -paBc123%% -u admin_user mariadb_exa_demo
```
MariaDB (direct)
```bash
docker exec -it mariadb mariadb -paBc123%% -u admin_user mariadb_exa_demo
```
Exasol
```bash
docker exec -it exasoldb exaplus -c 127.0.0.1/nocertcheck:8563 -u sys -p exasol -s mariadb_exa_demo
```

## Database Schema

The default data loaded at startup is:

- `regions` - Geographic regions (5 regions)
- `customers` - Customer information (5,000 customers seeded)
- `products` - Product catalog (15 products)
- `orders` - Order records (100,000 orders seeded)
- `order_items` - Individual items in orders (~250,000 items seeded)

The initialization script (`sql/init.sql`) automatically:
- Creates all tables with proper indexes
- Seeds 5,000 customers across 5 regions
- Seeds 15 products across multiple categories
- Generates 100,000 historical orders with ~250,000 order items
- Distributes orders across the last 90 days

See `sql/init.sql` for the complete schema definition.

### Run Sales Simulator 

```bash
./scripts/sales-simulator.sh
```

### Standalone containers example

```bash
docker network create demo
docker run --rm -d --name mariadb  --network demo -p 127.0.0.1:3306:3306 -e MARIADB_ROOT_PASSWORD=1 mariadb:11.8
docker run --rm -d --name exasoldb --network demo -p 127.0.0.1:8563:8563 --detach --privileged --stop-timeout 120 exasol/docker-db:latest
docker exec -it exasoldb /opt/exasol/db-2025.2.0-dev.0/bin/Console/exaplus -u sys -p exasol -c 127.0.0.1/nocertcheck:8563 -sql "select 1 as connected;"
docker run --rm -it --name maxscale-test --network demo --platform linux/amd64 -p 3310:3310 -p 8989:8989 -v "$(pwd)/maxscale.cnf:/etc/maxscale.cnf" -v "$(pwd)/Exasol_ODBC-25.2.4-Linux_x86_64:/Exasol_ODBC-25.2.4-Linux_x86_64"  mariadb/maxscale:25.10.1
```

# Standalone turn off all containers
```bash
docker rm -f $(docker ps -aq)
docker network rm demo
```

## Project Structure

```
.
├── docker-compose.yml          # Main orchestration (MariaDB, Exasol, MaxScale, Debezium, API, app)
├── .env.example                # Environment variables template
├── .gitignore
├── start.sh                    # Start all services and run init
├── stop.sh                     # Stop services (use -a to remove volumes and data)
├── server/                     # Express API
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       ├── index.js            # Main server file
│       ├── db.js               # Database connection
│       └── routes/
│           ├── stats.js        # Statistics endpoints
│           ├── realtime.js     # SSE realtime endpoint
│           └── kpi.js          # KPI endpoints
├── vuejs-app/                  # Vue.js frontend app
│   ├── Dockerfile
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js
│   ├── nginx.conf
│   └── src/
│       ├── main.js
│       ├── App.vue
│       └── components/
│           ├── Dashboard.vue
│           ├── KPICard.vue
│           ├── BarChart.vue
│           ├── LineChart.vue
│           └── RealtimeChart.vue
├── scripts/                    # Database and setup scripts
│   ├── init.sh                 # Initialize MariaDB schema and data
│   ├── prepare-maxscale-config.sh   # Generate MaxScale config from .env
│   └── sales-simulator.sh      # Generate fake sales data
├── sql/                        # Database initialization and seed SQL
│   ├── init.sql                # Schema and bootstrap
│   ├── backfill-historical.sql # Historical data backfill
│   ├── customers_data.sql
│   ├── order_items_data.sql
│   ├── orders_data.sql
│   ├── products_data.sql
│   └── regions_data.sql
└── mounts/                     # Runtime mounts (config and persistent data)
    ├── exa-data/               # Exasol data (created at runtime)
    ├── mariadb/                # MariaDB data (created at runtime)
    └── maxscale/               # MaxScale config and Exasol ODBC driver (maxscale.cnf, etc.)
```

## API Endpoints

### Statistics Endpoints

- `GET /api/stats/total-sales` - Total number of orders
- `GET /api/stats/items-sold` - Total items sold
- `GET /api/stats/by-region` - Sales breakdown by region
- `GET /api/stats/by-product` - Sales breakdown by product
- `GET /api/stats/daily?range=7` - Sales per day (last N days)
- `GET /api/stats/hourly?hours=24` - Sales per hour

### KPI Endpoints

- `GET /api/kpi/api-latency` - Average API response time
- `GET /api/kpi/orders-per-minute` - Orders per minute
- `GET /api/kpi/items-per-minute` - Items per minute

### Realtime Endpoint

- `GET /api/realtime` - Server-Sent Events stream for real-time metrics (updates every 2 seconds)

## Features

### Dashboard Components

1. **KPI Cards**: Total sales, items sold, orders/min, items/min, API latency
2. **Sales by Region**: Bar chart showing revenue by geographic region
3. **Top Products**: Bar chart of top-selling products
4. **Daily Sales**: Line charts for 7-day and 30-day trends
5. **Realtime Chart**: Live updating chart showing sales and revenue per hour

### Real-time Updates

The dashboard uses Server-Sent Events (SSE) to receive real-time updates every 2 seconds, showing:
- Current hour order count and revenue
- Hourly sales trends for the last 24 hours

### Sales Simulator

The sales simulator generates fake sales data at a configurable rate with high-performance optimizations:
- **Configurable rate**: Set via `SALES_PER_MINUTE` environment variable (default: 100,000)
- **Batch processing**: Inserts orders in configurable batch sizes (default: 500 per batch)
- **Concurrent workers**: Uses multiple workers for parallel processing (default: 10 workers)
- **Optimized operations**: 
  - Pre-loads customers and products into memory (no per-order queries)
  - Uses bulk INSERT statements for maximum throughput
  - Connection pooling for efficient database access
- **Performance tuning**:
  - `SALES_PER_MINUTE`: Target sales rate (default: 100000)
  - `BATCH_SIZE`: Orders per batch insert (default: 500)
  - `WORKER_COUNT`: Number of concurrent workers (default: 10)
  
**Note**: For 100k sales/minute, ensure your database can handle the load. Adjust `BATCH_SIZE` and `WORKER_COUNT` based on your database performance.

### Debugging
```bash
docker exec -it maxscale curl -v --connect-timeout 3 exasoldb:8563 ; 
# Looking for status:error Invalid HTTP 
# request = Good it connected at least
```

## Troubleshooting

1. **Vue app calls wrong API (e.g. on EC2)**: If Docker is not on your local machine, set `PUBLIC_HOST` in `.env` to your instance's public IP or hostname (and `API_PORT` if not 3000). Then rebuild: `docker compose build vuejs-app && docker compose --profile application up -d`.

2. **Database connection issues**: Verify `.env` has correct credentials. For external MariaDB, ensure the host is reachable (e.g. security group allows your IP).

3. **Init script fails**: Check that the database exists, the user has CREATE TABLE permissions, and the `mysql` CLI can connect.

4. **App not loading**: Ensure the API is running and reachable at `http://PUBLIC_HOST:API_PORT`.

5. **Realtime updates not working**: Check the browser console for SSE errors and that the API is reachable at the configured URL.

## License

MIT



