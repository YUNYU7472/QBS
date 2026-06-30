#!/usr/bin/env bash
set -e

# =============================================================================
# init_db.sh — 初始化 qbank_db 数据库并执行建库 SQL 脚本
# =============================================================================

CONTAINER_NAME="qbank-opengauss"
DB_NAME="qbank_db"
ADMIN_DB="postgres"
DB_PORT="5432"
ADMIN_USER="omm"

# 自动定位 database/ 目录（脚本位于 database/scripts/ 下）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 按顺序执行的 SQL 文件列表（不含 00_drop_all.sql 与 11_test_queries.sql）
SQL_FILES=(
  "01_create_schema.sql"
  "02_create_tables.sql"
  "03_create_constraints.sql"
  "04_create_indexes.sql"
  "05_create_views.sql"
  "06_create_functions.sql"
  "07_create_procedures.sql"
  "08_create_triggers.sql"
  "09_init_roles.sql"
  "10_init_data.sql"
)

# -----------------------------------------------------------------------------
# 工具函数
# -----------------------------------------------------------------------------

# 在容器内以 omm 用户执行 gsql 命令（-c 模式）
run_gsql_cmd() {
  local db="$1"
  local sql_cmd="$2"
  docker exec "${CONTAINER_NAME}" bash -lc \
    "su - ${ADMIN_USER} -c \"gsql -d ${db} -p ${DB_PORT} -c \\\"${sql_cmd}\\\"\""
}

# 检查 Docker 是否可用
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

# 检查容器是否存在
check_container_exists() {
  echo "[INFO] 正在检查容器 ${CONTAINER_NAME}..."
  if ! docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
    echo "[ERROR] 容器 ${CONTAINER_NAME} 不存在，请先创建并配置 openGauss 容器。"
    exit 1
  fi
  echo "[INFO] 容器 ${CONTAINER_NAME} 已存在。"
}

# 若容器未运行则启动
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

# 检查目标数据库是否存在，不存在则创建
ensure_database_exists() {
  echo "[INFO] 正在检查数据库 ${DB_NAME} 是否存在..."
  local result
  result="$(docker exec "${CONTAINER_NAME}" bash -lc \
    "su - ${ADMIN_USER} -c \"gsql -d ${ADMIN_DB} -p ${DB_PORT} -t -A -c \\\"SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';\\\"\"" \
    2>/dev/null | tr -d '[:space:]')"

  if [[ "${result}" == "1" ]]; then
    echo "[INFO] 数据库 ${DB_NAME} 已存在，跳过创建。"
  else
    echo "[INFO] 正在创建数据库 ${DB_NAME}..."
    run_gsql_cmd "${ADMIN_DB}" "CREATE DATABASE ${DB_NAME};"
    echo "[INFO] 数据库 ${DB_NAME} 创建成功。"
  fi
}

# 执行单个 SQL 文件
execute_sql_file() {
  local filename="$1"
  local local_path="${DATABASE_DIR}/${filename}"

  if [[ ! -f "${local_path}" ]]; then
    echo "[WARN] 文件不存在，跳过: ${filename}"
    return 0
  fi

  echo "[INFO] 正在执行 ${filename}..."
  docker cp "${local_path}" "${CONTAINER_NAME}:/tmp/${filename}"
  docker exec "${CONTAINER_NAME}" bash -lc \
    "su - ${ADMIN_USER} -c 'gsql -d ${DB_NAME} -p ${DB_PORT} -f /tmp/${filename}'"
  echo "[INFO] ${filename} 执行完成。"
}

# -----------------------------------------------------------------------------
# 主流程
# -----------------------------------------------------------------------------

main() {
  echo "========================================"
  echo "  题库管理系统 — 数据库初始化"
  echo "  数据库目录: ${DATABASE_DIR}"
  echo "========================================"

  check_docker
  check_container_exists
  ensure_container_running
  ensure_database_exists

  echo "[INFO] 开始按顺序执行 SQL 脚本..."
  for sql_file in "${SQL_FILES[@]}"; do
    execute_sql_file "${sql_file}"
  done

  echo "[DONE] 数据库初始化完成。"
}

main "$@"
