import express from 'express';
import * as db from '../db.js';

const router = express.Router();

// Server-Sent Events endpoint for realtime metrics
router.get('/', (req, res) => {
  const useExa = req.query.exa === 'true';
  
  // Set headers for SSE
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('Access-Control-Allow-Origin', '*');

  // Send initial connection message
  res.write(`data: ${JSON.stringify({ type: 'connected', message: 'Realtime stream started' })}\n\n`);

  // Interval to send updates every 2 seconds
  const interval = setInterval(async () => {
    try {

      // Get last 5 minutes of sales grouped by second
      const now = Date.now();
      //console.log(`[Realtime] Querying ${db.qualify('orders')} and ${db.qualify('order_items')}`);
      const secondlyStats = await db.query(`SELECT TO_CHAR(o.created_at, 'YYYY-MM-DD HH24:MI:SS') AS 'second', COUNT(DISTINCT o.id) AS order_count, SUM(oi.quantity * oi.price) AS revenue FROM ${db.qualify('orders')} o JOIN ${db.qualify('order_items')} oi ON o.id = oi.order_id WHERE o.created_at >= CURRENT_TIMESTAMP - INTERVAL '5' MINUTE GROUP BY TO_CHAR(o.created_at, 'YYYY-MM-DD HH24:MI:SS') ORDER BY 'second' ASC`, [], useExa);
      const end = Date.now();

      // Derive current second stats from the last row of secondlyStats
      let currentSecondRow = { order_count: 0, revenue: 0 };

      if (secondlyStats.length > 0) {
        const last = secondlyStats[secondlyStats.length - 1];
        currentSecondRow = {
          order_count: Number(last.order_count) || 0,
          revenue: Number(last.revenue) || 0
        };
      }
      
      const data = {
        type: 'update',
        timestamp: new Date().toISOString(),
        secondly: secondlyStats,
        currentSecond: currentSecondRow,
        queryTime: end - now
      };

      res.write(`data: ${JSON.stringify(data)}\n\n`);
    } catch (error) {
      console.error('Realtime query error:', error);
      res.write(`data: ${JSON.stringify({ type: 'error', message: error.message })}\n\n`);
    }
  }, 2000); // Update every 2 seconds

  // Clean up on client disconnect
  req.on('close', () => {
    clearInterval(interval);
    res.end();
  });
});

export default router;

