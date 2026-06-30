-- =============================================================================
-- 文件名：08_create_triggers.sql
-- 作用：创建题库系统触发器
-- 所属数据库：qbank_db
-- 所属 schema：qbank
-- 说明：
--   - 本文件用于实现套题明细一致性校验、抽题次数自动累加、抽题日志自动记录、试卷总分自动维护
--   - 本文件不创建表、约束、索引、视图、普通函数、存储过程、初始化数据和角色授权
--   - 本文件建议在执行 07_create_procedures.sql 之后执行
--   - 本阶段直接对应课程设计题目中“习题每抽取一次，要使习题的抽取次数加 1，用触发器实现”的要求
--   - 触发器不是越多越好，本阶段只创建必要触发器
-- 执行说明：
--   - 本脚本推荐在 reset_db.sh 重建后的数据库结构上执行
--   - 如需重复执行，请先执行 reset_db.sh 或 00_drop_all.sql 后重新初始化
-- =============================================================================

\echo '[INFO] 正在创建题库管理系统触发器...'

SET search_path TO qbank, public;

-- =============================================================================
-- 1. trg_fn_check_paper_question_integrity
-- 插入或更新套题明细前校验套题与题目课程一致，禁止直接修改 paper_id / question_id
-- =============================================================================

CREATE OR REPLACE FUNCTION qbank.trg_fn_check_paper_question_integrity()
RETURNS TRIGGER
AS $$
DECLARE
    v_paper_course_id BIGINT;
    v_question_course_id BIGINT;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.paper_id <> OLD.paper_id OR NEW.question_id <> OLD.question_id THEN
            RAISE EXCEPTION '不允许直接修改套题明细的 paper_id 或 question_id；如需替换题目，请删除旧记录后新增记录';
        END IF;
    END IF;

    SELECT course_id INTO v_paper_course_id
    FROM qbank.paper
    WHERE paper_id = NEW.paper_id;

    IF v_paper_course_id IS NULL THEN
        RAISE EXCEPTION '套题或题目不存在，无法建立套题明细';
    END IF;

    SELECT course_id INTO v_question_course_id
    FROM qbank.question
    WHERE question_id = NEW.question_id;

    IF v_question_course_id IS NULL THEN
        RAISE EXCEPTION '套题或题目不存在，无法建立套题明细';
    END IF;

    IF v_paper_course_id <> v_question_course_id THEN
        RAISE EXCEPTION '套题所属课程与题目所属课程不一致，不能加入套题';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION qbank.trg_fn_check_paper_question_integrity()
IS '套题明细插入或更新前校验套题与题目课程一致，并禁止直接修改 paper_id 或 question_id';

CREATE TRIGGER trg_paper_question_before_ins_upd_check
BEFORE INSERT OR UPDATE ON qbank.paper_question
FOR EACH ROW
EXECUTE PROCEDURE qbank.trg_fn_check_paper_question_integrity();

-- =============================================================================
-- 2. trg_fn_after_paper_question_insert
-- 套题明细插入后自动累加习题抽取次数、写入抽题日志并重算试卷总分
-- 满足题目要求：习题每抽取一次，要使习题的抽取次数加 1，用触发器实现
-- =============================================================================

CREATE OR REPLACE FUNCTION qbank.trg_fn_after_paper_question_insert()
RETURNS TRIGGER
AS $$
DECLARE
    v_operator_id BIGINT;
    v_total_score NUMERIC;
BEGIN
    SELECT created_by INTO v_operator_id
    FROM qbank.paper
    WHERE paper_id = NEW.paper_id;

    UPDATE qbank.question
    SET extract_count = extract_count + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE question_id = NEW.question_id;

    INSERT INTO qbank.extract_log (
        paper_id,
        question_id,
        operator_id,
        remark
    ) VALUES (
        NEW.paper_id,
        NEW.question_id,
        v_operator_id,
        '由套题明细插入触发器自动记录抽题日志'
    );

    v_total_score := qbank.fn_recalculate_paper_score(NEW.paper_id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION qbank.trg_fn_after_paper_question_insert()
IS '套题明细插入后自动累加习题抽取次数、写入抽题日志并重算试卷总分';

CREATE TRIGGER trg_paper_question_after_insert_extract
AFTER INSERT ON qbank.paper_question
FOR EACH ROW
EXECUTE PROCEDURE qbank.trg_fn_after_paper_question_insert();

-- =============================================================================
-- 3. trg_fn_after_paper_question_change_score
-- 套题明细更新或删除后自动重算试卷总分（插入场景由 trg_fn_after_paper_question_insert 处理）
-- =============================================================================

CREATE OR REPLACE FUNCTION qbank.trg_fn_after_paper_question_change_score()
RETURNS TRIGGER
AS $$
DECLARE
    v_total_score NUMERIC;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        v_total_score := qbank.fn_recalculate_paper_score(NEW.paper_id);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        v_total_score := qbank.fn_recalculate_paper_score(OLD.paper_id);
        RETURN OLD;
    ELSE
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION qbank.trg_fn_after_paper_question_change_score()
IS '套题明细更新或删除后自动重算试卷总分';

CREATE TRIGGER trg_paper_question_after_upd_del_score
AFTER UPDATE OR DELETE ON qbank.paper_question
FOR EACH ROW
EXECUTE PROCEDURE qbank.trg_fn_after_paper_question_change_score();

\echo '[DONE] 触发器创建完成。'
