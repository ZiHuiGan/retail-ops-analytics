-- Phase 2 验收 SQL（带项目占位符版）
-- 使用前：把 YOUR_PROJECT_ID 全局替换成你的 BigQuery 项目 ID（例如 retail-ops-analytics）
-- 然后一段一段复制到 BigQuery 控制台执行

-- =============================================================================
-- 1. 四源 UNION 行数验收
-- =============================================================================
SELECT
    source_system,
    COUNT(*) AS row_count
FROM `YOUR_PROJECT_ID.marts_cvu_dining.fct_transactions`
GROUP BY source_system
ORDER BY source_system;


-- =============================================================================
-- 2. Grubhub payment_method_id 映射验收
-- =============================================================================
SELECT
    payment_method_id,
    payment_method_raw,
    COUNT(*) AS cnt
FROM `YOUR_PROJECT_ID.marts_cvu_dining.fct_transactions`
WHERE source_system = 'grubhub'
GROUP BY payment_method_id, payment_method_raw
ORDER BY payment_method_id, payment_method_raw;


-- =============================================================================
-- 3. Refund 识别验收
-- =============================================================================
SELECT
    transaction_type_id,
    COUNT(*) AS txn_count,
    ROUND(SUM(total_amount), 2) AS total_amount
FROM `YOUR_PROJECT_ID.marts_cvu_dining.fct_transactions`
GROUP BY transaction_type_id
ORDER BY transaction_type_id;


-- =============================================================================
-- 4. fct_payments 与 fct_transactions (stripe) 对账
-- =============================================================================
SELECT 'fct_transactions (stripe)' AS source_name, COUNT(*) AS row_count, ROUND(SUM(total_amount), 2) AS total_amount
FROM `YOUR_PROJECT_ID.marts_cvu_dining.fct_transactions`
WHERE source_system = 'stripe'
UNION ALL
SELECT 'fct_payments', COUNT(*), ROUND(SUM(amount_usd), 2)
FROM `YOUR_PROJECT_ID.marts_cvu_dining.fct_payments`;


-- =============================================================================
-- 5. dim_products 多源验收
-- =============================================================================
SELECT
    source_system,
    COUNT(*) AS product_count
FROM `YOUR_PROJECT_ID.marts_cvu_dining.dim_products`
GROUP BY source_system
ORDER BY source_system;

SELECT COUNT(*) AS total_products FROM `YOUR_PROJECT_ID.marts_cvu_dining.dim_products`;
