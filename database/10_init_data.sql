-- =============================================================================
-- 文件名：10_init_data.sql
-- 作用：初始化题库系统演示数据
-- 所属数据库：qbank_db
-- 所属 schema：qbank
-- 说明：
--   - 本文件用于插入课程、题型、章节、知识点、习题、选项、试卷等演示数据
--   - 本文件不创建表、约束、索引、视图、函数、存储过程、触发器和角色权限
--   - 本文件建议在执行 09_init_roles.sql 之后执行
--   - 本文件中的数据用于课程设计验收和后续 11_test_queries.sql 测试
-- 注意：
--   - password_hash 仅用于课程设计演示，不代表真实密码加密方案
--   - 不要手动更新 question.extract_count，不要手动插入 extract_log
--   - 插入 paper_question 后由触发器自动维护 extract_count、extract_log 和 paper.total_score
-- =============================================================================

\echo '[INFO] 正在初始化题库管理系统演示数据...'

SET search_path TO qbank, public;

-- =============================================================================
-- 1. 系统角色
-- =============================================================================

INSERT INTO qbank.sys_role (role_id, role_code, role_name, description, status) VALUES
(1, 'admin',   '系统管理员', '系统管理与配置', 'active'),
(2, 'teacher', '教师',       '题库管理与组卷', 'active'),
(3, 'student', '学生',       '题目预览与练习', 'active');

-- =============================================================================
-- 2. 系统用户（password_hash 为演示占位值）
-- =============================================================================

INSERT INTO qbank.sys_user (
    user_id, username, password_hash, real_name, email, phone, user_type, status, remark
) VALUES
(1, 'admin_user',    'demo_hash_admin',         '系统管理员',   'admin@demo.edu',   '13800000001', 'admin',   'active', '演示管理员账号'),
(2, 'teacher_zhang', 'demo_hash_teacher_zhang', '张老师',       'zhang@demo.edu',   '13800000002', 'teacher', 'active', '数据库课程教师'),
(3, 'teacher_li',    'demo_hash_teacher_li',    '李老师',       'li@demo.edu',      '13800000003', 'teacher', 'active', '数据结构课程教师'),
(4, 'student_demo',  'demo_hash_student',       '学生演示用户', 'student@demo.edu', '13800000004', 'student', 'active', '演示学生账号');

-- =============================================================================
-- 3. 用户角色关系
-- =============================================================================

INSERT INTO qbank.sys_user_role (user_role_id, user_id, role_id) VALUES
(1, 1, 1),
(2, 2, 2),
(3, 3, 2),
(4, 4, 3);

-- =============================================================================
-- 4. 教师信息
-- =============================================================================

INSERT INTO qbank.teacher (
    teacher_id, user_id, teacher_no, teacher_name, department, status
) VALUES
(1, 2, 'T001', '张老师', '数据库课程组', 'active'),
(2, 3, 'T002', '李老师', '数据结构课程组', 'active');

-- =============================================================================
-- 5. 课程信息
-- =============================================================================

INSERT INTO qbank.course (
    course_id, course_code, course_name, credit, owner_teacher_id, status
) VALUES
(1, 'DB001', '数据库系统', 3.0, 1, 'active'),
(2, 'DS001', '数据结构',   4.0, 2, 'active');

-- =============================================================================
-- 6. 题型信息
-- =============================================================================

INSERT INTO qbank.question_type (
    type_id, type_code, type_name, default_score, objective_flag, status
) VALUES
(1, 'single',   '单选题', 2.00,  TRUE,  'active'),
(2, 'multiple', '多选题', 3.00,  TRUE,  'active'),
(3, 'judgment', '判断题', 1.00,  TRUE,  'active'),
(4, 'short',    '简答题', 10.00, FALSE, 'active');

-- =============================================================================
-- 7. 课程题型关系
-- =============================================================================

INSERT INTO qbank.course_question_type (
    course_type_id, course_id, type_id, default_score, enabled, sort_no
) VALUES
(1, 1, 1, 2.00,  TRUE, 1),
(2, 1, 2, 3.00,  TRUE, 2),
(3, 1, 3, 1.00,  TRUE, 3),
(4, 1, 4, 10.00, TRUE, 4),
(5, 2, 1, 2.00,  TRUE, 1),
(6, 2, 3, 1.00,  TRUE, 2),
(7, 2, 4, 10.00, TRUE, 3);

-- =============================================================================
-- 8. 章节信息
-- =============================================================================

INSERT INTO qbank.chapter (
    chapter_id, course_id, chapter_no, chapter_name, sort_no, status
) VALUES
(1, 1, '01', '数据库概述', 1, 'active'),
(2, 1, '02', '关系模型',   2, 'active'),
(3, 1, '03', 'SQL基础',    3, 'active'),
(4, 2, '01', '线性表',     1, 'active'),
(5, 2, '02', '树与图',     2, 'active');

-- =============================================================================
-- 9. 知识点信息
-- =============================================================================

INSERT INTO qbank.knowledge_point (
    knowledge_point_id, course_id, chapter_id, point_name, sort_no, status
) VALUES
(1, 1, 1, '数据库基本概念', 1, 'active'),
(2, 1, 2, '关系代数',       1, 'active'),
(3, 1, 3, 'SQL查询',        1, 'active'),
(4, 2, 4, '顺序表',         1, 'active'),
(5, 2, 5, '二叉树',         1, 'active');

-- =============================================================================
-- 10. 题目标签
-- =============================================================================

INSERT INTO qbank.question_tag (tag_id, tag_name, status) VALUES
(1, '基础', 'active'),
(2, '重点', 'active'),
(3, 'SQL',  'active');

-- =============================================================================
-- 11. 习题主体（extract_count 使用默认值 0，由触发器维护）
-- =============================================================================

INSERT INTO qbank.question (
    question_id, course_id, type_id, chapter_id, knowledge_point_id,
    stem, answer, analysis, difficulty, score, status, created_by
) VALUES
(1, 1, 1, 1, 1,
 '数据库管理系统的英文缩写是什么？',
 'DBMS',
 'DBMS 是 Database Management System 的缩写。',
 2, 2.00, 'active', 2),
(2, 1, 3, 1, 1,
 '数据库系统只包含数据库本身。',
 '错误',
 '数据库系统还包括 DBMS、应用系统、DBA 等组成部分。',
 1, 1.00, 'active', 2),
(3, 1, 1, 2, 2,
 '关系模型中一行通常称为什么？',
 '元组',
 '关系中的一行称为元组，一列称为属性。',
 2, 2.00, 'active', 2),
(4, 1, 2, 3, 3,
 'SQL 查询语句常见子句有哪些？',
 'SELECT、FROM、WHERE',
 'SELECT 选取列，FROM 指定表，WHERE 指定条件。',
 3, 3.00, 'active', 2),
(5, 1, 4, 2, 2,
 '简述主键与外键的作用。',
 '主键唯一标识表中记录；外键建立表间引用关系并保证参照完整性。',
 '主键保证实体完整性，外键保证参照完整性。',
 3, 10.00, 'active', 2),
(6, 2, 1, 4, 4,
 '顺序表的存储特点是什么？',
 '逻辑上相邻的元素在物理存储上也尽量相邻',
 '顺序表采用连续存储，支持随机访问。',
 2, 2.00, 'active', 3),
(7, 2, 3, 5, 5,
 '二叉树每个结点最多有两个孩子。',
 '正确',
 '二叉树定义要求每个结点最多有两个子结点。',
 1, 1.00, 'active', 3),
(8, 2, 4, 4, 4,
 '简述栈和队列的区别。',
 '栈是后进先出，队列是先进先出。',
 '栈与队列都是线性结构，但操作受限方式不同。',
 3, 10.00, 'active', 3);

-- =============================================================================
-- 12. 选择题选项
-- =============================================================================

INSERT INTO qbank.question_option (
    option_id, question_id, option_label, option_content, is_correct, sort_no
) VALUES
(1, 1, 'A', 'DBMS', TRUE,  1),
(2, 1, 'B', 'DB',   FALSE, 2),
(3, 1, 'C', 'SQL',  FALSE, 3),
(4, 1, 'D', 'RDB',  FALSE, 4),
(5, 2, 'A', '正确', FALSE, 1),
(6, 2, 'B', '错误', TRUE,  2),
(7, 3, 'A', '属性', FALSE, 1),
(8, 3, 'B', '元组', TRUE,  2),
(9, 3, 'C', '关系', FALSE, 3),
(10, 3, 'D', '域',   FALSE, 4),
(11, 4, 'A', 'SELECT', TRUE,  1),
(12, 4, 'B', 'FROM',   TRUE,  2),
(13, 4, 'C', 'WHERE',  TRUE,  3),
(14, 4, 'D', 'INSERT', FALSE, 4),
(15, 6, 'A', '连续存储，支持随机访问', TRUE,  1),
(16, 6, 'B', '只能链式存储',           FALSE, 2),
(17, 6, 'C', '只能散列存储',           FALSE, 3),
(18, 6, 'D', '只能索引存储',           FALSE, 4),
(19, 7, 'A', '正确', TRUE,  1),
(20, 7, 'B', '错误', FALSE, 2);

-- =============================================================================
-- 13. 题目附件（演示元数据）
-- =============================================================================

INSERT INTO qbank.question_attachment (
    attachment_id, question_id, file_name, file_path, file_type, file_size, uploaded_by
) VALUES
(1, 1, 'dbms_intro.png', '/uploads/questions/dbms_intro.png', 'image/png', 102400, 2);

-- =============================================================================
-- 14. 试卷（total_score 初始为 0，插入明细后由触发器重算）
-- =============================================================================

INSERT INTO qbank.paper (
    paper_id, paper_name, course_id, total_score, paper_type, status, created_by
) VALUES
(1, '数据库系统基础练习卷', 1, 0, 'manual', 'draft', 2);

-- =============================================================================
-- 15. 套题明细（触发器将自动 extract_count+1、写入 extract_log、重算 total_score）
-- =============================================================================

INSERT INTO qbank.paper_question (paper_question_id, paper_id, question_id, order_no, score) VALUES
(1, 1, 1, 1, 2.00),
(2, 1, 2, 2, 1.00),
(3, 1, 3, 3, 2.00);

-- =============================================================================
-- 16. 组卷规则
-- =============================================================================

INSERT INTO qbank.paper_rule (
    rule_id, paper_id, course_id, type_id, chapter_id, difficulty,
    question_count, score_per_question, rule_content, created_by
) VALUES
(1, 1, 1, NULL, NULL, NULL, 3, 0,
 '手工组卷演示规则：从数据库系统课程中选择 3 道基础题', 2);

-- =============================================================================
-- 17. 系统配置
-- =============================================================================

INSERT INTO qbank.system_config (config_id, config_key, config_value, description, status) VALUES
(1, 'system_name',             '学校题库管理系统', '系统名称',           'active'),
(2, 'default_question_status', 'active',           '题目默认状态',       'active'),
(3, 'max_auto_question_count', '100',              '自动组卷最大抽题数', 'active');

-- =============================================================================
-- 18. 备份历史
-- =============================================================================

INSERT INTO qbank.backup_history (
    backup_id, file_name, file_path, backup_type, operator_id, status, remark
) VALUES
(1, 'qbank_db_demo_backup.sql', 'database/backup/qbank_db_demo_backup.sql',
 'backup', 1, 'success', '演示备份记录');

-- =============================================================================
-- 19. 审计日志（调用函数体现复用）
-- =============================================================================

SELECT qbank.fn_write_audit_log(
    1,
    'system_config',
    'INSERT',
    'system_name',
    NULL,
    '初始化系统配置',
    '127.0.0.1',
    '初始化数据脚本写入的演示审计日志'
);

-- =============================================================================
-- 20. 重置序列（显式 ID 插入后同步序列，避免后续主键冲突）
-- =============================================================================

SELECT setval('qbank.sys_role_role_id_seq', (SELECT MAX(role_id) FROM qbank.sys_role));
SELECT setval('qbank.sys_user_user_id_seq', (SELECT MAX(user_id) FROM qbank.sys_user));
SELECT setval('qbank.sys_user_role_user_role_id_seq', (SELECT MAX(user_role_id) FROM qbank.sys_user_role));
SELECT setval('qbank.teacher_teacher_id_seq', (SELECT MAX(teacher_id) FROM qbank.teacher));
SELECT setval('qbank.course_course_id_seq', (SELECT MAX(course_id) FROM qbank.course));
SELECT setval('qbank.question_type_type_id_seq', (SELECT MAX(type_id) FROM qbank.question_type));
SELECT setval('qbank.course_question_type_course_type_id_seq', (SELECT MAX(course_type_id) FROM qbank.course_question_type));
SELECT setval('qbank.chapter_chapter_id_seq', (SELECT MAX(chapter_id) FROM qbank.chapter));
SELECT setval('qbank.knowledge_point_knowledge_point_id_seq', (SELECT MAX(knowledge_point_id) FROM qbank.knowledge_point));
SELECT setval('qbank.question_tag_tag_id_seq', (SELECT MAX(tag_id) FROM qbank.question_tag));
SELECT setval('qbank.question_question_id_seq', (SELECT MAX(question_id) FROM qbank.question));
SELECT setval('qbank.question_option_option_id_seq', (SELECT MAX(option_id) FROM qbank.question_option));
SELECT setval('qbank.question_attachment_attachment_id_seq', (SELECT MAX(attachment_id) FROM qbank.question_attachment));
SELECT setval('qbank.paper_paper_id_seq', (SELECT MAX(paper_id) FROM qbank.paper));
SELECT setval('qbank.paper_question_paper_question_id_seq', (SELECT MAX(paper_question_id) FROM qbank.paper_question));
SELECT setval('qbank.paper_rule_rule_id_seq', (SELECT MAX(rule_id) FROM qbank.paper_rule));
SELECT setval('qbank.extract_log_extract_log_id_seq', (SELECT MAX(extract_log_id) FROM qbank.extract_log));
SELECT setval('qbank.audit_log_audit_log_id_seq', (SELECT MAX(audit_log_id) FROM qbank.audit_log));
SELECT setval('qbank.backup_history_backup_id_seq', (SELECT MAX(backup_id) FROM qbank.backup_history));
SELECT setval('qbank.system_config_config_id_seq', (SELECT MAX(config_id) FROM qbank.system_config));

\echo '[DONE] 演示数据初始化完成。'
