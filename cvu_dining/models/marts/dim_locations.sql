-- models/marts/dim_locations.sql
-- Purpose: Location master dimension (from seed)
-- SCD Type: Type 1 (overwrite)

WITH source AS (
    
    SELECT * FROM {{ ref('locations') }}

),

final AS (

    SELECT
        location_id,
        location_name,
        category,
        building,
        floor,
        operating_hours_start,
        operating_hours_end,
        seating_capacity,
        has_wifi,
        profit_center,
        region,
        is_active,
        opened_date,
        closed_date,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM source

)

SELECT * FROM final
