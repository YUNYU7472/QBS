#!/usr/bin/env bash
set -e

# =============================================================================
# restore_db.sh — 从备份文件恢复 qbank_db 数据库
# =============================================================================

CONTAINER_NAME="qbank-opengauss"
DB_NAME="qbank_db"
DB_PORT="5432"
ADMIN_USER="omm"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 默认进行干净恢复：删除并重建 qbank_db 后再导入备份
# 如确实想导入到当前已有库，可执行：CLEAN_RESTORE=0 bash database/scripts/restore_db.sh <备份文件>
CLEAN_RESTORE="${CLEAN_RESTORE:-1}"

print_usage() {
  echo "用法: bash $(basename "$0") <备份文件路径>"
  echo ""
  echo "示例:"
  echo "  bash database/scripts/restore_db.sh database/backup/qbank_db_20260630_143025.sql"
  echo ""
  echo "说明:"
  echo "  默认执行干净恢复：删除并重建 qbank_db 后再导入备份。"
  echo "  如需导入到当前已有库，可使用：CLEAN_RESTORE=0 bash database/scripts/restore_db.sh <备份文件>"
}

check_docker() {
  echo "[INFO] 正在检查 Docker..."
  if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] 未找到 docker 命令，请先安装并启动 Docker。"
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "[ERROR] Docker 未运行或无权限访问，请启动 Docker 后重试。"
    exit 1
  fi
  echo "[INFO] Docker 检查通过。"
}

check_container_exists() {
  echo "[INFO] 正在检查容器 ${CONTAINER_NAME}..."
  if ! docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
    echo "[ERROR] 容器 ${CONTAINER_NAME} 不存在，请先创建并配置 openGauss 容器。"
    exit 1
  fi
  echo "[INFO] 容器 ${CONTAINER_NAME} 已存在。"
}

ensure_container_running() {
  local status
  status="$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || echo "false")"
  if [[ "${status}" != "true" ]]; then
    echo "[INFO] 容器未运行，正在启动 ${CONTAINER_NAME}..."
    docker start "${CONTAINER_NAME}" >/dev/null
    echo "[INFO] 等待容器内 openGauss 服务就绪..."
    sleep 3
  else
    echo "[INFO] 容器 ${CONTAINER_NAME} 已在运行。"
  fi
}

main() {
  if [[ $# -lt 1 ]]; then
    echo "[ERROR] 缺少备份文件路径参数。"
    echo ""
    print_usage
    exit 1
  fi

  local backup_input="$1"
  local backup_path

  if [[ -f "${backup_input}" ]]; then
    backup_path="$(cd "$(dirname "${backup_input}")" && pwd)/$(basename "${backup_input}")"
  elif [[ -f "${DATABASE_DIR}/${backup_input}" ]]; then
    backup_path="$(cd "${DATABASE_DIR}/$(dirname "${backup_input}")" && pwd)/$(basename "${backup_input}")"
  else
    echo "[ERROR] 备份文件不存在: ${backup_input}"
    exit 1
  fi

  if [[ ! -s "${backup_path}" ]]; then
    echo "[ERROR] 备份文件为空: ${backup_path}"
    exit 1
  fi

  local backup_filename
  backup_filename="$(basename "${backup_path}")"
  local container_tmp="/tmp/${backup_filename}"

  echo "========================================"
  echo "  题库管理系统 — 数据库恢复"
  echo "========================================"
  echo ""
  echo "[WARN] 恢复操作会覆盖当前 ${DB_NAME} 数据库。"
  echo "[WARN] 请确认没有其他 gsql 窗口正在连接 ${DB_NAME}。"
  echo ""

  check_docker
  check_container_exists
  ensure_container_running

  echo "[INFO] 备份文件: ${backup_path}"
  echo "[INFO] 正在将备份文件复制到容器..."
  docker cp "${backup_path}" "${CONTAINER_NAME}:${container_tmp}"

  echo "[INFO] 正在修复容器内备份文件权限，确保 ${ADMIN_USER} 可读取..."
  docker exec "${CONTAINER_NAME}" bash -lc \
    "chown ${ADMIN_USER} '${container_tmp}' && chmod 600 '${container_tmp}'"

  if [[ "${CLEAN_RESTORE}" == "1" ]]; then
    echo "[INFO] 正在执行干净恢复：删除并重建数据库 ${DB_NAME}..."
    echo "[WARN] 如果此处失败，请先退出所有连接 ${DB_NAME} 的 gsql 窗口。"

    docker exec "${CONTAINER_NAME}" bash -lc \
      "su - ${ADMIN_USER} -c \"gsql -d postgres -p ${DB_PORT} -c 'DROP DATABASE IF EXISTS ${DB_NAME};' -c 'CREATE DATABASE ${DB_NAME};'\""

    echo "[PASS] 数据库 ${DB_NAME} 已重建为空库。"
  else
    echo "[WARN] CLEAN_RESTORE=0：将直接导入当前已有数据库，可能出现对象已存在冲突。"
  fi

  echo "[INFO] 正在从备份文件恢复数据库 ${DB_NAME}..."
  docker exec "${CONTAINER_NAME}" bash -lc \
    "su - ${ADMIN_USER} -c \"gsql -d ${DB_NAME} -p ${DB_PORT} -f '${container_tmp}'\""

  echo "[INFO] 正在清理容器内临时备份文件..."
  docker exec "${CONTAINER_NAME}" bash -lc "rm -f '${container_tmp}'" 2>/dev/null || true

  echo "[DONE] 数据库恢复完成。"
  echo "[INFO] 已从备份文件恢复: ${backup_filename}"
}

main "$@"
