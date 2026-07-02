import express from 'express';
import * as db from '../db.js';

const router = express.Router();

// Total number of sales (orders)
router.get('/total-sales', async (req, res) => {
  const startTime = Date.now();
  const useExa = req.query.exa === 'true';
  try {
    const result = await db.query(`SELECT COUNT(*) as total FROM ${db.qualify('orders')}`, [], useExa);
    const queryTime = Date.now() - startTime;
    res.json({ total: result[0].total, queryTime });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Total items sold
router.get('/items-sold', async (req, res) => {
  const startTime = Date.now();
  const useExa = req.query.exa === 'true';
  try {
    const result = await db.query(`SELECT SUM(quantity) as total FROM ${db.qualify('order_items')}`, [], useExa);
    const queryTime = Date.now() - startTime;
    res.json({ total: result[0].total || 0, queryTime });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Sales breakdown by region
router.get('/by-region', async (req, res) => {
  const startTime = Date.now();
  const useExa = req.query.exa === 'true';
  try {
    const result = await db.query(`SELECT r.name as region, COUNT(o.id) as order_count, SUM(oi.quantity * oi.price) as total_revenue, SUM(oi.quantity) as total_items FROM ${db.qualify('orders')} o JOIN ${db.qualify('customers')} c ON o.customer_id = c.id JOIN ${db.qualify('regions')} r ON c.region_id = r.id JOIN ${db.qualify('order_items')} oi ON o.id = oi.order_id GROUP BY r.id, r.name ORDER BY total_revenue DESC`, [], useExa);
    const queryTime = Date.now() - startTime;
    res.json({ data: result, queryTime });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Sales breakdown by product
router.get('/by-product', async (req, res) => {
  const startTime = Date.now();
  const useExa = req.query.exa === 'true';
  try {
    const result = await db.query(`SELECT p.id, p.name as product, p.category, COUNT(DISTINCT oi.order_id) as order_count, SUM(oi.quantity) as total_quantity, SUM(oi.quantity * oi.price) as total_revenue FROM ${db.qualify('order_items')} oi JOIN ${db.qualify('products')} p ON oi.product_id = p.id GROUP BY p.id, p.name, p.category ORDER BY total_revenue DESC LIMIT 50`, [], useExa);
    const queryTime = Date.now() - startTime;
    res.json({ data: result, queryTime });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Sales per day
router.get('/daily', async (req, res) => {
  const startTime = Date.now();
  const useExa = req.query.exa === 'true';
  try {
    const range = parseInt(req.query.range) || 7;
    
    // Get all dates in the range (excluding today)
    // Range of 7 means: yesterday, 2 days ago, ..., 7 days ago (7 days total, excluding today)
    const dateRange = [];
    for (let i = 1; i <= range; i++) { // Start from 1 to skip today (i=0)
      const date = new Date();
      date.setDate(date.getDate() - i);
      dateRange.push(date.toISOString().split('T')[0]); // YYYY-MM-DD format
    }
    // Reverse to get chronological order (oldest first)
    dateRange.reverse();
    
    // Get the exact start and end dates from the dateRange array
    const startDate = dateRange[0]; // Oldest date
    const endDate = dateRange[dateRange.length - 1]; // Newest date (yesterday, not today)
    
    //console.log(`[Daily Stats] Querying date range: ${startDate} to ${endDate} (${dateRange.length} days)`);

    // Debug
    // console.log(`[Daily Stats] Expected dates:`, dateRange);
    
    // // First, check what dates actually exist in the database for debugging
    // // Use direct string comparison since dates are in YYYY-MM-DD format
    // const dateCheck = await db.query(`
    //   SELECT 
    //     DATE_FORMAT(DATE(o.created_at), '%Y-%m-%d') as date,
    //     COUNT(*) as order_count, 
    //     SUM(total_amount) as revenue
    //   FROM orders o
    //   WHERE DATE(o.created_at) >= ?
    //     AND DATE(o.created_at) <= ?
    //   GROUP BY DATE(o.created_at)
    //   ORDER BY date ASC
    // `, [startDate, endDate]);
    // console.log(`[Daily Stats] Dates found in DB (${dateCheck.length} days):`, dateCheck.map(r => ({ date: r.date, orders: r.order_count, revenue: r.revenue })));
    
    // // Check which dates have order_items matching our criteria
    // const orderItemsCheck = await db.query(`
    //   SELECT 
    //     DATE_FORMAT(DATE(o.created_at), '%Y-%m-%d') as date,
    //     COUNT(DISTINCT o.id) as order_count,
    //     COUNT(oi.id) as order_item_count
    //   FROM orders o
    //   INNER JOIN order_items oi ON o.id = oi.order_id
    //   WHERE DATE(o.created_at) >= ?
    //     AND DATE(o.created_at) <= ?
    //     AND oi.quantity > 0
    //     AND oi.price > 0
    //   GROUP BY DATE(o.created_at)
    //   ORDER BY date ASC
    // `, [startDate, endDate]);
    // console.log(`[Daily Stats] Dates with valid order_items (${orderItemsCheck.length} days):`, orderItemsCheck.map(r => ({ date: r.date, orders: r.order_count, items: r.order_item_count })));
    
    // // Also check the overall date range in the database
    // const dateRangeCheck = await db.query(`
    //   SELECT 
    //     DATE_FORMAT(MIN(DATE(created_at)), '%Y-%m-%d') as min_date,
    //     DATE_FORMAT(MAX(DATE(created_at)), '%Y-%m-%d') as max_date,
    //     COUNT(DISTINCT DATE(created_at)) as distinct_days
    //   FROM orders
    // `);

    // if (dateRangeCheck.length > 0) {
    //   console.log(`[Daily Stats] Overall DB date range:`, dateRangeCheck[0]);
    // }
    
    // // Check what dates actually exist in the database (all dates, not just the range)
    // const allDatesCheck = await db.query(`
    //   SELECT 
    //     DATE_FORMAT(DATE(created_at), '%Y-%m-%d') as date,
    //     COUNT(*) as order_count
    //   FROM orders
    //   GROUP BY DATE(created_at)
    //   ORDER BY date DESC
    //   LIMIT 10
    // `);
    // console.log(`[Daily Stats] Last 10 dates in DB:`, allDatesCheck.map(r => ({ date: r.date, orders: r.order_count })));
    
    
    // Get sales data for the exact date range
    // Use LEFT JOIN to include dates even if they don't have order_items
    // Calculate revenue from orders.total_amount (using subquery to avoid duplicates from JOIN)
    // Calculate items_sold from order_items (will be 0 if no order_items exist)
    const result = await db.query(`SELECT DATE_FORMAT(DATE(o.created_at), '%Y-%m-%d') as date, COUNT(DISTINCT o.id) as order_count, COALESCE(SUM(oi.quantity), 0) as items_sold, COALESCE(SUM(o.total_amount), 0) as revenue FROM ${db.qualify('orders')} o LEFT JOIN ${db.qualify('order_items')} oi ON o.id = oi.order_id AND oi.quantity > 0 AND oi.price > 0 WHERE DATE(o.created_at) >= ? AND DATE(o.created_at) <= ? GROUP BY DATE(o.created_at) ORDER BY date ASC`, [startDate, endDate], useExa);
    
    // Debug: log the revenue values being returned
    console.log(`[Daily Stats] Query returned ${result.length} rows with order_items - Range: ${startDate} to ${endDate}`);
    // if (result.length > 0) {
    //   console.log(`[Daily Stats] Sample results:`, result);
    // } else {
    //   console.log(`[Daily Stats] WARNING: No results found for date range ${startDate} to ${endDate}`);
    // }
    
    // Create a map of date -> data for quick lookup
    const dataMap = {};
    result.forEach(row => {
      const dateStr = String(row.date || '');
      dataMap[dateStr] = {
        date: dateStr,
        order_count: Number(row.order_count) || 0,
        items_sold: Number(row.items_sold) || 0,
        revenue: Number(row.revenue) || 0
      };
    });
    
    // console.log(`[Daily Stats] Found ${result.length} days with data:`, Object.keys(dataMap));
    
    // Build result array with all dates in range, filling in zeros for missing days
    const processedResult = dateRange.map(dateStr => {
      if (dataMap[dateStr]) {
        return dataMap[dateStr];
      } else {
        // Return zero values for days with no sales
        return {
          date: dateStr,
          order_count: 0,
          items_sold: 0,
          revenue: 0
        };
      }
    });
    
    const queryTime = Date.now() - startTime;
    res.json({ data: processedResult, queryTime });
  } catch (error) {
    console.error('Error in /daily endpoint:', error);
    res.status(500).json({ error: error.message });
  }
});

// Sales per minute (for realtime chart)
router.get('/minutely', async (req, res) => {
  const startTime = Date.now();
  const useExa = req.query.exa === 'true';
  try {
    const minutes = parseInt(req.query.minutes) || 60;
    const result = await db.query(`SELECT DATE_FORMAT(o.created_at, '%Y-%m-%d %H:%i:00') as minute, COUNT(DISTINCT o.id) as order_count, SUM(oi.quantity * oi.price) as revenue FROM ${db.qualify('orders')} o JOIN ${db.qualify('order_items')} oi ON o.id = oi.order_id WHERE o.created_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE) GROUP BY DATE_FORMAT(o.created_at, '%Y-%m-%d %H:%i:00') ORDER BY minute ASC`, [minutes], useExa);
    const queryTime = Date.now() - startTime;
    res.json({ data: result, queryTime });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

