import * as mariadb from 'mariadb';

// Default port (MaxScale)
const DEFAULT_PORT = parseInt(process.env.DB_PORT || '3307');
// ExaScale port
const EXA_PORT = parseInt(process.env.MAXSCALE_MARIADB_EXA_PORT || '3308');

// Create connection pools for both databases
const createPool = (port) => {
  return mariadb.createPool({
    host: process.env.DB_HOST,
    port: port,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    connectionLimit: 25,
    acquireTimeout: 3000,
    timeout: 30000,
    supportBigNumbers: true,
    bigNumberStrings: true, // Return big numbers as strings to avoid BigInt issues
  });
};

// Connection pools
const pools = {
  maxscale: createPool(DEFAULT_PORT),
  exa: createPool(EXA_PORT)
};

// Test connections with retry logic
async function testConnection(name, pool, maxWaitTime = 600000, retryInterval = 5000) {
  const startTime = Date.now();
  let attempt = 0;
  
  while (Date.now() - startTime < maxWaitTime) {
    attempt++;
    try {
      const conn = await pool.getConnection();
      console.log(`Database connected successfully (${name}) after ${attempt} attempt(s)`);
      conn.release();
      return true;
    } catch (err) {
      const elapsed = Math.floor((Date.now() - startTime) / 1000);
      console.log(`Database connection attempt ${attempt} failed (${name}) - elapsed: ${elapsed}s - retrying in ${retryInterval / 1000}s...`);
      
      // Wait before retrying, but check if we've exceeded max time
      if (Date.now() - startTime + retryInterval < maxWaitTime) {
        await new Promise(resolve => setTimeout(resolve, retryInterval));
      } else {
        // Not enough time left for another retry
        break;
      }
    }
  }
  
  // If we get here, we've exhausted all retries
  const totalElapsed = Math.floor((Date.now() - startTime) / 1000);
  console.error(`Database connection failed (${name}) after ${attempt} attempt(s) over ${totalElapsed} seconds`);
  return false;
}

// Test all connections in parallel
Promise.all(
  Object.entries(pools).map(([name, pool]) => 
    testConnection(name, pool, 600000, 5000) // 10 minutes max, retry every 5 seconds
  )
).then(results => {
  const allConnected = results.every(result => result === true);
  if (allConnected) {
    console.log('All database connections established successfully');
  } else {
    console.warn('Some database connections failed to establish');
  }
});

// Get the appropriate pool based on useExa flag
function getPool(useExa = false) {
  return useExa ? pools.exa : pools.maxscale;
}

// Database name from env (for qualifying table names in queries)
const dbName = process.env.DB_NAME || 'mariadb_exa_demo';
const dbNameFromEnv = Boolean(process.env.DB_NAME);

// Qualify a table name with the database: e.g. qualify('orders') => `dbname`.`orders`
function qualify(tableName) {
  if (!dbName) return tableName;
  return `${dbName}.${tableName}`;
}

// Log at load time so container/process logs show what we're using
console.log(`[db] DB_NAME for qualified queries: "${dbName}" (${dbNameFromEnv ? 'from env' : 'fallback'})`);

// Normalize driver values for JSON: BigInt, numeric strings, and Buffers (Exasol/MaxScale
// can expose some columns as binary; MariaDB path usually returns scalars already).
function convertBigInts(obj) {
  if (obj === null || obj === undefined) {
    return obj;
  }

  if (Buffer.isBuffer(obj)) {
    if (obj.length === 0) return null;
    const s = obj.toString('utf8');
    const trimmed = s.trim();
    if (/^-?\d+(\.\d+)?([eE][+-]?\d+)?$/.test(trimmed)) {
      const n = Number(trimmed);
      if (!Number.isNaN(n)) return n;
    }
    return s;
  }

  if (typeof obj === 'bigint') {
    return Number(obj);
  }
  
  if (typeof obj === 'string' && /^\d+$/.test(obj)) {
    // If it's a numeric string (from bigNumberStrings), convert to number
    const num = Number(obj);
    return isNaN(num) ? obj : num;
  }
  
  if (Array.isArray(obj)) {
    return obj.map(convertBigInts);
  }
  
  if (typeof obj === 'object') {
    const converted = {};
    for (const key in obj) {
      converted[key] = convertBigInts(obj[key]);
    }
    return converted;
  }
  
  return obj;
}

// Helper function to execute queries
async function query(sql, params = [], useExa = false) {
  let conn;
  const pool = getPool(useExa);
  try {
    conn = await pool.getConnection();
    const result = await conn.query(sql, params);
    // Convert BigInt values to Numbers for JSON serialization
    return convertBigInts(result);
  } catch (error) {
    console.error('Query error:', error);
    throw error;
  } finally {
    if (conn) conn.release();
  }
}

// Ping database
async function ping(useExa = false) {
  try {
    const pool = getPool(useExa);
    const conn = await pool.getConnection();
    await conn.ping();
    conn.release();
    return true;
  } catch (error) {
    throw error;
  }
}

// Close all connections
async function close() {
  await Promise.all([
    pools.maxscale.end(),
    pools.exa.end()
  ]);
}

export {
  query,
  ping,
  close,
  getPool,
  dbName,
  qualify
};
export const pool = pools.maxscale; // Default pool for backward compatibility

