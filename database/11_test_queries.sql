-- =============================================================================
-- 文件名：11_test_queries.sql
-- 作用：题库管理系统数据库验收测试脚本
-- 所属数据库：qbank_db
-- 所属 schema：qbank
-- 说明：
--   - 本文件用于检查 schema、表、约束、索引、视图、函数、存储过程、触发器、
--     角色权限、初始化数据、自动组卷和备份恢复支撑情况
--   - 本文件不创建表、约束、索引、视图、函数、存储过程、触发器和初始化数据
--   - 本文件建议在完整执行 reset_db.sh 后手动执行，或通过 run_tests.sh 一键执行
--   - 测试输出使用 [INFO]、[PASS]、[WARN]、[FAIL]、[DONE] 等中文提示
-- =============================================================================

\echo '============================================================'
\echo '[INFO] 题库管理系统数据库验收测试开始'
\echo '============================================================'

\timing on
\pset border 2
\pset null '[NULL]'
\pset pager off

SET search_path TO qbank, public;

-- =============================================================================
-- 测试项 1：Schema 与对象数量检查
-- =============================================================================

\echo ''
\echo '------------------------------------------------------------'
\echo '[INFO] 测试项 1：Schema 与对象数量检查'
\echo '------------------------------------------------------------'

SELECT
    'qbank schema 存在性检查' AS 测试项目,
    COUNT(*) AS 实际值,
    1 AS 预期值,
    CASE WHEN COUNT(*) = 1 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    'qbank 业务 schema 应存在' AS 说明
FROM information_schema.schemata
WHERE schema_name = 'qbank';

SELECT
    '核心表数量检查' AS 测试项目,
    COUNT(*) AS 实际值,
    21 AS 预期值,
    CASE WHEN COUNT(*) = 21 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    'qbank schema 下应有 21 张核心表' AS 说明
FROM information_schema.tables
WHERE table_schema = 'qbank'
  AND table_type = 'BASE TABLE';

SELECT
    '业务索引数量检查' AS 测试项目,
    COUNT(*) AS 实际值,
    39 AS 预期值,
    CASE WHEN COUNT(*) = 39 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    '04_create_indexes.sql 创建的 idx_* 业务索引（不含主键/唯一约束自动索引）' AS 说明
FROM pg_indexes
WHERE schemaname = 'qbank'
  AND indexname LIKE 'idx_%';

SELECT
    '业务视图数量检查' AS 测试项目,
    COUNT(*) AS 实际值,
    5 AS 预期值,
    CASE WHEN COUNT(*) = 5 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    '05_create_views.sql 创建的业务视图' AS 说明
FROM information_schema.views
WHERE table_schema = 'qbank';

SELECT
    '业务函数数量检查' AS 测试项目,
    COUNT(*) AS 实际值,
    5 AS 预期值,
    CASE WHEN COUNT(*) = 5 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    'fn_* 前缀业务函数（不含触发器函数）' AS 说明
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'qbank'
  AND p.proname LIKE 'fn_%';

SELECT
    '存储过程数量检查' AS 测试项目,
    COUNT(*) AS 实际值,
    4 AS 预期值,
    CASE WHEN COUNT(*) = 4 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    'sp_* 前缀存储过程' AS 说明
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'qbank'
  AND p.proname LIKE 'sp_%';

SELECT
    '触发器函数数量检查' AS 测试项目,
    COUNT(*) AS 实际值,
    3 AS 预期值,
    CASE WHEN COUNT(*) = 3 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    'trg_fn_* 前缀触发器函数' AS 说明
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'qbank'
  AND p.proname LIKE 'trg_fn_%';

SELECT
    'paper_question 用户触发器数量检查' AS 测试项目,
    COUNT(*) AS 实际值,
    3 AS 预期值,
    CASE WHEN COUNT(*) = 3 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    'paper_question 表应绑定 3 个用户触发器' AS 说明
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'qbank'
  AND c.relname = 'paper_question'
  AND NOT t.tgisinternal;

-- =============================================================================
-- 测试项 2：完整性约束检查
-- =============================================================================

\echo ''
\echo '------------------------------------------------------------'
\echo '[INFO] 测试项 2：完整性约束检查'
\echo '------------------------------------------------------------'

SELECT
    '核心表主键完整性检查' AS 测试项目,
    t.table_count AS 表总数,
    pk.pk_count AS 有主键表数,
    CASE WHEN t.table_count = pk.pk_count AND t.table_count = 21
         THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    '21 张核心表均应定义主键' AS 说明
FROM (
    SELECT COUNT(*) AS table_count
    FROM information_schema.tables
    WHERE table_schema = 'qbank'
      AND table_type = 'BASE TABLE'
) t,
(
    SELECT COUNT(DISTINCT tc.table_name) AS pk_count
    FROM information_schema.table_constraints tc
    WHERE tc.table_schema = 'qbank'
      AND tc.constraint_type = 'PRIMARY KEY'
) pk;

SELECT
    c.conname AS 约束名称,
    CASE WHEN c.conname IS NOT NULL THEN '[PASS] 存在' ELSE '[FAIL] 不存在' END AS 检查结果,
    '关键唯一约束' AS 约束类型
FROM (
    VALUES
        ('uq_course_question_type_course_type'),
        ('uq_chapter_course_chapter'),
        ('uq_knowledge_point_course_chapter_point'),
        ('uq_paper_question_paper_question')
) AS req(conname)
LEFT JOIN pg_constraint c ON c.conname = req.conname
LEFT JOIN pg_namespace n ON n.oid = c.connamespace AND n.nspname = 'qbank';

SELECT
    c.conname AS 约束名称,
    CASE WHEN c.conname IS NOT NULL THEN '[PASS] 存在' ELSE '[FAIL] 不存在' END AS 检查结果,
    '关键外键约束' AS 约束类型
FROM (
    VALUES
        ('fk_question_course_type'),
        ('fk_question_chapter'),
        ('fk_question_knowledge_point'),
        ('fk_paper_question_paper'),
        ('fk_paper_question_question')
) AS req(conname)
LEFT JOIN pg_constraint c ON c.conname = req.conname
LEFT JOIN pg_namespace n ON n.oid = c.connamespace AND n.nspname = 'qbank';

SELECT
    c.conname AS 约束名称,
    CASE WHEN c.conname IS NOT NULL THEN '[PASS] 存在' ELSE '[FAIL] 不存在' END AS 检查结果,
    '关键检查约束' AS 约束类型
FROM (
    VALUES
        ('ck_question_difficulty'),
        ('ck_question_extract_count'),
        ('ck_paper_question_score')
) AS req(conname)
LEFT JOIN pg_constraint c ON c.conname = req.conname
LEFT JOIN pg_namespace n ON n.oid = c.connamespace AND n.nspname = 'qbank';

-- =============================================================================
-- 测试项 3：索引检查
-- =============================================================================

\echo ''
\echo '------------------------------------------------------------'
\echo '[INFO] 测试项 3：关键业务索引检查'
\echo '------------------------------------------------------------'

SELECT
    req.index_name AS 索引名称,
    CASE WHEN idx.indexname IS NOT NULL THEN '[PASS] 存在' ELSE '[FAIL] 不存在' END AS 检查结果,
    '关键业务索引' AS 说明
FROM (
    VALUES
        ('idx_question_auto_pick'),
        ('idx_question_course_type_status'),
        ('idx_question_course_chapter_status'),
        ('idx_paper_course_status_created'),
        ('idx_paper_question_paper_order'),
        ('idx_extract_log_question_time'),
        ('idx_audit_log_table_operation_time')
) AS req(index_name)
LEFT JOIN pg_indexes idx
    ON idx.schemaname = 'qbank'
   AND idx.indexname = req.index_name;

-- =============================================================================
-- 测试项 4：视图设计与安全字段检查
-- =============================================================================

\echo ''
\echo '------------------------------------------------------------'
\echo '[INFO] 测试项 4：视图设计与安全字段检查'
\echo '------------------------------------------------------------'

SELECT
    req.view_name AS 视图名称,
    CASE WHEN v.table_name IS NOT NULL THEN '[PASS] 存在' ELSE '[FAIL] 不存在' END AS 检查结果
FROM (
    VALUES
        ('v_course_type_usage'),
        ('v_question_public'),
        ('v_question_teacher'),
        ('v_paper_detail'),
        ('v_course_question_stat')
) AS req(view_name)
LEFT JOIN information_schema.views v
    ON v.table_schema = 'qbank'
   AND v.table_name = req.view_name;

SELECT
    'v_question_public 不含 answer 字段' AS 测试项目,
    COUNT(*) AS 实际值,
    0 AS 预期值,
    CASE WHEN COUNT(*) = 0 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    '学生视图隐藏答案，体现视图安全隔离' AS 说明
FROM information_schema.columns
WHERE table_schema = 'qbank'
  AND table_name = 'v_question_public'
  AND column_name = 'answer';

SELECT
    'v_question_public 不含 analysis 字段' AS 测试项目,
    COUNT(*) AS 实际值,
    0 AS 预期值,
    CASE WHEN COUNT(*) = 0 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    '学生视图隐藏解析，体现视图安全隔离' AS 说明
FROM information_schema.columns
WHERE table_schema = 'qbank'
  AND table_name = 'v_question_public'
  AND column_name = 'analysis';

SELECT
    'v_question_teacher 包含 answer 字段' AS 测试项目,
    COUNT(*) AS 实际值,
    1 AS 预期值,
    CASE WHEN COUNT(*) = 1 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    '教师视图应包含答案供审阅' AS 说明
FROM information_schema.columns
WHERE table_schema = 'qbank'
  AND table_name = 'v_question_teacher'
  AND column_name = 'answer';

SELECT
    'v_question_teacher 包含 analysis 字段' AS 测试项目,
    COUNT(*) AS 实际值,
    1 AS 预期值,
    CASE WHEN COUNT(*) = 1 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果,
    '教师视图应包含解析供审阅' AS 说明
FROM information_schema.columns
WHERE table_schema = 'qbank'
  AND table_name = 'v_question_teacher'
  AND column_name = 'analysis';

\echo '[INFO] 学生视图 v_question_public 隐藏答案和解析，体现视图安全隔离。'

\echo '[INFO] 展示 v_question_public 前 5 条题目（不含答案与解析）：'
SELECT question_id, course_name, type_name, chapter_name, stem, difficulty, score, status
FROM qbank.v_question_public
ORDER BY question_id
LIMIT 5;

\echo '[INFO] 展示 v_course_type_usage 课程题型配置：'
SELECT course_id, course_name, type_id, type_name, default_score, enabled, sort_no
FROM qbank.v_course_type_usage
ORDER BY course_id, sort_no;

-- =============================================================================
-- 测试项 5：初始化数据数量检查
-- =============================================================================

\echo ''
\echo '------------------------------------------------------------'
\echo '[INFO] 测试项 5：初始化数据数量检查'
\echo '------------------------------------------------------------'

SELECT * FROM (
    SELECT 'sys_role' AS 数据表, COUNT(*) AS 实际值, 3 AS 预期值,
           CASE WHEN COUNT(*) = 3 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果
    FROM qbank.sys_role
    UNION ALL
    SELECT 'sys_user', COUNT(*), 4,
           CASE WHEN COUNT(*) = 4 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.sys_user
    UNION ALL
    SELECT 'teacher', COUNT(*), 2,
           CASE WHEN COUNT(*) = 2 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.teacher
    UNION ALL
    SELECT 'course', COUNT(*), 2,
           CASE WHEN COUNT(*) = 2 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.course
    UNION ALL
    SELECT 'question_type', COUNT(*), 4,
           CASE WHEN COUNT(*) = 4 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.question_type
    UNION ALL
    SELECT 'course_question_type', COUNT(*), 7,
           CASE WHEN COUNT(*) = 7 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.course_question_type
    UNION ALL
    SELECT 'chapter', COUNT(*), 5,
           CASE WHEN COUNT(*) = 5 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.chapter
    UNION ALL
    SELECT 'knowledge_point', COUNT(*), 5,
           CASE WHEN COUNT(*) = 5 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.knowledge_point
    UNION ALL
    SELECT 'question_tag', COUNT(*), 3,
           CASE WHEN COUNT(*) = 3 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.question_tag
    UNION ALL
    SELECT 'question', COUNT(*), 8,
           CASE WHEN COUNT(*) = 8 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.question
    UNION ALL
    SELECT 'question_option', COUNT(*), 20,
           CASE WHEN COUNT(*) = 20 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.question_option
    UNION ALL
    SELECT 'question_attachment', COUNT(*), 1,
           CASE WHEN COUNT(*) = 1 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.question_attachment
    UNION ALL
    SELECT 'paper', COUNT(*), 1,
           CASE WHEN COUNT(*) = 1 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.paper
    UNION ALL
    SELECT 'paper_question', COUNT(*), 3,
           CASE WHEN COUNT(*) = 3 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.paper_question
    UNION ALL
    SELECT 'paper_rule', COUNT(*), 1,
           CASE WHEN COUNT(*) = 1 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.paper_rule
    UNION ALL
    SELECT 'system_config', COUNT(*), 3,
           CASE WHEN COUNT(*) = 3 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.system_config
    UNION ALL
    SELECT 'backup_history', COUNT(*), 1,
           CASE WHEN COUNT(*) = 1 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.backup_history
    UNION ALL
    SELECT 'audit_log', COUNT(*), 1,
           CASE WHEN COUNT(*) >= 1 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.audit_log
    UNION ALL
    SELECT 'extract_log', COUNT(*), 3,
           CASE WHEN COUNT(*) = 3 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
    FROM qbank.extract_log
) AS init_data_check
ORDER BY 数据表;

-- =============================================================================
-- 测试项 6：课程设计题目要求功能检查
-- =============================================================================

\echo ''
\echo '------------------------------------------------------------'
\echo '[INFO] 测试项 6：课程设计题目要求功能检查'
\echo '------------------------------------------------------------'

\echo '[INFO] 6.1 课程、题型基本信息管理'
SELECT course_id, course_code, course_name, credit, status
FROM qbank.course
ORDER BY course_id;

SELECT type_id, type_code, type_name, default_score, objective_flag, status
FROM qbank.question_type
ORDER BY type_id;

\echo '[INFO] 6.2 每门课程的题型（v_course_type_usage）'
SELECT course_name, type_name, default_score, enabled
FROM qbank.v_course_type_usage
ORDER BY course_id, sort_no;

\echo '[INFO] 6.3 每门课程的章节'
SELECT c.course_name, ch.chapter_no, ch.chapter_name, ch.status
FROM qbank.chapter ch
JOIN qbank.course c ON c.course_id = ch.course_id
ORDER BY ch.course_id, ch.sort_no;

\echo '[INFO] 6.4 按题型或章节录入课程习题分布'
SELECT course_name, type_name, chapter_name, COUNT(*) AS 题目数量
FROM qbank.v_question_teacher
GROUP BY course_name, type_name, chapter_name
ORDER BY course_name, type_name, chapter_name;

\echo '[INFO] 6.5 每个习题题号自动生成'
SELECT
    '题号自动生成检查' AS 测试项目,
    MIN(question_id) AS 最小题号,
    MAX(question_id) AS 最大题号,
    COUNT(*) AS 题目数量,
    CASE WHEN MIN(question_id) = 1 AND COUNT(*) = 8 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果
FROM qbank.question;

\echo '[INFO] 6.6 建立日期默认系统时间'
SELECT
    '习题建立日期默认值检查' AS 测试项目,
    COUNT(*) AS 题目总数,
    COUNT(created_at) AS 已有建立日期数量,
    CASE WHEN COUNT(*) = COUNT(created_at) THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果
FROM qbank.question;

\echo '[INFO] 6.7 视图查询各门课程使用的题型'
SELECT course_name, type_name, default_score, enabled, sort_no
FROM qbank.v_course_type_usage
ORDER BY course_id, sort_no;

\echo '[INFO] 6.8 存储过程 sp_get_course_question_stat：查询数据库系统课程各题型与章节题量'
BEGIN;
CALL qbank.sp_get_course_question_stat(1, 'cur_course_stat');
FETCH ALL FROM cur_course_stat;
COMMIT;

\echo '[INFO] 6.9 存储过程 sp_get_all_course_type_stat：查询各课程各题型题量'
BEGIN;
CALL qbank.sp_get_all_course_type_stat('cur_all_course_type_stat');
FETCH ALL FROM cur_all_course_type_stat;
COMMIT;

\echo '[INFO] 6.10 事务内测试自动组卷 sp_generate_paper，测试完成后 ROLLBACK，不污染演示数据'
BEGIN;
CALL qbank.sp_generate_paper(
    '自动组卷功能测试卷',
    1,
    1,
    NULL,
    NULL,
    2,
    2.00,
    2,
    NULL
);

SELECT paper_id, paper_name, course_id, paper_type, total_score
FROM qbank.paper
WHERE paper_name = '自动组卷功能测试卷'
ORDER BY paper_id DESC
LIMIT 1;

SELECT pq.paper_id, pq.question_id, pq.order_no, pq.score
FROM qbank.paper_question pq
JOIN qbank.paper p ON p.paper_id = pq.paper_id
WHERE p.paper_name = '自动组卷功能测试卷'
ORDER BY pq.order_no;

ROLLBACK;

\echo '[INFO] 6.11 触发器实现抽取次数 +1'
SELECT
    '触发器抽取次数检查' AS 测试项目,
    SUM(CASE WHEN question_id IN (1, 2, 3) AND extract_count = 1 THEN 1 ELSE 0 END) AS 符合预期题目数,
    3 AS 预期值,
    CASE
        WHEN SUM(CASE WHEN question_id IN (1, 2, 3) AND extract_count = 1 THEN 1 ELSE 0 END) = 3
        THEN '[PASS] 通过'
        ELSE '[FAIL] 失败'
    END AS 测试结果
FROM qbank.question;

SELECT question_id, LEFT(stem, 40) AS stem_preview, extract_count
FROM qbank.question
ORDER BY question_id;

\echo '[INFO] 6.12 数据备份和恢复支撑（backup_history 演示记录）'
SELECT backup_id, file_name, backup_type, status, created_at, remark
FROM qbank.backup_history;

-- =============================================================================
-- 测试项 7：触发器与日志联动检查
-- =============================================================================

\echo ''
\echo '------------------------------------------------------------'
\echo '[INFO] 测试项 7：触发器与日志联动检查'
\echo '------------------------------------------------------------'

SELECT
    'extract_log 数量检查' AS 测试项目,
    COUNT(*) AS 实际值,
    3 AS 预期值,
    CASE WHEN COUNT(*) = 3 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果
FROM qbank.extract_log;

SELECT
    'paper.total_score 检查' AS 测试项目,
    total_score AS 实际值,
    5.00 AS 预期值,
    CASE WHEN total_score = 5.00 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果
FROM qbank.paper
WHERE paper_id = 1;

SELECT
    '题目 1/2/3 extract_count 检查' AS 测试项目,
    SUM(CASE WHEN question_id IN (1, 2, 3) AND extract_count = 1 THEN 1 ELSE 0 END) AS 实际值,
    3 AS 预期值,
    CASE
        WHEN SUM(CASE WHEN question_id IN (1, 2, 3) AND extract_count = 1 THEN 1 ELSE 0 END) = 3
        THEN '[PASS] 通过'
        ELSE '[FAIL] 失败'
    END AS 测试结果
FROM qbank.question;

\echo '[INFO] extract_log 与试卷、题目关联展示：'
SELECT
    el.extract_log_id,
    p.paper_name,
    q.question_id,
    LEFT(q.stem, 30) AS stem_preview,
    el.operator_id,
    el.extracted_at,
    el.remark
FROM qbank.extract_log el
JOIN qbank.paper p ON p.paper_id = el.paper_id
JOIN qbank.question q ON q.question_id = el.question_id
ORDER BY el.extract_log_id;

-- =============================================================================
-- 测试项 8：角色权限检查
-- =============================================================================

\echo ''
\echo '------------------------------------------------------------'
\echo '[INFO] 测试项 8：角色权限检查'
\echo '------------------------------------------------------------'

SELECT
    '数据库用户存在性检查' AS 测试项目,
    COUNT(*) AS 实际值,
    3 AS 预期值,
    CASE WHEN COUNT(*) = 3 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果
FROM pg_roles
WHERE rolname IN ('qbank_app', 'qbank_readonly', 'qbank_student_viewer');

SELECT
    '只读审阅用户视图 SELECT 权限数量' AS 测试项目,
    COUNT(DISTINCT table_name) AS 实际值,
    5 AS 预期值,
    CASE WHEN COUNT(DISTINCT table_name) = 5 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果
FROM information_schema.role_table_grants
WHERE table_schema = 'qbank'
  AND grantee = 'qbank_readonly'
  AND privilege_type = 'SELECT';

SELECT
    '学生预览用户视图 SELECT 权限数量' AS 测试项目,
    COUNT(DISTINCT table_name) AS 实际值,
    2 AS 预期值,
    CASE WHEN COUNT(DISTINCT table_name) = 2 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果
FROM information_schema.role_table_grants
WHERE table_schema = 'qbank'
  AND grantee = 'qbank_student_viewer'
  AND privilege_type = 'SELECT';

SELECT
    '学生用户不能访问 question 基表权限检查' AS 测试项目,
    COUNT(*) AS 非法授权数量,
    0 AS 预期值,
    CASE WHEN COUNT(*) = 0 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果
FROM information_schema.role_table_grants
WHERE table_schema = 'qbank'
  AND grantee = 'qbank_student_viewer'
  AND table_name IN ('question', 'v_question_teacher', 'v_paper_detail');

\echo '[INFO] 只读审阅与学生预览用户权限明细：'
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'qbank'
  AND grantee IN ('qbank_readonly', 'qbank_student_viewer')
ORDER BY grantee, table_name, privilege_type;

-- =============================================================================
-- 测试项 9：关键函数测试
-- =============================================================================

\echo ''
\echo '------------------------------------------------------------'
\echo '[INFO] 测试项 9：关键函数测试'
\echo '------------------------------------------------------------'

SELECT
    '课程题型启用函数检查' AS 测试项目,
    qbank.fn_check_course_type_enabled(1, 1) AS 实际结果,
    TRUE AS 预期结果,
    CASE WHEN qbank.fn_check_course_type_enabled(1, 1) = TRUE THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果;

SELECT
    '可抽题数量函数检查' AS 测试项目,
    qbank.fn_count_available_questions(1, 1, NULL, NULL) AS 实际值,
    CASE WHEN qbank.fn_count_available_questions(1, 1, NULL, NULL) >= 1 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果;

SELECT
    '试卷总分计算函数检查' AS 测试项目,
    qbank.fn_calculate_paper_total_score(1) AS 实际总分,
    5.00 AS 预期总分,
    CASE WHEN qbank.fn_calculate_paper_total_score(1) = 5.00 THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果;

-- =============================================================================
-- 测试项 10：备份恢复脚本提示
-- =============================================================================

\echo ''
\echo '------------------------------------------------------------'
\echo '[INFO] 测试项 10：备份恢复脚本提示'
\echo '------------------------------------------------------------'

\echo '[INFO] 备份与恢复功能由 scripts/backup_db.sh 和 scripts/restore_db.sh 实现。'
\echo '[INFO] 可在终端执行 bash database/scripts/backup_db.sh 生成逻辑备份。'
\echo '[INFO] 可在终端执行 bash database/scripts/restore_db.sh <备份文件> 恢复。'
\echo '[INFO] backup/README.md 与脚本存在性由 run_tests.sh 启动时检查。'

-- =============================================================================
-- 测试项 11：最终汇总
-- =============================================================================

\echo ''
\echo '------------------------------------------------------------'
\echo '[INFO] 测试项 11：最终验收汇总'
\echo '------------------------------------------------------------'

SELECT
    '核心表数量' AS 检查项,
    (SELECT COUNT(*) FROM information_schema.tables
     WHERE table_schema = 'qbank' AND table_type = 'BASE TABLE') AS 实际值,
    21 AS 预期值,
    CASE WHEN (SELECT COUNT(*) FROM information_schema.tables
               WHERE table_schema = 'qbank' AND table_type = 'BASE TABLE') = 21
         THEN '[PASS] 通过' ELSE '[FAIL] 失败' END AS 测试结果
UNION ALL
SELECT
    '索引数量',
    (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'qbank' AND indexname LIKE 'idx_%'),
    39,
    CASE WHEN (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'qbank' AND indexname LIKE 'idx_%') = 39
         THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
UNION ALL
SELECT
    '视图数量',
    (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'qbank'),
    5,
    CASE WHEN (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'qbank') = 5
         THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
UNION ALL
SELECT
    '函数数量',
    (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'qbank' AND p.proname LIKE 'fn_%'),
    5,
    CASE WHEN (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = 'qbank' AND p.proname LIKE 'fn_%') = 5
         THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
UNION ALL
SELECT
    '存储过程数量',
    (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'qbank' AND p.proname LIKE 'sp_%'),
    4,
    CASE WHEN (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = 'qbank' AND p.proname LIKE 'sp_%') = 4
         THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
UNION ALL
SELECT
    '触发器数量',
    (SELECT COUNT(*) FROM pg_trigger t
     JOIN pg_class c ON c.oid = t.tgrelid
     JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'qbank' AND c.relname = 'paper_question' AND NOT t.tgisinternal),
    3,
    CASE WHEN (SELECT COUNT(*) FROM pg_trigger t
               JOIN pg_class c ON c.oid = t.tgrelid
               JOIN pg_namespace n ON n.oid = c.relnamespace
               WHERE n.nspname = 'qbank' AND c.relname = 'paper_question' AND NOT t.tgisinternal) = 3
         THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
UNION ALL
SELECT
    '题目数量',
    (SELECT COUNT(*) FROM qbank.question),
    8,
    CASE WHEN (SELECT COUNT(*) FROM qbank.question) = 8
         THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
UNION ALL
SELECT
    '试卷数量',
    (SELECT COUNT(*) FROM qbank.paper),
    1,
    CASE WHEN (SELECT COUNT(*) FROM qbank.paper) = 1
         THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
UNION ALL
SELECT
    '抽题日志数量',
    (SELECT COUNT(*) FROM qbank.extract_log),
    3,
    CASE WHEN (SELECT COUNT(*) FROM qbank.extract_log) = 3
         THEN '[PASS] 通过' ELSE '[FAIL] 失败' END
UNION ALL
SELECT
    '学生权限安全检查',
    (SELECT COUNT(*) FROM information_schema.role_table_grants
     WHERE table_schema = 'qbank'
       AND grantee = 'qbank_student_viewer'
       AND table_name IN ('question', 'v_question_teacher', 'v_paper_detail')),
    0,
    CASE WHEN (SELECT COUNT(*) FROM information_schema.role_table_grants
               WHERE table_schema = 'qbank'
                 AND grantee = 'qbank_student_viewer'
                 AND table_name IN ('question', 'v_question_teacher', 'v_paper_detail')) = 0
         THEN '[PASS] 通过' ELSE '[FAIL] 失败' END;

\echo ''
\echo '============================================================'
\echo '[DONE] 题库管理系统数据库验收测试脚本执行完成'
\echo '============================================================'
