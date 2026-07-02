import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import dotenv from 'dotenv';
import express from 'express';
import cors from 'cors';
import * as db from './db.js';
import statsRoutes from './routes/stats.js';
import realtimeRoutes from './routes/realtime.js';
import kpiRoutes from './routes/kpi.js';

// Load .env from repo root when running locally (Docker sets env via compose)
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: resolve(__dirname, '../../.env') });

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Health check (includes dbName so you can confirm qualified queries use it)
app.get('/health', async (req, res) => {
  const useExa = req.query.exa === 'true';
  try {
    await db.ping(useExa);
    res.json({
      status: 'ok',
      database: 'connected',
      exa: useExa,
      dbName: db.dbName,
      qualifySample: db.qualify ? db.qualify('orders') : undefined,
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      database: 'disconnected',
      error: error.message,
      dbName: db.dbName,
      qualifySample: db.qualify ? db.qualify('orders') : undefined,
    });
  }
});

// Routes
app.use('/api/stats', statsRoutes);
app.use('/api/realtime', realtimeRoutes);
app.use('/api/kpi', kpiRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal server error', message: err.message });
});

// Start server
app.listen(PORT, () => {
  console.log(`API server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing database connections...');
  await db.close();
  process.exit(0);
});

