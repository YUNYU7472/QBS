-- =============================================================================
-- 文件名：09_init_roles.sql
-- 作用：初始化题库系统数据库连接用户与权限
-- 所属数据库：qbank_db
-- 所属 schema：qbank
-- 说明：
--   - 本文件用于体现数据库安全性和最小权限原则
--   - 本文件不创建表、约束、索引、视图、函数、存储过程、触发器和初始化业务数据
--   - 本文件建议在执行 08_create_triggers.sql 之后执行
--   - 后端应用不得使用超级用户 omm 连接数据库，应使用 qbank_app
-- 执行说明：
--   - 本脚本推荐在 reset_db.sh 重建后的数据库结构上执行
--   - 为避免重复初始化时触发“新密码不能与旧密码相同”的 openGauss 报错，
--     本脚本只在用户不存在时创建用户，不在每次初始化时重复 ALTER USER
-- =============================================================================

\echo '[INFO] 正在初始化题库管理系统角色与权限...'

SET search_path TO qbank, public;

-- =============================================================================
-- 1. 创建数据库连接用户
-- =============================================================================

-- 1.1 后端业务用户：Flask / 后端应用统一使用的业务连接账号
CREATE USER IF NOT EXISTS qbank_app PASSWORD 'DataBase@2026';

-- 1.2 只读审阅用户：课程验收、教师审阅或只读统计查询
CREATE USER IF NOT EXISTS qbank_readonly PASSWORD 'ReadOnly@2026';

-- 1.3 学生预览用户：只能查看不含答案解析的公开题目信息
CREATE USER IF NOT EXISTS qbank_student_viewer PASSWORD 'Student@2026';

-- =============================================================================
-- 2. 基础安全收敛（最小权限原则）
-- =============================================================================

REVOKE ALL ON SCHEMA qbank FROM PUBLIC;

-- =============================================================================
-- 3. 授予数据库连接权限
-- =============================================================================

GRANT CONNECT ON DATABASE qbank_db TO qbank_app;
GRANT CONNECT ON DATABASE qbank_db TO qbank_readonly;
GRANT CONNECT ON DATABASE qbank_db TO qbank_student_viewer;

-- =============================================================================
-- 4. 授予 schema 使用权限（不授予 CREATE）
-- =============================================================================

GRANT USAGE ON SCHEMA qbank TO qbank_app;
GRANT USAGE ON SCHEMA qbank TO qbank_readonly;
GRANT USAGE ON SCHEMA qbank TO qbank_student_viewer;

-- =============================================================================
-- 5. qbank_app：后端业务账号，执行业务增删改查与调用存储过程
-- =============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA qbank TO qbank_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA qbank TO qbank_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA qbank TO qbank_app;

-- =============================================================================
-- 6. qbank_readonly：只读审阅，仅访问必要视图
-- =============================================================================

GRANT SELECT ON qbank.v_course_type_usage TO qbank_readonly;
GRANT SELECT ON qbank.v_question_public TO qbank_readonly;
GRANT SELECT ON qbank.v_question_teacher TO qbank_readonly;
GRANT SELECT ON qbank.v_paper_detail TO qbank_readonly;
GRANT SELECT ON qbank.v_course_question_stat TO qbank_readonly;

-- =============================================================================
-- 7. qbank_student_viewer：学生预览，仅访问公开视图（不含答案与解析）
-- =============================================================================

GRANT SELECT ON qbank.v_course_type_usage TO qbank_student_viewer;
GRANT SELECT ON qbank.v_question_public TO qbank_student_viewer;

\echo '[DONE] 角色与权限初始化完成。'
