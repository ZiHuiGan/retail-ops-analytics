-- models/staging/stg_stripe__payments.sql
-- Purpose: Clean Stripe payment event data
-- Issues Fixed:
--   - Convert cents to dollars
--   - Filter to succeeded events only
--   - Extract payment details from STRUCT

WITH source AS (
    
    SELECT
        id,
        type,
        created,
        data
    FROM {{ source('raw_cvu_dining', 'stripe_events_raw') }}

),

succeeded_only AS (

    SELECT
        id AS event_id,
        type AS event_type,
        created,
        data
        
    FROM source
    WHERE type = 'payment_intent.succeeded'

),

cleaned AS (

    SELECT
        event_id,
        event_type,
        
        -- Payment intent details
        data.object.id AS payment_intent_id,
        
        -- Timestamp
        TIMESTAMP_SECONDS(CAST(created AS INT64)) AS payment_timestamp,
        DATE(TIMESTAMP_SECONDS(CAST(created AS INT64))) AS payment_date,
        
        EXTRACT(
            HOUR FROM TIMESTAMP_SECONDS(CAST(created AS INT64))
        ) AS hour_of_day,
        
        -- Amount conversion: cents to dollars
        SAFE_CAST(data.object.amount AS INT64) / 100.0 AS amount_usd,
        
        -- Currency
        data.object.currency AS currency,
        
        -- Source tracking
        'stripe' AS source_system,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM succeeded_only

),

final AS (

    SELECT * FROM cleaned
    WHERE payment_intent_id IS NOT NULL
        AND amount_usd IS NOT NULL
        AND amount_usd > 0

)

SELECT * FROM final