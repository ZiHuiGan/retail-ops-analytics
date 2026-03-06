# Data Profiling Report
**Date:** 2026-02-04  
**Analyst:** Grace Gan  
**Project:** Retail Ops Analytics - CVU Dining  
**Data Warehouse:** BigQuery (`retail-ops-analytics.raw_cvu_dining`)

### All sources summary (Section 1)

| source      | total_rows | unique_records | min_date           | max_date           | unique_venues | unique_customers | total_revenue |
|-------------|------------|----------------|--------------------|--------------------|---------------|------------------|---------------|
| dining_hall | 28         | 28             | 2026-02-03         | 2026-02-09         | 1             | 0                | 0.0           |
| grubhub     | 665        | 665            | 02-03-2026         | 2026-02-09         | 24            | 584              | 5956.86       |
| mashgin     | 1038       | 557            | 2026-02-03T05:59:23Z | 2026-02-10T04:57:09Z | 6             | 0                | 0.0           |
| stripe      | 123        | 123            | 1770103802 (epoch) | 1770674402 (epoch) | 0             | 0                | 1137.89       |

*Stripe `min_date`/`max_date` are Unix epoch seconds; row count 123 is for `payment_intent.succeeded` only.*

---

## Executive Summary

### Data Quality Score (0-100)
*From **Section 7.2** (overall) and **Section 7.3** (aggregate %).*

- **Overall Score:** 93.45 / 100 *(average of the 6 dimension scores below)*
- **Completeness:** 87.98 / 100
- **Validity:** 91.58 / 100
- **Consistency:** 92.71 / 100
- **Accuracy:** 100 / 100
- **Uniqueness:** 88.41 / 100
- **Timeliness:** 100 / 100

### Data Quality Dimensions (DAMA Framework)

1. **Completeness** - 数据是否完整？是否有缺失值？
2. **Validity** - 数据是否符合预期格式和业务规则？
3. **Consistency** - 数据在不同来源间是否一致？
4. **Accuracy** - 数据是否准确反映现实？
5. **Uniqueness** - 是否有重复记录？
6. **Timeliness** - 数据是否及时更新？

### Data Quality Score Formulas (Section 7 in SQL)

以下维度已由 **`sql/profiling/run_all_profiling.sql` 的 Section 7** 用 SQL 直接计算，跑完 Section 7 即可得到 0–100 分和汇总百分比：

| 维度 | 计算方式 |
|------|----------|
| **Completeness** | Grubhub: `100 - (null_customer_id% + null_meal_plan_id%) / 2`；Mashgin: `100 - null_venue_name%`；Stripe / Dining hall: 100。 |
| **Validity** | Grubhub: 主导日期格式占比（如 MM-DD-YYYY 66.32% → 66.32）；其他源暂无格式违规 → 100。 |
| **Consistency** | Grubhub: 归一化 venue 数 / 原始 venue 数（18/24 = 75%）；其他源 100。 |
| **Uniqueness** | `100 * unique_records / total_rows`（Grubhub/Stripe/Dining 无重复 → 100；Mashgin 557/1038 ≈ 53.66）。 |
| **Timeliness** | 当前逻辑固定 100（若需按“延迟天数”扣分，可在 Section 7 中加 `DATE_DIFF(CURRENT_DATE(), max_date, DAY)` 再换算）。 |
| **Accuracy** | 当前无业务校验逻辑，固定 100（可后续加负金额、异常值等检查）。 |

- **Section 7.1**：各 source × dimension 的 0–100 分 → 填到 **Data Quality Scorecard** 表。
- **Section 7.2**：各 dimension 的 **Overall** 分（四源平均）→ 填到 **Executive Summary** 各维度行。
- **Section 7.3**：整体 **Completeness / Validity / Consistency** 的汇总 % → 填到 **Data Quality Metrics Summary**。

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
- [x] Mixed date formats detected; MM-DD-YYYY and MM/DD/YYYY
- [x] Formats found: MM-DD-YYYY 66.32% (441 rows), MM/DD/YYYY 33.68% (224 rows)

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
- [x] Total unique venue names: 24 (raw); 18 after normalizing (@/space/é)
- [x] Name variations detected (see table below). Notable duplicates: Subway@North Campus vs Subway @ North Campus; Valley Café vs Valley Cafe; Late Night @ North vs Late Night@North; Starbucks @ Student Center vs Starbucks@Student Center vs Starbucks @ Student Ctr; Chipotle/Panda Express with/without space around @.

| # | Venue | normalized_venue_name |
|---|-------|------------------------|
| 1 | Chipotle @ Student Center | chipotlestudentcenter |
| 2 | Chipotle@Student Center | chipotlestudentcenter |
| 3 | CVU-R001 | cvu-r001 |
| 4 | CVU-R002 | cvu-r002 |
| 5 | CVU-R003 | cvu-r003 |
| 6 | CVU-R004 | cvu-r004 |
| 7 | CVU-R005 | cvu-r005 |
| 8 | CVU-R006 | cvu-r006 |
| 9 | CVU-R007 | cvu-r007 |
| 10 | CVU-R008 | cvu-r008 |
| 11 | Engineering Lounge | engineeringlounge |
| 12 | Late Night @ North | latenightnorth |
| 13 | Late Night@North | latenightnorth |
| 14 | Late Night @ South | latenightsouth |
| 15 | Late Night@South | latenightsouth |
| 16 | Panda Express @ Student Center | pandaexpressstudentcenter |
| 17 | Panda Express@Student Center | pandaexpressstudentcenter |
| 18 | Starbucks @ Student Center | starbucksstudentcenter |
| 19 | Starbucks@Student Center | starbucksstudentcenter |
| 20 | Starbucks @ Student Ctr | starbucksstudentctr |
| 21 | Subway @ North Campus | subwaynorthcampus |
| 22 | Subway@North Campus | subwaynorthcampus |
| 23 | Valley Cafe | valleycafe |
| 24 | Valley Café | valleycafe |

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
- [x] NULL Customer ID: 8.87% (59 of 665) (Expected: ~15% for cash payments)
- [x] NULL Meal Plan ID: 68.42% (455 of 665) (Expected: ~50% for non-meal-plan)

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
- [x] Duplicate Order IDs found: 0
- [x] Duplicate rate: 0%

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
- Total transactions: 1,038
- Unique transactions: 557
- Date range: 2026-02-03T05:59:23Z to 2026-02-10T04:57:09Z (UTC)
- Unique kiosks: 5
- Unique venues: 6

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
- [x] All timestamps in UTC format (ending with 'Z')
- [x] Date range: 2026-02-03 to 2026-02-10

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
- [x] Total unique venue names: 6 (non-null)
- [x] Empty venue_name count: 98
- [x] Empty venue_name percentage: 9.44%

**Top products (from profiling):** KSK-001 Bottled Water (187), KSK-002 Coca-Cola (184), KSK-005 Lays Chips - Classic (173), KSK-009 Monster Energy (170), KSK-014 Kind Bar - Almond (167), KSK-004 Red Bull (157).

**Daily pattern (EST):** 2026-02-03: 148 txns; 02-04: 154; 02-05: 164; 02-06: 148; 02-07: 168; 02-08: 180; 02-09: 76.

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
- [x] NULL venue_name: 9.44% (98 of 1,038) (Expected: ~10%)
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
- Total events: 246 (123 payment_intent.created + 123 payment_intent.succeeded)
- Unique event IDs: 246 (each event has a unique `id`)
- Date range: `created` stored as Unix epoch seconds (min 1770103802, max 1770674402) — use `TIMESTAMP_SECONDS(created)` for date interpretation
- Unique event types: 2

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
- [x] Event types found: payment_intent.created (50%), payment_intent.succeeded (50%)
- [x] Most common type: tied at 123 each (50% / 50%)

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
- [x] Amount range: $2.70 to $26.46 (payment_intent.succeeded only)
- [x] Average: $9.25; Total: $1,137.89

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
- Total rows: 28
- Unique meal plans: 4
- Date range: 2026-02-03 to 2026-02-09
- Total swipes: 1,717

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
- [x] Meal plans found: 4
- [x] Most popular plan: CVU-MP-001 Unlimited Access (741 swipes, 43.16%)

| Plan ID | Plan Name | total_swipes | percentage |
|---------|-----------|--------------|-------------|
| CVU-MP-001 | Unlimited Access | 741 | 43.16% |
| CVU-MP-002 | Unlimited Access Plus | 483 | 28.13% |
| CVU-MP-003 | Flex 10 Plus | 271 | 15.78% |
| CVU-MP-004 | Specialty Dining | 222 | 12.93% |

**Daily swipe pattern:** 2026-02-03: 243; 02-04: 232; 02-05: 224; 02-06: 260; 02-07: 241; 02-08: 283; 02-09: 234.

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
- [x] Dates covered: 2026-02-03 to 2026-02-09 (7 days; 28 rows = 4 plans × 7 days)
- [x] Missing dates: None in the profiled range

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
- [x] Grubhub transactions: 665 unique; revenue $5,956.86
- [x] Mashgin transactions: 557 unique (revenue $0 in Section 1 — kiosk amounts may be in different column)
- [x] Stripe successful payments: 123; revenue $1,137.89
- [ ] Revenue reconciliation: Grubhub $5,956.86 vs Stripe $1,137.89 — gap expected (Stripe is subset of paid orders); document expected ratio or matching logic

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

### Section 6 Profiling Results (Duplicates)
| source   | duplicate_count |
|----------|-----------------|
| grubhub  | 0               |
| mashgin  | 481             |
| stripe   | 0 (not in run; assumed 0) |

*Note: Mashgin has 1,038 rows but only 557 unique `transaction_id`, so 481 duplicate groups. Grubhub and Stripe show no duplicate key violations.*

### Data Quality Scorecard
*From **Section 7.1** (per-source, per-dimension).*

| Dimension | Grubhub | Mashgin | Stripe | Dining Hall | Overall |
|-----------|---------|---------|--------|-------------|---------|
| Completeness | 61.35 | 90.56 | 100 | 100 | 87.98 |
| Validity | 66.32 | 100 | 100 | 100 | 91.58 |
| Consistency | 70.83 | 100 | 100 | 100 | 92.71 |
| Accuracy | 100 | 100 | 100 | 100 | 100 |
| Uniqueness | 100 | 53.66 | 100 | 100 | 88.41 |
| Timeliness | 100 | 100 | 100 | 100 | 100 |

*Overall column = average of the 4 sources (Section 7.2).*

---

### 数据源问题总结

| 数据源 | 综合表现 | 主要问题 | 建议 |
|--------|----------|----------|------|
| **Grubhub** | 得分最低（Completeness 61.35，Validity 66.32，Consistency 70.83） | ① Customer ID / Meal Plan ID 空值较多（8.87% / 68.42%） ② 日期格式不统一（MM-DD-YYYY 与 MM/DD/YYYY 混用） ③ Venue 命名不一致（24 种写法归一化后仅 18 种） | 在 staging 层统一日期解析、Venue 归一化；空值按业务规则标注或补全。 |
| **Mashgin** | Uniqueness 仅 53.66，拉低整体 | ① 1,038 行中仅 557 个唯一 transaction_id（481 组重复） ② 9.44% 行为空 venue_name | 明确业务规则：按 transaction_id 去重或保留多行并记录原因；空 venue 在 staging 中标记或排除。 |
| **Stripe** | 各维度均为 100 | ① `created` 为 Unix 秒（需用 TIMESTAMP_SECONDS 转换） | 在模型中统一做时间转换即可。 |
| **Dining Hall** | 各维度均为 100 | 无显著数据质量问题 | 保持监控即可。 |

**整体结论：**  
- 整体数据质量得分 **93.45/100**；Completeness、Validity、Consistency、Uniqueness 受 Grubhub 与 Mashgin 影响。  
- 优先在 staging 处理：**Mashgin 重复键**、**Grubhub 日期与 Venue 一致性**；其余为文档与监控项。

---

### Critical (Must fix immediately)
1. **Mashgin duplicate transaction_id:** 481 duplicate groups (1,038 rows vs 557 unique transactions) — decide business rule: dedupe by transaction_id or keep all rows and document reason.

### High (Fix in staging)
1. **Grubhub venue name inconsistency:** 24 raw names collapse to 18 normalized (e.g. "Subway@North Campus" vs "Subway @ North Campus", "Valley Café" vs "Valley Cafe"). Use normalized venue in staging for joins and reporting.
2. **Grubhub mixed date formats:** MM-DD-YYYY (66.32%) and MM/DD/YYYY (33.68%). Parse and store as single format (e.g. DATE) in staging.

### Medium (Document and handle)
1. **Stripe `created` as Unix seconds:** Stored as 1770103802 / 1770674402 — convert in models with TIMESTAMP_SECONDS(created) for date range and freshness.
2. **Mashgin NULL venue_name:** 9.44% (98 rows). Confirm expected for kiosk data; handle in staging (e.g. 'Unknown' or exclude from venue-level metrics).

### Low (Monitor)
1. **Grubhub NULL Meal Plan ID:** 68.42% — expected for non-meal-plan payments; document and leave as-is.

---

## Data Quality Metrics Summary
*From **Section 7.3** (aggregate %). Run Section 7 in `run_all_profiling.sql` and paste the single-row result here.*

### Completeness / Validity / Consistency (%)
- **Overall Completeness:** 87.98%
- **Overall Validity:** 91.58%
- **Overall Consistency:** 92.71%

### Other metrics (optional; extend Section 7 if needed)
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

1. [x] Review all findings
2. [x] Calculate data quality scores for each dimension (Section 7.1–7.3 已填入)
3. [ ] Prioritize data quality issues
4. [ ] Create staging models to handle issues
5. [ ] Document data transformation rules
6. [ ] Set up automated data quality monitoring
7. [ ] Create data quality dashboard queries

### Missing from current profiling run (to fill by additional queries or later runs)

- **Executive Summary / Scorecard:** Overall and dimension scores (0–100) not calculated; run scoring logic or set manually after review.
- **Grubhub:** Referential integrity (Venue vs location_master); Business rule validation (negative amounts, future dates, amounts > $1000).
- **Mashgin:** Amount analysis (min/max/avg — column may be `amount` or `total`); Time distribution (peak hours); Referential integrity (kiosk_id vs location_master).
- **Stripe:** Metadata analysis (order_id, location_id, customer_id in `data`); Event sequence / multi-event orders; Referential integrity (Stripe order_id vs Grubhub Order ID).
- **Dining Hall:** NULL analysis (Date, Plan ID, Swipes); Referential integrity (Plan ID vs meal_plans); Data completeness (missing dates in 2026-02-03–2026-02-09).
- **Cross-Source:** Data freshness (days behind); Cross-source reconciliation (Grubhub vs Stripe revenue); Daily volume trends.
- **Section 6:** Negative amount check (Grubhub/Mashgin) was in the script but not in the provided results.
