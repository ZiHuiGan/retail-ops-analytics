-- models/marts/dim_fiscal_calendar.sql
-- Purpose: Master calendar with CVU fiscal week logic
-- Note: Date-level only; fiscal week starts Thursday (WEEK(THURSDAY))

WITH date_spine AS (

    SELECT
        DATE_ADD(CURRENT_DATE(), INTERVAL day_offset DAY) AS date
    FROM UNNEST(GENERATE_ARRAY(-365, 364)) AS day_offset

),

fiscal_weeks AS (

    SELECT
        date,
        
        -- Fiscal week start (Thursday of this week)
        {{ get_fiscal_week_start_date('date') }} AS fiscal_week_start_date,
        
        -- Fiscal week end (Wednesday, 6 days after Thursday start)
        DATE_ADD(
            {{ get_fiscal_week_start_date('date') }},
            INTERVAL 6 DAY
        ) AS fiscal_week_end_date,
        
        -- Fiscal week ID (e.g., '2026-W06')
        FORMAT_DATE(
            '%Y-W%V',
            {{ get_fiscal_week_start_date('date') }}
        ) AS fiscal_week_id,
        
        -- Day of week
        FORMAT_DATE('%A', date) AS day_of_week,
        EXTRACT(DAYOFWEEK FROM date) AS day_of_week_num,
        
        -- Weekend flag (Saturday = 7, Sunday = 1)
        EXTRACT(DAYOFWEEK FROM date) IN (1, 7) AS is_weekend,
        
        -- Month
        FORMAT_DATE('%B', date) AS month_name,
        EXTRACT(MONTH FROM date) AS month_number,
        
        -- Year
        EXTRACT(YEAR FROM date) AS year,
        
        -- Calendar quarter
        EXTRACT(QUARTER FROM date) AS quarter_number,
        CONCAT('Q', CAST(EXTRACT(QUARTER FROM date) AS STRING)) AS quarter,
        
        -- Fiscal year (Aug-Jul academic calendar)
        CASE
            WHEN EXTRACT(MONTH FROM date) >= 8
            THEN EXTRACT(YEAR FROM date)
            ELSE EXTRACT(YEAR FROM date) - 1
        END AS fiscal_year,
        
        -- Fiscal quarter (Aug-Oct=Q1, Nov-Jan=Q2, Feb-Apr=Q3, May-Jul=Q4)
        CASE
            WHEN EXTRACT(MONTH FROM date) IN (8, 9, 10) THEN 1
            WHEN EXTRACT(MONTH FROM date) IN (11, 12, 1) THEN 2
            WHEN EXTRACT(MONTH FROM date) IN (2, 3, 4) THEN 3
            ELSE 4
        END AS fiscal_quarter_number,
        
        -- Current date flag
        date = CURRENT_DATE() AS is_current_day,
        
        -- Current week flag
        DATE_TRUNC(date, WEEK(THURSDAY)) = 
            DATE_TRUNC(CURRENT_DATE(), WEEK(THURSDAY)) AS is_current_week,
        
        -- Current month flag
        EXTRACT(MONTH FROM date) = EXTRACT(MONTH FROM CURRENT_DATE())
            AND EXTRACT(YEAR FROM date) = EXTRACT(YEAR FROM CURRENT_DATE()) 
            AS is_current_month,
        
        -- Current year flag
        EXTRACT(YEAR FROM date) = EXTRACT(YEAR FROM CURRENT_DATE()) 
            AS is_current_year
        
    FROM date_spine

)

SELECT * FROM fiscal_weeks
ORDER BY date;
