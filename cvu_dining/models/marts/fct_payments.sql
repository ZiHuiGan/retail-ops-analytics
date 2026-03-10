-- models/marts/fct_payments.sql
-- Purpose: Payment-level fact for Stripe (reconciliation and payment analytics)
-- Grain: One row per Stripe payment_intent
-- Joins to dimensions for consistent reporting; reconciles with fct_transactions (stripe source)

WITH stripe AS (
    SELECT
        payment_intent_id,
        payment_timestamp,
        payment_date,
        hour_of_day,
        amount_usd,
        currency,
        source_system,
        _loaded_at
    FROM {{ ref('stg_stripe_payments') }}
),

with_types AS (
    SELECT
        s.*,
        CASE WHEN s.amount_usd < 0 THEN 'TXN-REFUND' ELSE 'TXN-SALE' END AS transaction_type_id
    FROM stripe s
),

-- Join to dimension for referential integrity and attributes (e.g. affects_revenue)
final AS (
    SELECT
        with_types.payment_intent_id,
        with_types.payment_date,
        with_types.payment_timestamp,
        with_types.hour_of_day,
        with_types.amount_usd,
        with_types.currency,
        with_types.transaction_type_id,
        with_types.source_system,
        with_types._loaded_at,
        -- FK to dim (optional: join to dim_transaction_types for attributes)
        dt.transaction_type_name
    FROM with_types
    LEFT JOIN {{ ref('dim_transaction_types') }} AS dt
        ON with_types.transaction_type_id = dt.transaction_type_id
)

SELECT * FROM final
