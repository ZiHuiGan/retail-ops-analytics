# BigQuery Data Profiling 操作指南

## 专业数据工程师的 Data Profiling 方法论

### 数据质量维度（DAMA Framework）

专业的数据工程师使用 **DAMA 数据管理知识体系** 的 6 个维度来评估数据质量：

1. **Completeness (完整性)** - 数据是否完整？缺失值比例？
2. **Validity (有效性)** - 数据是否符合格式和业务规则？
3. **Consistency (一致性)** - 跨源数据是否一致？格式是否统一？
4. **Accuracy (准确性)** - 数据是否准确反映业务现实？
5. **Uniqueness (唯一性)** - 是否有重复记录？
6. **Timeliness (及时性)** - 数据是否及时更新？

### Profiling 工作流程

```
1. 基础统计 (Basic Statistics)
   ↓
2. 列级分析 (Column Analysis)
   ↓
3. 数据质量检查 (Data Quality Checks)
   ↓
4. 关系完整性 (Referential Integrity)
   ↓
5. 业务规则验证 (Business Rules)
   ↓
6. 跨源分析 (Cross-Source Analysis)
   ↓
7. 数据质量评分 (Quality Scoring)
```

---

## 第一步：打开 BigQuery Console

1. 访问：https://console.cloud.google.com/bigquery
2. 确保选择了正确的项目：`retail-ops-analytics`
3. 在左侧面板找到数据集：`raw_cvu_dining`

## 第二步：验证数据已加载

在运行 profiling 查询之前，先检查表是否存在：

```sql
-- 检查所有表
SELECT 
    table_name,
    row_count,
    size_bytes,
    creation_time
FROM `retail-ops-analytics.raw_cvu_dining.INFORMATION_SCHEMA.TABLES`
ORDER BY table_name;
```

或者简单检查每个表：

```sql
-- 检查 Grubhub
SELECT COUNT(*) as row_count 
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`;

-- 检查 Mashgin
SELECT COUNT(*) as row_count 
FROM `retail-ops-analytics.raw_cvu_dining.mashgin_transactions_raw`;

-- 检查 Stripe
SELECT COUNT(*) as row_count 
FROM `retail-ops-analytics.raw_cvu_dining.stripe_events_raw`;

-- 检查 Dining Hall
SELECT COUNT(*) as row_count 
FROM `retail-ops-analytics.raw_cvu_dining.dining_hall_swipes_raw`;
```

## 第三步：运行 Profiling 查询

### 操作步骤：

1. **复制查询**：从 `DATA_PROFILE.md` 中复制 SQL 查询
2. **粘贴到 BigQuery Console**：在查询编辑器中粘贴
3. **运行查询**：点击 "Run" 按钮（或按 Cmd+Enter）
4. **查看结果**：结果会显示在下方
5. **填写报告**：将结果填写到 `DATA_PROFILE.md` 中

### 示例：运行第一个查询

```sql
SELECT 
    COUNT(*) as total_rows,
    COUNT(DISTINCT `Order ID`) as unique_orders,
    MIN(`Order Date`) as min_date,
    MAX(`Order Date`) as max_date,
    COUNT(DISTINCT Venue) as unique_venues
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`;
```

**预期结果格式：**
```
total_rows | unique_orders | min_date    | max_date    | unique_venues
-----------|---------------|-------------|-------------|---------------
665        | 665          | 2026-02-03  | 2026-02-09  | 4
```

## 第四步：处理常见问题

### 问题1：表不存在
**错误：** `Table not found: retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`

**解决：**
1. 检查数据是否已加载：运行 `python python/src/load_standard_csv_json.py`
2. 检查数据集名称是否正确
3. 检查项目 ID 是否正确

### 问题2：列名包含特殊字符
**错误：** `Invalid column name`

**解决：** BigQuery 中列名包含空格或特殊字符需要用反引号 `` ` `` 包裹：
```sql
-- 正确
SELECT `Order ID`, `Order Date` FROM table;

-- 错误
SELECT Order ID, Order Date FROM table;
```

### 问题3：数据类型转换错误
**错误：** `Could not cast value to FLOAT64`

**解决：** 使用 `SAFE_CAST` 而不是 `CAST`，它会返回 NULL 而不是报错：
```sql
-- 正确
SAFE_CAST(Total AS FLOAT64)

-- 如果包含 $ 符号，先清理
SAFE_CAST(REPLACE(REPLACE(Total, '$', ''), ',', '') AS FLOAT64)
```

## 第五步：填写报告

对于每个查询的结果：

1. **复制数值**：从 BigQuery 结果中复制数值
2. **填写到报告**：粘贴到 `DATA_PROFILE.md` 中对应的位置
3. **标记完成**：在复选框 `[ ]` 中打勾 `[x]`
4. **记录发现**：在 Findings 部分记录任何异常

### 示例填写：

```markdown
**Results:**
- Total rows: 665
- Unique orders: 665
- Date range: 2026-02-03 to 2026-02-09
- Unique venues: 4

**Findings:**
- [x] Mixed date formats detected
- [x] Formats found: MM/DD/YYYY, MM-DD-YYYY, YYYY-MM-DD
```

## 第六步：分析结果

### 需要关注的问题：

1. **数据完整性**
   - NULL 值比例是否合理？
   - 是否有缺失的日期？

2. **数据一致性**
   - 日期格式是否统一？
   - 金额格式是否一致？
   - 名称是否有变体？

3. **数据准确性**
   - 金额范围是否合理？
   - 日期范围是否符合预期？
   - 计数是否匹配？

4. **数据质量问题**
   - 重复记录
   - 异常值（outliers）
   - 格式不一致

## 提示

- **保存查询**：在 BigQuery Console 中，可以保存常用查询以便重复使用
- **导出结果**：可以导出查询结果为 CSV，方便后续分析
- **使用 LIMIT**：对于大表，先用 `LIMIT 100` 测试查询
- **检查成本**：BigQuery 按查询数据量收费，注意控制查询范围

## 专业技巧

### 1. 使用 APPROX_QUANTILES 进行分布分析
```sql
-- 快速计算分位数（比 PERCENTILE_CONT 快）
SELECT 
    APPROX_QUANTILES(amount, 100)[OFFSET(25)] as p25,
    APPROX_QUANTILES(amount, 100)[OFFSET(50)] as median,
    APPROX_QUANTILES(amount, 100)[OFFSET(75)] as p75
FROM table;
```

### 2. 使用 INFORMATION_SCHEMA 获取元数据
```sql
-- 获取表结构信息
SELECT 
    column_name,
    data_type,
    is_nullable
FROM `retail-ops-analytics.raw_cvu_dining.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'grubhub_sales_raw'
ORDER BY ordinal_position;
```

### 3. 使用 SAFE 函数避免错误
```sql
-- SAFE_CAST, SAFE_DIVIDE, SAFE_SUBTRACT 等
SELECT 
    SAFE_CAST(value AS INT64) as safe_int,
    SAFE_DIVIDE(numerator, denominator) as safe_division
FROM table;
```

### 4. 使用窗口函数进行相对分析
```sql
-- 计算每行的相对位置
SELECT 
    *,
    COUNT(*) OVER() as total_rows,
    ROW_NUMBER() OVER(ORDER BY amount DESC) as rank
FROM table;
```

### 5. 使用 CTE 组织复杂查询
```sql
WITH base_stats AS (
    SELECT COUNT(*) as total FROM table
),
null_analysis AS (
    SELECT COUNTIF(col IS NULL) as null_count FROM table
)
SELECT 
    bs.total,
    na.null_count,
    ROUND(na.null_count * 100.0 / bs.total, 2) as pct_null
FROM base_stats bs, null_analysis na;
```

## 数据质量评分计算

### 示例：Completeness Score
```sql
SELECT 
    'grubhub_sales_raw' as table_name,
    ROUND(
        (COUNTIF(`Order ID` IS NOT NULL AND `Order ID` != '') * 1.0 / COUNT(*)) * 100, 
        2
    ) as completeness_score
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`;
```

### 示例：Uniqueness Score
```sql
SELECT 
    'grubhub_sales_raw' as table_name,
    ROUND(
        (COUNT(DISTINCT `Order ID`) * 1.0 / COUNT(*)) * 100,
        2
    ) as uniqueness_score
FROM `retail-ops-analytics.raw_cvu_dining.grubhub_sales_raw`;
```

## 自动化 Profiling 脚本

### 创建可重复使用的查询模板

建议创建一个 SQL 文件库，包含：
- `profiling_basic_stats.sql` - 基础统计
- `profiling_null_analysis.sql` - NULL 值分析
- `profiling_distribution.sql` - 分布分析
- `profiling_referential_integrity.sql` - 关系完整性
- `profiling_business_rules.sql` - 业务规则验证

## 完成检查清单

### 基础 Profiling
- [ ] 所有 4 个数据源的基本统计已完成
- [ ] 所有列分析已完成
- [ ] NULL 值分析已完成
- [ ] 分布分析（分位数）已完成

### 高级 Profiling
- [ ] 重复记录分析已完成
- [ ] 关系完整性检查已完成
- [ ] 业务规则验证已完成
- [ ] 跨源数据对比已完成
- [ ] 数据新鲜度检查已完成

### 数据质量评估
- [ ] 数据质量评分已计算
- [ ] 数据质量问题已记录
- [ ] 问题已按优先级分类（Critical/High/Medium/Low）
- [ ] 数据质量报告已生成

### 后续行动
- [ ] 数据质量问题已分配给开发团队
- [ ] 数据转换规则已文档化
- [ ] 自动化监控已设置（可选）