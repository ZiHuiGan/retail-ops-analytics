# Data Profiling Report
**Date:** 2026-02-04  
**Analyst:** Grace Gan  
**Project:** Retail Ops Analytics - CVU Dining  
**Data Warehouse:** BigQuery (`retail-ops-analytics.raw_cvu_dining`)

---

## Executive Summary

### Data Quality Score (0-100)
- **Overall Score:** ___ / 100
- **Completeness:** ___ / 100
- **Validity:** ___ / 100
- **Consistency:** ___ / 100
- **Accuracy:** ___ / 100
- **Uniqueness:** ___ / 100
- **Timeliness:** ___ / 100

### Data Quality Dimensions (DAMA Framework)

1. **Completeness** - 数据是否完整？是否有缺失值？
2. **Validity** - 数据是否符合预期格式和业务规则？
3. **Consistency** - 数据在不同来源间是否一致？
4. **Accuracy** - 数据是否准确反映现实？
5. **Uniqueness** - 是否有重复记录？
6. **Timeliness** - 数据是否及时更新？

---

## 1. Grubhub Sales

### Basic Stats
```sql
SELECT 
    COUNT(*) as total_rows,
    COUNT(DISTINCT `Order ID`) as unique_orders,
    MIN(`Order Date`) as min_date,
    MAX(`Order Date`) as max_date,
    COUNT(DISTINCT Venue) as unique_venues
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`;
```

**Results:**
- Total rows: 665
- Unique orders: 665
- Date range: 02-03-2026 to 2026-02-09
- Unique venues: 24

### Column Analysis

#### Order Date
```sql
SELECT 
    `Order Date`,
    COUNT(*) as frequency,
    -- Check different formats
    CASE 
        WHEN `Order Date` LIKE '%/%' THEN 'MM/DD/YYYY'
        WHEN `Order Date` LIKE '%-%' AND LENGTH(`Order Date`) = 10 THEN 'MM-DD-YYYY'
        ELSE 'YYYY-MM-DD'
    END as date_format
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
GROUP BY `Order Date`, date_format
ORDER BY frequency DESC
LIMIT 10;
```

**Findings:**
- [ ] Mixed date formats detected; MM-DD-YYYY and MM/DD/YYYY
- [ ] Formats found: 2

#### Venue
```sql
SELECT
  Venue,
  LOWER(REPLACE(REPLACE(REPLACE(Venue, '@', ''), ' ', ''), 'é', 'e')) AS normalized_venue_name
FROM
  `retail-ops-analytics`.`raw_cvu_dining`.`grubhub_sales_raw`
GROUP BY
  Venue,
  normalized_venue_name
ORDER BY
  normalized_venue_name,
  Venue;
```

**Findings:**
- [ ] Total unique venue names: 18
- [ ] Name variations detected Row	Venue	normalized_venue_name
1	Chipotle @ Student Center	chipotlestudentcenter
2	Chipotle@Student Center	chipotlestudentcenter
3	CVU-R001	cvu-r001
4	CVU-R002	cvu-r002
5	CVU-R003	cvu-r003
6	CVU-R004	cvu-r004
7	CVU-R005	cvu-r005
8	CVU-R006	cvu-r006
9	CVU-R007	cvu-r007
10	CVU-R008	cvu-r008
11	Engineering Lounge	engineeringlounge
12	Late Night @ North	latenightnorth
13	Late Night@North	latenightnorth
14	Late Night @ South	latenightsouth
15	Late Night@South	latenightsouth
16	Panda Express @ Student Center	pandaexpressstudentcenter
17	Panda Express@Student Center	pandaexpressstudentcenter
18	Starbucks @ Student Center	starbucksstudentcenter
19	Starbucks@Student Center	starbucksstudentcenter
20	Starbucks @ Student Ctr	starbucksstudentctr
21	Subway @ North Campus	subwaynorthcampus
22	Subway@North Campus	subwaynorthcampus
23	Valley Cafe	valleycafe
24	Valley Café	valleycafe

#### Amount Analysis
```sql
SELECT 
    MIN(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64)) as min_amount,
    MAX(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64)) as max_amount,
    AVG(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64)) as avg_amount,
    STDDEV(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64)) as stddev_amount
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`;
```
**Findings:**
min_amount: 2.7
max_amount: 26.46
avg_amount: 8.96
stddev_amount:4.56


#### Amount Distribution (Percentiles)
```sql
SELECT 
    APPROX_QUANTILES(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64), 100)[OFFSET(25)] as p25,
    APPROX_QUANTILES(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64), 100)[OFFSET(50)] as p50_median,
    APPROX_QUANTILES(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64), 100)[OFFSET(75)] as p75,
    APPROX_QUANTILES(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64), 100)[OFFSET(95)] as p95,
    APPROX_QUANTILES(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64), 100)[OFFSET(99)] as p99
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`;
```

**Findings:**
- [ ] 25th percentile: $4.86
- [ ] Median (50th): $8.59
- [ ] 75th percentile: $11.34
- [ ] 95th percentile: $17.82
- [ ] 99th percentile: $25.81

### NULL Analysis
```sql
SELECT 
    COUNTIF(`Customer ID` IS NULL OR `Customer ID` = '') as null_customer_id,
    COUNTIF(`Meal Plan ID` IS NULL OR `Meal Plan ID` = '') as null_meal_plan_id,
    COUNT(*) as total_rows,
    ROUND(COUNTIF(`Customer ID` IS NULL OR `Customer ID` = '') * 100.0 / COUNT(*), 2) as pct_null_customer,
    ROUND(COUNTIF(`Meal Plan ID` IS NULL OR `Meal Plan ID` = '') * 100.0 / COUNT(*), 2) as pct_null_meal_plan
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`;
```

**Findings:**
- [ ] NULL Customer ID: 8.87% (Expected: ~15% for cash payments)
- [ ] NULL Meal Plan ID: 68.42% (Expected: ~50% for non-meal-plan)

### Duplicate Analysis
```sql
SELECT 
    `Order ID`,
    COUNT(*) as duplicate_count
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
GROUP BY `Order ID`
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
```

**Findings:**
- [ ] Duplicate Order IDs found: 0
- [ ] Duplicate rate: ___%

### Referential Integrity Check
```sql
-- Check if Venue names match location_master
SELECT 
    g.Venue,
    COUNT(*) as grubhub_count,
    CASE WHEN l.location_name IS NULL THEN 'NOT IN MASTER' ELSE 'IN MASTER' END as in_master
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw` g
LEFT JOIN `retail-ops-analytics.raw_cvu_dining.location_master` l
    ON g.Venue = l.location_name
GROUP BY g.Venue, in_master
ORDER BY grubhub_count DESC;
```

**Findings:**
- [ ] Venues not in location_master: ___
- [ ] Venue matching rate: ___%

### Business Rule Validation
```sql
-- Check business rules
SELECT 
    COUNTIF(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64) < 0) as negative_amounts,
    COUNTIF(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64) > 1000) as very_large_amounts,
    COUNTIF(`Order Date` > CURRENT_DATE()) as future_dates,
    COUNTIF(`Order Date` < '2020-01-01') as very_old_dates,
    COUNT(*) as total_rows
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`;
```

**Findings:**
- [ ] Negative amounts: ___
- [ ] Amounts > $1000: ___
- [ ] Future dates: ___
- [ ] Dates before 2020: ___

---

## 2. Mashgin Transactions

### Basic Stats
```sql
SELECT 
    COUNT(*) as total_transactions,
    COUNT(DISTINCT transaction_id) as unique_transactions,
    MIN(timestamp) as min_timestamp,
    MAX(timestamp) as max_timestamp,
    COUNT(DISTINCT kiosk_id) as unique_kiosks,
    COUNT(DISTINCT venue_name) as unique_venues
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`;
```

**Results:**
- Total transactions: ___
- Unique transactions: ___
- Date range: ___ to ___
- Unique kiosks: ___
- Unique venues: ___

### Column Analysis

#### Timestamp (UTC)
```sql
SELECT 
    DATE(timestamp) as date,
    COUNT(*) as transactions_per_day,
    MIN(timestamp) as first_transaction,
    MAX(timestamp) as last_transaction
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`
GROUP BY date
ORDER BY date;
```

**Findings:**
- [ ] All timestamps in UTC format (ending with 'Z')
- [ ] Date range: ___ to ___

#### Venue Name
```sql
SELECT 
    venue_name,
    COUNT(*) as transaction_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct_of_total
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`
GROUP BY venue_name
ORDER BY transaction_count DESC;
```

**Findings:**
- [ ] Total unique venue names: ___
- [ ] Empty venue_name count: ___
- [ ] Empty venue_name percentage: ___%

#### Amount Analysis
```sql
SELECT 
    MIN(SAFE_CAST(total AS FLOAT64)) as min_amount,
    MAX(SAFE_CAST(total AS FLOAT64)) as max_amount,
    AVG(SAFE_CAST(total AS FLOAT64)) as avg_amount,
    STDDEV(SAFE_CAST(total AS FLOAT64)) as stddev_amount
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`;
```

**Findings:**
- [ ] Amount range: $___ to $___
- [ ] Average: $___

### NULL Analysis
```sql
SELECT 
    COUNTIF(venue_name IS NULL OR venue_name = '') as null_venue_name,
    COUNTIF(payment_method IS NULL) as null_payment_method,
    COUNTIF(customer_id IS NULL) as null_customer_id,
    COUNT(*) as total_rows,
    ROUND(COUNTIF(venue_name IS NULL OR venue_name = '') * 100.0 / COUNT(*), 2) as pct_null_venue,
    ROUND(COUNTIF(payment_method IS NULL) * 100.0 / COUNT(*), 2) as pct_null_payment,
    ROUND(COUNTIF(customer_id IS NULL) * 100.0 / COUNT(*), 2) as pct_null_customer
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`;
```

**Findings:**
- [ ] NULL venue_name: ___% (Expected: ~10%)
- [ ] NULL payment_method: ___% (Expected: 100% - kiosks don't have payment method)
- [ ] NULL customer_id: ___% (Expected: 100% - kiosks are anonymous)

### Time Distribution Analysis
```sql
SELECT 
    EXTRACT(HOUR FROM TIMESTAMP(timestamp)) as hour_of_day,
    COUNT(*) as transaction_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct_of_total
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`
GROUP BY hour_of_day
ORDER BY hour_of_day;
```

**Findings:**
- [ ] Peak hours: ___
- [ ] Low activity hours: ___

### Referential Integrity Check
```sql
-- Check if kiosk_id maps to valid locations
SELECT 
    m.kiosk_id,
    COUNT(*) as transaction_count,
    CASE WHEN l.location_id IS NULL THEN 'UNMAPPED' ELSE 'MAPPED' END as mapping_status
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw` m
LEFT JOIN `retail-ops-analytics.raw_cvu_dining.location_master` l
    ON CAST(m.kiosk_id AS STRING) = l.location_id
GROUP BY m.kiosk_id, mapping_status
ORDER BY transaction_count DESC;
```

**Findings:**
- [ ] Unmapped kiosk_ids: ___
- [ ] Mapping coverage: ___%

---

## 3. Stripe Events

### Basic Stats
```sql
SELECT 
    COUNT(*) as total_events,
    COUNT(DISTINCT id) as unique_event_ids,
    MIN(created) as min_created,
    MAX(created) as max_created,
    COUNT(DISTINCT type) as unique_event_types
FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`;
```

**Results:**
- Total events: ___
- Unique event IDs: ___
- Date range: ___ to ___
- Unique event types: ___

### Column Analysis

#### Event Types
```sql
SELECT 
    type,
    COUNT(*) as event_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct_of_total
FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`
GROUP BY type
ORDER BY event_count DESC;
```

**Findings:**
- [ ] Event types found: ___
- [ ] Most common type: ___

#### Amount Analysis (in cents)
```sql
SELECT 
    MIN(SAFE_CAST(JSON_EXTRACT_SCALAR(data, '$.object.amount') AS INT64)) as min_amount_cents,
    MAX(SAFE_CAST(JSON_EXTRACT_SCALAR(data, '$.object.amount') AS INT64)) as max_amount_cents,
    AVG(SAFE_CAST(JSON_EXTRACT_SCALAR(data, '$.object.amount') AS INT64)) as avg_amount_cents,
    STDDEV(SAFE_CAST(JSON_EXTRACT_SCALAR(data, '$.object.amount') AS INT64)) as stddev_amount_cents,
    -- Convert to dollars for readability
    MIN(SAFE_CAST(JSON_EXTRACT_SCALAR(data, '$.object.amount') AS INT64)) / 100.0 as min_amount_dollars,
    MAX(SAFE_CAST(JSON_EXTRACT_SCALAR(data, '$.object.amount') AS INT64)) / 100.0 as max_amount_dollars,
    AVG(SAFE_CAST(JSON_EXTRACT_SCALAR(data, '$.object.amount') AS INT64)) / 100.0 as avg_amount_dollars
FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`
WHERE JSON_EXTRACT_SCALAR(data, '$.object.amount') IS NOT NULL;
```

**Findings:**
- [ ] Amount range: $___ to $___ (in cents: ___ to ___)
- [ ] Average: $___

### Metadata Analysis
```sql
SELECT 
    COUNTIF(JSON_EXTRACT_SCALAR(data, '$.object.metadata.order_id') IS NOT NULL) as has_order_id,
    COUNTIF(JSON_EXTRACT_SCALAR(data, '$.object.metadata.location_id') IS NOT NULL) as has_location_id,
    COUNTIF(JSON_EXTRACT_SCALAR(data, '$.object.metadata.customer_id') IS NOT NULL) as has_customer_id,
    COUNT(*) as total_events
FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`;
```

**Findings:**
- [ ] Events with order_id: ___%
- [ ] Events with location_id: ___%
- [ ] Events with customer_id: ___%

### Event Sequence Analysis
```sql
-- Check for duplicate events per order
SELECT 
    JSON_EXTRACT_SCALAR(data, '$.object.metadata.order_id') as order_id,
    COUNT(*) as event_count,
    STRING_AGG(DISTINCT type, ', ') as event_types
FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`
WHERE JSON_EXTRACT_SCALAR(data, '$.object.metadata.order_id') IS NOT NULL
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY event_count DESC
LIMIT 20;
```

**Findings:**
- [ ] Orders with multiple events: ___
- [ ] Average events per order: ___

### Referential Integrity Check
```sql
-- Check if Stripe order_ids match Grubhub orders
SELECT 
    s.order_id,
    COUNT(DISTINCT s.event_id) as stripe_events,
    COUNT(DISTINCT g.`Order ID`) as grubhub_matches
FROM (
    SELECT 
        id as event_id,
        JSON_EXTRACT_SCALAR(data, '$.object.metadata.order_id') as order_id
    FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`
    WHERE JSON_EXTRACT_SCALAR(data, '$.object.metadata.order_id') IS NOT NULL
) s
LEFT JOIN `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw` g
    ON s.order_id = g.`Order ID`
GROUP BY s.order_id
HAVING COUNT(DISTINCT g.`Order ID`) = 0
LIMIT 20;
```

**Findings:**
- [ ] Stripe orders not in Grubhub: ___
- [ ] Reconciliation rate: ___%

---

## 4. Dining Hall Swipes

### Basic Stats
```sql
SELECT 
    COUNT(*) as total_rows,
    COUNT(DISTINCT `Plan ID`) as unique_plans,
    MIN(Date) as min_date,
    MAX(Date) as max_date,
    SUM(SAFE_CAST(Swipes AS INT64)) as total_swipes
FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`;
```

**Results:**
- Total rows: ___
- Unique meal plans: ___
- Date range: ___ to ___
- Total swipes: ___

### Column Analysis

#### Meal Plans
```sql
SELECT 
    `Plan ID`,
    `Plan Name`,
    SUM(SAFE_CAST(Swipes AS INT64)) as total_swipes,
    COUNT(*) as days_recorded,
    ROUND(AVG(SAFE_CAST(Swipes AS INT64)), 2) as avg_swipes_per_day
FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`
GROUP BY `Plan ID`, `Plan Name`
ORDER BY total_swipes DESC;
```

**Findings:**
- [ ] Meal plans found: ___
- [ ] Most popular plan: ___

#### Date Analysis
```sql
SELECT 
    Date,
    COUNT(*) as records_per_date,
    SUM(SAFE_CAST(Swipes AS INT64)) as swipes_per_date
FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`
GROUP BY Date
ORDER BY Date;
```

**Findings:**
- [ ] Dates covered: ___
- [ ] Missing dates: ___

### NULL Analysis
```sql
SELECT 
    COUNTIF(Date IS NULL OR Date = '') as null_date,
    COUNTIF(`Plan ID` IS NULL OR `Plan ID` = '') as null_plan_id,
    COUNTIF(Swipes IS NULL OR Swipes = '') as null_swipes,
    COUNT(*) as total_rows
FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`;
```

**Findings:**
- [ ] NULL Date: ___%
- [ ] NULL Plan ID: ___%
- [ ] NULL Swipes: ___%

### Referential Integrity Check
```sql
-- Check if Plan IDs match meal_plans reference data
SELECT 
    d.`Plan ID`,
    COUNT(*) as dining_hall_records,
    CASE WHEN m.plan_id IS NULL THEN 'NOT IN MASTER' ELSE 'IN MASTER' END as in_master
FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw` d
LEFT JOIN `retail-ops-analytics.raw_cvu_dining.meal_plans` m
    ON d.`Plan ID` = m.plan_id
GROUP BY d.`Plan ID`, in_master
ORDER BY dining_hall_records DESC;
```

**Findings:**
- [ ] Plan IDs not in meal_plans: ___
- [ ] Matching rate: ___%

### Data Completeness Check
```sql
-- Check for missing dates in expected range
WITH date_series AS (
    SELECT date
    FROM UNNEST(GENERATE_DATE_ARRAY('2026-02-03', '2026-02-09')) AS date
),
actual_dates AS (
    SELECT DISTINCT Date as date
    FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`
    WHERE Date IS NOT NULL
)
SELECT 
    ds.date,
    CASE WHEN ad.date IS NULL THEN 'MISSING' ELSE 'PRESENT' END as status
FROM date_series ds
LEFT JOIN actual_dates ad ON ds.date = ad.date
ORDER BY ds.date;
```

**Findings:**
- [ ] Missing dates: ___
- [ ] Data completeness: ___%

---

## 5. Cross-Source Data Quality Analysis

### Data Freshness Check
```sql
-- Check when data was last updated
SELECT 
    'grubhub_sales_raw' as table_name,
    MAX(`Order Date`) as latest_date,
    CURRENT_DATE() as today,
    DATE_DIFF(CURRENT_DATE(), MAX(`Order Date`), DAY) as days_behind
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
UNION ALL
SELECT 
    'mashgin_transactions_raw' as table_name,
    MAX(DATE(timestamp)) as latest_date,
    CURRENT_DATE() as today,
    DATE_DIFF(CURRENT_DATE(), MAX(DATE(timestamp)), DAY) as days_behind
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`
UNION ALL
SELECT 
    'stripe_events_raw' as table_name,
    MAX(DATE(TIMESTAMP_SECONDS(created))) as latest_date,
    CURRENT_DATE() as today,
    DATE_DIFF(CURRENT_DATE(), MAX(DATE(TIMESTAMP_SECONDS(created))), DAY) as days_behind
FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`
UNION ALL
SELECT 
    'dining_hall_swipes_raw' as table_name,
    MAX(Date) as latest_date,
    CURRENT_DATE() as today,
    DATE_DIFF(CURRENT_DATE(), MAX(Date), DAY) as days_behind
FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`;
```

**Findings:**
- [ ] Grubhub data freshness: ___ days behind
- [ ] Mashgin data freshness: ___ days behind
- [ ] Stripe data freshness: ___ days behind
- [ ] Dining Hall data freshness: ___ days behind

### Cross-Source Reconciliation
```sql
-- Compare transaction volumes across sources
SELECT 
    'Grubhub' as source,
    COUNT(DISTINCT `Order ID`) as unique_transactions,
    SUM(SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64)) as total_revenue
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
UNION ALL
SELECT 
    'Mashgin' as source,
    COUNT(DISTINCT transaction_id) as unique_transactions,
    SUM(SAFE_CAST(total AS FLOAT64)) as total_revenue
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`
UNION ALL
SELECT 
    'Stripe' as source,
    COUNT(DISTINCT JSON_EXTRACT_SCALAR(data, '$.object.metadata.order_id')) as unique_transactions,
    SUM(SAFE_CAST(JSON_EXTRACT_SCALAR(data, '$.object.amount') AS INT64)) / 100.0 as total_revenue
FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`
WHERE type = 'payment_intent.succeeded';
```

**Findings:**
- [ ] Grubhub transactions: ___
- [ ] Mashgin transactions: ___
- [ ] Stripe successful payments: ___
- [ ] Revenue reconciliation: ___ (should match between Grubhub and Stripe)

### Data Volume Trends
```sql
-- Daily transaction volume by source
SELECT 
    DATE(`Order Date`) as date,
    'Grubhub' as source,
    COUNT(*) as daily_count
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
GROUP BY date
UNION ALL
SELECT 
    DATE(timestamp) as date,
    'Mashgin' as source,
    COUNT(*) as daily_count
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`
GROUP BY date
ORDER BY date, source;
```

**Findings:**
- [ ] Daily volume trends: ___
- [ ] Anomalies detected: ___

---

## Summary: Data Quality Issues Found

### Data Quality Scorecard

| Dimension | Grubhub | Mashgin | Stripe | Dining Hall | Overall |
|-----------|---------|---------|--------|-------------|---------|
| Completeness | ___/100 | ___/100 | ___/100 | ___/100 | ___/100 |
| Validity | ___/100 | ___/100 | ___/100 | ___/100 | ___/100 |
| Consistency | ___/100 | ___/100 | ___/100 | ___/100 | ___/100 |
| Accuracy | ___/100 | ___/100 | ___/100 | ___/100 | ___/100 |
| Uniqueness | ___/100 | ___/100 | ___/100 | ___/100 | ___/100 |
| Timeliness | ___/100 | ___/100 | ___/100 | ___/100 | ___/100 |

### Critical (Must fix immediately)
1. 

### High (Fix in staging)
1. 
2. 

### Medium (Document and handle)
1. 
2. 

### Low (Monitor)
1. 

---

## Data Quality Metrics Summary

### Completeness Metrics
- **Overall Completeness:** ___%
- **Critical Fields Complete:** ___%
- **Optional Fields Complete:** ___%

### Validity Metrics
- **Format Compliance:** ___%
- **Business Rule Compliance:** ___%
- **Referential Integrity:** ___%

### Consistency Metrics
- **Cross-Source Consistency:** ___%
- **Format Consistency:** ___%
- **Naming Consistency:** ___%

---

## Next Steps

1. [ ] Review all findings
2. [ ] Calculate data quality scores for each dimension
3. [ ] Prioritize data quality issues
4. [ ] Create staging models to handle issues
5. [ ] Document data transformation rules
6. [ ] Set up automated data quality monitoring
7. [ ] Create data quality dashboard queries
