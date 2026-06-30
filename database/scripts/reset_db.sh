#!/usr/bin/env bash
set -e

# =============================================================================
# reset_db.sh — 删除并重建 qbank_db，随后调用 init_db.sh 初始化
# =============================================================================

CONTAINER_NAME="qbank-opengauss"
DB_NAME="qbank_db"
ADMIN_DB="postgres"
DB_PORT="5432"
ADMIN_USER="omm"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_SCRIPT="${SCRIPT_DIR}/init_db.sh"

# 在容器内以 omm 用户执行 gsql 命令（-c 模式）
run_gsql_cmd() {
  local db="$1"
  local sql_cmd="$2"
  docker exec "${CONTAINER_NAME}" bash -lc \
    "su - ${ADMIN_USER} -c \"gsql -d ${db} -p ${DB_PORT} -c \\\"${sql_cmd}\\\"\""
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

# 删除目标数据库（失败时给出明确提示）
drop_database() {
  echo "[INFO] 正在删除数据库 ${DB_NAME}..."
  local drop_output
  local drop_status

  set +e
  drop_output="$(run_gsql_cmd "${ADMIN_DB}" "DROP DATABASE IF EXISTS ${DB_NAME};" 2>&1)"
  drop_status=$?
  set -e

  if [[ ${drop_status} -ne 0 ]]; then
    echo "[ERROR] 删除数据库 ${DB_NAME} 失败。"
    echo "${drop_output}"
    echo ""
    echo "[提示] 可能存在活动连接占用该数据库（例如后端服务、gsql 客户端未退出）。"
    echo "[提示] 请先停止占用连接的应用，或重启容器后重试："
    echo "       docker restart ${CONTAINER_NAME}"
    echo "       bash ${INIT_SCRIPT%/*}/reset_db.sh"
    exit 1
  fi

  echo "[INFO] 数据库 ${DB_NAME} 已删除。"
}

# 重新创建目标数据库
create_database() {
  echo "[INFO] 正在重新创建数据库 ${DB_NAME}..."
  run_gsql_cmd "${ADMIN_DB}" "CREATE DATABASE ${DB_NAME};"
  echo "[INFO] 数据库 ${DB_NAME} 创建成功。"
}

main() {
  echo "========================================"
  echo "  题库管理系统 — 数据库重置"
  echo "========================================"

  check_docker
  check_container_exists
  ensure_container_running

  # 检查数据库是否存在，存在则删除
  local result
  result="$(docker exec "${CONTAINER_NAME}" bash -lc \
    "su - ${ADMIN_USER} -c \"gsql -d ${ADMIN_DB} -p ${DB_PORT} -t -A -c \\\"SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';\\\"\"" \
    2>/dev/null | tr -d '[:space:]')"

  if [[ "${result}" == "1" ]]; then
    drop_database
  else
    echo "[INFO] 数据库 ${DB_NAME} 不存在，跳过删除步骤。"
  fi

  create_database

  echo "[INFO] 正在调用 init_db.sh 完成初始化..."
  bash "${INIT_SCRIPT}"

  echo "[DONE] 数据库重置完成。"
}

main "$@"
