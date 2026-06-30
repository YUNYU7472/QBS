# 题库管理系统 — 数据库工程说明

## 1. 项目数据库说明

本数据库服务于**某学校的题库管理系统**，为后端应用提供持久化存储与数据访问支持。

- **数据库引擎**：openGauss
- **运行方式**：Docker 容器
- **容器名称**：`qbank-opengauss`
- **正式数据库名**：`qbank_db`

数据库结构、权限与演示数据均通过本目录下的 SQL 脚本统一管理，便于课程设计小组成员协同开发与本地部署。

---

## 2. 数据库目录说明

本目录（`database/`）为数据库工程根目录，主要包含 SQL 脚本、备份文件及运维脚本。

### SQL 脚本

| 文件 | 用途 |
|------|------|
| `00_drop_all.sql` | 清理 `qbank_db` 内部的项目对象（见下文「清理脚本说明」） |
| `01_create_schema.sql` | 创建 `qbank` schema 及命名空间（**已完成**） |
| `02_create_tables.sql` | 创建核心数据表及字段定义（**已完成**） |
| `03_create_constraints.sql` | 创建主键、外键、唯一约束、检查约束等（**已完成**） |
| `04_create_indexes.sql` | 创建业务查询索引，优化查询性能（**已完成**） |
| `05_create_views.sql` | 创建视图，封装常用查询逻辑（**已完成**） |
| `06_create_functions.sql` | 创建用户自定义函数（**已完成**） |
| `07_create_procedures.sql` | 创建存储过程（**已完成**） |
| `08_create_triggers.sql` | 创建触发器，实现数据变更时的自动逻辑（**已完成**） |
| `09_init_roles.sql` | 初始化角色、用户及权限（含业务用户 `qbank_app`）（**已完成**） |
| `10_init_data.sql` | 插入演示/初始数据（**已完成**） |
| `11_test_queries.sql` | 验收测试查询脚本，覆盖结构与功能验证（**已完成**） |

### 目录与运维脚本

| 路径 | 用途 |
|------|------|
| `backup/` | 存放数据库逻辑备份文件（由 `backup_db.sh` 生成） |
| `scripts/init_db.sh` | 检查环境并初始化数据库，按顺序执行建库相关 SQL |
| `scripts/reset_db.sh` | 删除并重建 `qbank_db`，随后调用 `init_db.sh` 完成初始化 |
| `scripts/backup_db.sh` | 对 `qbank_db` 进行逻辑备份，输出至 `backup/` |
| `scripts/restore_db.sh` | 从指定备份文件恢复数据库 |
| `scripts/run_tests.sh` | 一键执行 `11_test_queries.sql` 验收测试 |

---

## 3. Schema 设计说明

本项目正式数据库对象统一放在 **`qbank`** schema 下，不建议将正式业务表放在 **`public`** schema 中。

后续对象命名示例：

- `qbank.course`
- `qbank.question_type`
- `qbank.chapter`
- `qbank.question`
- `qbank.paper`
- `qbank.v_course_type_usage`
- `qbank.sp_generate_paper`

使用独立 schema 的好处：

- **便于对象隔离**：业务对象与系统默认 schema 分离，结构清晰
- **便于权限管理**：可针对 `qbank` schema 单独授权给 `qbank_app` 等业务用户
- **便于清理和重建**：执行 `DROP SCHEMA qbank CASCADE` 即可一次性清理所有业务对象
- **便于报告展示**：体现数据库结构设计的规范性与专业性

---

## 4. 核心数据表设计说明

`02_create_tables.sql` 已在 **`qbank`** schema 下创建 **21 张核心数据表**，按业务职责分为四层：

### 基础主数据层（9 张）

| 表名 | 说明 |
|------|------|
| `qbank.sys_user` | 系统登录用户 |
| `qbank.sys_role` | 系统角色 |
| `qbank.sys_user_role` | 用户与角色多对多关系 |
| `qbank.teacher` | 教师信息 |
| `qbank.course` | 课程基本信息 |
| `qbank.question_type` | 题型基本信息 |
| `qbank.course_question_type` | 课程与题型关联（每门课程可用题型） |
| `qbank.chapter` | 课程章节（支持章节树） |
| `qbank.knowledge_point` | 知识点 |

### 题库业务层（4 张）

| 表名 | 说明 |
|------|------|
| `qbank.question` | 习题主体 |
| `qbank.question_option` | 选择题选项 |
| `qbank.question_tag` | 题目标签 |
| `qbank.question_attachment` | 题目附件元信息 |

### 组卷事务层（4 张）

| 表名 | 说明 |
|------|------|
| `qbank.paper` | 套题/试卷 |
| `qbank.paper_question` | 套题题目明细 |
| `qbank.paper_rule` | 自动组卷规则 |
| `qbank.extract_log` | 抽题日志 |

### 安全审计与系统辅助层（4 张）

| 表名 | 说明 |
|------|------|
| `qbank.login_log` | 登录日志 |
| `qbank.audit_log` | 操作审计 |
| `qbank.backup_history` | 备份/恢复记录 |
| `qbank.system_config` | 系统配置 |

### 本阶段设计原则

- **只创建表和字段**：使用 `CREATE TABLE IF NOT EXISTS`、`NOT NULL`、`DEFAULT` 等基础定义
- **不创建完整性约束**：本阶段**不包含**主键（`PRIMARY KEY`）、外键（`FOREIGN KEY`）、唯一约束（`UNIQUE`）、检查约束（`CHECK`）
- **不创建索引、视图、函数、存储过程、触发器及初始化数据**
- **约束集中管理**：主键、外键、唯一约束、检查约束等将在 **`03_create_constraints.sql`** 中统一创建
- **Schema 规范**：所有正式表均位于 **`qbank`** schema，使用 `qbank.` 前缀显式引用

---

## 5. 完整性约束设计说明

`03_create_constraints.sql` 为 21 张核心表创建了完整性约束，涵盖以下四类：

| 完整性类型 | 约束形式 | 作用 |
|------------|----------|------|
| **实体完整性** | 主键（`PRIMARY KEY`） | 保证每条记录有唯一标识，21 张表均设 `pk_表名` |
| **用户自定义完整性** | 唯一约束（`UNIQUE`） | 防止业务重复，如用户名、课程代码、同一套题重复题目等 |
| **域完整性** | 检查约束（`CHECK`） | 限制字段取值，如状态、难度 1–5、分值非负、抽题次数非负等 |
| **参照完整性** | 外键（`FOREIGN KEY`） | 保证课程、题型、章节、习题、套题之间的引用关系正确 |

### 主键约束

21 张表均通过 `pk_表名` 主键约束保证实体完整性，例如 `pk_question` 约束 `question_id` 唯一且非空。

### 唯一约束

- `uq_course_course_code`：课程编码不重复
- `uq_question_type_type_code` / `uq_question_type_type_name`：题型编码与名称不重复
- `uq_course_question_type_course_type`：同一课程不能重复配置同一种题型
- `uq_chapter_course_no`：同一课程内章节编号不重复
- `uq_paper_question_paper_question`：同一套题不能重复包含同一道题
- `uq_question_option_question_label`：同一道题不能有两个相同选项标签

### 检查约束

- 通用 `status` 字段：`active`、`disabled`、`deleted`
- `ck_question_difficulty`：难度 1–5
- `ck_question_score` / `ck_question_extract_count`：分值与抽题次数非负
- `ck_paper_type` / `ck_paper_status`：组卷类型与套题状态枚举

### 外键约束

以下两个复合外键是题库业务逻辑的核心保障：

1. **`fk_question_course_type`**：`qbank.question(course_id, type_id)` → `qbank.course_question_type(course_id, type_id)`  
   保证**某课程未启用的题型不能录入到该课程习题中**。

2. **`fk_question_chapter`**：`qbank.question(course_id, chapter_id)` → `qbank.chapter(course_id, chapter_id)`  
   保证**题目所属章节一定属于该课程**。

其他重要外键还包括：`fk_question_knowledge_point`（知识点归属校验）、`fk_paper_rule_course_type`（组卷规则引用合法课程题型）等。

### 删除行为约定

外键统一使用默认 **NO ACTION / RESTRICT**，**不使用 `ON DELETE CASCADE`**。业务删除采用 `status='disabled'` 或 `status='deleted'` 软删除，避免误删历史数据。

### 本阶段范围

- **已创建**：主键、唯一约束、检查约束、外键
- **未创建**：索引（留待 `04_create_indexes.sql`）、视图、函数、存储过程、触发器、初始化数据、角色授权

### 执行说明

- 约束脚本应在 `02_create_tables.sql` 之后执行
- 推荐通过 `bash database/scripts/reset_db.sh` 删库重建后完整初始化
- 重复执行可能因约束已存在而报错，需先 `reset_db.sh` 或 `00_drop_all.sql` 后重新初始化

---

## 6. 索引设计说明

`04_create_indexes.sql` 为高频业务查询场景创建了 **39 个普通 B-tree 业务索引**，命名统一为 `idx_表名_字段或场景`。

### 设计原则

- **索引不是越多越好**：围绕课程查询、题库检索、自动组卷、试卷明细、日志审计等高频场景设计，避免给每个字段都建索引
- **避免重复**：主键和唯一约束已在阶段 3 创建，数据库通常会自动生成隐式索引，本阶段**不重复创建**等价单列或复合索引
- **普通 B-tree 索引**：不使用 GIN、GiST、Hash、全文索引、表达式索引、部分索引等复杂类型

### 重点索引场景

| 场景 | 代表索引 |
|------|----------|
| 题库按课程/题型查询 | `idx_question_course_type_status` |
| 题库按课程/章节查询 | `idx_question_course_chapter_status` |
| 自动组卷筛选 | `idx_question_auto_pick` |
| 试卷列表与套题明细 | `idx_paper_course_status_created`、`idx_paper_question_paper_order` |
| 抽题日志统计 | `idx_extract_log_question_time`、`idx_extract_log_paper_time` |
| 登录日志查询 | `idx_login_log_user_time`、`idx_login_log_status_time` |
| 审计日志查询 | `idx_audit_log_table_operation_time`、`idx_audit_log_table_record` |
| 备份恢复记录查询 | `idx_backup_history_type_status_time` |

### 关键索引：`idx_question_auto_pick`

复合索引 `(course_id, type_id, chapter_id, difficulty, status, extract_count)` 用于：

- 自动组卷时按课程、题型、章节、难度、状态筛选候选题
- 将 `extract_count` 纳入索引列，便于后续实现**低抽取次数优先**的抽题策略

### 本阶段范围

- **已创建**：39 个业务查询索引（`CREATE INDEX`）
- **未创建**：视图（留待 `05_create_views.sql`）、函数、存储过程、触发器、初始化数据、角色授权

### 执行说明

- 索引脚本应在 `03_create_constraints.sql` 之后执行
- 推荐通过 `bash database/scripts/reset_db.sh` 删库重建后完整初始化
- 重复执行可能因索引已存在而报错，需先 `reset_db.sh` 或 `00_drop_all.sql` 后重新初始化

---

## 7. 视图设计说明

`05_create_views.sql` 创建了 **5 个业务视图**，遵循「视图不是越多越好，只创建有明确业务价值的视图」原则。

### 设计目标

1. **简化多表连接查询**：封装课程、题型、章节、题目、套题等常用 JOIN，减少后端重复 SQL
2. **通过视图隐藏敏感字段**：体现数据库安全性中的视图隔离机制

### 视图列表

| 视图 | 用途 |
|------|------|
| `qbank.v_course_type_usage` | 查询各门课程使用的题型，**满足课程设计题目要求** |
| `qbank.v_question_public` | 普通查看题目视图，**隐藏 `answer` 和 `analysis`** |
| `qbank.v_question_teacher` | 教师题库管理视图，包含答案、解析及创建人信息 |
| `qbank.v_paper_detail` | 套题明细视图，展示试卷题目、顺序与分值 |
| `qbank.v_course_question_stat` | 课程题量统计视图，按课程/题型/章节汇总题量与指标 |

### 安全性说明

- **`v_question_public`** 不暴露 `answer` 和 `analysis` 字段，面向学生或普通预览场景
- 与 **`v_question_teacher`** 形成对比：后者供教师管理端使用，可查看完整题目信息
- 后续权限阶段（`09_init_roles.sql`）可只授权学生或普通用户访问 **`v_question_public`**，而不直接授予 `qbank.question` 表的 SELECT 权限

### 课程设计题目对应

**`v_course_type_usage`** 直接对应题目要求：「定义视图查询各门课程使用的题型」。以 `course_question_type` 为核心关联表，保留 `enabled` 字段，查询方可筛选全部配置或仅启用题型。

### 本阶段范围

- **已创建**：5 个普通视图（`CREATE OR REPLACE VIEW`）及 `COMMENT ON VIEW`
- **未创建**：函数（留待 `06_create_functions.sql`）、存储过程、触发器、初始化数据、角色授权
- **未使用**：物化视图、递归视图、安全屏障语法、视图内 `ORDER BY`

### 执行说明

- 视图脚本应在 `04_create_indexes.sql` 之后执行
- 推荐通过 `bash database/scripts/reset_db.sh` 删库重建后完整初始化

---

## 8. 函数与存储过程设计说明

`06_create_functions.sql` 与 `07_create_procedures.sql` 分别创建了 **5 个函数** 和 **4 个存储过程**，用于封装可复用逻辑与数据库侧核心业务。

### 函数列表

| 函数 | 用途 |
|------|------|
| `qbank.fn_check_course_type_enabled` | 检查指定课程是否启用了指定题型 |
| `qbank.fn_count_available_questions` | 统计符合筛选条件的可抽题数量 |
| `qbank.fn_calculate_paper_total_score` | 计算指定套题的题目总分 |
| `qbank.fn_recalculate_paper_score` | 重算并更新套题 `total_score` |
| `qbank.fn_write_audit_log` | 写入操作审计日志，供触发器或后端复用 |

### 存储过程列表

| 存储过程 | 用途 |
|----------|------|
| `qbank.sp_get_course_question_stat` | 查询指定课程各种题型和各章节题量，**满足课程设计题目要求** |
| `qbank.sp_get_all_course_type_stat` | 查询各门课程、各种题型题量，**满足课程设计题目要求** |
| `qbank.sp_generate_paper` | 自动抽题生成套题，**满足「可以自动抽题组成套题」要求** |
| `qbank.sp_recalculate_paper_score` | 重新计算指定套题总分 |

### 职责分工说明

- **自动组卷**由 `sp_generate_paper` 完成：创建 `paper`、`paper_rule`、`paper_question` 并调用 `fn_recalculate_paper_score`
- 自动组卷候选题会同时校验课程题型关系 `enabled=TRUE`，避免抽取已禁用题型下的题目
- **`question.extract_count + 1`** 与 **`extract_log` 写入**将在阶段 8（`08_create_triggers.sql`）通过触发器实现
- 本阶段**不创建触发器**，避免与存储过程职责混淆
- `sp_generate_paper` **不更新** `question.extract_count`，**不写入** `extract_log`

### 查询型存储过程调用方式

查询型存储过程使用 **`REFCURSOR`** 返回结果集。调用示例：

```sql
BEGIN;
CALL qbank.sp_get_course_question_stat(1, 'cur_course_stat');
FETCH ALL FROM cur_course_stat;
COMMIT;
```

```sql
BEGIN;
CALL qbank.sp_get_all_course_type_stat('cur_all_course_type');
FETCH ALL FROM cur_all_course_type;
COMMIT;
```

### 本阶段范围

- **已创建**：5 个 PL/pgSQL 函数、4 个 openGauss 原生存储过程
- **语法说明**：存储过程采用 openGauss 原生 `CREATE PROCEDURE ... IS ... BEGIN ... END; /` 形式编写，以保证 `gsql` 执行兼容性；函数仍使用 PL/pgSQL 风格
- **未创建**：触发器（留待 `08_create_triggers.sql`）、初始化数据、角色授权
- **未使用**：动态 SQL、DO 块、JSONB、事务内 COMMIT/ROLLBACK

### 执行说明

- 函数脚本应在 `05_create_views.sql` 之后执行
- 存储过程脚本应在 `06_create_functions.sql` 之后执行
- 推荐通过 `bash database/scripts/reset_db.sh` 删库重建后完整初始化

---

## 9. 触发器设计说明

`08_create_triggers.sql` 创建了 **3 个触发器函数** 和 **3 个触发器**，均围绕 `qbank.paper_question` 表设计。

### 设计目标

当题目被加入套题（插入 `paper_question`）时，自动完成：

1. 校验套题与题目属于同一课程
2. `question.extract_count + 1`
3. 写入 `extract_log` 抽题日志
4. 重算 `paper.total_score`

### 触发器函数与触发器

| 触发器函数 | 绑定触发器 | 触发时机 | 用途 |
|------------|------------|----------|------|
| `trg_fn_check_paper_question_integrity` | `trg_paper_question_before_ins_upd_check` | BEFORE INSERT OR UPDATE | 校验课程一致；禁止直接修改 `paper_id` / `question_id` |
| `trg_fn_after_paper_question_insert` | `trg_paper_question_after_insert_extract` | AFTER INSERT | 累加抽取次数、写入抽题日志、重算总分 |
| `trg_fn_after_paper_question_change_score` | `trg_paper_question_after_upd_del_score` | AFTER UPDATE OR DELETE | 更新或删除明细后重算总分 |

### 与存储过程的职责分工

- **自动组卷**：`sp_generate_paper` 负责创建 `paper`、`paper_rule` 并插入 `paper_question`
- **抽取次数与日志**：`sp_generate_paper` **不更新** `extract_count`、**不写入** `extract_log`；由 **`trg_paper_question_after_insert_extract`** 在 `paper_question` 插入后自动维护
- **题目要求对应**：直接满足「**习题每抽取一次，要使习题的抽取次数加 1，用触发器实现**」

### 语法说明

- 触发器函数使用 PL/pgSQL：`RETURNS TRIGGER` + `$$ LANGUAGE plpgsql;`
- 触发器使用 `EXECUTE PROCEDURE qbank.trg_fn_xxx();`（openGauss 兼容写法）

### 本阶段范围

- **已创建**：3 个触发器函数、3 个触发器及 `COMMENT ON FUNCTION`
- **未创建**：初始化数据（留待 `10_init_data.sql`）、角色授权（留待 `09_init_roles.sql`）

### 执行说明

- 触发器脚本应在 `07_create_procedures.sql` 之后执行
- 推荐通过 `bash database/scripts/reset_db.sh` 删库重建后完整初始化

---

## 10. 角色权限与初始化数据说明

`09_init_roles.sql` 与 `10_init_data.sql` 分别完成**数据库连接用户权限**与**演示数据初始化**，体现最小权限原则与可验收的演示环境。

### 角色权限设计（最小权限原则）

| 数据库用户 | 密码（演示） | 用途 |
|------------|--------------|------|
| `qbank_app` | `DataBase@2026` | **后端业务用户**，Flask 应用统一连接账号，**不使用 `omm`** |
| `qbank_readonly` | `ReadOnly@2026` | 只读审阅用户，课程验收或教师审阅 |
| `qbank_student_viewer` | `Student@2026` | 学生预览用户，仅访问不含答案解析的公开视图 |

### 各用户权限概要

**`qbank_app`**

- `CONNECT` + `USAGE ON SCHEMA qbank`
- `SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA qbank`
- `USAGE, SELECT ON ALL SEQUENCES IN SCHEMA qbank`
- `EXECUTE ON ALL FUNCTIONS IN SCHEMA qbank`（含存储过程调用）

**`qbank_readonly`**

- `CONNECT` + `USAGE ON SCHEMA qbank`
- 仅 `SELECT` 于 5 个视图：`v_course_type_usage`、`v_question_public`、`v_question_teacher`、`v_paper_detail`、`v_course_question_stat`
- 无增删改权限，不直接访问 `qbank.question`、`qbank.sys_user` 等基表

**`qbank_student_viewer`**

- `CONNECT` + `USAGE ON SCHEMA qbank`
- 仅 `SELECT` 于 2 个视图：`v_course_type_usage`、`v_question_public`
- **不能**访问 `qbank.question` 基表、`v_question_teacher`、`v_paper_detail`
- **`v_question_public`** 隐藏 `answer` 和 `analysis`，体现视图 + 权限的数据安全隔离

基础安全收敛：`REVOKE ALL ON SCHEMA qbank FROM PUBLIC;`

### 演示数据概要（`10_init_data.sql`）

| 数据类别 | 数量/说明 |
|----------|-----------|
| 应用层角色 | 3（admin、teacher、student） |
| 系统用户 | 4（admin_user、teacher_zhang、teacher_li、student_demo） |
| 教师 | 2 |
| 课程 | 2（数据库系统、数据结构） |
| 题型 | 4（单选、多选、判断、简答） |
| 课程题型关系 | 7 |
| 章节 | 5 |
| 知识点 | 5 |
| 题目标签 | 3 |
| 习题 | 8（含选项、1 条附件） |
| 试卷与明细 | 1 套试卷 + 3 条 `paper_question` |
| 组卷规则 | 1 |
| 系统配置 | 3 |
| 备份历史 / 审计日志 | 各 1 条 |

### 触发器与初始化数据的联动

插入 `paper_question` 时，**不手动**更新 `extract_count`、**不手动**插入 `extract_log`。触发器 `trg_paper_question_after_insert_extract` 会自动：

- 将题目 1、2、3 的 `extract_count` 各 **+1**
- 写入 **3 条** `extract_log`
- 将 `paper.total_score` 重算为 **5**（2 + 1 + 2）

### 本阶段范围

- **已创建**：3 个数据库用户及权限、`GRANT`/`REVOKE`、演示数据、`setval` 序列重置
- **未创建**：新的表结构、约束、索引、视图、函数、存储过程、触发器

### 执行说明

- 角色脚本应在 `08_create_triggers.sql` 之后执行
- 演示数据脚本应在 `09_init_roles.sql` 之后执行
- 推荐通过 `bash database/scripts/reset_db.sh` 删库重建后完整初始化

---

## 11. 测试 SQL 与脚本工具说明

`11_test_queries.sql` 与 `scripts/run_tests.sh` 完成**数据库验收测试**与**一键执行工具**，用于课程设计答辩与功能点逐项验证。

### 验收测试覆盖范围（`11_test_queries.sql`）

| 测试模块 | 说明 |
|----------|------|
| Schema 与对象数量 | `qbank` schema、21 张表、39 个索引、5 个视图、5 个函数、4 个存储过程、3 个触发器 |
| 表、约束、索引 | 主键完整性、关键唯一/外键/检查约束、7 个关键业务索引 |
| 视图与安全字段 | 5 个视图存在性；`v_question_public` 隐藏 `answer`/`analysis`；教师视图含答案解析 |
| 初始化数据 | 各业务表演示数据数量（角色、用户、课程、题目、试卷、日志等） |
| 课程设计题目要求 | 课程/题型/章节管理、题号自动生成、建立日期默认值、视图查询、存储过程统计 |
| 函数 | `fn_check_course_type_enabled`、`fn_count_available_questions`、`fn_calculate_paper_total_score` |
| 存储过程 | `sp_get_course_question_stat`、`sp_get_all_course_type_stat`、REFCURSOR 结果展示 |
| 自动组卷 | 事务内调用 `sp_generate_paper` 后 `ROLLBACK`，不污染演示数据 |
| 触发器 | `extract_count` 累加、`extract_log` 写入、`paper.total_score` 重算 |
| 角色权限 | 3 个数据库用户、只读/学生视图权限隔离、学生不能访问敏感对象 |
| 备份恢复支撑 | `backup_history` 演示记录；脚本存在性由 `run_tests.sh` 检查 |

### 一键执行测试（`run_tests.sh`）

`scripts/run_tests.sh` 会：

1. 检查 Docker 与容器 `qbank-opengauss`（未运行则自动启动）
2. 检查 `11_test_queries.sql`、备份脚本与 `backup/` 目录
3. 将测试 SQL 复制到容器并执行
4. **不会**自动执行 `reset_db.sh`，避免误删当前数据

**常用命令：**

```bash
# 在当前已初始化库上执行验收测试
bash database/scripts/run_tests.sh

# 从空库完整重建后再测试（推荐答辩前使用）
bash database/scripts/reset_db.sh
bash database/scripts/run_tests.sh
```

测试输出使用 `[INFO]`、`[PASS]`、`[FAIL]`、`[WARN]`、`[DONE]` 中文提示，便于终端展示。

### 本阶段范围

- **已创建**：`11_test_queries.sql`、`scripts/run_tests.sh`；修复 `09_init_roles.sql` 重复 `ALTER USER` 改密报错
- **未创建**：新的表结构、约束、索引、视图、函数、存储过程、触发器、初始化数据

---

## 12. 清理脚本说明（`00_drop_all.sql`）

`00_drop_all.sql` 用于在 **`qbank_db` 数据库内部**清理本项目创建的对象，方便开发阶段反复重建，**不负责删除数据库本身**。

主要行为：

- 执行 `DROP SCHEMA IF EXISTS qbank CASCADE;`，删除 `qbank` schema 及其下所有依赖对象
- 顺手清理早期测试阶段在 `public` 下创建的临时测试表：`public.course`、`public.question_type`
- **不会**删除 `qbank_db` 数据库本身
- **不会**删除 `omm` 用户或 openGauss 系统对象
- **不会**删除业务用户角色（角色清理与重建由 `09_init_roles.sql` 统一处理）

使用场景：

- 需要保留 `qbank_db` 数据库、仅清空内部业务对象时，**手动执行** `00_drop_all.sql`
- 需要完全删除并重建整个数据库时，使用 `scripts/reset_db.sh`（删库重建后无需再执行 `00_drop_all.sql`）

> **注意**：`init_db.sh` **不会**自动执行 `00_drop_all.sql`，避免初始化时误删已有对象。

---

## 13. SQL 文件执行顺序

数据库初始化时应按以下顺序执行 SQL 脚本（`init_db.sh` 已内置该顺序，跳过尚未创建的文件）：

1. **清理旧对象** — `00_drop_all.sql`（**手动执行**；`reset_db.sh` 通过删库重建替代此步骤）
2. **创建 Schema** — `01_create_schema.sql`
3. **创建表** — `02_create_tables.sql`
4. **创建约束** — `03_create_constraints.sql`
5. **创建索引** — `04_create_indexes.sql`
6. **创建视图** — `05_create_views.sql`
7. **创建函数** — `06_create_functions.sql`
8. **创建存储过程** — `07_create_procedures.sql`
9. **创建触发器** — `08_create_triggers.sql`
10. **初始化角色和权限** — `09_init_roles.sql`
11. **初始化演示数据** — `10_init_data.sql`
12. **运行测试查询** — `11_test_queries.sql`（手动执行，用于验收与调试）

---

## 14. 初始化流程说明

`scripts/init_db.sh` 的完整流程如下：

1. 检查 Docker 是否可用
2. 检查容器 `qbank-opengauss` 是否存在；若未运行则自动启动
3. 检查数据库 `qbank_db` 是否存在；若不存在则连接 `postgres` 创建
4. 按顺序执行以下 SQL 文件（**存在则执行，不存在则跳过并提示**）：
   - `01_create_schema.sql` → `02_create_tables.sql` → … → `10_init_data.sql`
5. **不执行** `00_drop_all.sql`（清理由手动或 `reset_db.sh` 负责）

当前阶段（阶段 9）已存在 `01_create_schema.sql` ~ `11_test_queries.sql`，执行 `init_db.sh` 会：

- 创建 `qbank_db`（若不存在）
- 执行 `01_create_schema.sql` 创建 `qbank` schema
- 执行 `02_create_tables.sql` 创建 21 张核心数据表
- 执行 `03_create_constraints.sql` 创建完整性约束
- 执行 `04_create_indexes.sql` 创建 39 个业务查询索引
- 执行 `05_create_views.sql` 创建 5 个业务视图
- 执行 `06_create_functions.sql` 创建 5 个函数
- 执行 `07_create_procedures.sql` 创建 4 个存储过程
- 执行 `08_create_triggers.sql` 创建 3 个触发器函数与 3 个触发器
- 执行 `09_init_roles.sql` 创建 3 个数据库用户并授权
- 执行 `10_init_data.sql` 插入演示数据并重置序列
- 对 `11_test_queries.sql` **不自动执行**（由 `run_tests.sh` 或手动执行）

验收测试请执行：

```bash
bash database/scripts/run_tests.sh
```

`scripts/reset_db.sh` 的流程：

1. 删除并重建整个 `qbank_db` 数据库
2. 自动调用 `init_db.sh` 完成初始化
3. 无需额外执行 `00_drop_all.sql`（数据库已重建，内部为空）

---

## 15. 当前 Docker openGauss 连接信息

| 项目 | 值 |
|------|-----|
| 容器名 | `qbank-opengauss` |
| 管理用户 | `omm` |
| 容器内数据库端口 | `5432` |
| 宿主机映射端口 | `15432` |
| 正式数据库名 | `qbank_db` |
| 后端业务用户（后续） | `qbank_app` |
| 后端业务用户密码（后续） | `DataBase@2026` |

- 在容器内连接数据库时，使用 `gsql` 命令，默认连接容器内部端口 `5432`。
- 从宿主机或 Python Flask 后端访问时，使用主机 `localhost`（或容器 IP）及端口 **15432**。
- 后端业务连接应统一使用 **`qbank_app`**，不建议使用超级用户 `omm` 作为应用连接账号。

---

## 16. 常用命令说明

以下命令均在项目根目录或 `database/scripts/` 下执行。首次使用前请赋予脚本执行权限：

```bash
chmod +x database/scripts/*.sh
```

### 进入数据库

```bash
docker exec -it qbank-opengauss bash -lc "su - omm -c 'gsql -d qbank_db -p 5432'"
```

以管理用户 `omm` 进入 `qbank_db` 的交互式 `gsql` 客户端（容器内端口 5432）。

### 初始化数据库

```bash
bash database/scripts/init_db.sh
```

检查 Docker 与容器环境，创建 `qbank_db`（若不存在），并按顺序执行已存在的建库 SQL 脚本。

### 重置数据库

```bash
bash database/scripts/reset_db.sh
```

删除并重新创建 `qbank_db`，然后自动调用 `init_db.sh` 完成初始化。适用于需要完全清空数据的场景。

### 备份数据库

```bash
bash database/scripts/backup_db.sh
```

对 `qbank_db` 进行逻辑备份，备份文件保存至 `database/backup/`，文件名格式为 `qbank_db_YYYYMMDD_HHMMSS.sql`。

容器内使用 openGauss 的 `gs_dump`，数据库名作为**位置参数**传入（不支持 `-d`）：

```text
gs_dump -p 5432 qbank_db -f /tmp/qbank_db_YYYYMMDD_HHMMSS.sql
```

备份完成后脚本会检查本地文件是否存在且非空。

### 恢复数据库

```bash
bash database/scripts/restore_db.sh database/backup/qbank_db_YYYYMMDD_HHMMSS.sql
```

从指定备份文件恢复数据。**建议在恢复前先执行 `reset_db.sh`**，或手动确认当前库状态，避免与现有对象冲突。

### 执行验收测试

```bash
bash database/scripts/run_tests.sh
```

一键执行 `11_test_queries.sql`，检查 schema、约束、视图、触发器、权限与演示数据等验收项。脚本**不会**自动执行 `reset_db.sh`。

如需从空库完整测试，建议先重建再测试：

```bash
bash database/scripts/reset_db.sh
bash database/scripts/run_tests.sh
```

---

## 17. 协同开发约定

1. **职责划分**：数据库开发人员负责维护 `database/` 目录下的 SQL 脚本与运维脚本；表结构变更应提交 SQL 文件，而非仅在本地手动修改。
2. **后端协作**：后端开发人员**不直接手动修改**生产/共享环境的数据库结构，应通过执行本目录 SQL 脚本完成初始化与升级。
3. **环境一致**：所有成员在本地部署 openGauss（Docker），通过共享同一套 SQL 脚本保持数据库结构一致。
4. **连接账号**：**不建议**使用 `omm` 作为 Flask 后端业务连接用户；后端应统一使用 **`qbank_app`**（在 `09_init_roles.sql` 中创建并授权）。
5. **版本管理**：备份文件体积较大时不宜提交至 Git，详见 `backup/README.md`。
6. **Schema 规范**：后续所有正式对象必须使用 `qbank.` 前缀，不要放在 `public` schema 下。

---

## 目录结构概览

```text
database/
│  README.md
│  00_drop_all.sql
│  01_create_schema.sql
│  02_create_tables.sql
│  03_create_constraints.sql
│  04_create_indexes.sql
│  05_create_views.sql
│  06_create_functions.sql
│  07_create_procedures.sql
│  08_create_triggers.sql
│  09_init_roles.sql
│  10_init_data.sql
│  11_test_queries.sql
│
├─ backup/
│  │  .gitkeep
│  │  README.md
│
└─ scripts/
   │  init_db.sh
   │  reset_db.sh
   │  backup_db.sh
   │  restore_db.sh
   │  run_tests.sh
```
