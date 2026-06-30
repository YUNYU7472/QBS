-- =============================================================================
-- 文件名：05_create_views.sql
-- 作用：为学校题库管理系统创建业务视图
-- 所属数据库：qbank_db
-- 所属 schema：qbank
-- 说明：
--   - 本文件用于封装课程题型查询、题库安全访问、教师题库管理、试卷明细和题量统计等常用查询
--   - 本文件不创建表、约束、索引、函数、存储过程、触发器和初始化数据
--   - 本文件建议在执行 04_create_indexes.sql 之后执行
--   - 视图不是越多越好，本阶段只创建必要视图，用于体现查询简化和安全性隔离
-- =============================================================================

\echo '[INFO] 正在创建题库管理系统业务视图...'

SET search_path TO qbank, public;

-- =============================================================================
-- 1. v_course_type_usage
-- 查询各门课程使用的题型，对应课程设计题目要求
-- =============================================================================

CREATE OR REPLACE VIEW qbank.v_course_type_usage AS
SELECT
    c.course_id,
    c.course_code,
    c.course_name,
    qt.type_id,
    qt.type_code,
    qt.type_name,
    COALESCE(cqt.default_score, qt.default_score) AS default_score,
    qt.objective_flag,
    cqt.enabled,
    cqt.sort_no,
    c.status       AS course_status,
    qt.status      AS type_status,
    cqt.created_at
FROM qbank.course_question_type cqt
INNER JOIN qbank.course c
    ON c.course_id = cqt.course_id
INNER JOIN qbank.question_type qt
    ON qt.type_id = cqt.type_id;

COMMENT ON VIEW qbank.v_course_type_usage IS '查询各门课程使用题型的视图';

-- =============================================================================
-- 2. v_question_public
-- 面向学生或普通预览场景，隐藏答案和解析，体现视图安全隔离
-- =============================================================================

CREATE OR REPLACE VIEW qbank.v_question_public AS
SELECT
    q.question_id,
    q.course_id,
    c.course_code,
    c.course_name,
    q.type_id,
    qt.type_code,
    qt.type_name,
    q.chapter_id,
    ch.chapter_no,
    ch.chapter_name,
    q.knowledge_point_id,
    kp.point_name,
    q.stem,
    q.difficulty,
    q.score,
    q.status,
    q.extract_count,
    q.created_at,
    q.updated_at
FROM qbank.question q
INNER JOIN qbank.course c
    ON c.course_id = q.course_id
INNER JOIN qbank.question_type qt
    ON qt.type_id = q.type_id
INNER JOIN qbank.chapter ch
    ON ch.chapter_id = q.chapter_id
   AND ch.course_id = q.course_id
LEFT JOIN qbank.knowledge_point kp
    ON kp.knowledge_point_id = q.knowledge_point_id
   AND kp.course_id = q.course_id
   AND kp.chapter_id = q.chapter_id;

COMMENT ON VIEW qbank.v_question_public IS '普通查看题目视图，隐藏答案和解析';

-- =============================================================================
-- 3. v_question_teacher
-- 面向教师题库管理场景，包含答案和解析及创建人信息
-- =============================================================================

CREATE OR REPLACE VIEW qbank.v_question_teacher AS
SELECT
    q.question_id,
    q.course_id,
    c.course_code,
    c.course_name,
    q.type_id,
    qt.type_code,
    qt.type_name,
    q.chapter_id,
    ch.chapter_no,
    ch.chapter_name,
    q.knowledge_point_id,
    kp.point_name,
    q.stem,
    q.answer,
    q.analysis,
    q.difficulty,
    q.score,
    q.status,
    q.extract_count,
    q.created_by,
    u.username     AS creator_username,
    u.real_name    AS creator_real_name,
    q.created_at,
    q.updated_at,
    q.remark
FROM qbank.question q
INNER JOIN qbank.course c
    ON c.course_id = q.course_id
INNER JOIN qbank.question_type qt
    ON qt.type_id = q.type_id
INNER JOIN qbank.chapter ch
    ON ch.chapter_id = q.chapter_id
   AND ch.course_id = q.course_id
LEFT JOIN qbank.knowledge_point kp
    ON kp.knowledge_point_id = q.knowledge_point_id
   AND kp.course_id = q.course_id
   AND kp.chapter_id = q.chapter_id
LEFT JOIN qbank.sys_user u
    ON u.user_id = q.created_by;

COMMENT ON VIEW qbank.v_question_teacher IS '教师题库管理视图，包含答案、解析及创建人信息';

-- =============================================================================
-- 4. v_paper_detail
-- 封装套题明细查询，便于展示试卷题目、顺序与分值
-- =============================================================================

CREATE OR REPLACE VIEW qbank.v_paper_detail AS
SELECT
    p.paper_id,
    p.paper_name,
    p.paper_type,
    p.status           AS paper_status,
    p.course_id,
    c.course_code,
    c.course_name,
    p.total_score,
    p.created_by       AS paper_created_by,
    p.created_at       AS paper_created_at,
    pq.paper_question_id,
    pq.order_no,
    q.question_id,
    q.type_id,
    qt.type_name,
    q.chapter_id,
    ch.chapter_no,
    ch.chapter_name,
    q.stem,
    q.answer,
    q.analysis,
    q.difficulty,
    q.score            AS question_score,
    pq.score           AS paper_question_score,
    q.status           AS question_status,
    q.created_at       AS question_created_at
FROM qbank.paper_question pq
INNER JOIN qbank.paper p
    ON p.paper_id = pq.paper_id
INNER JOIN qbank.question q
    ON q.question_id = pq.question_id
INNER JOIN qbank.course c
    ON c.course_id = p.course_id
INNER JOIN qbank.question_type qt
    ON qt.type_id = q.type_id
INNER JOIN qbank.chapter ch
    ON ch.chapter_id = q.chapter_id
   AND ch.course_id = q.course_id;

COMMENT ON VIEW qbank.v_paper_detail IS '套题明细视图，展示试卷包含的题目及分值信息';

-- =============================================================================
-- 5. v_course_question_stat
-- 课程题量统计概览，按课程、题型、章节分组统计
-- =============================================================================

CREATE OR REPLACE VIEW qbank.v_course_question_stat AS
SELECT
    c.course_id,
    c.course_code,
    c.course_name,
    qt.type_id,
    qt.type_code,
    qt.type_name,
    ch.chapter_id,
    ch.chapter_no,
    ch.chapter_name,
    COUNT(*)                  AS question_count,
    AVG(q.difficulty)         AS avg_difficulty,
    AVG(q.score)              AS avg_score,
    SUM(q.extract_count)      AS total_extract_count
FROM qbank.question q
INNER JOIN qbank.course c
    ON c.course_id = q.course_id
INNER JOIN qbank.question_type qt
    ON qt.type_id = q.type_id
INNER JOIN qbank.chapter ch
    ON ch.chapter_id = q.chapter_id
   AND ch.course_id = q.course_id
GROUP BY
    c.course_id,
    c.course_code,
    c.course_name,
    qt.type_id,
    qt.type_code,
    qt.type_name,
    ch.chapter_id,
    ch.chapter_no,
    ch.chapter_name;

COMMENT ON VIEW qbank.v_course_question_stat IS '课程题量统计视图，按课程、题型、章节汇总题目数量与指标';

\echo '[DONE] 业务视图创建完成。'
