-- =============================================================================
-- 文件名：03_create_constraints.sql
-- 作用：为学校题库管理系统核心表创建完整性约束
-- 所属数据库：qbank_db
-- 所属 schema：qbank
-- 说明：
--   - 本文件用于创建实体完整性、参照完整性、域完整性和用户自定义完整性
--   - 本文件不创建索引、视图、函数、存储过程、触发器和初始化数据
--   - 本文件建议在执行 02_create_tables.sql 之后执行
--   - 如需反复重建，建议使用 bash database/scripts/reset_db.sh
-- 执行说明：
--   - 本脚本推荐在 reset_db.sh 重建后的空数据库结构上执行
--   - 如需重复执行，请先执行 reset_db.sh 或 00_drop_all.sql 后重新初始化
-- 约束创建顺序：主键 → 唯一约束 → 检查约束 → 外键
-- 外键删除行为：统一使用默认 NO ACTION / RESTRICT，不使用 ON DELETE CASCADE
--   业务删除采用 status='disabled' 或 status='deleted' 软删除，避免误删历史数据
-- =============================================================================

\echo '[INFO] 正在创建题库管理系统完整性约束...'

SET search_path TO qbank, public;

-- =============================================================================
-- 一、实体完整性：主键约束
-- =============================================================================

ALTER TABLE qbank.sys_user ADD CONSTRAINT pk_sys_user PRIMARY KEY (user_id);
ALTER TABLE qbank.sys_role ADD CONSTRAINT pk_sys_role PRIMARY KEY (role_id);
ALTER TABLE qbank.sys_user_role ADD CONSTRAINT pk_sys_user_role PRIMARY KEY (user_role_id);
ALTER TABLE qbank.teacher ADD CONSTRAINT pk_teacher PRIMARY KEY (teacher_id);
ALTER TABLE qbank.course ADD CONSTRAINT pk_course PRIMARY KEY (course_id);
ALTER TABLE qbank.question_type ADD CONSTRAINT pk_question_type PRIMARY KEY (type_id);
ALTER TABLE qbank.course_question_type ADD CONSTRAINT pk_course_question_type PRIMARY KEY (course_type_id);
ALTER TABLE qbank.chapter ADD CONSTRAINT pk_chapter PRIMARY KEY (chapter_id);
ALTER TABLE qbank.knowledge_point ADD CONSTRAINT pk_knowledge_point PRIMARY KEY (knowledge_point_id);
ALTER TABLE qbank.question ADD CONSTRAINT pk_question PRIMARY KEY (question_id);
ALTER TABLE qbank.question_option ADD CONSTRAINT pk_question_option PRIMARY KEY (option_id);
ALTER TABLE qbank.question_tag ADD CONSTRAINT pk_question_tag PRIMARY KEY (tag_id);
ALTER TABLE qbank.question_attachment ADD CONSTRAINT pk_question_attachment PRIMARY KEY (attachment_id);
ALTER TABLE qbank.paper ADD CONSTRAINT pk_paper PRIMARY KEY (paper_id);
ALTER TABLE qbank.paper_question ADD CONSTRAINT pk_paper_question PRIMARY KEY (paper_question_id);
ALTER TABLE qbank.paper_rule ADD CONSTRAINT pk_paper_rule PRIMARY KEY (rule_id);
ALTER TABLE qbank.extract_log ADD CONSTRAINT pk_extract_log PRIMARY KEY (extract_log_id);
ALTER TABLE qbank.login_log ADD CONSTRAINT pk_login_log PRIMARY KEY (login_log_id);
ALTER TABLE qbank.audit_log ADD CONSTRAINT pk_audit_log PRIMARY KEY (audit_log_id);
ALTER TABLE qbank.backup_history ADD CONSTRAINT pk_backup_history PRIMARY KEY (backup_id);
ALTER TABLE qbank.system_config ADD CONSTRAINT pk_system_config PRIMARY KEY (config_id);

-- =============================================================================
-- 二、用户自定义完整性：唯一约束
-- =============================================================================

-- 2.1 用户与角色相关唯一约束
ALTER TABLE qbank.sys_user
ADD CONSTRAINT uq_sys_user_username UNIQUE (username);

ALTER TABLE qbank.sys_role
ADD CONSTRAINT uq_sys_role_role_code UNIQUE (role_code);

ALTER TABLE qbank.sys_user_role
ADD CONSTRAINT uq_sys_user_role_user_role UNIQUE (user_id, role_id);

-- 2.2 教师、课程、题型唯一约束
ALTER TABLE qbank.teacher
ADD CONSTRAINT uq_teacher_teacher_no UNIQUE (teacher_no);

ALTER TABLE qbank.course
ADD CONSTRAINT uq_course_course_code UNIQUE (course_code);

ALTER TABLE qbank.question_type
ADD CONSTRAINT uq_question_type_type_code UNIQUE (type_code);

ALTER TABLE qbank.question_type
ADD CONSTRAINT uq_question_type_type_name UNIQUE (type_name);

-- 2.3 课程题型关系唯一约束
-- 保证同一门课程不能重复配置同一种题型
-- 同时供 question(course_id, type_id) 复合外键引用
ALTER TABLE qbank.course_question_type
ADD CONSTRAINT uq_course_question_type_course_type UNIQUE (course_id, type_id);

-- 2.4 章节唯一约束
-- uq_chapter_course_no：同一课程内章节编号不重复
-- uq_chapter_course_chapter：供复合外键引用，保证题目章节属于指定课程
ALTER TABLE qbank.chapter
ADD CONSTRAINT uq_chapter_course_no UNIQUE (course_id, chapter_no);

ALTER TABLE qbank.chapter
ADD CONSTRAINT uq_chapter_course_chapter UNIQUE (course_id, chapter_id);

-- 2.5 知识点唯一约束
-- 同一章节下知识点名称不重复；第二个唯一约束供复合外键引用
ALTER TABLE qbank.knowledge_point
ADD CONSTRAINT uq_knowledge_point_course_chapter_name UNIQUE (course_id, chapter_id, point_name);

ALTER TABLE qbank.knowledge_point
ADD CONSTRAINT uq_knowledge_point_course_chapter_point UNIQUE (course_id, chapter_id, knowledge_point_id);

-- 2.6 题目选项唯一约束
-- 同一道题不能出现两个相同选项标签（如两个 A 选项）
ALTER TABLE qbank.question_option
ADD CONSTRAINT uq_question_option_question_label UNIQUE (question_id, option_label);

-- 2.7 标签、套题明细、系统配置唯一约束
ALTER TABLE qbank.question_tag
ADD CONSTRAINT uq_question_tag_tag_name UNIQUE (tag_name);

ALTER TABLE qbank.paper_question
ADD CONSTRAINT uq_paper_question_paper_question UNIQUE (paper_id, question_id);

ALTER TABLE qbank.system_config
ADD CONSTRAINT uq_system_config_key UNIQUE (config_key);

-- =============================================================================
-- 三、域完整性：检查约束
-- =============================================================================

-- 3.1 通用 status 字段检查（active / disabled / deleted）
ALTER TABLE qbank.sys_user
ADD CONSTRAINT ck_sys_user_status
CHECK (status IN ('active', 'disabled', 'deleted'));

ALTER TABLE qbank.sys_role
ADD CONSTRAINT ck_sys_role_status
CHECK (status IN ('active', 'disabled', 'deleted'));

ALTER TABLE qbank.teacher
ADD CONSTRAINT ck_teacher_status
CHECK (status IN ('active', 'disabled', 'deleted'));

ALTER TABLE qbank.course
ADD CONSTRAINT ck_course_status
CHECK (status IN ('active', 'disabled', 'deleted'));

ALTER TABLE qbank.question_type
ADD CONSTRAINT ck_question_type_status
CHECK (status IN ('active', 'disabled', 'deleted'));

ALTER TABLE qbank.chapter
ADD CONSTRAINT ck_chapter_status
CHECK (status IN ('active', 'disabled', 'deleted'));

ALTER TABLE qbank.knowledge_point
ADD CONSTRAINT ck_knowledge_point_status
CHECK (status IN ('active', 'disabled', 'deleted'));

ALTER TABLE qbank.question
ADD CONSTRAINT ck_question_status
CHECK (status IN ('active', 'disabled', 'deleted'));

ALTER TABLE qbank.question_tag
ADD CONSTRAINT ck_question_tag_status
CHECK (status IN ('active', 'disabled', 'deleted'));

ALTER TABLE qbank.system_config
ADD CONSTRAINT ck_system_config_status
CHECK (status IN ('active', 'disabled', 'deleted'));

-- 3.2 用户类型检查
ALTER TABLE qbank.sys_user
ADD CONSTRAINT ck_sys_user_user_type
CHECK (user_type IN ('admin', 'manager', 'teacher', 'student'));

-- 3.3 分值与学分检查
ALTER TABLE qbank.course
ADD CONSTRAINT ck_course_credit
CHECK (credit IS NULL OR credit >= 0);

ALTER TABLE qbank.question_type
ADD CONSTRAINT ck_question_type_default_score
CHECK (default_score >= 0);

ALTER TABLE qbank.course_question_type
ADD CONSTRAINT ck_course_question_type_default_score
CHECK (default_score IS NULL OR default_score >= 0);

ALTER TABLE qbank.question
ADD CONSTRAINT ck_question_score
CHECK (score >= 0);

ALTER TABLE qbank.paper
ADD CONSTRAINT ck_paper_total_score
CHECK (total_score >= 0);

ALTER TABLE qbank.paper_question
ADD CONSTRAINT ck_paper_question_score
CHECK (score >= 0);

ALTER TABLE qbank.paper_rule
ADD CONSTRAINT ck_paper_rule_score_per_question
CHECK (score_per_question >= 0);

-- 3.4 难度检查
ALTER TABLE qbank.question
ADD CONSTRAINT ck_question_difficulty
CHECK (difficulty BETWEEN 1 AND 5);

ALTER TABLE qbank.paper_rule
ADD CONSTRAINT ck_paper_rule_difficulty
CHECK (difficulty IS NULL OR difficulty BETWEEN 1 AND 5);

-- 3.5 抽题次数与数量检查
ALTER TABLE qbank.question
ADD CONSTRAINT ck_question_extract_count
CHECK (extract_count >= 0);

ALTER TABLE qbank.paper_rule
ADD CONSTRAINT ck_paper_rule_question_count
CHECK (question_count >= 0);

-- 3.6 排序号非负检查
ALTER TABLE qbank.course_question_type
ADD CONSTRAINT ck_course_question_type_sort_no
CHECK (sort_no >= 0);

ALTER TABLE qbank.chapter
ADD CONSTRAINT ck_chapter_sort_no
CHECK (sort_no >= 0);

ALTER TABLE qbank.knowledge_point
ADD CONSTRAINT ck_knowledge_point_sort_no
CHECK (sort_no >= 0);

ALTER TABLE qbank.question_option
ADD CONSTRAINT ck_question_option_sort_no
CHECK (sort_no >= 0);

ALTER TABLE qbank.paper_question
ADD CONSTRAINT ck_paper_question_order_no
CHECK (order_no >= 0);

-- 3.7 试卷类型与状态检查
ALTER TABLE qbank.paper
ADD CONSTRAINT ck_paper_type
CHECK (paper_type IN ('auto', 'manual'));

ALTER TABLE qbank.paper
ADD CONSTRAINT ck_paper_status
CHECK (status IN ('draft', 'published', 'archived', 'disabled', 'deleted'));

-- 3.8 日志与备份字段检查
ALTER TABLE qbank.login_log
ADD CONSTRAINT ck_login_log_status
CHECK (login_status IS NULL OR login_status IN ('success', 'failed'));

ALTER TABLE qbank.audit_log
ADD CONSTRAINT ck_audit_log_operation
CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE'));

ALTER TABLE qbank.backup_history
ADD CONSTRAINT ck_backup_history_type
CHECK (backup_type IN ('backup', 'restore'));

ALTER TABLE qbank.backup_history
ADD CONSTRAINT ck_backup_history_status
CHECK (status IN ('success', 'failed'));

-- 3.9 文件大小检查
ALTER TABLE qbank.question_attachment
ADD CONSTRAINT ck_question_attachment_file_size
CHECK (file_size IS NULL OR file_size >= 0);

-- =============================================================================
-- 四、参照完整性：外键约束
-- 说明：外键统一使用默认 NO ACTION / RESTRICT，不使用 ON DELETE CASCADE
-- =============================================================================

-- 4.1 用户角色与教师外键
ALTER TABLE qbank.sys_user_role
ADD CONSTRAINT fk_sys_user_role_user
FOREIGN KEY (user_id) REFERENCES qbank.sys_user(user_id);

ALTER TABLE qbank.sys_user_role
ADD CONSTRAINT fk_sys_user_role_role
FOREIGN KEY (role_id) REFERENCES qbank.sys_role(role_id);

ALTER TABLE qbank.teacher
ADD CONSTRAINT fk_teacher_user
FOREIGN KEY (user_id) REFERENCES qbank.sys_user(user_id);

-- 4.2 课程、题型、章节、知识点外键
ALTER TABLE qbank.course
ADD CONSTRAINT fk_course_owner_teacher
FOREIGN KEY (owner_teacher_id) REFERENCES qbank.teacher(teacher_id);

ALTER TABLE qbank.course_question_type
ADD CONSTRAINT fk_course_question_type_course
FOREIGN KEY (course_id) REFERENCES qbank.course(course_id);

ALTER TABLE qbank.course_question_type
ADD CONSTRAINT fk_course_question_type_type
FOREIGN KEY (type_id) REFERENCES qbank.question_type(type_id);

ALTER TABLE qbank.chapter
ADD CONSTRAINT fk_chapter_course
FOREIGN KEY (course_id) REFERENCES qbank.course(course_id);

ALTER TABLE qbank.chapter
ADD CONSTRAINT fk_chapter_parent
FOREIGN KEY (parent_id) REFERENCES qbank.chapter(chapter_id);

ALTER TABLE qbank.knowledge_point
ADD CONSTRAINT fk_knowledge_point_chapter
FOREIGN KEY (course_id, chapter_id)
REFERENCES qbank.chapter(course_id, chapter_id);

-- 4.3 习题相关外键
-- fk_question_course_type：保证只有课程已配置的题型才能录入到该课程习题中
ALTER TABLE qbank.question
ADD CONSTRAINT fk_question_course
FOREIGN KEY (course_id) REFERENCES qbank.course(course_id);

ALTER TABLE qbank.question
ADD CONSTRAINT fk_question_course_type
FOREIGN KEY (course_id, type_id)
REFERENCES qbank.course_question_type(course_id, type_id);

-- fk_question_chapter：保证题目章节属于该课程
ALTER TABLE qbank.question
ADD CONSTRAINT fk_question_chapter
FOREIGN KEY (course_id, chapter_id)
REFERENCES qbank.chapter(course_id, chapter_id);

-- knowledge_point_id 为 NULL 时复合外键不会阻止插入
ALTER TABLE qbank.question
ADD CONSTRAINT fk_question_knowledge_point
FOREIGN KEY (course_id, chapter_id, knowledge_point_id)
REFERENCES qbank.knowledge_point(course_id, chapter_id, knowledge_point_id);

ALTER TABLE qbank.question
ADD CONSTRAINT fk_question_created_by
FOREIGN KEY (created_by) REFERENCES qbank.sys_user(user_id);

-- 4.4 选项、附件外键
ALTER TABLE qbank.question_option
ADD CONSTRAINT fk_question_option_question
FOREIGN KEY (question_id) REFERENCES qbank.question(question_id);

ALTER TABLE qbank.question_attachment
ADD CONSTRAINT fk_question_attachment_question
FOREIGN KEY (question_id) REFERENCES qbank.question(question_id);

ALTER TABLE qbank.question_attachment
ADD CONSTRAINT fk_question_attachment_uploaded_by
FOREIGN KEY (uploaded_by) REFERENCES qbank.sys_user(user_id);

-- 4.5 试卷与组卷外键
-- paper_rule 的 type_id、chapter_id 允许为空，复合外键含 NULL 时不强制匹配
ALTER TABLE qbank.paper
ADD CONSTRAINT fk_paper_course
FOREIGN KEY (course_id) REFERENCES qbank.course(course_id);

ALTER TABLE qbank.paper
ADD CONSTRAINT fk_paper_created_by
FOREIGN KEY (created_by) REFERENCES qbank.sys_user(user_id);

ALTER TABLE qbank.paper_question
ADD CONSTRAINT fk_paper_question_paper
FOREIGN KEY (paper_id) REFERENCES qbank.paper(paper_id);

ALTER TABLE qbank.paper_question
ADD CONSTRAINT fk_paper_question_question
FOREIGN KEY (question_id) REFERENCES qbank.question(question_id);

ALTER TABLE qbank.paper_rule
ADD CONSTRAINT fk_paper_rule_paper
FOREIGN KEY (paper_id) REFERENCES qbank.paper(paper_id);

ALTER TABLE qbank.paper_rule
ADD CONSTRAINT fk_paper_rule_course
FOREIGN KEY (course_id) REFERENCES qbank.course(course_id);

ALTER TABLE qbank.paper_rule
ADD CONSTRAINT fk_paper_rule_course_type
FOREIGN KEY (course_id, type_id)
REFERENCES qbank.course_question_type(course_id, type_id);

ALTER TABLE qbank.paper_rule
ADD CONSTRAINT fk_paper_rule_chapter
FOREIGN KEY (course_id, chapter_id)
REFERENCES qbank.chapter(course_id, chapter_id);

ALTER TABLE qbank.paper_rule
ADD CONSTRAINT fk_paper_rule_created_by
FOREIGN KEY (created_by) REFERENCES qbank.sys_user(user_id);

-- 4.6 抽题日志、登录日志、审计日志、备份记录外键
ALTER TABLE qbank.extract_log
ADD CONSTRAINT fk_extract_log_paper
FOREIGN KEY (paper_id) REFERENCES qbank.paper(paper_id);

ALTER TABLE qbank.extract_log
ADD CONSTRAINT fk_extract_log_question
FOREIGN KEY (question_id) REFERENCES qbank.question(question_id);

ALTER TABLE qbank.extract_log
ADD CONSTRAINT fk_extract_log_operator
FOREIGN KEY (operator_id) REFERENCES qbank.sys_user(user_id);

ALTER TABLE qbank.login_log
ADD CONSTRAINT fk_login_log_user
FOREIGN KEY (user_id) REFERENCES qbank.sys_user(user_id);

ALTER TABLE qbank.audit_log
ADD CONSTRAINT fk_audit_log_user
FOREIGN KEY (user_id) REFERENCES qbank.sys_user(user_id);

ALTER TABLE qbank.backup_history
ADD CONSTRAINT fk_backup_history_operator
FOREIGN KEY (operator_id) REFERENCES qbank.sys_user(user_id);

\echo '[DONE] 完整性约束创建完成。'
