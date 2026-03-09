-- models/staging/stg_grubhub__sales.sql
-- Purpose: Clean and standardize Grubhub retail transaction data
-- Issues Fixed:
--   - Parse 3 different date formats
--   - Map venue names to location_id
--   - Clean currency formatting
--   - Handle NULL customer_id and meal_plan_id

WITH source AS (
    
    SELECT
        `Order ID`,
        `Order Date`,
        Venue,
        `Product Name`,
        Quantity,
        Total,
        `Customer ID`,
        `Meal Plan ID`,
        `Payment Method`
    FROM {{ source('raw_cvu_dining', 'grubhub_sales_raw') }}

),

cleaned AS (

    SELECT
        -- Primary key
        `Order ID` AS order_id,
        
        -- Date parsing - handles 3 formats
        CASE 
            WHEN `Order Date` LIKE '%/%' THEN 
                PARSE_DATE('%m/%d/%Y', `Order Date`)
            WHEN `Order Date` LIKE '%-%' 
                AND LENGTH(`Order Date`) = 10 THEN
                PARSE_DATE('%m-%d-%Y', `Order Date`)
            ELSE 
                PARSE_DATE('%Y-%m-%d', `Order Date`)
        END AS order_date,
        
        -- Location mapping
        CASE
            WHEN LOWER(Venue) LIKE '%starbucks%student%' 
                THEN 'CVU-R001'
            WHEN LOWER(Venue) LIKE '%panda%valley%' 
                THEN 'CVU-R002'
            WHEN LOWER(Venue) LIKE '%chipotle%' 
                THEN 'CVU-R003'
            WHEN LOWER(Venue) LIKE '%subway%' 
                THEN 'CVU-R004'
            WHEN LOWER(Venue) LIKE '%taco%bell%' 
                THEN 'CVU-R005'
            WHEN LOWER(Venue) LIKE '%late%night%north%' 
                THEN 'CVU-R006'
            WHEN LOWER(Venue) LIKE '%campus%cafe%' 
                THEN 'CVU-R007'
            WHEN LOWER(Venue) LIKE '%pizza%' 
                THEN 'CVU-R008'
            ELSE 'UNKNOWN'
        END AS location_id,
        
        Venue AS venue_raw,
        
        -- Product information
        `Product Name` AS product_name,
        SAFE_CAST(Quantity AS INT64) AS quantity,
        
        -- Amount cleaning
        SAFE_CAST(
            REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64
        ) AS total_amount,
        
        -- Customer information
        NULLIF(`Customer ID`, '') AS customer_id,
        NULLIF(`Meal Plan ID`, '') AS meal_plan_id,
        
        -- Payment method
        `Payment Method` AS payment_method,
        
        -- Source tracking
        'grubhub' AS source_system,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM source

),

final AS (

    SELECT * FROM cleaned
    WHERE order_id IS NOT NULL
        AND order_date IS NOT NULL
        AND total_amount IS NOT NULL
        AND total_amount >= 0

)

SELECT * FROM final;