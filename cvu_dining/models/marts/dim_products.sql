-- models/marts/dim_products.sql
-- Purpose: Product master from transactions
-- SCD Type: Type 2 (track price changes)
-- 埋雷: 只从grubhub提取，mashgin留给Phase 4

WITH grubhub_products AS (

    SELECT DISTINCT
        product_name,
        'grubhub' AS source_system
    FROM {{ ref('stg_grubhub_sales') }}
    WHERE product_name IS NOT NULL

),

-- 埋雷: mashgin products commented out
-- mashgin_products AS (
--     SELECT DISTINCT
--         product_name,
--         'mashgin' AS source_system
--     FROM {{ ref('stg_mashgin_transactions') }}
--     WHERE product_name IS NOT NULL
-- ),

all_products AS (

    SELECT * FROM grubhub_products
    -- UNION ALL
    -- SELECT * FROM mashgin_products

),

with_ids AS (

    SELECT
        -- Generate surrogate key (埋雷: 简单hash，未来改成真正的SK)
        TO_HEX(MD5(product_name)) AS product_id,
        
        product_name,
        source_system,
        
        -- Placeholder attributes (埋雷: 未来从product master填充)
        NULL AS category,
        NULL AS subcategory,
        NULL AS current_price,
        
        -- SCD Type 2 fields
        CURRENT_DATE() AS effective_from_date,
        CAST(NULL AS DATE) AS effective_to_date,
        TRUE AS is_current,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM all_products

)

SELECT * FROM with_ids