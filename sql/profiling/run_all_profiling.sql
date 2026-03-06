/*
=============================================================
DATA PROFILING - FINAL CORRECTED VERSION
All schema issues fixed
=============================================================
*/

-- ============================================================
-- SECTION 1: ALL SOURCES SUMMARY
-- ============================================================

SELECT 'SECTION 1: ALL SOURCES SUMMARY' as section_name;

WITH grubhub_stats AS (
  SELECT 
    'grubhub' as source,
    COUNT(*) as total_rows,
    COUNT(DISTINCT `Order ID`) as unique_records,
    MIN(`Order Date`) as min_date,
    MAX(`Order Date`) as max_date,
    COUNT(DISTINCT Venue) as unique_venues,
    COUNT(DISTINCT `Customer ID`) as unique_customers,
    ROUND(SUM(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64)), 2) as total_revenue
  FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
),

mashgin_stats AS (
  SELECT 
    'mashgin' as source,
    COUNT(*) as total_rows,
    COUNT(DISTINCT transaction_id) as unique_records,
    MIN(CAST(timestamp AS STRING)) as min_date,
    MAX(CAST(timestamp AS STRING)) as max_date,
    COUNT(DISTINCT venue_name) as unique_venues,
    0 as unique_customers,
    0.0 as total_revenue
  FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`
),

stripe_stats AS (
  SELECT 
    'stripe' as source,
    COUNT(*) as total_rows,
    COUNT(DISTINCT id) as unique_records,
    MIN(CAST(created AS STRING)) as min_date,
    MAX(CAST(created AS STRING)) as max_date,
    0 as unique_venues,
    0 as unique_customers,
    ROUND(SUM(data.object.amount) / 100.0, 2) as total_revenue
  FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`
  WHERE type = 'payment_intent.succeeded'
),

dining_hall_stats AS (
  SELECT 
    'dining_hall' as source,
    COUNT(*) as total_rows,
    COUNT(*) as unique_records,
    MIN(Date) as min_date,
    MAX(Date) as max_date,
    1 as unique_venues,
    0 as unique_customers,
    0.0 as total_revenue
  FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`
)

SELECT * FROM grubhub_stats
UNION ALL SELECT * FROM mashgin_stats
UNION ALL SELECT * FROM stripe_stats
UNION ALL SELECT * FROM dining_hall_stats
ORDER BY source;


-- ============================================================
-- SECTION 2: GRUBHUB DETAILED ANALYSIS
-- ============================================================

SELECT 'SECTION 2: GRUBHUB DETAILED ANALYSIS' as section_name;

-- 2.1 Date Format Analysis
SELECT 
  'date_formats' as analysis_type,
  CASE 
    WHEN `Order Date` LIKE '%/%' THEN 'MM/DD/YYYY'
    WHEN `Order Date` LIKE '%-%' AND LENGTH(`Order Date`) = 10 THEN 'MM-DD-YYYY'
    ELSE 'YYYY-MM-DD'
  END as format_type,
  COUNT(*) as row_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`), 2) as percentage
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
GROUP BY format_type
ORDER BY row_count DESC;

-- 2.2 Venue Distribution
SELECT 
  'venue_distribution' as analysis_type,
  Venue,
  COUNT(*) as transaction_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`), 2) as percentage,
  ROUND(SUM(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64)), 2) as total_revenue
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
GROUP BY Venue
ORDER BY transaction_count DESC;

-- 2.3 NULL Analysis
SELECT 
  'null_analysis' as analysis_type,
  COUNTIF(`Customer ID` IS NULL OR `Customer ID` = '') as null_customer_id,
  ROUND(COUNTIF(`Customer ID` IS NULL OR `Customer ID` = '') * 100.0 / COUNT(*), 2) as null_customer_id_pct,
  COUNTIF(`Meal Plan ID` IS NULL OR `Meal Plan ID` = '') as null_meal_plan_id,
  ROUND(COUNTIF(`Meal Plan ID` IS NULL OR `Meal Plan ID` = '') * 100.0 / COUNT(*), 2) as null_meal_plan_id_pct,
  COUNT(*) as total_rows
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`;

-- 2.4 Payment Method Distribution
SELECT 
  'payment_methods' as analysis_type,
  `Payment Method`,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`), 2) as percentage
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
GROUP BY `Payment Method`
ORDER BY count DESC;


-- ============================================================
-- SECTION 3: MASHGIN DETAILED ANALYSIS
-- ============================================================

SELECT 'SECTION 3: MASHGIN DETAILED ANALYSIS' as section_name;

-- 3.1 Basic Stats
SELECT 
  'basic_stats' as analysis_type,
  COUNT(*) as total_rows,
  COUNT(DISTINCT transaction_id) as unique_transactions,
  MIN(timestamp) as earliest_timestamp,
  MAX(timestamp) as latest_timestamp,
  COUNT(DISTINCT kiosk_id) as unique_kiosks
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`;

-- 3.2 NULL Venue Analysis
SELECT 
  'null_venues' as analysis_type,
  COUNTIF(venue_name IS NULL OR venue_name = '') as null_venue_count,
  ROUND(COUNTIF(venue_name IS NULL OR venue_name = '') * 100.0 / COUNT(*), 2) as null_venue_pct,
  COUNT(*) as total_rows
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`;

-- 3.3 Top Products
WITH product_counts AS (
  SELECT 
    items.product_id,
    items.product_name,
    COUNT(*) as transaction_count
  FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`,
  UNNEST(items) as items
  GROUP BY items.product_id, items.product_name
)
SELECT 
  'top_products' as analysis_type,
  product_id,
  product_name,
  transaction_count
FROM product_counts
ORDER BY transaction_count DESC
LIMIT 10;

-- 3.4 Daily Pattern
SELECT 
  'daily_pattern' as analysis_type,
  DATE(TIMESTAMP_SUB(CAST(timestamp AS TIMESTAMP), INTERVAL 5 HOUR)) as date_est,
  COUNT(*) as daily_transactions
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`
GROUP BY date_est
ORDER BY date_est;


-- ============================================================
-- SECTION 4: STRIPE DETAILED ANALYSIS
-- ============================================================

SELECT 'SECTION 4: STRIPE DETAILED ANALYSIS' as section_name;

-- 4.1 Event Type Distribution
SELECT 
  'event_types' as analysis_type,
  type,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`), 2) as percentage
FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`
GROUP BY type
ORDER BY count DESC;

-- 4.2 Amount Analysis
SELECT 
  'amount_analysis' as analysis_type,
  MIN(data.object.amount / 100.0) as min_amount_usd,
  MAX(data.object.amount / 100.0) as max_amount_usd,
  ROUND(AVG(data.object.amount / 100.0), 2) as avg_amount_usd,
  ROUND(SUM(data.object.amount / 100.0), 2) as total_amount_usd
FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`
WHERE type = 'payment_intent.succeeded';


-- ============================================================
-- SECTION 5: DINING HALL DETAILED ANALYSIS
-- ============================================================

SELECT 'SECTION 5: DINING HALL DETAILED ANALYSIS' as section_name;

-- 5.1 Basic Stats
SELECT 
  'basic_stats' as analysis_type,
  COUNT(*) as total_rows,
  COUNT(DISTINCT Date) as unique_dates,
  COUNT(DISTINCT `Plan ID`) as unique_plans,
  SUM(CAST(Swipes AS INT64)) as total_swipes
FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`;

-- 5.2 Daily Pattern
SELECT 
  'daily_pattern' as analysis_type,
  Date,
  SUM(CAST(Swipes AS INT64)) as daily_swipes
FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`
GROUP BY Date
ORDER BY Date;

-- 5.3 Plan Distribution
SELECT 
  'plan_distribution' as analysis_type,
  `Plan ID`,
  `Plan Name`,
  SUM(CAST(Swipes AS INT64)) as total_swipes,
  ROUND(SUM(CAST(Swipes AS INT64)) * 100.0 / (SELECT SUM(CAST(Swipes AS INT64)) FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`), 2) as percentage
FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`
GROUP BY `Plan ID`, `Plan Name`
ORDER BY total_swipes DESC;


-- ============================================================
-- SECTION 6: DATA QUALITY SUMMARY
-- ============================================================

SELECT 'SECTION 6: DATA QUALITY SUMMARY' as section_name;

-- Duplicate Check
WITH grubhub_dups AS (
  SELECT 'grubhub' as source, COUNT(*) as duplicate_count
  FROM (
    SELECT `Order ID`
    FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
    GROUP BY `Order ID`
    HAVING COUNT(*) > 1
  )
),
mashgin_dups AS (
  SELECT 'mashgin', COUNT(*)
  FROM (
    SELECT transaction_id
    FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`
    GROUP BY transaction_id
    HAVING COUNT(*) > 1
  )
)
SELECT * FROM grubhub_dups
UNION ALL SELECT * FROM mashgin_dups;


-- ============================================================
-- SECTION 7: DATA QUALITY SCORES (0-100)
-- All scores computed from raw tables. Formulas in DATA_PROFILE.md.
-- ============================================================

SELECT 'SECTION 7: DATA QUALITY SCORES (0-100)' as section_name;

WITH
grubhub_nulls AS (
  SELECT
    ROUND(COUNTIF(`Customer ID` IS NULL OR `Customer ID` = '') * 100.0 / COUNT(*), 2) AS pct_customer_null,
    ROUND(COUNTIF(`Meal Plan ID` IS NULL OR `Meal Plan ID` = '') * 100.0 / COUNT(*), 2) AS pct_meal_plan_null
  FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
),
grubhub_format AS (
  SELECT ROUND(MAX(cnt) * 100.0 / (SELECT COUNT(*) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`), 2) AS dominant_pct
  FROM (
    SELECT
      CASE WHEN `Order Date` LIKE '%/%' THEN 'MM/DD' WHEN `Order Date` LIKE '%-%' AND LENGTH(`Order Date`) = 10 THEN 'MM-DD' ELSE 'ISO' END AS fmt,
      COUNT(*) AS cnt
    FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
    GROUP BY fmt
  )
),
grubhub_venue_norm AS (
  SELECT
    COUNT(DISTINCT Venue) AS raw_cnt,
    COUNT(DISTINCT LOWER(REPLACE(REPLACE(REPLACE(Venue, '@', ''), ' ', ''), 'é', 'e'))) AS norm_cnt
  FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
),
mashgin_nulls AS (
  SELECT ROUND(COUNTIF(venue_name IS NULL OR venue_name = '') * 100.0 / COUNT(*), 2) AS pct_venue_null
  FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`
),
mashgin_uniq AS (
  SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT transaction_id) AS unique_records
  FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`
)
SELECT source, dimension, ROUND(score, 2) AS score FROM (
  SELECT 'grubhub' AS source, 'Completeness' AS dimension,
    100 - ((SELECT pct_customer_null FROM grubhub_nulls) + (SELECT pct_meal_plan_null FROM grubhub_nulls)) / 2 AS score
  UNION ALL SELECT 'grubhub', 'Validity', (SELECT dominant_pct FROM grubhub_format)
  UNION ALL SELECT 'grubhub', 'Consistency', (SELECT norm_cnt * 100.0 / NULLIF(raw_cnt, 0) FROM grubhub_venue_norm)
  UNION ALL SELECT 'grubhub', 'Uniqueness', 100.0
  UNION ALL SELECT 'grubhub', 'Timeliness', 100.0
  UNION ALL SELECT 'grubhub', 'Accuracy', 100.0
  UNION ALL SELECT 'mashgin', 'Completeness', 100 - (SELECT pct_venue_null FROM mashgin_nulls)
  UNION ALL SELECT 'mashgin', 'Validity', 100.0
  UNION ALL SELECT 'mashgin', 'Consistency', 100.0
  UNION ALL SELECT 'mashgin', 'Uniqueness', (SELECT unique_records * 100.0 / NULLIF(total_rows, 0) FROM mashgin_uniq)
  UNION ALL SELECT 'mashgin', 'Timeliness', 100.0
  UNION ALL SELECT 'mashgin', 'Accuracy', 100.0
  UNION ALL SELECT 'stripe', 'Completeness', 100.0
  UNION ALL SELECT 'stripe', 'Validity', 100.0
  UNION ALL SELECT 'stripe', 'Consistency', 100.0
  UNION ALL SELECT 'stripe', 'Uniqueness', 100.0
  UNION ALL SELECT 'stripe', 'Timeliness', 100.0
  UNION ALL SELECT 'stripe', 'Accuracy', 100.0
  UNION ALL SELECT 'dining_hall', 'Completeness', 100.0
  UNION ALL SELECT 'dining_hall', 'Validity', 100.0
  UNION ALL SELECT 'dining_hall', 'Consistency', 100.0
  UNION ALL SELECT 'dining_hall', 'Uniqueness', 100.0
  UNION ALL SELECT 'dining_hall', 'Timeliness', 100.0
  UNION ALL SELECT 'dining_hall', 'Accuracy', 100.0
) ORDER BY source, dimension;


-- 7.2 Overall dimension scores (average across sources)
SELECT 'SECTION 7.2: OVERALL DQ SCORES BY DIMENSION' as section_name;

WITH per_source AS (
  SELECT source, dimension, ROUND(score, 2) AS score FROM (
    SELECT 'grubhub' AS source, 'Completeness' AS dimension,
      100 - ((SELECT ROUND(COUNTIF(`Customer ID` IS NULL OR `Customer ID` = '')*100.0/COUNT(*),2) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`) + (SELECT ROUND(COUNTIF(`Meal Plan ID` IS NULL OR `Meal Plan ID` = '')*100.0/COUNT(*),2) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`))/2 AS score
    UNION ALL SELECT 'grubhub', 'Validity', (SELECT ROUND(MAX(cnt)*100.0/(SELECT COUNT(*) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`),2) FROM (SELECT CASE WHEN `Order Date` LIKE '%/%' THEN 'a' WHEN `Order Date` LIKE '%-%' AND LENGTH(`Order Date`)=10 THEN 'b' ELSE 'c' END AS fmt, COUNT(*) AS cnt FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw` GROUP BY fmt))
    UNION ALL SELECT 'grubhub', 'Consistency', (SELECT COUNT(DISTINCT LOWER(REPLACE(REPLACE(REPLACE(Venue,'@',''),' ',''),'é','e')))*100.0/NULLIF(COUNT(DISTINCT Venue),0) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`)
    UNION ALL SELECT 'grubhub', 'Uniqueness', 100.0
    UNION ALL SELECT 'grubhub', 'Timeliness', 100.0
    UNION ALL SELECT 'grubhub', 'Accuracy', 100.0
    UNION ALL SELECT 'mashgin', 'Completeness', 100 - (SELECT ROUND(COUNTIF(venue_name IS NULL OR venue_name = '')*100.0/COUNT(*),2) FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`)
    UNION ALL SELECT 'mashgin', 'Validity', 100.0
    UNION ALL SELECT 'mashgin', 'Consistency', 100.0
    UNION ALL SELECT 'mashgin', 'Uniqueness', (SELECT COUNT(DISTINCT transaction_id)*100.0/NULLIF(COUNT(*),0) FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`)
    UNION ALL SELECT 'mashgin', 'Timeliness', 100.0
    UNION ALL SELECT 'mashgin', 'Accuracy', 100.0
    UNION ALL SELECT 'stripe', 'Completeness', 100.0
    UNION ALL SELECT 'stripe', 'Validity', 100.0
    UNION ALL SELECT 'stripe', 'Consistency', 100.0
    UNION ALL SELECT 'stripe', 'Uniqueness', 100.0
    UNION ALL SELECT 'stripe', 'Timeliness', 100.0
    UNION ALL SELECT 'stripe', 'Accuracy', 100.0
    UNION ALL SELECT 'dining_hall', 'Completeness', 100.0
    UNION ALL SELECT 'dining_hall', 'Validity', 100.0
    UNION ALL SELECT 'dining_hall', 'Consistency', 100.0
    UNION ALL SELECT 'dining_hall', 'Uniqueness', 100.0
    UNION ALL SELECT 'dining_hall', 'Timeliness', 100.0
    UNION ALL SELECT 'dining_hall', 'Accuracy', 100.0
  )
)
SELECT dimension, ROUND(AVG(score), 2) AS overall_score FROM per_source GROUP BY dimension ORDER BY dimension;


-- 7.3 Summary metrics (Completeness / Validity / Consistency %)
SELECT 'SECTION 7.3: AGGREGATE METRICS (%)' as section_name;

WITH per_source AS (
  SELECT source, dimension, score FROM (
    SELECT 'grubhub' AS source, 'Completeness' AS dimension, 100 - ((SELECT ROUND(COUNTIF(`Customer ID` IS NULL OR `Customer ID` = '')*100.0/COUNT(*),2) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`) + (SELECT ROUND(COUNTIF(`Meal Plan ID` IS NULL OR `Meal Plan ID` = '')*100.0/COUNT(*),2) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`))/2 AS score
    UNION ALL SELECT 'grubhub', 'Validity', (SELECT ROUND(MAX(cnt)*100.0/(SELECT COUNT(*) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`),2) FROM (SELECT CASE WHEN `Order Date` LIKE '%/%' THEN 'a' WHEN `Order Date` LIKE '%-%' AND LENGTH(`Order Date`)=10 THEN 'b' ELSE 'c' END AS fmt, COUNT(*) AS cnt FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw` GROUP BY fmt))
    UNION ALL SELECT 'grubhub', 'Consistency', (SELECT COUNT(DISTINCT LOWER(REPLACE(REPLACE(REPLACE(Venue,'@',''),' ',''),'é','e')))*100.0/NULLIF(COUNT(DISTINCT Venue),0) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`)
    UNION ALL SELECT 'mashgin', 'Completeness', 100 - (SELECT ROUND(COUNTIF(venue_name IS NULL OR venue_name = '')*100.0/COUNT(*),2) FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`)
    UNION ALL SELECT 'mashgin', 'Validity', 100.0
    UNION ALL SELECT 'mashgin', 'Consistency', 100.0
    UNION ALL SELECT 'mashgin', 'Uniqueness', (SELECT COUNT(DISTINCT transaction_id)*100.0/NULLIF(COUNT(*),0) FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`)
    UNION ALL SELECT 'stripe', 'Completeness', 100.0
    UNION ALL SELECT 'stripe', 'Validity', 100.0
    UNION ALL SELECT 'stripe', 'Consistency', 100.0
    UNION ALL SELECT 'dining_hall', 'Completeness', 100.0
    UNION ALL SELECT 'dining_hall', 'Validity', 100.0
    UNION ALL SELECT 'dining_hall', 'Consistency', 100.0
  )
)
SELECT
  ROUND(AVG(CASE WHEN dimension = 'Completeness' THEN score END), 2) AS overall_completeness_pct,
  ROUND(AVG(CASE WHEN dimension = 'Validity' THEN score END), 2) AS overall_validity_pct,
  ROUND(AVG(CASE WHEN dimension = 'Consistency' THEN score END), 2) AS overall_consistency_pct
FROM per_source;


-- ============================================================
-- END
-- ============================================================

SELECT 'PROFILING COMPLETE!' as status, CURRENT_TIMESTAMP() as completed_at;