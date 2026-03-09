-- models/staging/stg_dining_hall__swipes.sql
-- Purpose: Clean dining hall daily swipe data
-- Issues Fixed:
--   - Parse date field
--   - Cast swipes to integer
--   - Map to location

WITH source AS (
    
    SELECT
        Date,
        `Plan ID`,
        `Plan Name`,
        Swipes
    FROM {{ source('raw_cvu_dining', 'dining_hall_swipes_raw') }}

),

cleaned AS (

    SELECT
        -- Date
        PARSE_DATE('%Y-%m-%d', Date) AS swipe_date,
        
        -- Meal plan
        `Plan ID` AS meal_plan_id,
        `Plan Name` AS meal_plan_name,
        
        -- Swipe count
        SAFE_CAST(Swipes AS INT64) AS swipe_count,
        
        -- Hard-coded location for dining hall
        'CVU-D001' AS location_id,
        
        -- Source tracking
        'dining_hall' AS source_system,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM source

),

final AS (

    SELECT * FROM cleaned
    WHERE swipe_date IS NOT NULL
        AND meal_plan_id IS NOT NULL
        AND swipe_count IS NOT NULL
        AND swipe_count >= 0

)

SELECT * FROM final
