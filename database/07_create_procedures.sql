-- =============================================================================
-- 文件名：07_create_procedures.sql
-- 作用：创建题库系统核心存储过程
-- 所属数据库：qbank_db
-- 所属 schema：qbank
-- 说明：
--   - 本文件用于实现题量统计、课程题型统计、自动组卷等数据库侧业务逻辑
--   - 本文件不创建表、约束、索引、视图、函数、触发器、初始化数据和角色授权
--   - 本文件建议在执行 06_create_functions.sql 之后执行
--   - 存储过程采用 openGauss 原生 CREATE PROCEDURE ... IS ... BEGIN ... END; / 语法
--   - 存储过程用于体现数据库程序设计能力，直接对应课程设计题目中的存储过程要求
-- 执行说明：
--   - 本脚本推荐在 reset_db.sh 重建后的数据库结构上执行
--   - 如需重复执行，请先执行 reset_db.sh 或 00_drop_all.sql 后重新初始化
-- =============================================================================

\echo '[INFO] 正在创建题库管理系统存储过程...'

SET search_path TO qbank, public;

-- =============================================================================
-- 1. sp_get_course_question_stat
-- 作用：查询指定课程在各种题型、各章节下的习题数量
-- 对应题目要求：定义存储过程查询指定课程各种题型和各章节的习题数量
-- 调用示例：
--   BEGIN;
--   CALL qbank.sp_get_course_question_stat(1, 'cur_course_stat');
--   FETCH ALL FROM cur_course_stat;
--   COMMIT;
-- =============================================================================

CREATE OR REPLACE PROCEDURE qbank.sp_get_course_question_stat(
    IN p_course_id BIGINT,
    INOUT p_result REFCURSOR
)
IS
BEGIN
    OPEN p_result FOR
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
        COUNT(q.question_id)              AS question_count,
        COALESCE(AVG(q.difficulty), 0)    AS avg_difficulty,
        COALESCE(AVG(q.score), 0)         AS avg_score,
        COALESCE(SUM(q.extract_count), 0) AS total_extract_count
    FROM qbank.course c
    INNER JOIN qbank.course_question_type cqt
        ON cqt.course_id = c.course_id
       AND cqt.enabled = TRUE
    INNER JOIN qbank.question_type qt
        ON qt.type_id = cqt.type_id
    INNER JOIN qbank.chapter ch
        ON ch.course_id = c.course_id
    LEFT JOIN qbank.question q
        ON q.course_id = c.course_id
       AND q.type_id = qt.type_id
       AND q.chapter_id = ch.chapter_id
       AND (q.status IS NULL OR q.status <> 'deleted')
    WHERE c.course_id = p_course_id
    GROUP BY
        c.course_id,
        c.course_code,
        c.course_name,
        qt.type_id,
        qt.type_code,
        qt.type_name,
        ch.chapter_id,
        ch.chapter_no,
        ch.chapter_name
    ORDER BY qt.type_id, ch.chapter_no;
END;
/

-- =============================================================================
-- 2. sp_get_all_course_type_stat
-- 作用：查询各门课程、各种题型的习题数量
-- 对应题目要求：定义存储过程实现查询各门课程、各种题型的习题数量
-- 调用示例：
--   BEGIN;
--   CALL qbank.sp_get_all_course_type_stat('cur_all_course_type');
--   FETCH ALL FROM cur_all_course_type;
--   COMMIT;
-- =============================================================================

CREATE OR REPLACE PROCEDURE qbank.sp_get_all_course_type_stat(
    INOUT p_result REFCURSOR
)
IS
BEGIN
    OPEN p_result FOR
    SELECT
        c.course_id,
        c.course_code,
        c.course_name,
        qt.type_id,
        qt.type_code,
        qt.type_name,
        cqt.enabled,
        COUNT(q.question_id)              AS question_count,
        COALESCE(AVG(q.difficulty), 0)    AS avg_difficulty,
        COALESCE(AVG(q.score), 0)         AS avg_score,
        COALESCE(SUM(q.extract_count), 0) AS total_extract_count
    FROM qbank.course c
    INNER JOIN qbank.course_question_type cqt
        ON cqt.course_id = c.course_id
    INNER JOIN qbank.question_type qt
        ON qt.type_id = cqt.type_id
    LEFT JOIN qbank.question q
        ON q.course_id = c.course_id
       AND q.type_id = qt.type_id
       AND (q.status IS NULL OR q.status <> 'deleted')
    GROUP BY
        c.course_id,
        c.course_code,
        c.course_name,
        qt.type_id,
        qt.type_code,
        qt.type_name,
        cqt.enabled
    ORDER BY c.course_id, qt.type_id;
END;
/

-- =============================================================================
-- 3. sp_generate_paper
-- 作用：自动抽题生成套题
-- 对应题目要求：可以自动抽题组成套题
-- 说明：
--   - 本过程负责创建试卷和试卷题目明细
--   - question.extract_count 更新和 extract_log 写入由 08_create_triggers.sql 触发器完成
-- 调用示例：
--   BEGIN;
--   CALL qbank.sp_generate_paper(
--       '2026春季测验', 1, 1, NULL, 3, 5, 10.00, 1, NULL
--   );
--   -- p_paper_id 通过 INOUT 参数返回
--   COMMIT;
-- =============================================================================

CREATE OR REPLACE PROCEDURE qbank.sp_generate_paper(
    IN p_paper_name VARCHAR,
    IN p_course_id BIGINT,
    IN p_type_id BIGINT,
    IN p_chapter_id BIGINT,
    IN p_difficulty INT,
    IN p_question_count INT,
    IN p_score_per_question NUMERIC,
    IN p_created_by BIGINT,
    INOUT p_paper_id BIGINT
)
IS
    v_available BIGINT;
    v_chapter_count INT;
    v_total NUMERIC;
BEGIN
    IF p_paper_name IS NULL OR TRIM(p_paper_name) = '' THEN
        RAISE EXCEPTION '试卷名称不能为空';
    END IF;

    IF p_question_count IS NULL OR p_question_count <= 0 THEN
        RAISE EXCEPTION '抽题数量必须大于 0';
    END IF;

    IF p_score_per_question IS NOT NULL AND p_score_per_question < 0 THEN
        RAISE EXCEPTION '每题分值不能为负数';
    END IF;

    IF p_difficulty IS NOT NULL AND NOT (p_difficulty BETWEEN 1 AND 5) THEN
        RAISE EXCEPTION '难度必须在 1 到 5 之间';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM qbank.course
        WHERE course_id = p_course_id
          AND status <> 'deleted'
    ) THEN
        RAISE EXCEPTION '课程不存在或已删除，course_id=%', p_course_id;
    END IF;

    IF p_type_id IS NOT NULL THEN
        IF NOT qbank.fn_check_course_type_enabled(p_course_id, p_type_id) THEN
            RAISE EXCEPTION '课程未启用指定题型，course_id=%, type_id=%', p_course_id, p_type_id;
        END IF;
    END IF;

    IF p_chapter_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_chapter_count
        FROM qbank.chapter
        WHERE chapter_id = p_chapter_id
          AND course_id = p_course_id;

        IF v_chapter_count = 0 THEN
            RAISE EXCEPTION '章节不属于指定课程，course_id=%, chapter_id=%', p_course_id, p_chapter_id;
        END IF;
    END IF;

    v_available := qbank.fn_count_available_questions(
        p_course_id,
        p_type_id,
        p_chapter_id,
        p_difficulty
    );

    IF v_available < p_question_count THEN
        RAISE EXCEPTION '可抽题数量不足，需要 % 道，当前仅 % 道', p_question_count, v_available;
    END IF;

    INSERT INTO qbank.paper (
        paper_name,
        course_id,
        total_score,
        paper_type,
        status,
        created_by
    ) VALUES (
        p_paper_name,
        p_course_id,
        0,
        'auto',
        'draft',
        p_created_by
    )
    RETURNING paper_id INTO p_paper_id;

    INSERT INTO qbank.paper_rule (
        paper_id,
        course_id,
        type_id,
        chapter_id,
        difficulty,
        question_count,
        score_per_question,
        created_by
    ) VALUES (
        p_paper_id,
        p_course_id,
        p_type_id,
        p_chapter_id,
        p_difficulty,
        p_question_count,
        COALESCE(p_score_per_question, 0),
        p_created_by
    );

    WITH candidate AS (
        SELECT
            q.question_id,
            q.score,
            ROW_NUMBER() OVER (ORDER BY q.extract_count ASC, random()) AS order_no
        FROM qbank.question q
        INNER JOIN qbank.course_question_type cqt
            ON cqt.course_id = q.course_id
           AND cqt.type_id = q.type_id
           AND cqt.enabled = TRUE
        WHERE q.course_id = p_course_id
          AND q.status = 'active'
          AND (p_type_id IS NULL OR q.type_id = p_type_id)
          AND (p_chapter_id IS NULL OR q.chapter_id = p_chapter_id)
          AND (p_difficulty IS NULL OR q.difficulty = p_difficulty)
    )
    INSERT INTO qbank.paper_question (paper_id, question_id, order_no, score)
    SELECT
        p_paper_id,
        candidate.question_id,
        candidate.order_no,
        COALESCE(p_score_per_question, candidate.score)
    FROM candidate
    WHERE candidate.order_no <= p_question_count;

    v_total := qbank.fn_recalculate_paper_score(p_paper_id);
END;
/

-- =============================================================================
-- 4. sp_recalculate_paper_score
-- 作用：重新计算指定套题总分
-- 用途：后端修改套题题目分值后可调用
-- 调用示例：
--   CALL qbank.sp_recalculate_paper_score(1);
-- =============================================================================

CREATE OR REPLACE PROCEDURE qbank.sp_recalculate_paper_score(
    IN p_paper_id BIGINT
)
IS
    v_total NUMERIC;
BEGIN
    v_total := qbank.fn_recalculate_paper_score(p_paper_id);
END;
/

\echo '[DONE] 存储过程创建完成。'
