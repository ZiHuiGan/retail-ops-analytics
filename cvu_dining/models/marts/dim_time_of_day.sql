-- models/marts/dim_time_of_day.sql
-- Purpose: Time of day dimension (0-23 hours)

WITH hours AS (

    SELECT hour
    FROM UNNEST(GENERATE_ARRAY(0, 23)) AS hour

),

time_periods AS (

    SELECT
        hour AS hour_of_day,
        
        -- Time period classification
        CASE
            WHEN hour BETWEEN 6 AND 10 THEN 'Breakfast'
            WHEN hour BETWEEN 11 AND 14 THEN 'Lunch'
            WHEN hour BETWEEN 15 AND 17 THEN 'Afternoon Snack'
            WHEN hour BETWEEN 18 AND 21 THEN 'Dinner'
            WHEN hour BETWEEN 22 AND 23 THEN 'Late Night'
            ELSE 'Overnight'
        END AS time_period,
        
        -- Day part
        CASE
            WHEN hour BETWEEN 6 AND 11 THEN 'Morning'
            WHEN hour BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN hour BETWEEN 18 AND 21 THEN 'Evening'
            ELSE 'Night'
        END AS day_part,
        
        -- Peak hours flag
        hour IN (12, 13, 18, 19) AS is_peak_hour
        
    FROM hours

)

SELECT * FROM time_periods
ORDER BY hour_of_day