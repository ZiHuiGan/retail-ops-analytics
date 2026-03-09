-- macros/fiscal_week.sql
-- Purpose: Calculate fiscal week with Thursday 4:00 AM start logic
-- Business Rule: Week starts Thursday 4am, ends Wednesday 3:59am

-- For DATE columns (calendar table)
{% macro get_fiscal_week_start_date(date_column) %}
    DATE_TRUNC({{ date_column }}, WEEK(THURSDAY))
{% endmacro %}


-- For TIMESTAMP columns (transaction data with 4am logic)
{% macro get_fiscal_week_start_timestamp(timestamp_column) %}
    DATE_TRUNC(
        CASE
            -- If Thursday before 4am, use previous week
            WHEN EXTRACT(DAYOFWEEK FROM {{ timestamp_column }}) = 5
                AND EXTRACT(HOUR FROM {{ timestamp_column }}) < 4
            THEN TIMESTAMP_SUB({{ timestamp_column }}, INTERVAL 7 DAY)
            ELSE {{ timestamp_column }}
        END,
        WEEK(THURSDAY)
    )
{% endmacro %}


-- Get fiscal week ID (works for both DATE and TIMESTAMP)
{% macro get_fiscal_week_id(date_or_timestamp) %}
    FORMAT_DATE('%Y-W%V', DATE({{ date_or_timestamp }}))
{% endmacro %}