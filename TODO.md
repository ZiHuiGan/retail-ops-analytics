# CVU Dining Analytics - 项目进度追踪

> **更新时间**: 2026-03-10  
> **当前阶段**: Phase 2 核心逻辑已完成，待验收确认后进入 Phase 3  
---

### 1. 规划与设计 (100%)
- Bus Matrix (high-level + detailed)
- ENTITIES.md (8 dimensions, 2 facts, 完整属性定义)
- DATA_QUALITY_ISSUES.md (12个问题，4个优先级)
- DATA_PROFILE.md (profiling查询模板)

### 2. 环境配置 (100%)
- dbt-bigquery 1.11.7
- profiles.yml (dev/prod环境)
- dbt_project.yml (materialization策略)
- .sqlfluff (BigQuery/dbt规则配置)

### 3. Seeds - 参考数据 (100%)
- locations.csv (14行: 8 retail + 3 kiosk + 3 dining hall)
- meal_plans.csv (7行, SCD Type 2结构)
- payment_methods.csv (5行, 费率结构)
- transaction_types.csv (4行)
- kiosk_locations.csv (3行, kiosk映射)
- seeds/schema.yml (显式列类型定义)

### 4. Staging Models - 数据清洗 (100%)
- _sources.yml (4个raw表文档化)
- stg_grubhub_sales.sql (665 rows)
  - 解析3种日期格式 (MM/DD/YYYY, MM-DD-YYYY, YYYY-MM-DD)
  - 映射8个venues到location_id
  - 清理货币格式 (\$和逗号)
  - 处理NULL customer_id/meal_plan_id
- stg_mashgin_transactions.sql (~1000 rows)
  - UTC → EST时区转换 (-5小时)
  - UNNEST items数组
  - 映射kiosk_id到location_id
- stg_stripe_payments.sql (~200 rows)
  - Cents → Dollars转换 (/100.0)
  - 过滤到succeeded events
  - 从STRUCT提取payment details
- stg_dininghall_swipes.sql (28 rows)
  - 日期解析
  - Swipe count类型转换

### 5. Dimension Tables - 维度建模 (100%)
- dim_fiscal_calendar (730 rows)
  - Thursday 4:00 AM财政周逻辑
  - 2年日历数据 (过去1年 + 未来1年)
  - Academic fiscal year (Aug-Jul)
  - macros/fiscal_week.sql (自定义宏)
- dim_locations (14 rows, from seed)
- dim_meal_plans (7 rows, SCD Type 2 ready)
- dim_payment_methods (5 rows, 费率追踪)
- dim_transaction_types (4 rows)
- dim_time_of_day (24 rows, 餐期分类)
- dim_products (48 rows，grubhub + mashgin 去重)
- dim_customers (584 rows, 客户分层)

### 6. Fact Tables - 事实表 (90%)
- fct_transactions (四源 UNION：grubhub 665 + mashgin ~1038 + stripe 123 + dining_hall 1717，需 `dbt run` 后跑验收 SQL 确认)
  - UNION ALL 各分支已统一类型：order_id / kiosk_transaction_id / payment_intent_id / customer_id / meal_plan_id / transaction_timestamp / hour_of_day 等用 CAST(NULL AS 类型)
- fct_payments (123 rows，从 stg_stripe_payments，JOIN dim_transaction_types)

## 📊 项目统计

### BigQuery Datasets
- dev_cvu_dining_marts_cvu_dining: 9 tables
- dev_cvu_dining_staging_cvu_dining: 4 views  
- dev_cvu_dining_seeds_cvu_dining: 5 tables
- raw_cvu_dining: 4 tables

### dbt项目
- Models: 13 (4 staging + 8 dimensions + 1 fact)
- Seeds: 5 (33 rows)
- Sources: 4 (raw tables)
- Macros: 3 (fiscal week逻辑)
- Tests: schema.yml已配置，未实施

### 数据量
- Raw rows loaded: 1,977
- Transformed rows: ~2,200
- Total tables created: 22

## 🎯 埋雷清单 (Phase 2-3修复)

### 🔴 High Priority (Phase 2) — 已实现
1. ~~fct_transactions: 只有grubhub源~~ → 已四源 UNION，类型已统一
2. ~~payment_method_id: hardcoded~~ → 已 CASE WHEN 映射 (Grubhub)
3. ~~transaction_type_id: 都是'TXN-SALE'~~ → 已识别 refund (负金额 → TXN-REFUND)
4. ~~dim_products: 只有grubhub~~ → 已 UNION mashgin 并去重
5. ~~缺少fct_payments表~~ → 已创建

### 🟡 Medium Priority (Phase 3)
6. dim_customers: 缺少student master属性 (name, major, grad_year)
7. stg_grubhub_sales: 部分venues映射为'UNKNOWN'
8. 无数据质量tests实施
9. 无dbt文档生成

### 🟢 Low Priority (Phase 4-5)
10. Intermediate layer未使用
11. OBT/Analytics layer缺失
12. Source-to-Target文档缺失 (3份)
13. 示例analytics查询缺失

## 🏗️ 数据架构

### Kimball Dimensional Model
- 8 Dimensions (conformed across facts)
- 1 Fact Table (transaction grain: one row per line item)
- Star Schema设计

### 数据流转层次
```
Layer 1: Raw (4 sources)
   ↓
Layer 2: Staging (1:1 source mapping, views)
   ↓
Layer 3: Marts (dimensional model, tables)
   ├── Dimensions (8个)
   └── Facts (1个)
```

### 数据质量问题已识别
- P0 Critical: 3个 (日期格式、时区、货币单位)
- P1 High: 4个 (venue映射、NULL处理)
- P2 Medium: 3个 (重复事件、累积数据)
- P3 Low: 2个 (outliers、weekend patterns)

## ⏱️ 时间投入

### Day 1-2: 规划与数据加载 (3小时)
- Bus Matrix设计
- ENTITIES.md建模
- Python脚本加载raw data
- Data profiling SQL

### Day 3: dbt实施 (7小时)
- dbt环境配置 (1h)
- Seeds创建与加载 (0.5h)
- Staging models (1.5h)
- Dimension tables (2.5h)
- Fact table (0.5h)
- 调试与修复 (1h)

**Total: ~10小时**

## 🚀 下一步计划
## 📋 Phase 2: 完善核心逻辑 (本周重点)

**预计时间**: 4小时  
**截止日期**: 2026-03-13

### 🔴 High Priority (必须完成)

#### 1. fct_transactions - 四源UNION
- [x] grubhub源 (已完成，含 line_idx 生成)
- [x] mashgin源 (stg UNNEST items + kiosk→location，fct 已 UNION)
  - [x] UNNEST 逻辑在 stg_mashgin_transactions
  - [x] transaction_id 用 MD5(order_id|product_id|date) 映射
  - [ ] 本地/CI 测试行数
- [x] stripe源 (payment_intent_id 作 transaction_id，金额 amount_usd)
- [x] dining_hall源 (GENERATE_ARRAY + UNNEST 将 swipe_count 转为 transaction grain，location_id = CVU-D001)

**验收标准**:
```sql
SELECT source_system, COUNT(*) 
FROM fct_transactions 
GROUP BY source_system;

-- 预期结果:
-- grubhub: 665
-- mashgin: ~1000
-- stripe: 123 (仅 succeeded；若 raw 为 246 则 123 为正确)
-- dining_hall: 1717 (28 天×计划 的 swipe 行 × 每行 swipe_count 展开)
```

#### 2. payment_method_id Mapping
- [x] 创建 mapping 逻辑 (Grubhub: CASE WHEN payment_method → PM-*；Stripe/Dining/Mashgin 固定)
  - [x] Grubhub: Meal Plan→PM-MEALPLAN, Convenience→PM-MOBILE, Cash→PM-CASH, Dining Points→PM-DINING$, Credit→PM-CREDIT
  - [x] 默认 ELSE 'PM-CREDIT'
- [ ] 测试所有 payment methods 被正确映射 (见下方验收 SQL)

#### 3. Refund Detection
- [x] 识别负金额为 refund (Grubhub/Stripe: CASE WHEN amount < 0 THEN 'TXN-REFUND')
- [x] transaction_type_id = 'TXN-REFUND'
- [ ] 验证 refund 数量 (见验收 SQL)

#### 4. fct_payments 创建
- [x] 从 stg_stripe_payments
- [x] JOIN dim_transaction_types
- [ ] 验证 reconciliation (fct_transactions stripe 行数/金额 = fct_payments)

#### 5. dim_products 添加 mashgin
- [x] UNION mashgin products (grubhub_products + mashgin_products，GROUP BY product_id 去重)
- [x] 去重逻辑 (MAX(product_name), MAX(source_system))
- [ ] 验证总行数增加 (见验收 SQL)

**Phase 2 完成标志**: 
- [x] fct_transactions 有 4 个 sources
- [x] payment_method_id mapping 已实现
- [x] fct_payments 已创建
- [x] 本地 `dbt run` 通过（dim_fiscal_calendar 语法已修；fct_transactions UNION 类型已统一）
- [ ] 在 BigQuery 跑完 phase2_acceptance.sql 五段验收并填 PHASE2_ACCEPTANCE_REPORT 后可选 commit

---

### Phase 2 验收步骤与知识点 (面试可讲)

1. **四源 UNION 与 Grain**
   - 跑: `SELECT source_system, COUNT(*) FROM fct_transactions GROUP BY source_system;`
   - 知识点: 单事实表多 source_system 的 Kimball 做法；Grubhub/Mashgin 为 line item grain，Stripe 为 payment grain，Dining Hall 为 swipe grain（由 GENERATE_ARRAY + UNNEST 展开）。

2. **Payment method 映射**
   - 跑: `SELECT payment_method_id, payment_method_raw, COUNT(*) FROM fct_transactions WHERE source_system='grubhub' GROUP BY 1,2;`
   - 知识点: 在 fact 层用 CASE WHEN 将 raw 值映射到 dim 的 FK（payment_methods seed），避免硬编码 ID，便于维护。

3. **Refund 识别**
   - 跑: `SELECT transaction_type_id, COUNT(*), SUM(total_amount) FROM fct_transactions GROUP BY transaction_type_id;`
   - 知识点: 负金额即退款，统一用 transaction_type_id = 'TXN-REFUND'，便于与 dim_transaction_types（affects_revenue, reverses_transaction）做分析。

4. **fct_payments 与 reconciliation**
   - 跑: `SELECT COUNT(*), SUM(amount_usd) FROM fct_payments;` 与 `SELECT COUNT(*), SUM(total_amount) FROM fct_transactions WHERE source_system='stripe';` 应一致。
   - 知识点: 支付事实表用于对账与支付分析；与 fct_transactions 的 stripe 部分可互相校验。

5. **dim_products 多源去重**
   - 跑: `SELECT source_system, COUNT(*) FROM dim_products GROUP BY source_system;`
   - 知识点: 多源 product 用 UNION ALL 后按 product_id 去重（MAX 取名称），SCD Type 2 可后续加 effective_from/to。

---

## 📋 Phase 3: 测试与质量 (下周)

**预计时间**: 2小时

### dbt Tests
- [ ] schema.yml添加tests (1小时)
  - [ ] unique tests (所有主键)
  - [ ] not_null tests (必填字段)
  - [ ] relationships tests (外键)
  - [ ] accepted_values tests (枚举字段)
  - [ ] custom tests (业务规则)
- [ ] 运行`dbt test`全部通过 (20分钟)
- [ ] 修复失败的tests (40分钟)

**验收标准**: `dbt test` 输出 `PASS=30+ ERROR=0`

---

## 📋 Phase 4: 文档化 (后续)

**预计时间**: 2小时

- [ ] dbt docs generate (5分钟)
- [ ] dbt docs serve截图 (10分钟)
- [ ] Source-to-Target文档3份 (60分钟)
  - [ ] DATA_LAKE_TO_STAGING.md
  - [ ] STAGING_TO_WAREHOUSE.md
  - [ ] WAREHOUSE_TO_OBT.md
- [ ] Model descriptions完善 (45分钟)

---

## 📋 Phase 5: Analytics层 (可选)

**预计时间**: 2小时

- [ ] OBT创建 (60分钟)
- [ ] 10个示例查询 (40分钟)
- [ ] Dashboard设计 (20分钟)


## 📝 已知问题

### 技术债务
- stg_grubhub_sales日期解析有3个CASE分支 (可优化为COALESCE)
- dim_customers的DATE_DIFF曾有类型问题 (已修复)
- SQLFluff warnings (行长度>100字符)
- dbt_project.yml有unused 'intermediate' path

### 数据质量
- 4个venues映射为'UNKNOWN' (需补充seed)
- Mashgin 10% NULL venue_name (部分通过kiosk_id解决)
- 无自动化测试阻止脏数据

## 🎓 学习成果

### 技术技能
- dbt项目结构与最佳实践
- Kimball维度建模方法论
- BigQuery数据类型处理
- SQL窗口函数与聚合
- Jinja模板与宏编程
- Git版本控制工作流

### 工程思维
- 增量开发（先框架后完善）
- Schema-first设计
- 埋雷策略（Phase 1框架，Phase 2polish）
- Test-driven思维
- 文档即代码

### 工具熟练度
- dbt-bigquery
- SQLFluff linting
- Cursor AI辅助
- BigQuery Console
- Terminal/命令行

---

**项目状态**: Phase 2 核心逻辑完成 ✅  
**完成度**: 核心框架 100%，业务逻辑 90%  
**下次启动**: Phase 3 - dbt tests；或先跑 phase2_acceptance.sql 填报告
```

---

## 🎉 Phase 1 完成总结
```
✅ 完成时间: 2026-03-09 21:16
✅ 总耗时: Day 3, 10小时
✅ Git commits: 4次
✅ BigQuery tables: 22个
✅ dbt models: 13个
✅ 数据行数: ~2,200行

🎯 成就解锁:
- 完整的Kimball星型模型
- 4层数据架构 (raw/staging/marts)
- Fiscal calendar with 特殊逻辑
- 584个客户维度记录
- 可工作的数据仓库原型

🚀 下次目标:
Phase 2 - 完成4-source union + 所有埋雷修复

---

## 📌 换电脑 / 进度记忆 (2026-03-10)

### 本机今日完成
- **dbt seed**：meal_plans 的 dining_dollars/convenience_points/price_per_semester 在 dbt_project.yml 中配置 `+column_types: FLOAT64`，解决 BigQuery 解析 "0.00" 报错。
- **fct_transactions**：四源 UNION 已生效；BigQuery UNION 要求同列类型一致，对所有 NULL 列做了显式 CAST（order_id, kiosk_transaction_id, payment_intent_id, customer_id, meal_plan_id, transaction_timestamp, hour_of_day 等）。
- **dim_fiscal_calendar**：去掉末尾分号、整理最后一列格式，语法错误已修复。
- **验收**：staging 四表有数据；BigQuery 实际 dataset 名为 `dev_cvu_dining_marts_cvu_dining`（非 `marts_cvu_dining`）；phase2_acceptance.sql 已按该 dataset 写好；phase2_diagnose_sources.sql、如何执行验收SQL.md、PHASE2_ACCEPTANCE_REPORT.md 已就绪。

### 换机后必做
1. **拉代码**：新电脑上 `git clone` 或从 iCloud/同步目录打开 `retail-ops-analytics`。
2. **配置 dbt**：`profiles.yml` 放在 `~/.dbt/` 或项目内，BigQuery 认证（ADC 或 service account key）。
3. **验证**：`cd cvu_dining && dbt seed && dbt run`，再在 BigQuery 跑 `cvu_dining/analyses/phase2_acceptance.sql` 五段验收。

### 检查「记忆」是否在 iCloud（换机前在本机做）
- **项目代码与进度**：进度写在 **本仓库的 TODO.md** 和 **PHASE2_ACCEPTANCE_REPORT.md** 里，没有单独“AI memory”云服务；换机后能看到的内容 = 你同步过去的文件。
- **确认项目目录被 iCloud 同步**：  
  1. 看项目路径：你当前是 `~/Desktop/Analytics Engineer/Retail Ops/CodeSpace`。  
  2. 若 Desktop 在 iCloud Drive：系统设置 → Apple ID → iCloud → iCloud Drive → 选项 → 勾选「桌面与文稿」；则 Desktop 下内容会同步。  
  3. 在 Finder 中右键该文件夹 → 选「现在下载」或确认无云朵图标表示已本地+同步。  
  4. 或把项目复制到 **iCloud Drive** 下的文件夹（如 iCloud Drive/CodeSpace/），确保该文件夹在 iCloud 中。  
- **Git 作为备份**：今日变更 commit 并 push 到 GitHub 后，新电脑 `git pull` 即可拿到最新 TODO 与代码，不依赖 iCloud。