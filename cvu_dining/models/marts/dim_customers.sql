-- models/marts/dim_customers.sql
-- Purpose: Customer dimension from transactions
-- SCD Type: Type 1 (overwrite)

WITH grubhub_customers AS (

    SELECT
        customer_id,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(total_amount) AS lifetime_value
        
    FROM {{ ref('stg_grubhub_sales') }}
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id

),

final AS (

    SELECT
        customer_id,
        first_order_date,
        last_order_date,
        total_orders,
        ROUND(lifetime_value, 2) AS lifetime_value,
        
        -- Days since last order (no CAST needed - already DATE)
        DATE_DIFF(CURRENT_DATE(), last_order_date, DAY) AS days_since_last_order,
        
        -- Customer segmentation
        CASE
            WHEN DATE_DIFF(CURRENT_DATE(), last_order_date, DAY) > 90
            THEN 'Inactive'
            WHEN total_orders >= 20 THEN 'Frequent'
            WHEN total_orders >= 10 THEN 'Regular'
            ELSE 'Occasional'
        END AS customer_segment,
        
        -- Placeholder attributes
        CAST(NULL AS STRING) AS student_name,
        CAST(NULL AS INT64) AS graduation_year,
        CAST(NULL AS STRING) AS major,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM grubhub_customers

)

SELECT * FROM final