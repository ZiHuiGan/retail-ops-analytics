-- models/marts/dim_payment_methods.sql
-- Purpose: Payment method dimension (from seed)
-- SCD Type: Type 2 (track fee changes)

WITH source AS (
    
    SELECT * FROM {{ ref('payment_methods') }}

),

final AS (

    SELECT
        payment_method_id,
        payment_method_name,
        processor,
        fee_percentage,
        fee_fixed,
        requires_internet,
        is_active,
        effective_from_date,
        effective_to_date,
        is_current,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM source

)

SELECT * FROM final
