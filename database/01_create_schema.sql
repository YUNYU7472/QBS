-- =============================================================================
-- 文件名：01_create_schema.sql
-- 作用：创建题库管理系统独立 schema
-- 说明：
--   - 后续所有项目对象统一归属 qbank schema
--   - 使用独立 schema 的意义：对象隔离、权限控制清晰、避免污染 public
-- =============================================================================

\echo '[INFO] 正在创建 schema qbank...'

-- 创建项目统一 schema
CREATE SCHEMA IF NOT EXISTS qbank;

-- 添加 schema 注释
COMMENT ON SCHEMA qbank IS '学校题库管理系统业务对象统一命名空间';

-- 设置当前会话 search_path（仅影响本脚本执行会话）
-- 后续 SQL 文件仍建议显式使用 qbank. 前缀引用对象，不要依赖隐式 schema
SET search_path TO qbank, public;

-- 设置数据库默认 search_path（新连接默认优先查找 qbank schema）
-- 即使设置了默认 search_path，后续 SQL 文件也应尽量显式写 qbank. 前缀
ALTER DATABASE qbank_db SET search_path TO qbank, public;

\echo '[DONE] Schema qbank 创建完成。'
