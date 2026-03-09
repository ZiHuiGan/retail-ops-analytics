-- models/staging/stg_mashgin__transactions.sql
-- Purpose: Clean Mashgin kiosk transaction data
-- Issues Fixed:
--   - Convert UTC timestamps to EST
--   - UNNEST items array to product level
--   - Map kiosk_id to location_id

WITH source AS (
    
    SELECT
        transaction_id,
        kiosk_id,
        timestamp,
        venue_name,
        items
    FROM {{ source('raw_cvu_dining', 'mashgin_transactions_raw') }}

),

timezone_converted AS (

    SELECT
        transaction_id,
        kiosk_id,
        
        -- UTC to EST conversion (-5 hours)
        TIMESTAMP_SUB(
            CAST(timestamp AS TIMESTAMP), 
            INTERVAL 5 HOUR
        ) AS transaction_timestamp_est,
        
        DATE(
            TIMESTAMP_SUB(
                CAST(timestamp AS TIMESTAMP), 
                INTERVAL 5 HOUR
            )
        ) AS transaction_date,
        
        EXTRACT(
            HOUR FROM TIMESTAMP_SUB(
                CAST(timestamp AS TIMESTAMP), 
                INTERVAL 5 HOUR
            )
        ) AS hour_of_day,
        
        venue_name,
        items
        
    FROM source

),

items_unnested AS (

    SELECT
        transaction_id,
        kiosk_id,
        transaction_timestamp_est,
        transaction_date,
        hour_of_day,
        venue_name,
        
        -- UNNEST items array
        item.product_id,
        item.product_name
        
    FROM timezone_converted,
    UNNEST(items) AS item

),

location_mapped AS (

    SELECT
        t.transaction_id,
        t.kiosk_id,
        t.transaction_timestamp_est,
        t.transaction_date,
        t.hour_of_day,
        
        -- Map kiosk to location
        COALESCE(
            k.location_id,
            'UNKNOWN'
        ) AS location_id,
        
        t.venue_name AS venue_raw,
        t.product_id,
        t.product_name,
        
        -- Source tracking
        'mashgin' AS source_system,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM items_unnested AS t
    LEFT JOIN {{ ref('kiosk_locations') }} AS k
        ON t.kiosk_id = k.kiosk_id

),

final AS (

    SELECT * FROM location_mapped
    WHERE transaction_id IS NOT NULL
        AND transaction_date IS NOT NULL

)

SELECT * FROM final
