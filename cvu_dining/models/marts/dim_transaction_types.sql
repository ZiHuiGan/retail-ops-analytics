-- models/marts/dim_transaction_types.sql
-- Purpose: Transaction type dimension (from seed)
-- SCD Type: Type 1

WITH source AS (
    
    SELECT * FROM {{ ref('transaction_types') }}

),

final AS (

    SELECT
        transaction_type_id,
        transaction_type_name,
        affects_revenue,
        reverses_transaction,
        requires_approval,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM source

)

SELECT * FROM final