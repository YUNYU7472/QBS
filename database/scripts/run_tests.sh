#!/usr/bin/env bash
set -e

# =============================================================================
# run_tests.sh — 一键执行数据库验收测试脚本 11_test_queries.sql
# =============================================================================

CONTAINER_NAME="qbank-opengauss"
DB_NAME="qbank_db"
DB_PORT="5432"
ADMIN_USER="omm"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SQL_FILE="${DATABASE_DIR}/11_test_queries.sql"
BACKUP_DIR="${DATABASE_DIR}/backup"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup_db.sh"
RESTORE_SCRIPT="${SCRIPT_DIR}/restore_db.sh"

check_docker() {
  echo "[INFO] 正在检查 Docker 环境..."
  if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] 未找到 docker 命令，请先安装并启动 Docker。"
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "[ERROR] Docker 未运行或无权限访问，请启动 Docker 后重试。"
    exit 1
  fi
  echo "[PASS] Docker 可用。"
}

check_container_exists() {
  echo "[INFO] 正在检查 openGauss 容器 ${CONTAINER_NAME}..."
  if ! docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
    echo "[ERROR] 容器 ${CONTAINER_NAME} 不存在，请先创建并配置 openGauss 容器。"
    exit 1
  fi
  echo "[PASS] 容器 ${CONTAINER_NAME} 已存在。"
}

ensure_container_running() {
  local status
  status="$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || echo "false")"
  if [[ "${status}" != "true" ]]; then
    echo "[INFO] 容器未运行，正在启动 ${CONTAINER_NAME}..."
    docker start "${CONTAINER_NAME}" >/dev/null
    echo "[INFO] 等待容器内 openGauss 服务就绪..."
    sleep 3
    echo "[PASS] 容器已启动。"
  else
    echo "[PASS] 容器 ${CONTAINER_NAME} 已在运行。"
  fi
}

check_test_sql_file() {
  echo "[INFO] 正在检查验收测试脚本..."
  if [[ ! -f "${SQL_FILE}" ]]; then
    echo "[ERROR] 测试脚本不存在: ${SQL_FILE}"
    exit 1
  fi
  echo "[PASS] 找到测试脚本: 11_test_queries.sql"
}

check_backup_support() {
  echo "[INFO] 正在检查备份恢复支撑文件..."

  if [[ -f "${BACKUP_SCRIPT}" ]]; then
    echo "[PASS] 找到备份脚本: scripts/backup_db.sh"
  else
    echo "[WARN] 未找到备份脚本: scripts/backup_db.sh"
  fi

  if [[ -f "${RESTORE_SCRIPT}" ]]; then
    echo "[PASS] 找到恢复脚本: scripts/restore_db.sh"
  else
    echo "[WARN] 未找到恢复脚本: scripts/restore_db.sh"
  fi

  if [[ -d "${BACKUP_DIR}" ]]; then
    echo "[PASS] 找到备份目录: backup/"
    if [[ -f "${BACKUP_DIR}/README.md" ]]; then
      echo "[PASS] 找到备份说明: backup/README.md"
    else
      echo "[WARN] 未找到 backup/README.md"
    fi
  else
    echo "[WARN] 未找到备份目录: backup/"
  fi
}

run_test_queries() {
  echo "[INFO] 正在复制 11_test_queries.sql 到容器..."
  docker cp "${SQL_FILE}" "${CONTAINER_NAME}:/tmp/11_test_queries.sql"

  echo "[INFO] 正在执行数据库验收测试..."
  docker exec "${CONTAINER_NAME}" bash -lc \
    "su - ${ADMIN_USER} -c 'gsql -d ${DB_NAME} -p ${DB_PORT} -f /tmp/11_test_queries.sql'"
}

main() {
  echo "========================================"
  echo "  题库管理系统 — 数据库验收测试"
  echo "  数据库目录: ${DATABASE_DIR}"
  echo "========================================"
  echo "[INFO] 如需完整重建后测试，请先执行: bash database/scripts/reset_db.sh"
  echo ""

  check_docker
  check_container_exists
  ensure_container_running
  check_test_sql_file
  check_backup_support
  run_test_queries

  echo ""
  echo "[DONE] 数据库验收测试执行完成。"
}

main "$@"
