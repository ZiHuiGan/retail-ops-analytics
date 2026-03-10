# 如何在 BigQuery 里执行 Phase 2 验收 SQL

## 〇、为什么报错 "Dataset retail-ops-analytics:marts_cvu_dining was not found"？

dbt 在 **dev** 环境下会在 schema 前加 target 前缀，所以 BigQuery 里**实际 dataset 名**不是 `marts_cvu_dining`，而是：

- **`dev_cvu_dining_marts_cvu_dining`**（marts 表）
- **`dev_cvu_dining_staging_cvu_dining`**（staging 表）
- **`dev_cvu_dining_seeds_cvu_dining`**（seeds 表）

所以表全名是：`retail-ops-analytics.dev_cvu_dining_marts_cvu_dining.fct_transactions`。  
`phase2_acceptance.sql` 已改为使用该 dataset，直接执行即可。

---

## 一、「表名前缀」是什么意思？

在 BigQuery 里，一张表的**全名**由三部分组成：

```
项目 ID（Project ID）  .  数据集（Dataset）  .  表名（Table）
     ↓                        ↓                  ↓
  your-gcp-project     marts_cvu_dining      fct_transactions
```

- **项目 ID**：你的 GCP 项目，例如 `retail-ops-analytics` 或 `dev-retail-ops`（和 dbt 的 `profiles.yml` 里用的 project 一致）。
- **数据集**：dbt 把 marts 的表建在 `marts_cvu_dining` 里（见 `dbt_project.yml` 的 `+schema: marts_cvu_dining`）。
- **表名**：如 `fct_transactions`、`fct_payments`、`dim_products`。

验收 SQL 里写的是 **`marts_cvu_dining.fct_transactions`**，只有「数据集.表名」，没有写「项目 ID」。  
BigQuery 会用在当前会话里选中的那个**项目**来补全。所以：

- 如果你在 BigQuery 里**已经选对了项目**（和 dbt 建表的项目一致），直接执行 `marts_cvu_dining.fct_transactions` 即可，**不用改任何前缀**。
- 如果当前选中的不是 dbt 用的项目，或者你想明确写死项目，就要加上**项目 ID 前缀**，变成：**`<你的项目>.marts_cvu_dining`**，例如：

  `retail-ops-analytics.marts_cvu_dining.fct_transactions`

「把表名前缀改成 \<你的项目\>.marts_cvu_dining」的意思就是：  
把 SQL 里所有的 **`marts_cvu_dining.xxx`** 改成 **`你的项目ID.marts_cvu_dining.xxx`**。

---

## 二、怎么查「我的项目 ID」？

任选一种即可：

1. **看 dbt 配置**  
   打开 `profiles.yml`（在用户目录或项目里），找到 BigQuery 的 `project`，那就是项目 ID。
2. **看 BigQuery 控制台**  
   打开 [BigQuery 控制台](https://console.cloud.google.com/bigquery)，左上角会显示当前项目名称，点进去可以看到 **项目 ID**（Project ID）。
3. **看 dbt run 的日志**  
   运行 `dbt run` 时，日志里会写把表建在哪个 project / dataset 下（例如 `dev_cvu_dining_marts_cvu_dining`）。

---

## 二（续）、不用浏览器也能验证吗？工业环境里通常怎么做？

**可以。** 不一定要用浏览器。

| 方式 | 说明 |
|------|------|
| **浏览器 BigQuery 控制台** | 打开 console.cloud.google.com/bigquery，贴 SQL 运行。适合临时查数、演示。 |
| **本机 bq 命令行** | 安装 Google Cloud SDK 后，在终端执行 `bq query --use_legacy_sql=false "SELECT ..."`（或把 SQL 写进文件再 `cat` 进去）。适合脚本化、CI。 |
| **VS Code / Cursor + BigQuery 扩展** | 安装 “BigQuery” 或 “Google BigQuery” 等扩展，在编辑器里连上 GCP 项目后，在 .sql 文件里选中一段 SQL 即可“在 BigQuery 运行”，不用切浏览器。 |
| **dbt test** | 用 `dbt test` 或自定义 test 做断言（如行数、金额）。CI 里 `dbt run && dbt test` 即完成构建+验证。 |
| **笔记本 / 调度** | 用 Colab、Databricks、Airflow 等跑 BigQuery 查询并做断言或报表。 |

**工业环境常见做法**：开发时用 IDE 连 BigQuery 或 bq CLI 跑验收 SQL；上线前 CI 跑 `dbt run` + `dbt test`，必要时加 `bq query` 跑关键验收；生产用数据质量平台或调度里嵌验收，失败告警。  
所以：**可以用 Cursor/其他编辑器连 BigQuery 做验证**，装好对应扩展并配置 GCP 认证即可。

---

## 三、具体执行步骤（BigQuery 网页控制台）

### 1. 打开 BigQuery

- 浏览器打开：<https://console.cloud.google.com/bigquery>
- 登录你的 Google 账号，并**在左上角选中 dbt 建表用的那个项目**。

### 2. 打开验收 SQL 文件

- 在本地用编辑器打开：`cvu_dining/analyses/phase2_acceptance.sql`。

### 3. 需要时改表名前缀

- 验收 SQL 已使用 **`retail-ops-analytics.dev_cvu_dining_marts_cvu_dining`**（项目 + 实际 dev dataset）。
- 若你的项目 ID 不是 `retail-ops-analytics`，在编辑器里**全局替换**：`retail-ops-analytics.` → `你的项目ID.`

### 4. 一段一段执行（推荐）

文件里有 **5 段** 验收查询（每段一个 `SELECT`），建议**一次只执行一段**：

1. 在 `phase2_acceptance.sql` 里**选中第一段**（从第一个 `SELECT` 到下一个 `-- ===` 或空行前的全部内容）。
2. 复制，粘贴到 BigQuery 控制台左侧的「查询编辑器」。
3. 点击 **运行**，看结果是否符合预期（见文件里的「预期」注释）。
4. 再选第二段、第三段……重复直到 5 段都跑完。

也可以一次只复制一个完整的 `SELECT ... ;`，避免把多条语句一起跑导致只显示最后一条结果。

### 5. 可选：用「带占位符」的版本一次性替换

项目根目录下有一个 **`phase2_acceptance_with_project.sql`**，里面表名统一写成：

`YOUR_PROJECT_ID.marts_cvu_dining.xxx`

你只需要：

1. 打开该文件，
2. 全局把 `YOUR_PROJECT_ID` 替换成你的真实项目 ID（例如 `retail-ops-analytics`），
3. 然后在 BigQuery 里**一段一段**复制执行（同上）。

---

## 四、执行顺序提醒

- 先在本机跑完 **`dbt seed`** 和 **`dbt run`**，确保 BigQuery 里已有 **`dev_cvu_dining_marts_cvu_dining`** 下的 `fct_transactions`、`fct_payments`、`dim_products` 等表。
- 再在 BigQuery 里执行验收 SQL，否则会报「表不存在」。

---

## 五、一句话总结

- **「在 BigQuery 中执行 phase2_acceptance.sql」** = 把该文件里的 SQL 复制到 BigQuery 控制台（或 Cursor/VS Code 的 BigQuery 扩展）的查询框里，点「运行」。
- **dev 下表全名** = `你的项目ID.dev_cvu_dining_marts_cvu_dining.表名`（不是 `marts_cvu_dining`）。
