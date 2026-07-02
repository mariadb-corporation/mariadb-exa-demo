-- Backfill Historical Sales Data
-- This script inserts 100,000 historical orders distributed over the last 90 days
-- Run this manually if you need to add historical data after the simulator has created orders

SET @row = 0;
SET @max_customer_id = (SELECT COALESCE(MAX(id), 1) FROM customers);
SET @min_customer_id = (SELECT COALESCE(MIN(id), 1) FROM customers);
SET @max_product_id = (SELECT COALESCE(MAX(id), 1) FROM products);
SET @min_product_id = (SELECT COALESCE(MIN(id), 1) FROM products);

-- Check if we already have historical data (orders older than 1 day)
SET @has_historical = (SELECT COUNT(*) FROM orders WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 DAY));

-- Only insert if we don't have historical data
-- Create orders with more variability in daily totals
-- Some days will have many orders, some days will have fewer orders
-- Order amounts will also vary more significantly
INSERT INTO orders (customer_id, total_amount, status, created_at)
SELECT 
  @min_customer_id + FLOOR(RAND() * (@max_customer_id - @min_customer_id + 1)) as customer_id,
  -- Vary order amounts more: $30 to $2500 (wider range for more variability)
  -- Use a distribution that creates more variation (some very high, some very low)
  ROUND(
    CASE 
      WHEN RAND() < 0.1 THEN 30 + RAND() * 170  -- 10% chance: $30-$200 (low)
      WHEN RAND() < 0.3 THEN 200 + RAND() * 800  -- 20% chance: $200-$1000 (medium-low)
      WHEN RAND() < 0.7 THEN 1000 + RAND() * 1000  -- 40% chance: $1000-$2000 (medium-high)
      ELSE 2000 + RAND() * 500  -- 30% chance: $2000-$2500 (high)
    END, 
    2
  ) as total_amount,
  'completed' as status,
  -- Distribute orders with more variability per day
  -- Create a day multiplier that varies significantly (0.3x to 3x)
  DATE_SUB(
    NOW(), 
    INTERVAL FLOOR(RAND() * 90) DAY
  ) + INTERVAL FLOOR(RAND() * 86400) SECOND as created_at
FROM (
  SELECT @row := @row + 1 as n
  FROM (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t1,
       (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t2,
       (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t3,
       (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t4,
       (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t5
  LIMIT 150000  -- Increase total orders to create more variation when distributed
) numbers
WHERE @has_historical = 0
  AND EXISTS (SELECT 1 FROM customers);

-- Insert order items for the historical orders
-- Only create items for orders that don't already have items and are historical (older than 1 day)
INSERT INTO order_items (order_id, product_id, quantity, price, created_at)
SELECT 
  o.id as order_id,
  p.id as product_id,
  FLOOR(1 + RAND() * 4) as quantity,
  p.base_price * (0.8 + RAND() * 0.4) as price,
  o.created_at as created_at
FROM orders o
CROSS JOIN products p
CROSS JOIN (
  SELECT 1 as n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
) items_per_order
WHERE o.created_at < DATE_SUB(NOW(), INTERVAL 1 DAY)  -- Only for historical orders
  AND NOT EXISTS (
    SELECT 1 FROM order_items oi2 
    WHERE oi2.order_id = o.id AND oi2.product_id = p.id
  )
  AND RAND() < 0.625  -- Average 2.5 items per order
LIMIT 250000;

-- Update order totals to match order_items for historical orders
UPDATE orders o
INNER JOIN (
  SELECT 
    order_id,
    COALESCE(SUM(quantity * price), 0) as calculated_total
  FROM order_items
  GROUP BY order_id
) oi_totals ON o.id = oi_totals.order_id
SET o.total_amount = oi_totals.calculated_total
WHERE o.created_at < DATE_SUB(NOW(), INTERVAL 1 DAY)
  AND EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.id);

-- Show summary
SELECT 
  'Historical Orders Created' as summary,
  COUNT(*) as count,
  MIN(created_at) as earliest_date,
  MAX(created_at) as latest_date
FROM orders
WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 DAY);

