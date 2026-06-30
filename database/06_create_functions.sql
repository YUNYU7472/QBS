-- =============================================================================
-- 文件名：06_create_functions.sql
-- 作用：创建题库系统可复用函数
-- 所属数据库：qbank_db
-- 所属 schema：qbank
-- 说明：
--   - 本文件用于提供课程题型合法性检查、可抽题数量统计、试卷分数计算、审计日志写入等可复用能力
--   - 本文件不创建表、约束、索引、视图、存储过程、触发器、初始化数据和角色授权
--   - 本文件建议在执行 05_create_views.sql 之后执行
--   - 如需反复重建，建议使用 bash database/scripts/reset_db.sh
-- 执行说明：
--   - 本脚本推荐在 reset_db.sh 重建后的数据库结构上执行
--   - 如需重复执行，请先执行 reset_db.sh 或 00_drop_all.sql 后重新初始化
-- =============================================================================

\echo '[INFO] 正在创建题库管理系统函数...'

SET search_path TO qbank, public;

-- =============================================================================
-- 1. fn_check_course_type_enabled
-- 检查指定课程是否启用了指定题型，服务于录题校验与自动组卷
-- =============================================================================

CREATE OR REPLACE FUNCTION qbank.fn_check_course_type_enabled(
    p_course_id BIGINT,
    p_type_id BIGINT
)
RETURNS BOOLEAN
AS $$
DECLARE
    v_enabled BOOLEAN;
BEGIN
    SELECT TRUE INTO v_enabled
    FROM qbank.course_question_type cqt
    INNER JOIN qbank.course c
        ON c.course_id = cqt.course_id
    INNER JOIN qbank.question_type qt
        ON qt.type_id = cqt.type_id
    WHERE cqt.course_id = p_course_id
      AND cqt.type_id = p_type_id
      AND cqt.enabled = TRUE
      AND c.status <> 'deleted'
      AND qt.status <> 'deleted'
    LIMIT 1;

    RETURN COALESCE(v_enabled, FALSE);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION qbank.fn_check_course_type_enabled(BIGINT, BIGINT)
IS '检查指定课程是否启用了指定题型';

-- =============================================================================
-- 2. fn_count_available_questions
-- 统计符合条件的可抽取题目数量（仅统计课程当前启用题型下的 active 题目）
-- 调用时显式传入 NULL 表示不限制该维度
-- =============================================================================

CREATE OR REPLACE FUNCTION qbank.fn_count_available_questions(
    p_course_id BIGINT,
    p_type_id BIGINT,
    p_chapter_id BIGINT,
    p_difficulty INT
)
RETURNS BIGINT
AS $$
DECLARE
    v_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM qbank.question q
    INNER JOIN qbank.course_question_type cqt
        ON cqt.course_id = q.course_id
       AND cqt.type_id = q.type_id
       AND cqt.enabled = TRUE
    WHERE q.course_id = p_course_id
      AND q.status = 'active'
      AND (p_type_id IS NULL OR q.type_id = p_type_id)
      AND (p_chapter_id IS NULL OR q.chapter_id = p_chapter_id)
      AND (p_difficulty IS NULL OR q.difficulty = p_difficulty);

    RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION qbank.fn_count_available_questions(BIGINT, BIGINT, BIGINT, INT)
IS '统计指定课程下符合筛选条件且题型已启用的可抽取题目数量';

-- =============================================================================
-- 3. fn_calculate_paper_total_score
-- 计算指定套题的题目总分
-- =============================================================================

CREATE OR REPLACE FUNCTION qbank.fn_calculate_paper_total_score(
    p_paper_id BIGINT
)
RETURNS NUMERIC
AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(score), 0) INTO v_total
    FROM qbank.paper_question
    WHERE paper_id = p_paper_id;

    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION qbank.fn_calculate_paper_total_score(BIGINT)
IS '计算指定套题的题目总分';

-- =============================================================================
-- 4. fn_recalculate_paper_score
-- 重新计算并更新指定套题的 total_score
-- =============================================================================

CREATE OR REPLACE FUNCTION qbank.fn_recalculate_paper_score(
    p_paper_id BIGINT
)
RETURNS NUMERIC
AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    v_total := qbank.fn_calculate_paper_total_score(p_paper_id);

    UPDATE qbank.paper
    SET total_score = v_total,
        updated_at = CURRENT_TIMESTAMP
    WHERE paper_id = p_paper_id;

    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION qbank.fn_recalculate_paper_score(BIGINT)
IS '重新计算并更新指定套题的总分';

-- =============================================================================
-- 5. fn_write_audit_log
-- 写入操作审计日志，供后续触发器或后端服务复用
-- =============================================================================

CREATE OR REPLACE FUNCTION qbank.fn_write_audit_log(
    p_user_id BIGINT,
    p_table_name VARCHAR,
    p_operation VARCHAR,
    p_record_id VARCHAR,
    p_old_value TEXT,
    p_new_value TEXT,
    p_ip_address VARCHAR,
    p_remark TEXT
)
RETURNS BIGINT
AS $$
DECLARE
    v_audit_log_id BIGINT;
BEGIN
    INSERT INTO qbank.audit_log (
        user_id,
        table_name,
        operation,
        record_id,
        old_value,
        new_value,
        ip_address,
        remark
    ) VALUES (
        p_user_id,
        p_table_name,
        p_operation,
        p_record_id,
        p_old_value,
        p_new_value,
        p_ip_address,
        p_remark
    )
    RETURNING audit_log_id INTO v_audit_log_id;

    RETURN v_audit_log_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION qbank.fn_write_audit_log(BIGINT, VARCHAR, VARCHAR, VARCHAR, TEXT, TEXT, VARCHAR, TEXT)
IS '写入操作审计日志并返回 audit_log_id';

\echo '[DONE] 函数创建完成。'
