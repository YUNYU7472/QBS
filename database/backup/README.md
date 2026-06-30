# 数据库备份目录说明

## 用途

`backup/` 目录用于存放 **题库管理系统（qbank_db）** 的数据库逻辑备份文件。备份由 `scripts/backup_db.sh` 脚本自动生成。

## 使用约定

1. **请勿随意删除**备份文件，尤其是团队共享环境或演示/demo 数据的重要快照。
2. **建议命名格式**：`qbank_db_YYYYMMDD_HHMMSS.sql`  
   示例：`qbank_db_20260630_143025.sql`
3. **Git 提交**：若备份文件体积较大，**不建议**将其提交到 Git 仓库，可在本地保留或上传至团队约定的网盘/备份服务器。
4. **`.gitkeep` 说明**：该文件用于在 Git 中保留空的 `backup/` 目录结构；目录内实际备份文件可按需加入 `.gitignore`。

## 相关脚本

- 创建备份：`bash database/scripts/backup_db.sh`
- 从备份恢复：`bash database/scripts/restore_db.sh database/backup/备份文件名.sql`

恢复前建议先执行 `reset_db.sh` 或确认当前数据库状态，避免与现有对象冲突。
