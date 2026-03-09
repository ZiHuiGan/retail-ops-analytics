-- models/marts/dim_meal_plans.sql
-- Purpose: Meal plan dimension (from seed)
-- SCD Type: Type 2 (track history with effective dates)

WITH source AS (
    
    SELECT * FROM {{ ref('meal_plans') }}

),

final AS (

    SELECT
        meal_plan_id,
        plan_name,
        dining_hall_swipes,
        dining_dollars,
        convenience_points,
        price_per_semester,
        is_active,
        effective_from_date,
        effective_to_date,
        is_current,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM source

)

SELECT * FROM final
