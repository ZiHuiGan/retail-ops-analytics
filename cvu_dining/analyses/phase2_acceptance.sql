-- Phase 2 Acceptance Queries
-- Run after: dbt run
--
-- 【重要】dbt dev 环境下，BigQuery 里的 dataset 名 = target 前缀 + schema：
--   实际 dataset = dev_cvu_dining_marts_cvu_dining（不是 marts_cvu_dining）
-- 若你的 target 不同，请在 BigQuery 资源管理器里看实际 dataset 名并替换下面 DATASET。
--
-- 用法：把下面 DATASET 替换成你的实际 dataset（dev 一般为 dev_cvu_dining_marts_cvu_dining）
-- 表全名：`项目ID.DATASET.表名`，例如 retail-ops-analytics.dev_cvu_dining_marts_cvu_dining.fct_transactions

-- =============================================================================
-- 1. 四源 UNION 行数验收
-- 知识点: 单事实表多 source_system；grain 差异 (line item / payment / swipe)
-- =============================================================================
SELECT
    source_system,
    COUNT(*) AS row_count
FROM `retail-ops-analytics.dev_cvu_dining_marts_cvu_dining.fct_transactions`
GROUP BY source_system
ORDER BY source_system;

-- 预期 (参考):
-- dining_hall  1717  (28 天×计划 行 × swipe_count 展开)
-- grubhub      665
-- mashgin    ~1000  (UNNEST items 后行数)
-- stripe      123   (仅 payment_intent.succeeded)


-- =============================================================================
-- 2. Grubhub payment_method_id 映射验收
-- 知识点: raw → dim FK 在 fact 层 CASE WHEN 维护
-- =============================================================================
SELECT
    payment_method_id,
    payment_method_raw,
    COUNT(*) AS cnt
FROM `retail-ops-analytics.dev_cvu_dining_marts_cvu_dining.fct_transactions`
WHERE source_system = 'grubhub'
GROUP BY payment_method_id, payment_method_raw
ORDER BY payment_method_id, payment_method_raw;


-- =============================================================================
-- 3. Refund 识别验收
-- 知识点: 负金额 → TXN-REFUND，与 dim_transaction_types 一致
-- =============================================================================
SELECT
    transaction_type_id,
    COUNT(*) AS txn_count,
    ROUND(SUM(total_amount), 2) AS total_amount
FROM `retail-ops-analytics.dev_cvu_dining_marts_cvu_dining.fct_transactions`
GROUP BY transaction_type_id
ORDER BY transaction_type_id;


-- =============================================================================
-- 4. fct_payments 与 fct_transactions (stripe) 对账
-- 知识点: 支付事实表用于对账；两表 stripe 部分应一致
-- =============================================================================
SELECT 'fct_transactions (stripe)' AS source_name, COUNT(*) AS row_count, ROUND(SUM(total_amount), 2) AS total_amount
FROM `retail-ops-analytics.dev_cvu_dining_marts_cvu_dining.fct_transactions`
WHERE source_system = 'stripe'
UNION ALL
SELECT 'fct_payments', COUNT(*), ROUND(SUM(amount_usd), 2)
FROM `retail-ops-analytics.dev_cvu_dining_marts_cvu_dining.fct_payments`;


-- =============================================================================
-- 5. dim_products 多源验收
-- 知识点: Grubhub + Mashgin UNION 后按 product_id 去重
-- =============================================================================
SELECT
    source_system,
    COUNT(*) AS product_count
FROM `retail-ops-analytics.dev_cvu_dining_marts_cvu_dining.dim_products`
GROUP BY source_system
ORDER BY source_system;

-- 可选: 总行数
SELECT COUNT(*) AS total_products FROM `retail-ops-analytics.dev_cvu_dining_marts_cvu_dining.dim_products`;
