-- =============================================================================
-- 文件名：04_create_indexes.sql
-- 作用：为学校题库管理系统创建业务查询索引
-- 所属数据库：qbank_db
-- 所属 schema：qbank
-- 说明：
--   - 本文件用于提升课程查询、题库检索、自动组卷、套题明细、日志审计等场景性能
--   - 本文件不创建主键、外键、唯一约束、检查约束
--   - 本文件不创建视图、函数、存储过程、触发器和初始化数据
--   - 本文件建议在执行 03_create_constraints.sql 之后执行
--   - 如需反复重建，建议使用 bash database/scripts/reset_db.sh
--   - 主键和唯一约束已由 03_create_constraints.sql 创建，本文件避免重复创建等价索引
-- 执行说明：
--   - 本脚本推荐在 reset_db.sh 重建后的数据库结构上执行
--   - 如需重复执行，请先执行 reset_db.sh 或 00_drop_all.sql 后重新初始化
-- =============================================================================

\echo '[INFO] 正在创建题库管理系统业务索引...'

SET search_path TO qbank, public;

-- =============================================================================
-- 一、用户、角色、教师相关索引
-- =============================================================================

-- sys_user_role：已有 (user_id, role_id) 唯一约束可支持按 user_id 查角色
-- 按 role_id 反查用户列表需单独索引
CREATE INDEX idx_sys_user_role_role_id
ON qbank.sys_user_role (role_id);

-- teacher：支持用户与教师档案关联查询、按教师状态筛选
CREATE INDEX idx_teacher_user_id
ON qbank.teacher (user_id);

CREATE INDEX idx_teacher_status
ON qbank.teacher (status);

-- =============================================================================
-- 二、课程、课程题型、章节、知识点相关索引
-- =============================================================================

-- course：支持按课程负责人查询课程、按课程状态筛选
CREATE INDEX idx_course_owner_teacher
ON qbank.course (owner_teacher_id);

CREATE INDEX idx_course_status
ON qbank.course (status);

-- course_question_type：已有 (course_id, type_id) 唯一约束，不重复创建
-- 支持按题型反查课程、查询某课程已启用题型并按排序号展示
CREATE INDEX idx_course_question_type_type_id
ON qbank.course_question_type (type_id);

CREATE INDEX idx_course_question_type_course_enabled_sort
ON qbank.course_question_type (course_id, enabled, sort_no);

-- chapter：已有 (course_id, chapter_no) 与 (course_id, chapter_id) 唯一约束
-- 支持按课程展示章节树、查找某章节的子章节
CREATE INDEX idx_chapter_course_parent_sort
ON qbank.chapter (course_id, parent_id, sort_no);

CREATE INDEX idx_chapter_parent_id
ON qbank.chapter (parent_id);

-- knowledge_point：已有复合唯一约束，不重复创建
-- 支持按课程章节展示知识点、按知识点状态筛选
CREATE INDEX idx_knowledge_point_chapter_sort
ON qbank.knowledge_point (course_id, chapter_id, sort_no);

CREATE INDEX idx_knowledge_point_status
ON qbank.knowledge_point (status);

-- =============================================================================
-- 三、题库检索与自动组卷索引
-- 支持按课程、题型、章节、难度、状态查询题目，并服务于自动组卷过程
-- =============================================================================

-- question：按课程、题型、状态查询习题
CREATE INDEX idx_question_course_type_status
ON qbank.question (course_id, type_id, status);

-- question：按课程、章节、状态查询习题
CREATE INDEX idx_question_course_chapter_status
ON qbank.question (course_id, chapter_id, status);

-- question：自动组卷筛选候选题，extract_count 便于低抽取次数优先策略
CREATE INDEX idx_question_auto_pick
ON qbank.question (course_id, type_id, chapter_id, difficulty, status, extract_count);

-- question：按知识点查询习题
CREATE INDEX idx_question_knowledge_point
ON qbank.question (course_id, chapter_id, knowledge_point_id);

-- question：查询教师创建的题目
CREATE INDEX idx_question_created_by
ON qbank.question (created_by);

-- question：按创建时间排序或筛选题目
CREATE INDEX idx_question_created_at
ON qbank.question (created_at);

-- question_option：已有 (question_id, option_label) 唯一约束，不重复创建 question_id 索引

-- question_attachment：支持查询某题附件、某用户上传的附件
CREATE INDEX idx_question_attachment_question_id
ON qbank.question_attachment (question_id);

CREATE INDEX idx_question_attachment_uploaded_by
ON qbank.question_attachment (uploaded_by);

-- question_tag：已有 tag_name 唯一约束，不额外创建索引

-- =============================================================================
-- 四、试卷与组卷相关索引
-- =============================================================================

-- paper：支持按课程、状态、创建时间查询试卷列表
CREATE INDEX idx_paper_course_status_created
ON qbank.paper (course_id, status, created_at);

-- paper：支持查询某用户创建的试卷
CREATE INDEX idx_paper_created_by
ON qbank.paper (created_by);

-- paper：支持按自动/手动组卷类型筛选
CREATE INDEX idx_paper_type
ON qbank.paper (paper_type);

-- paper_question：已有 (paper_id, question_id) 唯一约束，不重复创建 paper_id 索引
-- 支持反查某题被哪些套题使用、按试卷题目顺序展示明细
CREATE INDEX idx_paper_question_question_id
ON qbank.paper_question (question_id);

CREATE INDEX idx_paper_question_paper_order
ON qbank.paper_question (paper_id, order_no);

-- paper_rule：支持查询某试卷对应组卷规则、按课程/题型/章节查询规则
CREATE INDEX idx_paper_rule_paper_id
ON qbank.paper_rule (paper_id);

CREATE INDEX idx_paper_rule_course_type_chapter
ON qbank.paper_rule (course_id, type_id, chapter_id);

CREATE INDEX idx_paper_rule_created_by
ON qbank.paper_rule (created_by);

-- =============================================================================
-- 五、抽题日志索引
-- 支持统计抽题历史、查询套题抽题过程、按时间范围分析
-- =============================================================================

CREATE INDEX idx_extract_log_question_time
ON qbank.extract_log (question_id, extracted_at);

CREATE INDEX idx_extract_log_paper_time
ON qbank.extract_log (paper_id, extracted_at);

CREATE INDEX idx_extract_log_operator_time
ON qbank.extract_log (operator_id, extracted_at);

CREATE INDEX idx_extract_log_time
ON qbank.extract_log (extracted_at);

-- =============================================================================
-- 六、登录日志、审计日志、备份记录索引
-- =============================================================================

-- login_log：支持查询用户登录历史、按用户名查询、统计成功/失败记录
CREATE INDEX idx_login_log_user_time
ON qbank.login_log (user_id, login_time);

CREATE INDEX idx_login_log_username_time
ON qbank.login_log (username, login_time);

CREATE INDEX idx_login_log_status_time
ON qbank.login_log (login_status, login_time);

-- audit_log：支持查询用户操作历史、按表名/操作类型/时间查询、追踪记录变更
CREATE INDEX idx_audit_log_user_time
ON qbank.audit_log (user_id, operated_at);

CREATE INDEX idx_audit_log_table_operation_time
ON qbank.audit_log (table_name, operation, operated_at);

CREATE INDEX idx_audit_log_table_record
ON qbank.audit_log (table_name, record_id);

-- backup_history：支持查询用户备份/恢复操作、按类型/状态/时间查询历史
CREATE INDEX idx_backup_history_operator_time
ON qbank.backup_history (operator_id, created_at);

CREATE INDEX idx_backup_history_type_status_time
ON qbank.backup_history (backup_type, status, created_at);

\echo '[DONE] 业务索引创建完成。'
