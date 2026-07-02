import express from 'express';
import * as db from '../db.js';

const router = express.Router();


// Middleware to track API latency
router.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.url}: ${duration}ms`);
  });
  next();
});

// Average API response time
router.get('/api-latency', async (req, res) => {
  const start = Date.now();
  const useExa = req.query.exa === 'true';
  await db.query(`SELECT 1 as connected`, [], useExa);  
  const duration = Date.now() - start;
  res.json({ latencyMs: duration });
});

// Orders per minute
router.get('/orders-per-minute', async (req, res) => {
  const startTime = Date.now();
  const useExa = req.query.exa === 'true';
  try {
    const minutes = parseInt(req.query.minutes) || 5;
    const result = await db.query(`SELECT COUNT(*) as order_count FROM ${db.qualify('orders')} WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '?' MINUTE`, [minutes], useExa);

    const orderCount = result[0].order_count || 0;
    // Use the actual time window (minutes parameter) instead of time span between orders
    // This gives a more accurate "per minute" rate over the requested time period
    const ordersPerMinute = orderCount / minutes;
    const queryTime = Date.now() - startTime;

    res.json({
      ordersPerMinute: Math.round(ordersPerMinute * 100) / 100,
      totalOrders: orderCount,
      timeWindow: minutes,
      queryTime
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Items per minute
router.get('/items-per-minute', async (req, res) => {
  const startTime = Date.now();
  const useExa = req.query.exa === 'true';
  try {
    const minutes = parseInt(req.query.minutes) || 5;
    const result = await db.query(`SELECT SUM(oi.quantity) as total_items FROM ${db.qualify('orders')} o JOIN ${db.qualify('order_items')} oi ON o.id = oi.order_id WHERE o.created_at >= CURRENT_TIMESTAMP - INTERVAL '?' MINUTE`, [minutes], useExa);

    const totalItems = result[0].total_items || 0;
    // Use the actual time window (minutes parameter) instead of time span between orders
    // This gives a more accurate "per minute" rate over the requested time period
    const itemsPerMinute = totalItems / minutes;
    const queryTime = Date.now() - startTime;

    res.json({
      itemsPerMinute: Math.round(itemsPerMinute * 100) / 100,
      totalItems: totalItems,
      timeWindow: minutes,
      queryTime
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

