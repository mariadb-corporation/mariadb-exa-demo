-- MariaDB Database Schema and Seed Data
-- This script creates tables and inserts sample data if tables are empty

-- Create regions table
CREATE TABLE IF NOT EXISTS regions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  code VARCHAR(10) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create customers table
CREATE TABLE IF NOT EXISTS customers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  email VARCHAR(255) UNIQUE,
  region_id INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (region_id) REFERENCES regions(id) ON DELETE RESTRICT
);

-- Create products table
CREATE TABLE IF NOT EXISTS products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  category VARCHAR(100) NOT NULL,
  base_price DECIMAL(10, 2) NOT NULL,
  description varchar(500) default null,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  total_amount DECIMAL(10, 2) NOT NULL,
  status VARCHAR(50) DEFAULT 'completed',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE RESTRICT,
  INDEX idx_created_at (created_at),
  INDEX idx_customer_id (customer_id)
);

-- Create order_items table
CREATE TABLE IF NOT EXISTS order_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  price DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
  INDEX idx_order_id (order_id),
  INDEX idx_product_id (product_id),
  INDEX idx_created_at (created_at)
);

-- Insert regions if table is empty
INSERT INTO regions (name, code)
SELECT * FROM (
  SELECT 'North America' as name, 'NA' as code
  UNION ALL SELECT 'Europe', 'EU'
  UNION ALL SELECT 'Asia Pacific', 'APAC'
  UNION ALL SELECT 'Latin America', 'LATAM'
  UNION ALL SELECT 'Middle East & Africa', 'MEA'
) AS tmp
WHERE NOT EXISTS (SELECT 1 FROM regions);

-- Insert products if table is empty
INSERT INTO products (name, category, base_price, description)
SELECT * FROM (
  SELECT 'OrionTech NovaBook 14"'        AS name, 'Electronics'           AS category, 1199.99 AS base_price, '14-inch lightweight laptop with IPS display and all-day battery life.' AS description
  UNION ALL SELECT 'OrionTech NovaBook 16"',        'Electronics', 1299.99, '16-inch performance laptop designed for creators and power users.'
  UNION ALL SELECT 'Voltix AirBuds Pro',            'Electronics', 149.99,  'True wireless earbuds with active noise cancelling and wireless charging.'
  UNION ALL SELECT 'Voltix AirBuds Lite',           'Electronics', 79.99,   'Compact wireless earbuds with splash resistance and quick-pair Bluetooth.'
  UNION ALL SELECT 'Hyperion 27" 4K Monitor',       'Electronics', 379.99,  'Ultra HD monitor with thin bezels, HDR support, and adjustable stand.'
  UNION ALL SELECT 'Hyperion 34" Ultrawide',        'Electronics', 699.99,  'Curved ultrawide display ideal for multitasking, trading, and gaming.'
  UNION ALL SELECT 'PulseLabs Wireless Mouse',      'Electronics', 29.99,   'Ergonomic wireless mouse with silent clicks and adjustable DPI.'
  UNION ALL SELECT 'PulseLabs Mechanical Keyboard', 'Electronics', 119.99,  'Tenkeyless mechanical keyboard with hot-swappable switches and RGB lighting.'
  UNION ALL SELECT 'Skyline USB-C Dock Pro',        'Electronics', 89.99,   'USB-C dock with dual HDMI, Ethernet, USB 3.2, and 100W pass-through.'
  UNION ALL SELECT 'Skyline 65W GaN Charger',       'Electronics', 39.99,   'Compact GaN wall charger with dual USB-C ports for fast charging.'
  UNION ALL SELECT 'NeuraCore Streaming Webcam',    'Electronics', 89.50,   '1080p webcam with dual microphones and auto light correction.'
  UNION ALL SELECT 'NeuraCore 2TB NVMe SSD',        'Electronics', 179.99,  'High-speed NVMe SSD for faster game loads and data transfers.'
  UNION ALL SELECT 'HomeGen Drip Coffee Maker',     'Appliances', 59.99,    'Programmable 12-cup coffee maker with reusable filter basket.'
  UNION ALL SELECT 'HomeGen Electric Kettle',       'Appliances', 34.99,    'Stainless steel electric kettle with auto shut-off and boil-dry protection.'
  UNION ALL SELECT 'AquaPure Water Filter Pitcher', 'Appliances', 29.99,    '10-cup water filter pitcher that reduces chlorine and off flavors.'
  UNION ALL SELECT 'AquaPure Countertop Filter',    'Appliances', 129.99,   'Countertop filtration system for clean tasting drinking water.'
  UNION ALL SELECT 'KitchPro High-Speed Blender',   'Appliances', 129.00,   'Powerful blender for smoothies, soups, and frozen drinks.'
  UNION ALL SELECT 'KitchPro Food Processor',       'Appliances', 99.50,    'Multi-function food processor with slicing, shredding, and chopping blades.'
  UNION ALL SELECT 'ThermaLux Air Fryer 5qt',       'Appliances', 119.99,   '5-quart air fryer with digital controls and crisping basket.'
  UNION ALL SELECT 'ThermaLux Convection Oven',     'Appliances', 149.99,   'Countertop convection oven with rotisserie and pizza settings.'
  UNION ALL SELECT 'BreezeTech Tower Fan',          'Appliances', 79.99,    'Tower fan with remote control, sleep mode, and oscillation.'
  UNION ALL SELECT 'BrightHome LED Floor Lamp',     'Appliances', 49.99,    'Dimmable LED floor lamp with adjustable color temperature.'
  UNION ALL SELECT 'Oakline Ergolift Office Chair', 'Furniture',   259.99,  'Ergonomic office chair with lumbar support and breathable mesh back.'
  UNION ALL SELECT 'Oakline Solid Wood Desk',       'Furniture',   399.99,  '60-inch solid wood work desk with cable management grommets.'
  UNION ALL SELECT 'UrbanLoft Standing Desk 48"',   'Furniture',   499.99,  'Electric height-adjustable standing desk with memory presets.'
  UNION ALL SELECT 'UrbanLoft Standing Desk 60"',   'Furniture',   599.99,  '60-inch motorized standing desk with dual motors and cable tray.'
  UNION ALL SELECT 'NordicForm Bookshelf 5-Shelf',  'Furniture',   179.99,  'Minimalist 5-shelf bookcase in matte white finish.'
  UNION ALL SELECT 'NordicForm TV Console 72"',     'Furniture',   329.99,  'Low-profile TV stand for up to 75-inch TVs with hidden storage.'
  UNION ALL SELECT 'ComfortHaus Memory Foam Chair', 'Furniture',   189.99,  'Memory foam lounge chair ideal for reading corners and bedrooms.'
  UNION ALL SELECT 'ComfortHaus Sectional Sofa',    'Furniture',   899.99,  'L-shaped sectional sofa with reversible chaise and washable covers.'
  UNION ALL SELECT 'StudioFrame Monitor Riser',     'Furniture',   39.99,   'Bamboo monitor riser to elevate screens and free desk space.'
  UNION ALL SELECT 'StudioFrame Laptop Stand',      'Furniture',   34.99,   'Aluminum laptop stand with adjustable angle for better ergonomics.'
  UNION ALL SELECT 'StreetLine Tech Tee',           'Clothing',    24.99,   'Lightweight moisture-wicking t-shirt for everyday wear or training.'
  UNION ALL SELECT 'StreetLine Performance Hoodie', 'Clothing',    59.99,   'Fleece-lined hoodie with zip pockets and modern athletic fit.'
  UNION ALL SELECT 'Everwear Slim Fit Jeans',       'Clothing',    69.99,   'Slim fit stretch denim jeans with classic five-pocket styling.'
  UNION ALL SELECT 'Everwear Chino Pants',          'Clothing',    54.99,   'Casual stretch chinos suitable for office or weekend outings.'
  UNION ALL SELECT 'MetroFit Running Shorts',       'Clothing',    29.99,   'Running shorts with mesh liner and reflective side details.'
  UNION ALL SELECT 'MetroFit Training Joggers',     'Clothing',    49.99,   'Slim joggers with ankle zips and breathable side panels.'
  UNION ALL SELECT 'CloudCotton Crew Socks 6-Pack', 'Clothing',    18.99,   'Six-pack of cushioned crew socks made from soft cotton blend.'
  UNION ALL SELECT 'CloudCotton Relaxed Sweatpants','Clothing',    44.99,   'Relaxed fit sweatpants with adjustable waistband and side pockets.'
  UNION ALL SELECT 'TrailWorks Rain Jacket',        'Clothing',    89.99,   'Waterproof shell jacket with sealed seams and packable hood.'
  UNION ALL SELECT 'TrailWorks Insulated Vest',     'Clothing',    79.99,   'Core insulated vest ideal for layering in cool weather.'
  UNION ALL SELECT 'CoreLayer Everyday Backpack',   'Accessories', 69.99,   '25L everyday backpack with padded laptop sleeve and side bottle pocket.'
  UNION ALL SELECT 'CoreLayer Travel Duffel 40L',   'Accessories', 89.99,   'Versatile 40L duffel with hideaway backpack straps.'
  UNION ALL SELECT 'Packsmith Urban Messenger Bag', 'Accessories', 74.99,   'Messenger bag with padded tablet sleeve and quick-access pockets.'
  UNION ALL SELECT 'Packsmith Cable Organizer',     'Accessories', 24.99,   'Zippered pouch for organizing charging cables and small tech gear.'
  UNION ALL SELECT 'DayCarry Slim Wallet',          'Accessories', 29.99,   'Minimalist RFID-blocking wallet that holds up to 10 cards.'
  UNION ALL SELECT 'DayCarry Leather Belt',         'Accessories', 34.99,   'Full-grain leather belt with brushed metal buckle.'
  UNION ALL SELECT 'VistaLens Polarized Sunglasses','Accessories', 59.99,   'Polarized sunglasses with scratch-resistant lenses for daily use.'
  UNION ALL SELECT 'VistaLens Blue Light Glasses',  'Accessories', 39.99,   'Blue light filtering glasses to reduce eye strain from screens.'
  UNION ALL SELECT 'PulseBand Activity Tracker',    'Accessories', 49.99,   'Slim fitness tracker with step counting and sleep monitoring.'
  UNION ALL SELECT 'PulseBand Smartwatch S',        'Accessories', 129.99,  'Compact smartwatch with heart rate, GPS, and notification alerts.'
  UNION ALL SELECT 'Shadowbyte Gaming Mouse',       'Gaming',      49.99,   'Ergonomic gaming mouse with adjustable weights and RGB lighting.'
  UNION ALL SELECT 'Shadowbyte RGB Keyboard',       'Gaming',      109.99,  'Mechanical gaming keyboard with macro keys and per-key lighting.'
  UNION ALL SELECT 'FluxCore Gaming Headset',       'Gaming',      79.99,   'Over-ear gaming headset with virtual surround sound and noise mic.'
  UNION ALL SELECT 'FluxCore Streaming Mic',        'Gaming',      99.99,   'USB condenser microphone optimized for streaming and podcasts.'
  UNION ALL SELECT 'NexusPlay Game Controller',     'Gaming',      59.99,   'Wireless controller compatible with PC, console, and mobile devices.'
  UNION ALL SELECT 'NexusPlay Racing Wheel',        'Gaming',      199.99,  'Racing wheel and pedal set for realistic driving simulations.'
  UNION ALL SELECT 'RiftForge Gaming Chair',        'Gaming',      289.99,  'Reclining gaming chair with lumbar pillow and adjustable armrests.'
  UNION ALL SELECT 'RiftForge Desk Mat XL',         'Gaming',      29.99,   'Extended desk mat for keyboard and mouse with stitched edges.'
  UNION ALL SELECT 'PixelDrive Capture Card',       'Gaming',      129.99,  'HDMI capture card for streaming consoles and cameras to PC.'
  UNION ALL SELECT 'PixelDrive External SSD 1TB',   'Gaming',      159.99,  'Portable SSD ideal for carrying large game libraries.'
  UNION ALL SELECT 'CalmGlow Scented Candle Set',   'Home & Living', 24.99, 'Set of three soy candles with calming lavender and vanilla scents.'
  UNION ALL SELECT 'CalmGlow Essential Oil Diffuser','Home & Living',39.99,'Ultrasonic aroma diffuser with timer and color-changing lights.'
  UNION ALL SELECT 'PureNest Weighted Blanket 15lb','Home & Living', 89.99, '15-pound weighted blanket designed to promote deeper sleep.'
  UNION ALL SELECT 'PureNest Throw Pillow 2-Pack',  'Home & Living', 34.99, 'Two decorative throw pillows with removable washable covers.'
  UNION ALL SELECT 'CleanSlate Microfiber Cloths',   'Home & Living', 12.99, 'Pack of microfiber cloths for dusting, glass, and screens.'
  UNION ALL SELECT 'CleanSlate All-Purpose Cleaner','Home & Living', 7.99,  'Multi-surface spray cleaner with citrus scent.'
  UNION ALL SELECT 'BrightPath LED Strip Lights',   'Home & Living', 29.99, 'Flexible LED strip lighting with remote and adhesive backing.'
  UNION ALL SELECT 'BrightPath Smart Bulb 4-Pack',  'Home & Living', 49.99, 'Wi-Fi smart bulbs with tunable white and color modes.'
  UNION ALL SELECT 'FreshStart Laundry Detergent',  'Home & Living', 11.49, 'Concentrated liquid detergent for up to 64 loads.'
  UNION ALL SELECT 'FreshStart Fabric Softener',    'Home & Living', 8.49,  'Liquid softener that reduces static and adds light fragrance.'
  UNION ALL SELECT 'PeakTrail Hiking Backpack 40L', 'Sports & Outdoors', 129.99, 'Trail-ready hiking pack with hydration sleeve and rain cover.'
  UNION ALL SELECT 'PeakTrail Trekking Poles',      'Sports & Outdoors', 59.99,  'Adjustable aluminum trekking poles with cork grips.'
  UNION ALL SELECT 'AeroRun Road Running Shoes',    'Sports & Outdoors', 99.99,  'Lightweight running shoes designed for daily training runs.'
  UNION ALL SELECT 'AeroRun Trail Running Shoes',   'Sports & Outdoors', 109.99, 'Trail shoes with aggressive lugs and rock plate protection.'
  UNION ALL SELECT 'LiftLab Adjustable Dumbbells',  'Sports & Outdoors', 249.99,'Pair of adjustable dumbbells replacing up to 10 weight sets.'
  UNION ALL SELECT 'LiftLab Yoga Mat Pro',          'Sports & Outdoors', 49.99, 'Non-slip yoga mat with extra cushioning and carrying strap.'
  UNION ALL SELECT 'AquaLine Stainless Water Bottle','Sports & Outdoors', 19.99,'Insulated bottle that keeps drinks cold for up to 24 hours.'
  UNION ALL SELECT 'AquaLine Hydration Pack',       'Sports & Outdoors', 69.99, 'Running hydration vest with dual front flasks.'
  UNION ALL SELECT 'SunGuard SPF 50 Sunscreen',     'Sports & Outdoors', 14.99, 'Broad spectrum SPF 50 sunscreen suitable for outdoor workouts.'
  UNION ALL SELECT 'SunGuard Performance Hat',      'Sports & Outdoors', 24.99, 'Lightweight cap with UPF 50+ sun protection.'
  UNION ALL SELECT 'GlowRise Vitamin C Serum',      'Beauty & Personal Care', 24.99, 'Brightening serum with vitamin C and hyaluronic acid.'
  UNION ALL SELECT 'GlowRise Night Repair Cream',   'Beauty & Personal Care', 29.99, 'Overnight face cream that supports skin barrier recovery.'
  UNION ALL SELECT 'SilkWave Shampoo 500ml',        'Beauty & Personal Care', 11.99, 'Sulfate-free shampoo for daily cleansing and shine.'
  UNION ALL SELECT 'SilkWave Conditioner 500ml',    'Beauty & Personal Care', 11.99, 'Moisturizing conditioner for soft, manageable hair.'
  UNION ALL SELECT 'CalmSkin Foaming Cleanser',     'Beauty & Personal Care', 9.99,  'Gentle face cleanser suitable for sensitive skin.'
  UNION ALL SELECT 'CalmSkin Daily Moisturizer',    'Beauty & Personal Care', 14.99, 'Lightweight moisturizer with SPF 30 for daily use.'
  UNION ALL SELECT 'PureBrush Electric Toothbrush', 'Beauty & Personal Care', 59.99, 'Rechargeable toothbrush with multiple cleaning modes.'
  UNION ALL SELECT 'PureBrush Replacement Heads 4p','Beauty & Personal Care', 19.99, 'Four replacement heads compatible with PureBrush handles.'
  UNION ALL SELECT 'Scentory Unisex Eau de Parfum', 'Beauty & Personal Care', 49.99, 'Balanced fragrance with citrus, cedarwood, and amber notes.'
  UNION ALL SELECT 'Scentory Travel Spray Set',     'Beauty & Personal Care', 29.99, 'Set of three travel-sized fragrance sprays.'
  UNION ALL SELECT 'PlayNest Wooden Train Set',     'Toys & Games', 39.99,   '32-piece wooden train set compatible with popular track systems.'
  UNION ALL SELECT 'PlayNest Building Bricks 500p', 'Toys & Games', 29.99,   'Box of 500 interlocking building bricks in assorted colors.'
  UNION ALL SELECT 'BrightMind Puzzle 1000-Piece',  'Toys & Games', 19.99,   'Challenging 1000-piece jigsaw puzzle with scenic artwork.'
  UNION ALL SELECT 'BrightMind Logic Game Pack',    'Toys & Games', 24.99,   'Collection of portable logic and brain teaser games.'
  UNION ALL SELECT 'SoftPals Plush Bear',           'Toys & Games', 14.99,   'Soft plush bear suitable for toddlers and young children.'
  UNION ALL SELECT 'SoftPals Storytime Set',        'Toys & Games', 24.99,   'Plush toy and picture book bundle for bedtime reading.'
  UNION ALL SELECT 'SkyRacer Foam Glider 2-Pack',   'Toys & Games', 12.99,   'Two lightweight foam gliders for outdoor play.'
  UNION ALL SELECT 'SkyRacer Mini Drone',           'Toys & Games', 59.99,   'Compact drone with beginner-friendly controls and prop guards.'
  UNION ALL SELECT 'FamilyFun Board Game Classic',  'Toys & Games', 19.99,   'Family board game suitable for 2–6 players ages 8 and up.'
  UNION ALL SELECT 'FamilyFun Strategy Game',       'Toys & Games', 29.99,   'Light strategy board game with modular board and variable setup.'
  UNION ALL SELECT 'PetNest Orthopedic Dog Bed L',  'Pet Supplies', 89.99,   'Large orthopedic foam bed for medium to large dogs.'
  UNION ALL SELECT 'PetNest Elevated Feeder',       'Pet Supplies', 39.99,   'Adjustable raised feeder to support better posture while eating.'
  UNION ALL SELECT 'TailTrail Dog Leash 6ft',       'Pet Supplies', 19.99,   'Durable 6-foot leash with padded handle and reflective trim.'
  UNION ALL SELECT 'TailTrail Harness Medium',      'Pet Supplies', 34.99,   'No-pull harness with front and back clip points.'
  UNION ALL SELECT 'WhiskerBowl Cat Food 5lb',      'Pet Supplies', 16.99,   'Dry cat food formulated for adult indoor cats.'
  UNION ALL SELECT 'WhiskerBowl Cat Treats',        'Pet Supplies', 6.99,    'Crunchy cat treats with salmon flavor and added vitamins.'
  UNION ALL SELECT 'AquaPaws Pet Fountain',         'Pet Supplies', 39.99,   'Filtered water fountain to encourage pets to drink more.'
  UNION ALL SELECT 'AquaPaws Litter Mat',           'Pet Supplies', 19.99,   'Textured mat that helps trap litter from cat paws.'
  UNION ALL SELECT 'PlayChase Cat Teaser Wand',     'Pet Supplies', 9.99,    'Interactive teaser toy to keep indoor cats active.'
  UNION ALL SELECT 'PlayChase Dog Toy Set 3-Pack',  'Pet Supplies', 14.99,   'Set of three chew and fetch toys for dogs.'
  UNION ALL SELECT 'AutoGuard Dash Cam 1080p',      'Automotive', 89.99,     'Front-facing dash camera with loop recording and G-sensor.'
  UNION ALL SELECT 'AutoGuard Trunk Organizer',     'Automotive', 29.99,     'Collapsible trunk organizer with multiple compartments.'
  UNION ALL SELECT 'RoadReady Emergency Kit',       'Automotive', 59.99,     'Car emergency kit with jumper cables, flashlight, and tools.'
  UNION ALL SELECT 'RoadReady Tire Inflator',       'Automotive', 39.99,     'Portable 12V air compressor for topping up tires.'
  UNION ALL SELECT 'CleanRide Interior Wipes',      'Automotive', 7.99,      'Interior cleaning wipes safe for dashboards and consoles.'
  UNION ALL SELECT 'CleanRide Glass Cleaner',       'Automotive', 6.99,      'Streak-free glass cleaner for windshields and windows.'
  UNION ALL SELECT 'BrightBeam LED Headlight Bulbs','Automotive', 69.99,     'Pair of LED headlight bulbs with cool white output.'
  UNION ALL SELECT 'BrightBeam Utility Flashlight', 'Automotive', 14.99,     'High-lumen flashlight ideal for glove compartment storage.'
  UNION ALL SELECT 'SeatSafe Child Seat Protector', 'Automotive', 29.99,     'Seat protector pad placed under child car seats.'
  UNION ALL SELECT 'CargoGrip Non-Slip Liner',      'Automotive', 19.99,     'Trim-to-fit cargo liner that keeps items from sliding.'
) AS tmp
WHERE NOT EXISTS (SELECT 1 FROM products);

-- Insert sample customers if table is empty
-- Generate 5000 customers for better distribution
SET @row = 0;

INSERT INTO customers (name, email, region_id)
SELECT 
  CONCAT(
    ELT(1 + FLOOR(RAND() * 19), 'John', 'Maria', 'Li', 'Carlos', 'Ahmed', 'Emma', 'Pierre', 'Yuki', 'Ana', 'Mohamed', 'David', 'Sophie', 'Chen', 'Roberto', 'Fatima', 'James', 'Sarah', 'Michael', 'Lisa'),
    ' ',
    ELT(1 + FLOOR(RAND() * 19), 'Smith', 'Garcia', 'Wei', 'Rodriguez', 'Hassan', 'Johnson', 'Dubois', 'Tanaka', 'Silva', 'Ali', 'Brown', 'Martin', 'Ming', 'Santos', 'Al-Mansouri', 'Wilson', 'Davis', 'Miller', 'Anderson', 'Taylor')
  ) as name,
  CONCAT('customer', COALESCE(n, 0), '@example.com') as email,
  1 + FLOOR(RAND() * 5) as region_id
FROM (
  SELECT @row := @row + 1 as n
  FROM (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t1,
       (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t2,
       (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t3,
       (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) t4
  LIMIT 5000
) numbers
WHERE NOT EXISTS (SELECT 1 FROM customers);

-- Insert sample orders and order_items if orders table is empty
-- This creates 100,000 orders with historical data for the last 90 days
-- Using a numbers table approach for efficient bulk generation
SET @row = 0;
SET @max_customer_id = (SELECT COALESCE(MAX(id), 1) FROM customers);
SET @min_customer_id = (SELECT COALESCE(MIN(id), 1) FROM customers);

INSERT INTO orders (customer_id, total_amount, status, created_at)
SELECT 
  @min_customer_id + FLOOR(RAND() * (@max_customer_id - @min_customer_id + 1)) as customer_id,
  ROUND(50 + RAND() * 950, 2) as total_amount,
  'completed' as status,
  NOW() - INTERVAL FLOOR(RAND() * (90*86400)) SECOND as created_at
FROM (
  SELECT @row := @row + 1 as n
  FROM (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t1,
       (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t2,
       (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t3,
       (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t4,
       (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) t5
  LIMIT 100000
) numbers
WHERE NOT EXISTS (
    SELECT 1 FROM orders 
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 DAY)
  )
  AND EXISTS (SELECT 1 FROM customers);

-- Insert order items for the sample orders (1-4 items per order, average ~2.5 items)
-- This will generate approximately 250,000 order_items
SET @max_product_id = (SELECT COALESCE(MAX(id), 1) FROM products);
SET @min_product_id = (SELECT COALESCE(MIN(id), 1) FROM products);

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
WHERE NOT EXISTS (SELECT 1 FROM order_items)
  AND RAND() < 0.625  -- Average 2.5 items per order (2.5/4 = 0.625)
LIMIT 25000;

-- Update order totals to match order_items
-- Use batch updates for better performance
UPDATE orders o
INNER JOIN (
  SELECT 
    order_id,
    COALESCE(SUM(quantity * price), 0) as calculated_total
  FROM order_items
  GROUP BY order_id
) oi_totals ON o.id = oi_totals.order_id
SET o.total_amount = oi_totals.calculated_total
WHERE EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.id);

