# Dimensional Model - Entities Definition (Attributes & Measures)

**Project:** Retail Ops Analytics - CVU Dining  
**Author:** Grace Gan  
**Date:** 2026-03-06  
**Methodology:** Kimball Dimensional Modeling + Analytics Engineering Bootcamp  
**Purpose:** Define all dimension and fact tables with complete attribute lists

---

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    DIMENSIONAL MODEL                         │
│                  (marts_cvu_dining)                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  FACT TABLES                     DIMENSION TABLES           │
│  ============                    =================           │
│                                                              │
│  fct_transactions  ──────────→  dim_fiscal_calendar         │
│       ↓                         dim_locations               │
│       │                         dim_products                │
│       │                         dim_customers               │
│       │                         dim_meal_plans              │
│       │                         dim_payment_methods         │
│       │                         dim_time_of_day             │
│       │                         dim_transaction_types       │
│       ↓                                                     │
│  fct_payments (Supporting)                                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🌟 DIMENSION TABLES

### **1. dim_fiscal_calendar** ⭐⭐⭐⭐⭐

**Purpose:** Master calendar with fiscal week logic  
**Type:** Conformed dimension (shared across ALL business processes)  
**Grain:** One row per calendar day  
**SCD Type:** Not applicable (static historical data)  
**Source:** Generated (dbt macro)  
**Estimated Rows:** 730 (2 years)

#### **Attributes**

| # | Column Name | Data Type | Mode | Key | Description | Example |
|---|-------------|-----------|------|-----|-------------|---------|
| 1 | date | DATE | REQUIRED | PK | Calendar date in YYYY-MM-DD | 2026-02-05 |
| 2 | fiscal_week_id | STRING | REQUIRED | | Fiscal week identifier | 2026-W06 |
| 3 | fiscal_week_start_date | DATE | REQUIRED | | Thursday 4:00 AM of week start | 2026-02-06 |
| 4 | fiscal_week_end_date | DATE | REQUIRED | | Wednesday 3:59 AM of week end | 2026-02-13 |
| 5 | fiscal_year | INTEGER | REQUIRED | | Fiscal year | 2026 |
| 6 | fiscal_quarter | STRING | REQUIRED | | Fiscal quarter | Q1 |
| 7 | week_number | INTEGER | REQUIRED | | Week number in year (1-52) | 6 |
| 8 | day_of_week | STRING | REQUIRED | | Day name | Wednesday |
| 9 | day_of_week_num | INTEGER | REQUIRED | | Day number (1=Mon, 7=Sun) | 3 |
| 10 | is_weekend | BOOLEAN | REQUIRED | | Weekend flag | FALSE |
| 11 | is_holiday | BOOLEAN | REQUIRED | | Holiday flag (US holidays) | FALSE |
| 12 | holiday_name | STRING | NULLABLE | | Holiday name if applicable | NULL |
| 13 | month_name | STRING | REQUIRED | | Month name | February |
| 14 | month_number | INTEGER | REQUIRED | | Month number (1-12) | 2 |
| 15 | quarter | STRING | REQUIRED | | Calendar quarter | Q1 |
| 16 | year | INTEGER | REQUIRED | | Calendar year | 2026 |
| 17 | is_current_day | BOOLEAN | REQUIRED | | Is today flag | FALSE |
| 18 | is_current_week | BOOLEAN | REQUIRED | | Is current fiscal week | FALSE |

**Special Business Rule:**
```sql
-- Fiscal week starts Thursday 4:00 AM
-- Why: Wednesday night is peak dining time for student events
-- Finance wants Wed night revenue in same week for clean reporting
```

**dbt Macro Reference:**
```sql
{{ calculate_fiscal_week(date_column) }}
```

---

### **2. dim_locations** ⭐⭐⭐⭐

**Purpose:** Physical dining locations (retail, kiosks, dining halls)  
**Type:** Conformed dimension  
**Grain:** One row per physical location  
**SCD Type:** Type 1 (overwrite changes)  
**Source:** Seed file (`seeds/locations.csv`)  
**Estimated Rows:** 14

#### **Attributes**

| # | Column Name | Data Type | Mode | Key | Description | Example |
|---|-------------|-----------|------|-----|-------------|---------|
| 1 | location_id | STRING | REQUIRED | PK | Unique location identifier | CVU-R001 |
| 2 | location_name | STRING | REQUIRED | | Official location name | Starbucks Student Center |
| 3 | category | STRING | REQUIRED | | Location type | Retail |
| 4 | building | STRING | REQUIRED | | Building name | Student Center |
| 5 | floor | INTEGER | NULLABLE | | Floor number | 1 |
| 6 | operating_hours_start | TIME | REQUIRED | | Opening time | 07:00:00 |
| 7 | operating_hours_end | TIME | REQUIRED | | Closing time | 23:00:00 |
| 8 | seating_capacity | INTEGER | NULLABLE | | Number of seats | 45 |
| 9 | has_wifi | BOOLEAN | REQUIRED | | WiFi availability | TRUE |
| 10 | profit_center | STRING | REQUIRED | | Accounting code | PC-001 |
| 11 | region | STRING | REQUIRED | | Campus region | Central |
| 12 | is_active | BOOLEAN | REQUIRED | | Currently operating | TRUE |
| 13 | opened_date | DATE | NULLABLE | | Date opened | 2020-08-15 |
| 14 | closed_date | DATE | NULLABLE | | Date closed (if applicable) | NULL |

**Location ID Format:**
- `CVU-R###` - Retail locations (R001-R008)
- `CVU-K###` - Kiosk locations (K001-K003)
- `CVU-D###` - Dining Hall locations (D001-D003)

**Category Values:**
- Retail
- Kiosk
- Dining Hall

**Mapping Logic (from raw data):**
```sql
-- Grubhub venue name → location_id mapping
CASE
  WHEN LOWER(Venue) LIKE '%starbucks%student%' THEN 'CVU-R001'
  WHEN LOWER(Venue) LIKE '%panda%valley%' THEN 'CVU-R002'
  WHEN LOWER(Venue) LIKE '%chipotle%' THEN 'CVU-R003'
  -- ... etc
END

-- Mashgin kiosk_id → location_id mapping (via seed file)
-- kiosk_id=1 → CVU-K001
```

---

### **3. dim_products** ⭐⭐⭐

**Purpose:** Items available for purchase  
**Type:** Conformed dimension  
**Grain:** One row per product SKU  
**SCD Type:** Type 2 (track price history)  
**Source:** Derived from transaction data + seed file  
**Estimated Rows:** 200

#### **Attributes**

| # | Column Name | Data Type | Mode | Key | Description | Example |
|---|-------------|-----------|------|-----|-------------|---------|
| 1 | product_key | STRING | REQUIRED | PK | Surrogate key | PRD-00001 |
| 2 | product_id | STRING | REQUIRED | NK | Natural key from source | SKU-12345 |
| 3 | product_name | STRING | REQUIRED | | Product description | Grande Latte |
| 4 | category | STRING | REQUIRED | | Product category | Beverages |
| 5 | subcategory | STRING | NULLABLE | | Product subcategory | Hot Drinks |
| 6 | unit_price | DECIMAL(10,2) | REQUIRED | | Current unit price | 4.95 |
| 7 | cost | DECIMAL(10,2) | NULLABLE | | Cost of goods sold | 1.50 |
| 8 | brand | STRING | NULLABLE | | Brand name | Starbucks |
| 9 | vendor | STRING | NULLABLE | | Supplier name | Starbucks Corp |
| 10 | is_meal_plan_eligible | BOOLEAN | REQUIRED | | Can be purchased with meal plan | TRUE |
| 11 | is_active | BOOLEAN | REQUIRED | | Currently available | TRUE |
| 12 | effective_from_date | DATE | REQUIRED | | Start of this version | 2026-01-01 |
| 13 | effective_to_date | DATE | NULLABLE | | End of this version | NULL |
| 14 | is_current | BOOLEAN | REQUIRED | | Latest version flag | TRUE |

**Product Categories:**
- Beverages (Hot Drinks, Cold Drinks, Specialty)
- Food (Sandwiches, Salads, Snacks, Bakery)
- Groceries (Packaged Goods, Fresh Produce)

**SCD Type 2 Example:**
```
product_id | product_name | unit_price | effective_from | effective_to | is_current
SKU-12345  | Grande Latte | 4.50       | 2025-08-01     | 2025-12-31   | FALSE
SKU-12345  | Grande Latte | 4.95       | 2026-01-01     | NULL         | TRUE
```

**Sources:**
- Grubhub: `Product Name` column
- Mashgin: `items.product_name` array

---

### **4. dim_customers** ⭐⭐⭐

**Purpose:** Student, staff, and guest customers  
**Type:** Conformed dimension  
**Grain:** One row per customer  
**SCD Type:** Type 1 (current state only)  
**Source:** Derived from Grubhub + Stripe  
**Estimated Rows:** 15,000

#### **Attributes**

| # | Column Name | Data Type | Mode | Key | Description | Example |
|---|-------------|-----------|------|-----|-------------|---------|
| 1 | customer_id | STRING | REQUIRED | PK | Customer identifier | CUST-12345 |
| 2 | customer_type | STRING | REQUIRED | | Customer classification | Student |
| 3 | first_seen_date | DATE | REQUIRED | | First transaction date | 2025-09-01 |
| 4 | last_seen_date | DATE | REQUIRED | | Most recent transaction | 2026-02-09 |
| 5 | total_transactions | INTEGER | REQUIRED | | Lifetime transaction count | 45 |
| 6 | total_lifetime_value | DECIMAL(10,2) | REQUIRED | | Total $ spent lifetime | 523.40 |
| 7 | preferred_location_id | STRING | NULLABLE | FK | Most frequented location | CVU-R001 |
| 8 | preferred_payment_method | STRING | NULLABLE | | Most used payment type | Meal Plan |
| 9 | has_meal_plan | BOOLEAN | REQUIRED | | Currently has meal plan | TRUE |
| 10 | is_active | BOOLEAN | REQUIRED | | Active in last 30 days | TRUE |
| 11 | enrollment_status | STRING | NULLABLE | | For students: Freshman/etc | Sophomore |
| 12 | graduation_year | INTEGER | NULLABLE | | Expected graduation | 2028 |

**Customer Type Values:**
- Student
- Staff
- Faculty
- Guest

**NULL Handling:**
- 15% of Grubhub transactions have NULL customer_id (cash/guest)
- These transactions excluded from customer dimension
- Or: create synthetic customer_id = 'GUEST-{order_id}'

---

### **5. dim_meal_plans** ⭐⭐⭐

**Purpose:** Meal plan types and pricing  
**Type:** Conformed dimension  
**Grain:** One row per meal plan type  
**SCD Type:** Type 2 (track pricing changes)  
**Source:** Seed file (`seeds/meal_plans.csv`)  
**Estimated Rows:** 7

#### **Attributes**

| # | Column Name | Data Type | Mode | Key | Description | Example |
|---|-------------|-----------|------|-----|-------------|---------|
| 1 | meal_plan_key | STRING | REQUIRED | PK | Surrogate key | MP-00001 |
| 2 | meal_plan_id | STRING | REQUIRED | NK | Natural key | MP-UNLIMITED |
| 3 | plan_name | STRING | REQUIRED | | Plan description | Unlimited Dining |
| 4 | dining_hall_swipes | INTEGER | NULLABLE | | Swipes per semester | NULL (unlimited) |
| 5 | dining_dollars | DECIMAL(10,2) | REQUIRED | | $ for dining halls | 0.00 |
| 6 | convenience_points | DECIMAL(10,2) | REQUIRED | | $ for retail locations | 100.00 |
| 7 | price_per_semester | DECIMAL(10,2) | REQUIRED | | Total cost | 2,500.00 |
| 8 | is_active | BOOLEAN | REQUIRED | | Currently offered | TRUE |
| 9 | effective_from_date | DATE | REQUIRED | | Start of this version | 2025-08-01 |
| 10 | effective_to_date | DATE | NULLABLE | | End of this version | NULL |
| 11 | is_current | BOOLEAN | REQUIRED | | Latest version flag | TRUE |

**Meal Plan Types:**

| meal_plan_id | plan_name | swipes | dining_$ | convenience_$ | semester_price |
|--------------|-----------|--------|----------|---------------|----------------|
| MP-UNLIMITED | Unlimited Dining | NULL | $0 | $100 | $2,500 |
| MP-200 | 200 Meals | 200 | $0 | $0 | $2,000 |
| MP-150-500 | 150 Meals + $500 | 150 | $0 | $500 | $2,200 |
| MP-COMMUTER | Commuter Plan | 50 | $200 | $300 | $1,000 |
| ... | ... | ... | ... | ... | ... |

---

### **6. dim_payment_methods** ⭐⭐

**Purpose:** Payment types and fees  
**Type:** Conformed dimension  
**Grain:** One row per payment method  
**SCD Type:** Type 2 (track fee changes)  
**Source:** Seed file + derived  
**Estimated Rows:** 4-5

#### **Attributes**

| # | Column Name | Data Type | Mode | Key | Description | Example |
|---|-------------|-----------|------|-----|-------------|---------|
| 1 | payment_method_id | STRING | REQUIRED | PK | Payment method identifier | PM-CREDIT |
| 2 | payment_method_name | STRING | REQUIRED | | Method description | Credit Card |
| 3 | processor | STRING | REQUIRED | | Payment processor | Stripe |
| 4 | fee_percentage | DECIMAL(5,2) | REQUIRED | | Processing fee % | 2.90 |
| 5 | fee_fixed | DECIMAL(10,2) | REQUIRED | | Fixed fee per transaction | 0.30 |
| 6 | requires_internet | BOOLEAN | REQUIRED | | Needs connectivity | TRUE |
| 7 | is_active | BOOLEAN | REQUIRED | | Currently accepted | TRUE |
| 8 | effective_from_date | DATE | REQUIRED | | Start of this version | 2025-08-01 |
| 9 | effective_to_date | DATE | NULLABLE | | End of this version | NULL |
| 10 | is_current | BOOLEAN | REQUIRED | | Latest version flag | TRUE |

**Payment Methods:**

| payment_method_id | name | processor | fee_% | fee_$ | internet |
|-------------------|------|-----------|-------|-------|----------|
| PM-CREDIT | Credit Card | Stripe | 2.90% | $0.30 | TRUE |
| PM-MEALPLAN | Meal Plan | Internal | 0.00% | $0.00 | FALSE |
| PM-DINING$ | Dining Dollars | Internal | 0.00% | $0.00 | FALSE |
| PM-CASH | Cash | Cash Register | 0.00% | $0.00 | FALSE |
| PM-MOBILE | Mobile Pay | Stripe | 2.90% | $0.30 | TRUE |

---

### **7. dim_time_of_day** ⭐⭐

**Purpose:** Hour-based time analysis  
**Type:** Conformed dimension  
**Grain:** One row per hour  
**SCD Type:** Not applicable (static)  
**Source:** Generated  
**Estimated Rows:** 24

#### **Attributes**

| # | Column Name | Data Type | Mode | Key | Description | Example |
|---|-------------|-----------|------|-----|-------------|---------|
| 1 | hour_of_day | INTEGER | REQUIRED | PK | Hour (0-23) | 12 |
| 2 | hour_12h | STRING | REQUIRED | | 12-hour format | 12 PM |
| 3 | time_period | STRING | REQUIRED | | Meal period | Lunch |
| 4 | is_peak_hour | BOOLEAN | REQUIRED | | High traffic flag | TRUE |
| 5 | is_operating_hour | BOOLEAN | REQUIRED | | Dining services open | TRUE |

**Time Periods:**
- Breakfast: 6:00-10:59
- Lunch: 11:00-14:59
- Dinner: 17:00-20:59
- Late Night: 21:00-01:59
- Off Hours: 02:00-05:59

**Peak Hours:**
- 11:00-13:00 (Lunch rush)
- 17:00-19:00 (Dinner rush)

---

### **8. dim_transaction_types** ⭐

**Purpose:** Transaction classification  
**Type:** Degenerate dimension (could be in fact table)  
**Grain:** One row per transaction type  
**SCD Type:** Not applicable (static)  
**Source:** Seed file  
**Estimated Rows:** 4

#### **Attributes**

| # | Column Name | Data Type | Mode | Key | Description | Example |
|---|-------------|-----------|------|-----|-------------|---------|
| 1 | transaction_type_id | STRING | REQUIRED | PK | Transaction type code | TXN-SALE |
| 2 | transaction_type_name | STRING | REQUIRED | | Type description | Sale |
| 3 | affects_revenue | BOOLEAN | REQUIRED | | Impacts revenue flag | TRUE |
| 4 | reverses_transaction | BOOLEAN | REQUIRED | | Is reversal flag | FALSE |
| 5 | requires_approval | BOOLEAN | REQUIRED | | Needs manager approval | FALSE |

**Transaction Types:**

| type_id | name | revenue | reversal | approval |
|---------|------|---------|----------|----------|
| TXN-SALE | Sale | TRUE | FALSE | FALSE |
| TXN-REFUND | Refund | TRUE (negative) | TRUE | TRUE |
| TXN-VOID | Void | FALSE | TRUE | TRUE |
| TXN-COMP | Complimentary | FALSE | FALSE | TRUE |

---

## 📦 FACT TABLES

### **9. fct_transactions** ⭐⭐⭐⭐⭐

**Purpose:** Primary business fact - all dining transactions  
**Type:** Transaction fact table  
**Grain:** One row per line item in an order  
**Source:** Unified from Grubhub + Mashgin + Dining Hall  
**Estimated Rows:** ~100,000/year

#### **Keys & Dimensions**

| # | Column Name | Data Type | Mode | Key | Description |
|---|-------------|-----------|------|-----|-------------|
| 1 | transaction_key | STRING | REQUIRED | PK | Surrogate key (UUID) |
| 2 | transaction_id | STRING | REQUIRED | DD | Transaction ID from source |
| 3 | order_id | STRING | NULLABLE | DD | Order ID (Grubhub only) |
| 4 | line_number | INTEGER | NULLABLE | | Line item sequence |
| 5 | source_system | STRING | REQUIRED | | Data source (grubhub/mashgin/dining_hall) |
| 6 | date | DATE | REQUIRED | FK | → dim_fiscal_calendar |
| 7 | fiscal_week_id | STRING | REQUIRED | FK | → dim_fiscal_calendar |
| 8 | time_of_day | INTEGER | NULLABLE | FK | → dim_time_of_day |
| 9 | location_id | STRING | REQUIRED | FK | → dim_locations |
| 10 | product_key | STRING | NULLABLE | FK | → dim_products |
| 11 | customer_id | STRING | NULLABLE | FK | → dim_customers |
| 12 | meal_plan_key | STRING | NULLABLE | FK | → dim_meal_plans |
| 13 | payment_method_id | STRING | NULLABLE | FK | → dim_payment_methods |
| 14 | transaction_type_id | STRING | REQUIRED | FK | → dim_transaction_types |

**DD = Degenerate Dimension** (ID stored in fact, no separate dimension table)

#### **Measures (Facts)**

| # | Column Name | Data Type | Mode | Description | Aggregation |
|---|-------------|-----------|------|-------------|-------------|
| 15 | quantity | INTEGER | REQUIRED | Number of items | SUM |
| 16 | unit_price | DECIMAL(10,2) | REQUIRED | Price per item | AVG |
| 17 | subtotal | DECIMAL(10,2) | REQUIRED | Before tax | SUM |
| 18 | tax_amount | DECIMAL(10,2) | REQUIRED | Sales tax | SUM |
| 19 | discount_amount | DECIMAL(10,2) | REQUIRED | Discounts applied | SUM |
| 20 | total_amount | DECIMAL(10,2) | REQUIRED | Final amount | SUM |
| 21 | cost_of_goods | DECIMAL(10,2) | NULLABLE | COGS | SUM |
| 22 | gross_profit | DECIMAL(10,2) | NULLABLE | total - COGS | SUM |

#### **Audit Columns**

| # | Column Name | Data Type | Mode | Description |
|---|-------------|-----------|------|-------------|
| 23 | transaction_timestamp | TIMESTAMP | REQUIRED | Exact time of transaction |
| 24 | created_at | TIMESTAMP | REQUIRED | When record created in DW |
| 25 | updated_at | TIMESTAMP | REQUIRED | When record last updated |
| 26 | dbt_updated_at | TIMESTAMP | REQUIRED | dbt run timestamp |

#### **Granularity Examples**

**Grubhub (line item level):**
```
Order ABC-123 with 2 items:
  - Row 1: Grande Latte, qty=1, $4.95
  - Row 2: Croissant, qty=2, $3.50
= 2 rows in fct_transactions
```

**Mashgin (transaction level):**
```
Transaction MASH-456 with 3 items in one scan:
  - Bottled Water, Chips, Candy Bar
= 3 rows in fct_transactions (UNNEST items array)
```

**Dining Hall (aggregated daily level):**
```
Meal Plan MP-200 had 15 swipes on 2026-02-05:
  - Row 1: 15 swipes, $0 revenue
= 1 row in fct_transactions
```

---

### **10. fct_payments** ⭐⭐⭐

**Purpose:** Supporting fact for payment reconciliation  
**Type:** Transaction fact table  
**Grain:** One row per payment event  
**Source:** Stripe webhook events  
**Estimated Rows:** ~6,000/year

#### **Keys & Dimensions**

| # | Column Name | Data Type | Mode | Key | Description |
|---|-------------|-----------|------|-----|-------------|
| 1 | payment_key | STRING | REQUIRED | PK | Surrogate key |
| 2 | payment_intent_id | STRING | REQUIRED | DD | Stripe payment intent ID |
| 3 | event_id | STRING | REQUIRED | DD | Stripe event ID |
| 4 | event_type | STRING | REQUIRED | | payment_intent.succeeded, etc |
| 5 | date | DATE | REQUIRED | FK | → dim_fiscal_calendar |
| 6 | fiscal_week_id | STRING | REQUIRED | FK | → dim_fiscal_calendar |
| 7 | time_of_day | INTEGER | REQUIRED | FK | → dim_time_of_day |
| 8 | customer_id | STRING | NULLABLE | FK | → dim_customers |
| 9 | payment_method_id | STRING | REQUIRED | FK | → dim_payment_methods |

#### **Measures**

| # | Column Name | Data Type | Mode | Description | Aggregation |
|---|-------------|-----------|------|-------------|-------------|
| 10 | amount_usd | DECIMAL(10,2) | REQUIRED | Payment amount | SUM |
| 11 | stripe_fee_usd | DECIMAL(10,2) | REQUIRED | Processing fee | SUM |
| 12 | net_amount_usd | DECIMAL(10,2) | REQUIRED | Amount - fee | SUM |
| 13 | currency | STRING | REQUIRED | Currency code (USD) | - |

#### **Audit Columns**

| # | Column Name | Data Type | Mode | Description |
|---|-------------|-----------|------|-------------|
| 14 | payment_created_at | TIMESTAMP | REQUIRED | When payment initiated |
| 15 | payment_succeeded_at | TIMESTAMP | NULLABLE | When payment succeeded |
| 16 | created_at | TIMESTAMP | REQUIRED | DW record created |
| 17 | dbt_updated_at | TIMESTAMP | REQUIRED | dbt run timestamp |

#### **Relationship to fct_transactions**

```sql
-- fct_payments is SUPPORTING fact for fct_transactions
-- NOT all transactions have payments (cash, meal plan)

-- Reconciliation query:
SELECT 
  t.date,
  SUM(CASE WHEN t.payment_method_id = 'PM-CREDIT' THEN t.total_amount END) as grubhub_credit_total,
  SUM(p.amount_usd) as stripe_total,
  SUM(CASE WHEN t.payment_method_id = 'PM-CREDIT' THEN t.total_amount END) - SUM(p.amount_usd) as variance
FROM fct_transactions t
LEFT JOIN fct_payments p 
  ON t.date = p.date 
  AND t.customer_id = p.customer_id
GROUP BY t.date
HAVING ABS(variance) > 0.01;  -- Flag discrepancies
```

---

## 📋 DETAILED BUS MATRIX (Professional Format)

Following Analytics Engineering Bootcamp methodology:

| Business Process | Fact Table | Fact Type | Granularity | Facts (Measures) | dim_fiscal_calendar | dim_locations | dim_products | dim_customers | dim_meal_plans | dim_payment_methods | dim_time_of_day | dim_transaction_types | Priority |
|------------------|------------|-----------|-------------|------------------|---------------------|---------------|--------------|---------------|----------------|---------------------|-----------------|----------------------|----------|
| **Retail Sales (Grubhub)** | fct_transactions | Transaction | One row per line item in order | quantity, unit_price, subtotal, tax, total, COGS, profit | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **HIGH** |
| **Kiosk Sales (Mashgin)** | fct_transactions | Transaction | One row per product in transaction | quantity, unit_price, total | ✓ | ✓ | ✓ | - | - | - | ✓ | ✓ | **HIGH** |
| **Dining Hall Swipes** | fct_transactions | Daily Snapshot | One row per meal plan per day | swipe_count | ✓ | ✓ | - | - | ✓ | - | - | ✓ | **MEDIUM** |
| **Payment Processing** | fct_payments | Transaction | One row per payment event | amount, stripe_fee, net_amount | ✓ | - | - | ✓ | - | ✓ | ✓ | - | **HIGH** |

---

## 🔗 Entity Relationships

```
                dim_fiscal_calendar (PK: date)
                         ↓
                    ┌────┴────┐
                    ↓         ↓
          fct_transactions  fct_payments
          (FK: date)        (FK: date)
                ↓
        ┌───────┼───────┬─────────┬──────────┬────────────┬──────────┬─────────┐
        ↓       ↓       ↓         ↓          ↓            ↓          ↓         ↓
   dim_locations  dim_products  dim_customers  dim_meal_plans  dim_payment_methods  dim_time_of_day  dim_transaction_types
   (PK: location_id)  (PK: product_key)  (PK: customer_id)  (PK: meal_plan_key)  (PK: payment_method_id)  (PK: hour_of_day)  (PK: transaction_type_id)
```

---

## 📐 Source-to-Target Mapping Summary

### **Raw → Staging**

| Source | Staging Table | Key Transformations |
|--------|---------------|---------------------|
| grubhub_sales_raw | stg_grubhub__sales | Date parsing, venue mapping, currency cleaning |
| mashgin_transactions_raw | stg_mashgin__transactions | UTC→EST conversion, UNNEST items, kiosk mapping |
| dining_hall_swipes_raw | stg_dining_hall__swipes | Add fiscal week, location mapping |
| stripe_events_raw | stg_stripe__payments | Cents→dollars, deduplicate events |

### **Staging → Warehouse (Dimensions)**

| Staging Source | Dimension Table | Logic |
|----------------|-----------------|-------|
| N/A (generated) | dim_fiscal_calendar | Generate 2 years, apply Thursday 4am logic |
| seeds/locations.csv | dim_locations | Direct load |
| stg_grubhub__sales, stg_mashgin__transactions | dim_products | UNION ALL → dedupe → SCD Type 2 |
| stg_grubhub__sales | dim_customers | Aggregate customer metrics |
| seeds/meal_plans.csv | dim_meal_plans | Direct load with SCD Type 2 |
| seeds/payment_methods.csv | dim_payment_methods | Direct load with SCD Type 2 |
| N/A (generated) | dim_time_of_day | Generate 24 hours |
| seeds/transaction_types.csv | dim_transaction_types | Direct load |

### **Staging → Warehouse (Facts)**

| Staging Source | Fact Table | Grain |
|----------------|------------|-------|
| stg_grubhub__sales | fct_transactions | Line item |
| stg_mashgin__transactions | fct_transactions | Product (UNNEST) |
| stg_dining_hall__swipes | fct_transactions | Daily aggregate |
| stg_stripe__payments | fct_payments | Payment event |

---

## ✅ Implementation Checklist

### **Phase 1: Seed Files (Day 3)**
- [ ] Create `seeds/locations.csv` (14 rows)
- [ ] Create `seeds/meal_plans.csv` (7 rows)
- [ ] Create `seeds/payment_methods.csv` (5 rows)
- [ ] Create `seeds/transaction_types.csv` (4 rows)
- [ ] Create `seeds/kiosk_locations.csv` (3 rows for Mashgin mapping)

### **Phase 2: Generated Dimensions (Day 4)**
- [ ] Create dbt macro `calculate_fiscal_week()`
- [ ] Generate `dim_fiscal_calendar` (730 rows)
- [ ] Generate `dim_time_of_day` (24 rows)

### **Phase 3: Derived Dimensions (Day 5)**
- [ ] Build `dim_locations` from seed + validation
- [ ] Build `dim_products` with SCD Type 2
- [ ] Build `dim_customers` with aggregations
- [ ] Build `dim_meal_plans` from seed + SCD Type 2
- [ ] Build `dim_payment_methods` from seed + SCD Type 2
- [ ] Build `dim_transaction_types` from seed

### **Phase 4: Fact Tables (Day 6-7)**
- [ ] Build `fct_transactions` unified model
- [ ] Build `fct_payments` from Stripe
- [ ] Add FK tests
- [ ] Add measure tests (totals, non-negative)

### **Phase 5: Analytics Layer (Day 8-9)**
- [ ] Build `fct_daily_revenue` (aggregated fact)
- [ ] Build One Big Table (OBT) for BI tools
- [ ] Create sample dashboard queries

---

## 📝 Notes for Interviews

**Key Talking Points:**

1. **"I designed a comprehensive dimensional model with 8 dimensions and 2 fact tables"**
   - 8 dimensions: fiscal_calendar, locations, products, customers, meal_plans, payment_methods, time_of_day, transaction_types
   - 2 facts: transactions (primary), payments (supporting)

2. **"Implemented Kimball conformed dimensions for cross-process analysis"**
   - dim_fiscal_calendar: 100% coverage (all processes)
   - dim_locations: 75% coverage (retail, kiosk, dining hall)
   - Ensures consistent metrics across business processes

3. **"Applied SCD Type 2 for slowly changing dimensions to track historical changes"**
   - dim_products: Track price history
   - dim_meal_plans: Track pricing changes
   - dim_payment_methods: Track fee changes

4. **"Handled varying granularities in unified fact table"**
   - Grubhub: Line item level
   - Mashgin: Product level (UNNEST from array)
   - Dining Hall: Daily aggregate level
   - Maintained grain consistency through clear documentation

5. **"Created supporting fact table pattern for financial reconciliation"**
   - fct_payments validates fct_transactions
   - Enables variance analysis (Grubhub vs Stripe)
   - Separate tables due to different grain and purpose

---

**End of ENTITIES.md**
