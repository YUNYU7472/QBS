#!/usr/bin/env bash
set -e

# =============================================================================
# backup_db.sh — 对 qbank_db 进行逻辑备份，输出至 database/backup/
# =============================================================================

CONTAINER_NAME="qbank-opengauss"
DB_NAME="qbank_db"
DB_PORT="5432"
ADMIN_USER="omm"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_DIR="${DATABASE_DIR}/backup"

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
  echo "========================================"
  echo "  题库管理系统 — 数据库备份"
  echo "========================================"

  check_docker
  check_container_exists
  ensure_container_running

  # 确保备份目录存在
  mkdir -p "${BACKUP_DIR}"

  local timestamp
  timestamp="$(date +%Y%m%d_%H%M%S)"
  local backup_filename="${DB_NAME}_${timestamp}.sql"
  local container_tmp="/tmp/${backup_filename}"
  local local_backup="${BACKUP_DIR}/${backup_filename}"

  echo "[INFO] 正在备份数据库 ${DB_NAME}..."
  echo "[INFO] 使用 gs_dump 进行逻辑备份..."
  echo "[INFO] gs_dump 使用 openGauss 位置参数语法：gs_dump -p <port> <dbname> -f <file>"

  docker exec "${CONTAINER_NAME}" bash -lc \
    "su - ${ADMIN_USER} -c 'gs_dump -p ${DB_PORT} ${DB_NAME} -f ${container_tmp}'"

  echo "[INFO] 正在将备份文件复制到本地..."
  docker cp "${CONTAINER_NAME}:${container_tmp}" "${local_backup}"

  # 清理容器内临时文件
  docker exec "${CONTAINER_NAME}" bash -lc "rm -f ${container_tmp}" 2>/dev/null || true

  if [[ -f "${local_backup}" ]] && [[ -s "${local_backup}" ]]; then
    echo "[PASS] 备份文件已生成且非空。"
  else
    echo "[ERROR] 备份文件未生成或为空。"
    exit 1
  fi

  echo "[DONE] 数据库备份完成。"
  echo "[INFO] 备份文件路径: ${local_backup}"
}

main "$@"
