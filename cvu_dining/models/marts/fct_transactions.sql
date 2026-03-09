-- models/marts/fct_transactions.sql
-- Purpose: Unified transaction fact table
-- Grain: One row per line item
-- 埋雷: 只做grubhub，其他sources留Phase 4

WITH grubhub_txns AS (

    SELECT
        -- Transaction keys
        order_id AS transaction_id,
        order_id AS order_id,
        NULL AS kiosk_transaction_id,
        NULL AS payment_intent_id,
        
        -- Date/time foreign keys
        order_date AS transaction_date,
        NULL AS transaction_timestamp,
        NULL AS hour_of_day,
        
        -- Dimension foreign keys
        location_id,
        
        COALESCE(
            TO_HEX(MD5(product_name)),
            'UNKNOWN'
        ) AS product_id,
        
        customer_id,
        meal_plan_id,
        
        -- Payment info (埋雷: payment_method_id需要mapping)
        payment_method AS payment_method_raw,
        'PM-CREDIT' AS payment_method_id,  -- 埋雷: hardcoded
        
        -- Transaction type (埋雷: 都是sale)
        'TXN-SALE' AS transaction_type_id,
        
        -- Measures
        quantity,
        total_amount,
        
        -- Degenerate dimensions
        venue_raw,
        
        -- Source tracking
        source_system,
        _loaded_at
        
    FROM {{ ref('stg_grubhub_sales') }}

),

-- 埋雷: 其他sources commented out
-- mashgin_txns AS (...),
-- stripe_txns AS (...),
-- dining_hall_txns AS (...),

all_transactions AS (

    SELECT * FROM grubhub_txns
    -- UNION ALL
    -- SELECT * FROM mashgin_txns
    -- UNION ALL  
    -- SELECT * FROM stripe_txns
    -- UNION ALL
    -- SELECT * FROM dining_hall_txns

)

SELECT * FROM all_transactions