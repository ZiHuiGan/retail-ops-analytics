-- models/marts/dim_products.sql
-- Purpose: Product master from transactions
-- SCD Type: Type 2 (track price changes)
-- Sources: Grubhub (product_name → hash id), Mashgin (product_id from kiosk)

WITH grubhub_products AS (

    SELECT
        TO_HEX(MD5(product_name)) AS product_id,
        product_name,
        'grubhub' AS source_system
    FROM {{ ref('stg_grubhub_sales') }}
    WHERE product_name IS NOT NULL

),

mashgin_products AS (

    SELECT
        COALESCE(CAST(product_id AS STRING), TO_HEX(MD5(product_name))) AS product_id,
        product_name,
        'mashgin' AS source_system
    FROM {{ ref('stg_mashgin_transactions') }}
    WHERE product_name IS NOT NULL OR product_id IS NOT NULL

),

all_products AS (

    SELECT * FROM grubhub_products
    UNION ALL
    SELECT * FROM mashgin_products

),

-- Dedupe by product_id (same product from two sources → one row; take arbitrary name/source)
deduped AS (

    SELECT
        product_id,
        MAX(product_name) AS product_name,
        MAX(source_system) AS source_system
    FROM all_products
    GROUP BY product_id

),

with_ids AS (

    SELECT
        product_id,
        product_name,
        source_system,
        NULL AS category,
        NULL AS subcategory,
        NULL AS current_price,
        CURRENT_DATE() AS effective_from_date,
        CAST(NULL AS DATE) AS effective_to_date,
        TRUE AS is_current,
        CURRENT_TIMESTAMP() AS _loaded_at
    FROM deduped

)

SELECT * FROM with_ids