-- 四源 Union 诊断：检查每个 staging 是否有数据
-- 若只有 stg_grubhub_sales 有行数，说明 mashgin/stripe/dining_hall 的 raw 无数据或 staging 未正确读取
-- 若项目 ID 不是 retail-ops-analytics，请全局替换

SELECT 'stg_grubhub_sales'      AS model_name, COUNT(*) AS row_count
FROM `retail-ops-analytics.dev_cvu_dining_staging_cvu_dining.stg_grubhub_sales`
UNION ALL
SELECT 'stg_mashgin_transactions', COUNT(*)
FROM `retail-ops-analytics.dev_cvu_dining_staging_cvu_dining.stg_mashgin_transactions`
UNION ALL
SELECT 'stg_stripe_payments', COUNT(*)
FROM `retail-ops-analytics.dev_cvu_dining_staging_cvu_dining.stg_stripe_payments`
UNION ALL
SELECT 'stg_dininghall_swipes', COUNT(*)
FROM `retail-ops-analytics.dev_cvu_dining_staging_cvu_dining.stg_dininghall_swipes`
ORDER BY model_name;

-- 若上面显示 mashgin/stripe/dining_hall 的 row_count = 0，再查 raw 表是否有数据：
/*
SELECT 'grubhub_sales_raw'         AS raw_table, COUNT(*) FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`
UNION ALL
SELECT 'mashgin_transactions_raw', COUNT(*) FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`
UNION ALL
SELECT 'stripe_events_raw',        COUNT(*) FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`
UNION ALL
SELECT 'dining_hall_swipes_raw',   COUNT(*) FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`
ORDER BY raw_table;
*/
