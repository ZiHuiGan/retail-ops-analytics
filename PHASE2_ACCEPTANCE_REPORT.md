# Phase 2 验收报告（提交前总结）

**日期**: 2026-03-10  
**范围**: TODO.md 第 154–205 行（fct 四源 UNION、payment 映射、refund、fct_payments、dim_products）

---

## 一、已完成的代码变更

| 项目 | 状态 | 说明 |
|------|------|------|
| **fct_transactions 四源 UNION** | ✅ | grubhub / mashgin / stripe / dining_hall 已 UNION ALL；Grubhub 增加 `grubhub_with_line` CTE 生成 `line_idx`，保证 `transaction_id` 唯一 |
| **payment_method_id 映射** | ✅ | Grubhub: CASE WHEN → PM-MEALPLAN, PM-MOBILE, PM-CASH, PM-DINING$, PM-CREDIT；Stripe/Dining/Mashgin 固定 ID |
| **Refund 识别** | ✅ | Grubhub/Stripe: `total_amount < 0` → `transaction_type_id = 'TXN-REFUND'` |
| **fct_payments** | ✅ | 基于 `stg_stripe_payments`，JOIN `dim_transaction_types`，含 `transaction_type_id` / `transaction_type_name` |
| **dim_products 含 Mashgin** | ✅ | `grubhub_products` + `mashgin_products` UNION，按 `product_id` 去重 (MAX name/source) |

**涉及文件**:
- `cvu_dining/models/marts/fct_transactions.sql`（新增 `grubhub_with_line`，修复 `line_idx`）
- `cvu_dining/models/marts/fct_payments.sql`（已存在）
- `cvu_dining/models/marts/dim_products.sql`（已存在）
- `cvu_dining/analyses/phase2_acceptance.sql`（本次新增，验收用 SQL）
- `TODO.md`（Phase 2 勾选与验收步骤说明）

---

## 二、验收执行说明

1. **构建模型**（在 `cvu_dining` 目录下）  
   ```bash
   dbt seed
   dbt run
   ```
2. **执行验收 SQL**  
   - 方式 A：在 BigQuery Console 中打开 `cvu_dining/analyses/phase2_acceptance.sql`，将表名前缀改为你的项目 ID（如 `your_project.marts_cvu_dining`），逐段执行。  
   - 方式 B：使用 `bq query` 或本地连接 BigQuery 执行同一组 SQL。

**说明**: 本机未连接 BigQuery 时，`dbt run` 可能失败或超时；请在具备认证的环境下执行上述步骤。

---

## 三、验收结果填写处（执行后填入）

跑完 `phase2_acceptance.sql` 后，将实际结果填到下面，便于提交前核对。

### 3.1 四源行数

| source_system | 预期约 | 实际 row_count |
|---------------|--------|-----------------|
| dining_hall   | 1717   | ________        |
| grubhub       | 665    | ________        |
| mashgin       | ~1000  | ________        |
| stripe        | 123    | ________        |

### 3.2 Grubhub payment_method_id

（应出现 PM-CASH, PM-CREDIT, PM-DINING$, PM-MEALPLAN, PM-MOBILE 及对应 raw 值，无异常 NULL 或未知 ID。）

- [ ] 已核对，映射正确

### 3.3 Refund

| transaction_type_id | 说明     | 实际 txn_count | 实际 total_amount |
|---------------------|----------|----------------|-------------------|
| TXN-REFUND          | 负金额笔数 | ________       | ________          |
| TXN-SALE            | 正金额笔数 | ________       | ________          |

### 3.4 Stripe 对账

| source_name              | row_count | total_amount |
|--------------------------|-----------|--------------|
| fct_transactions (stripe)| ________  | ________     |
| fct_payments             | ________  | ________     |

（两行应一致。）

### 3.5 dim_products

| source_system | 说明   | 实际 product_count |
|---------------|--------|--------------------|
| grubhub       | 产品数 | ________           |
| mashgin       | 产品数 | ________           |
| **合计**      |        | ________           |

---

## 四、提交前检查清单

- [ ] `dbt run` 成功
- [ ] 上述 3.1–3.5 验收结果已填写并符合预期
- [ ] 无敏感信息、临时文件未纳入提交
- [ ] 提交信息建议: `feat(cvu_dining): Phase 2 fct four-source union, payment mapping, refund, fct_payments, dim_products`

---

## 五、面试可讲要点（一句话）

- **单事实表多源**: 用 `source_system` 区分 grubhub / mashgin / stripe / dining_hall，统一 grain 与 FK，便于跨源分析。
- **Grain 差异**: Grubhub/Mashgin 为 line item；Stripe 为 payment；Dining Hall 用 GENERATE_ARRAY + UNNEST 将 swipe_count 展开为 swipe 级。
- **Payment 映射**: 在 fact 层用 CASE WHEN 将 raw payment_method 映射到 `dim_payment_methods` 的 FK，避免硬编码，便于维护。
- **Refund**: 负金额统一为 `TXN-REFUND`，与 `dim_transaction_types` 的 `reverses_transaction` 等属性一致。
- **对账**: `fct_payments` 与 `fct_transactions` 中 stripe 部分行数、金额一致，用于支付对账与审计。

---

**报告结束**。执行验收并填写第三节后即可 commit。
