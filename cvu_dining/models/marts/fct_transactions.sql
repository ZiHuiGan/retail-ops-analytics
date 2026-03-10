-- models/marts/fct_transactions.sql
-- Purpose: Unified transaction fact table
-- Grain: One row per line item (Grubhub/Mashgin) or per payment (Stripe) or per swipe (Dining Hall)
-- Modern pattern: Single fact with source_system discriminator; consistent FK and measures for analytics

WITH
-- ---------------------------------------------------------------------------
-- Payment method mapping: raw payment_method (Grubhub) -> dim FK (payment_methods seed)
-- Avoids hardcoded IDs; one place to maintain business logic (Convenience Points = Mobile Pay)
-- ---------------------------------------------------------------------------
grubhub_with_line AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY product_name, quantity
        ) AS line_idx
    FROM {{ ref('stg_grubhub_sales') }}
),

grubhub_txns AS (
    SELECT
        -- One row per line: unique transaction_id per line (line_idx handles duplicate product+qty in same order)
        TO_HEX(MD5(CONCAT(order_id, '|', COALESCE(product_name, ''), '|', CAST(line_idx AS STRING)))) AS transaction_id,
        order_id AS order_id,
        CAST(NULL AS STRING) AS kiosk_transaction_id,
        CAST(NULL AS STRING) AS payment_intent_id,
        order_date AS transaction_date,
        CAST(NULL AS TIMESTAMP) AS transaction_timestamp,
        CAST(NULL AS INT64) AS hour_of_day,
        location_id,
        COALESCE(TO_HEX(MD5(product_name)), 'UNKNOWN') AS product_id,
        customer_id,
        meal_plan_id,
        payment_method AS payment_method_raw,
        CASE
            WHEN LOWER(TRIM(payment_method)) LIKE '%meal plan%' THEN 'PM-MEALPLAN'
            WHEN LOWER(TRIM(payment_method)) LIKE '%convenience%' THEN 'PM-MOBILE'
            WHEN LOWER(TRIM(payment_method)) = 'cash' THEN 'PM-CASH'
            WHEN LOWER(TRIM(payment_method)) LIKE '%dining point%' THEN 'PM-DINING$'
            WHEN LOWER(TRIM(payment_method)) LIKE '%credit%' THEN 'PM-CREDIT'
            ELSE 'PM-CREDIT'
        END AS payment_method_id,
        CASE WHEN total_amount < 0 THEN 'TXN-REFUND' ELSE 'TXN-SALE' END AS transaction_type_id,
        quantity,
        total_amount,
        venue_raw,
        source_system,
        _loaded_at
    FROM grubhub_with_line
),

-- Mashgin: one row per UNNESTed item; transaction_id unique per line (composite hash)
mashgin_txns AS (
    SELECT
        TO_HEX(MD5(CONCAT(CAST(transaction_id AS STRING), COALESCE(product_id, ''), CAST(transaction_date AS STRING)))) AS transaction_id,
        CAST(NULL AS STRING) AS order_id,
        transaction_id AS kiosk_transaction_id,
        CAST(NULL AS STRING) AS payment_intent_id,
        transaction_date,
        transaction_timestamp_est AS transaction_timestamp,
        hour_of_day,
        location_id,
        COALESCE(product_id, 'UNKNOWN') AS product_id,
        CAST(NULL AS STRING) AS customer_id,
        CAST(NULL AS STRING) AS meal_plan_id,
        CAST(NULL AS STRING) AS payment_method_raw,
        'PM-MOBILE' AS payment_method_id,
        'TXN-SALE' AS transaction_type_id,
        1 AS quantity,
        0.0 AS total_amount,
        venue_raw,
        source_system,
        _loaded_at
    FROM {{ ref('stg_mashgin_transactions') }}
),

-- Stripe: one row per succeeded payment_intent; use payment_intent_id as transaction_id
stripe_txns AS (
    SELECT
        payment_intent_id AS transaction_id,
        CAST(NULL AS STRING) AS order_id,
        CAST(NULL AS STRING) AS kiosk_transaction_id,
        payment_intent_id,
        payment_date AS transaction_date,
        payment_timestamp AS transaction_timestamp,
        hour_of_day,
        'UNKNOWN' AS location_id,
        'UNKNOWN' AS product_id,
        CAST(NULL AS STRING) AS customer_id,
        CAST(NULL AS STRING) AS meal_plan_id,
        'card' AS payment_method_raw,
        'PM-CREDIT' AS payment_method_id,
        CASE WHEN amount_usd < 0 THEN 'TXN-REFUND' ELSE 'TXN-SALE' END AS transaction_type_id,
        1 AS quantity,
        amount_usd AS total_amount,
        CAST(NULL AS STRING) AS venue_raw,
        source_system,
        _loaded_at
    FROM {{ ref('stg_stripe_payments') }}
),

-- Dining hall: daily snapshot -> one row per swipe (explode swipe_count via GENERATE_ARRAY + UNNEST)
dining_hall_txns AS (
    SELECT
        TO_HEX(MD5(CONCAT(CAST(swipe_date AS STRING), meal_plan_id, CAST(swipe_idx AS STRING)))) AS transaction_id,
        CAST(NULL AS STRING) AS order_id,
        CAST(NULL AS STRING) AS kiosk_transaction_id,
        CAST(NULL AS STRING) AS payment_intent_id,
        swipe_date AS transaction_date,
        CAST(NULL AS TIMESTAMP) AS transaction_timestamp,
        CAST(NULL AS INT64) AS hour_of_day,
        location_id,
        'UNKNOWN' AS product_id,
        CAST(NULL AS STRING) AS customer_id,
        meal_plan_id,
        CAST(NULL AS STRING) AS payment_method_raw,
        'PM-MEALPLAN' AS payment_method_id,
        'TXN-SALE' AS transaction_type_id,
        1 AS quantity,
        0.0 AS total_amount,
        CAST(NULL AS STRING) AS venue_raw,
        source_system,
        _loaded_at
    FROM {{ ref('stg_dininghall_swipes') }}
    CROSS JOIN UNNEST(GENERATE_ARRAY(1, CAST(swipe_count AS INT64))) AS swipe_idx
),

all_transactions AS (
    SELECT * FROM grubhub_txns
    UNION ALL
    SELECT * FROM mashgin_txns
    UNION ALL
    SELECT * FROM stripe_txns
    UNION ALL
    SELECT * FROM dining_hall_txns
)

SELECT * FROM all_transactions
