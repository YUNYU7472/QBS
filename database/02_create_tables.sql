-- =============================================================================
-- 文件名：02_create_tables.sql
-- 作用：创建学校题库管理系统核心数据表
-- 所属数据库：qbank_db
-- 所属 schema：qbank
-- 说明：
--   - 本文件只创建表和字段，不创建主键、外键、唯一约束、检查约束
--   - 不创建索引、视图、函数、存储过程、触发器
--   - 正式完整性约束将在 03_create_constraints.sql 中集中创建
--   - 所有正式对象必须位于 qbank schema 下
-- =============================================================================

\echo '[INFO] 正在创建题库管理系统核心数据表...'

SET search_path TO qbank, public;

-- =============================================================================
-- 一、基础主数据层
-- =============================================================================

-- 1. 系统用户表
CREATE TABLE IF NOT EXISTS qbank.sys_user (
    user_id         BIGSERIAL,
    username        VARCHAR(50)  NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    real_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(100),
    phone           VARCHAR(30),
    user_type       VARCHAR(30)  NOT NULL DEFAULT 'teacher',
    status          VARCHAR(20)  NOT NULL DEFAULT 'active',
    last_login_at   TIMESTAMP,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP,
    remark          TEXT
);

COMMENT ON TABLE qbank.sys_user IS '系统登录用户表';
COMMENT ON COLUMN qbank.sys_user.user_id IS '用户编号，系统自动生成';
COMMENT ON COLUMN qbank.sys_user.username IS '登录用户名';
COMMENT ON COLUMN qbank.sys_user.password_hash IS '密码哈希值，不保存明文密码';
COMMENT ON COLUMN qbank.sys_user.real_name IS '用户真实姓名';
COMMENT ON COLUMN qbank.sys_user.user_type IS '用户类型：admin、manager、teacher、student 等';
COMMENT ON COLUMN qbank.sys_user.status IS '用户状态：active、inactive 等';
COMMENT ON COLUMN qbank.sys_user.last_login_at IS '最近一次登录时间';
COMMENT ON COLUMN qbank.sys_user.created_at IS '创建时间';

-- 2. 系统角色表
CREATE TABLE IF NOT EXISTS qbank.sys_role (
    role_id         BIGSERIAL,
    role_code       VARCHAR(50)  NOT NULL,
    role_name       VARCHAR(100) NOT NULL,
    description     TEXT,
    status          VARCHAR(20)  NOT NULL DEFAULT 'active',
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP
);

COMMENT ON TABLE qbank.sys_role IS '系统角色表';
COMMENT ON COLUMN qbank.sys_role.role_id IS '角色编号，系统自动生成';
COMMENT ON COLUMN qbank.sys_role.role_code IS '角色编码';
COMMENT ON COLUMN qbank.sys_role.role_name IS '角色名称';
COMMENT ON COLUMN qbank.sys_role.status IS '角色状态';

-- 3. 用户角色关系表
CREATE TABLE IF NOT EXISTS qbank.sys_user_role (
    user_role_id    BIGSERIAL,
    user_id         BIGINT       NOT NULL,
    role_id         BIGINT       NOT NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE qbank.sys_user_role IS '用户与角色多对多关系表';
COMMENT ON COLUMN qbank.sys_user_role.user_role_id IS '关系编号，系统自动生成';
COMMENT ON COLUMN qbank.sys_user_role.user_id IS '用户编号，外键关联 sys_user';
COMMENT ON COLUMN qbank.sys_user_role.role_id IS '角色编号，外键关联 sys_role';

-- 4. 教师表
CREATE TABLE IF NOT EXISTS qbank.teacher (
    teacher_id      BIGSERIAL,
    user_id         BIGINT,
    teacher_no      VARCHAR(50)  NOT NULL,
    teacher_name    VARCHAR(100) NOT NULL,
    department      VARCHAR(100),
    title           VARCHAR(100),
    email           VARCHAR(100),
    phone           VARCHAR(30),
    status          VARCHAR(20)  NOT NULL DEFAULT 'active',
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP,
    remark          TEXT
);

COMMENT ON TABLE qbank.teacher IS '教师信息表';
COMMENT ON COLUMN qbank.teacher.teacher_id IS '教师编号，系统自动生成';
COMMENT ON COLUMN qbank.teacher.user_id IS '关联系统用户编号';
COMMENT ON COLUMN qbank.teacher.teacher_no IS '教师工号';
COMMENT ON COLUMN qbank.teacher.teacher_name IS '教师姓名';
COMMENT ON COLUMN qbank.teacher.department IS '所属院系';
COMMENT ON COLUMN qbank.teacher.title IS '职称';

-- 5. 课程表
CREATE TABLE IF NOT EXISTS qbank.course (
    course_id           BIGSERIAL,
    course_code         VARCHAR(50)  NOT NULL,
    course_name         VARCHAR(100) NOT NULL,
    credit              NUMERIC(3,1),
    owner_teacher_id    BIGINT,
    status              VARCHAR(20)  NOT NULL DEFAULT 'active',
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP,
    remark              TEXT
);

COMMENT ON TABLE qbank.course IS '课程基本信息表';
COMMENT ON COLUMN qbank.course.course_id IS '课程编号，系统自动生成';
COMMENT ON COLUMN qbank.course.course_code IS '课程编码，后续设唯一约束';
COMMENT ON COLUMN qbank.course.course_name IS '课程名称';
COMMENT ON COLUMN qbank.course.credit IS '学分';
COMMENT ON COLUMN qbank.course.owner_teacher_id IS '课程负责人教师编号';

-- 6. 题型表
CREATE TABLE IF NOT EXISTS qbank.question_type (
    type_id         BIGSERIAL,
    type_code       VARCHAR(50)  NOT NULL,
    type_name       VARCHAR(50)  NOT NULL,
    default_score   NUMERIC(6,2) NOT NULL DEFAULT 0,
    objective_flag  BOOLEAN      NOT NULL DEFAULT FALSE,
    status          VARCHAR(20)  NOT NULL DEFAULT 'active',
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP,
    remark          TEXT
);

COMMENT ON TABLE qbank.question_type IS '题型基本信息表';
COMMENT ON COLUMN qbank.question_type.type_id IS '题型编号，系统自动生成';
COMMENT ON COLUMN qbank.question_type.type_code IS '题型编码，后续设唯一约束';
COMMENT ON COLUMN qbank.question_type.type_name IS '题型名称';
COMMENT ON COLUMN qbank.question_type.default_score IS '默认分值';
COMMENT ON COLUMN qbank.question_type.objective_flag IS '是否客观题';

-- 7. 课程题型关系表
CREATE TABLE IF NOT EXISTS qbank.course_question_type (
    course_type_id  BIGSERIAL,
    course_id       BIGINT       NOT NULL,
    type_id         BIGINT       NOT NULL,
    default_score   NUMERIC(6,2),
    enabled         BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_no         INT          NOT NULL DEFAULT 0,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP,
    remark          TEXT
);

COMMENT ON TABLE qbank.course_question_type IS '课程与题型关联表，管理每门课程可用的题型';
COMMENT ON COLUMN qbank.course_question_type.course_type_id IS '关系编号，系统自动生成';
COMMENT ON COLUMN qbank.course_question_type.course_id IS '课程编号';
COMMENT ON COLUMN qbank.course_question_type.type_id IS '题型编号';
COMMENT ON COLUMN qbank.course_question_type.default_score IS '该课程下该题型的默认分值';
COMMENT ON COLUMN qbank.course_question_type.enabled IS '是否启用该题型';

-- 8. 章节表
CREATE TABLE IF NOT EXISTS qbank.chapter (
    chapter_id      BIGSERIAL,
    course_id       BIGINT       NOT NULL,
    parent_id       BIGINT,
    chapter_no      VARCHAR(30)  NOT NULL,
    chapter_name    VARCHAR(100) NOT NULL,
    sort_no         INT          NOT NULL DEFAULT 0,
    status          VARCHAR(20)  NOT NULL DEFAULT 'active',
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP,
    remark          TEXT
);

COMMENT ON TABLE qbank.chapter IS '课程章节表，支持章节树结构';
COMMENT ON COLUMN qbank.chapter.chapter_id IS '章节编号，系统自动生成';
COMMENT ON COLUMN qbank.chapter.course_id IS '所属课程编号';
COMMENT ON COLUMN qbank.chapter.parent_id IS '父章节编号，支持多级章节';
COMMENT ON COLUMN qbank.chapter.chapter_no IS '章节序号，后续与 course_id 建唯一约束';
COMMENT ON COLUMN qbank.chapter.chapter_name IS '章节名称';

-- 9. 知识点表
CREATE TABLE IF NOT EXISTS qbank.knowledge_point (
    knowledge_point_id  BIGSERIAL,
    course_id           BIGINT       NOT NULL,
    chapter_id          BIGINT       NOT NULL,
    point_code          VARCHAR(50),
    point_name          VARCHAR(100) NOT NULL,
    description         TEXT,
    sort_no             INT          NOT NULL DEFAULT 0,
    status              VARCHAR(20)  NOT NULL DEFAULT 'active',
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP
);

COMMENT ON TABLE qbank.knowledge_point IS '知识点表，用于细粒度题库管理与自动组卷';
COMMENT ON COLUMN qbank.knowledge_point.knowledge_point_id IS '知识点编号，系统自动生成';
COMMENT ON COLUMN qbank.knowledge_point.course_id IS '所属课程编号';
COMMENT ON COLUMN qbank.knowledge_point.chapter_id IS '所属章节编号';
COMMENT ON COLUMN qbank.knowledge_point.point_name IS '知识点名称';

-- =============================================================================
-- 二、题库业务层
-- =============================================================================

-- 10. 习题表
CREATE TABLE IF NOT EXISTS qbank.question (
    question_id         BIGSERIAL,
    course_id           BIGINT       NOT NULL,
    type_id             BIGINT       NOT NULL,
    chapter_id          BIGINT       NOT NULL,
    knowledge_point_id  BIGINT,
    stem                TEXT         NOT NULL,
    answer              TEXT,
    analysis            TEXT,
    difficulty          INT          NOT NULL DEFAULT 3,
    score               NUMERIC(6,2) NOT NULL DEFAULT 0,
    status              VARCHAR(20)  NOT NULL DEFAULT 'active',
    extract_count       INT          NOT NULL DEFAULT 0,
    created_by          BIGINT,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP,
    remark              TEXT
);

COMMENT ON TABLE qbank.question IS '习题表，存储题目主体信息';
COMMENT ON COLUMN qbank.question.question_id IS '习题题号，系统自动生成';
COMMENT ON COLUMN qbank.question.course_id IS '所属课程编号';
COMMENT ON COLUMN qbank.question.type_id IS '题型编号';
COMMENT ON COLUMN qbank.question.chapter_id IS '所属章节编号';
COMMENT ON COLUMN qbank.question.knowledge_point_id IS '关联知识点编号';
COMMENT ON COLUMN qbank.question.stem IS '题干内容';
COMMENT ON COLUMN qbank.question.answer IS '参考答案';
COMMENT ON COLUMN qbank.question.analysis IS '题目解析';
COMMENT ON COLUMN qbank.question.difficulty IS '难度等级 1-5，后续设检查约束';
COMMENT ON COLUMN qbank.question.score IS '题目分值，后续设非负检查约束';
COMMENT ON COLUMN qbank.question.extract_count IS '被抽题次数，后续由触发器维护';
COMMENT ON COLUMN qbank.question.created_at IS '习题建立日期，默认系统当前时间';

-- 11. 题目选项表
CREATE TABLE IF NOT EXISTS qbank.question_option (
    option_id       BIGSERIAL,
    question_id     BIGINT       NOT NULL,
    option_label    VARCHAR(10)  NOT NULL,
    option_content  TEXT         NOT NULL,
    is_correct      BOOLEAN      NOT NULL DEFAULT FALSE,
    sort_no         INT          NOT NULL DEFAULT 0,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP
);

COMMENT ON TABLE qbank.question_option IS '题目选项表，用于选择题单选或多选';
COMMENT ON COLUMN qbank.question_option.option_id IS '选项编号，系统自动生成';
COMMENT ON COLUMN qbank.question_option.question_id IS '所属习题编号';
COMMENT ON COLUMN qbank.question_option.option_label IS '选项标签，如 A、B、C、D';
COMMENT ON COLUMN qbank.question_option.option_content IS '选项内容';
COMMENT ON COLUMN qbank.question_option.is_correct IS '是否为正确答案';

-- 12. 题目标签表
CREATE TABLE IF NOT EXISTS qbank.question_tag (
    tag_id          BIGSERIAL,
    tag_name        VARCHAR(100) NOT NULL,
    description     TEXT,
    status          VARCHAR(20)  NOT NULL DEFAULT 'active',
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP
);

COMMENT ON TABLE qbank.question_tag IS '题目标签表，用于题目灵活分类';
COMMENT ON COLUMN qbank.question_tag.tag_id IS '标签编号，系统自动生成';
COMMENT ON COLUMN qbank.question_tag.tag_name IS '标签名称';

-- 13. 题目附件表
CREATE TABLE IF NOT EXISTS qbank.question_attachment (
    attachment_id   BIGSERIAL,
    question_id     BIGINT       NOT NULL,
    file_name       VARCHAR(255) NOT NULL,
    file_path       VARCHAR(500) NOT NULL,
    file_type       VARCHAR(50),
    file_size       BIGINT,
    uploaded_by     BIGINT,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remark          TEXT
);

COMMENT ON TABLE qbank.question_attachment IS '题目附件表，保存图片、材料等元信息';
COMMENT ON COLUMN qbank.question_attachment.attachment_id IS '附件编号，系统自动生成';
COMMENT ON COLUMN qbank.question_attachment.question_id IS '所属习题编号';
COMMENT ON COLUMN qbank.question_attachment.file_name IS '文件名称';
COMMENT ON COLUMN qbank.question_attachment.file_path IS '文件存储路径';

-- =============================================================================
-- 三、组卷事务层
-- =============================================================================

-- 14. 套题表
CREATE TABLE IF NOT EXISTS qbank.paper (
    paper_id        BIGSERIAL,
    paper_name      VARCHAR(200) NOT NULL,
    course_id       BIGINT       NOT NULL,
    total_score     NUMERIC(8,2) NOT NULL DEFAULT 0,
    paper_type      VARCHAR(30)  NOT NULL DEFAULT 'auto',
    status          VARCHAR(20)  NOT NULL DEFAULT 'draft',
    created_by      BIGINT,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP,
    remark          TEXT
);

COMMENT ON TABLE qbank.paper IS '套题表，保存自动或手动生成的试卷';
COMMENT ON COLUMN qbank.paper.paper_id IS '套题编号，系统自动生成';
COMMENT ON COLUMN qbank.paper.paper_name IS '套题名称';
COMMENT ON COLUMN qbank.paper.course_id IS '所属课程编号';
COMMENT ON COLUMN qbank.paper.total_score IS '套题总分';
COMMENT ON COLUMN qbank.paper.paper_type IS '组卷类型：auto 自动、manual 手动';
COMMENT ON COLUMN qbank.paper.status IS '套题状态：draft、published 等';

-- 15. 套题题目明细表
CREATE TABLE IF NOT EXISTS qbank.paper_question (
    paper_question_id   BIGSERIAL,
    paper_id            BIGINT       NOT NULL,
    question_id         BIGINT       NOT NULL,
    order_no            INT          NOT NULL DEFAULT 0,
    score               NUMERIC(6,2) NOT NULL DEFAULT 0,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE qbank.paper_question IS '套题与习题关联明细表';
COMMENT ON COLUMN qbank.paper_question.paper_question_id IS '明细编号，系统自动生成';
COMMENT ON COLUMN qbank.paper_question.paper_id IS '套题编号';
COMMENT ON COLUMN qbank.paper_question.question_id IS '习题编号';
COMMENT ON COLUMN qbank.paper_question.order_no IS '题目在套题中的顺序号';
COMMENT ON COLUMN qbank.paper_question.score IS '该题在套题中的分值';

-- 16. 组卷规则表
CREATE TABLE IF NOT EXISTS qbank.paper_rule (
    rule_id             BIGSERIAL,
    paper_id            BIGINT,
    course_id           BIGINT       NOT NULL,
    type_id             BIGINT,
    chapter_id          BIGINT,
    difficulty          INT,
    question_count      INT          NOT NULL DEFAULT 0,
    score_per_question  NUMERIC(6,2) NOT NULL DEFAULT 0,
    rule_content        TEXT,
    created_by          BIGINT,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remark              TEXT
);

COMMENT ON TABLE qbank.paper_rule IS '自动组卷规则表';
COMMENT ON COLUMN qbank.paper_rule.rule_id IS '规则编号，系统自动生成';
COMMENT ON COLUMN qbank.paper_rule.paper_id IS '关联套题编号';
COMMENT ON COLUMN qbank.paper_rule.course_id IS '所属课程编号';
COMMENT ON COLUMN qbank.paper_rule.type_id IS '指定题型编号';
COMMENT ON COLUMN qbank.paper_rule.chapter_id IS '指定章节编号';
COMMENT ON COLUMN qbank.paper_rule.difficulty IS '指定难度等级';
COMMENT ON COLUMN qbank.paper_rule.question_count IS '抽取题目数量';
COMMENT ON COLUMN qbank.paper_rule.rule_content IS '规则描述或 JSON 字符串，使用 TEXT 存储';

-- 17. 抽题日志表
CREATE TABLE IF NOT EXISTS qbank.extract_log (
    extract_log_id  BIGSERIAL,
    paper_id        BIGINT       NOT NULL,
    question_id     BIGINT       NOT NULL,
    operator_id     BIGINT,
    extracted_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remark          TEXT
);

COMMENT ON TABLE qbank.extract_log IS '抽题日志表，记录每次抽题行为';
COMMENT ON COLUMN qbank.extract_log.extract_log_id IS '日志编号，系统自动生成';
COMMENT ON COLUMN qbank.extract_log.paper_id IS '套题编号';
COMMENT ON COLUMN qbank.extract_log.question_id IS '被抽取的习题编号';
COMMENT ON COLUMN qbank.extract_log.operator_id IS '操作人用户编号';
COMMENT ON COLUMN qbank.extract_log.extracted_at IS '抽题时间';

-- =============================================================================
-- 四、安全审计与系统辅助层
-- =============================================================================

-- 18. 登录日志表
CREATE TABLE IF NOT EXISTS qbank.login_log (
    login_log_id    BIGSERIAL,
    user_id         BIGINT,
    username        VARCHAR(50),
    login_time      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address      VARCHAR(100),
    user_agent      TEXT,
    login_status    VARCHAR(20),
    failure_reason  TEXT
);

COMMENT ON TABLE qbank.login_log IS '用户登录日志表，记录登录成功或失败';
COMMENT ON COLUMN qbank.login_log.login_log_id IS '日志编号，系统自动生成';
COMMENT ON COLUMN qbank.login_log.user_id IS '用户编号';
COMMENT ON COLUMN qbank.login_log.username IS '登录用户名';
COMMENT ON COLUMN qbank.login_log.login_time IS '登录时间';
COMMENT ON COLUMN qbank.login_log.login_status IS '登录状态：success、failure 等';

-- 19. 操作审计表
CREATE TABLE IF NOT EXISTS qbank.audit_log (
    audit_log_id    BIGSERIAL,
    user_id         BIGINT,
    table_name      VARCHAR(100) NOT NULL,
    operation       VARCHAR(20)  NOT NULL,
    record_id       VARCHAR(100),
    old_value       TEXT,
    new_value       TEXT,
    ip_address      VARCHAR(100),
    operated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remark          TEXT
);

COMMENT ON TABLE qbank.audit_log IS '操作审计表，记录关键数据变更';
COMMENT ON COLUMN qbank.audit_log.audit_log_id IS '审计编号，系统自动生成';
COMMENT ON COLUMN qbank.audit_log.user_id IS '操作用户编号';
COMMENT ON COLUMN qbank.audit_log.table_name IS '被操作的表名';
COMMENT ON COLUMN qbank.audit_log.operation IS '操作类型：INSERT、UPDATE、DELETE 等';
COMMENT ON COLUMN qbank.audit_log.old_value IS '变更前的值';
COMMENT ON COLUMN qbank.audit_log.new_value IS '变更后的值';

-- 20. 备份恢复记录表
CREATE TABLE IF NOT EXISTS qbank.backup_history (
    backup_id       BIGSERIAL,
    file_name       VARCHAR(255) NOT NULL,
    file_path       VARCHAR(500) NOT NULL,
    backup_type     VARCHAR(20)  NOT NULL,
    operator_id     BIGINT,
    status          VARCHAR(20)  NOT NULL DEFAULT 'success',
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remark          TEXT
);

COMMENT ON TABLE qbank.backup_history IS '数据库备份与恢复操作记录表';
COMMENT ON COLUMN qbank.backup_history.backup_id IS '记录编号，系统自动生成';
COMMENT ON COLUMN qbank.backup_history.file_name IS '备份文件名';
COMMENT ON COLUMN qbank.backup_history.file_path IS '备份文件路径';
COMMENT ON COLUMN qbank.backup_history.backup_type IS '操作类型：backup 或 restore';
COMMENT ON COLUMN qbank.backup_history.status IS '操作状态';

-- 21. 系统配置表
CREATE TABLE IF NOT EXISTS qbank.system_config (
    config_id       BIGSERIAL,
    config_key      VARCHAR(100) NOT NULL,
    config_value    TEXT,
    description     TEXT,
    status          VARCHAR(20)  NOT NULL DEFAULT 'active',
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP
);

COMMENT ON TABLE qbank.system_config IS '系统配置表，保存全局配置项';
COMMENT ON COLUMN qbank.system_config.config_id IS '配置编号，系统自动生成';
COMMENT ON COLUMN qbank.system_config.config_key IS '配置键，后续设唯一约束';
COMMENT ON COLUMN qbank.system_config.config_value IS '配置值';

\echo '[DONE] 核心数据表创建完成。'
