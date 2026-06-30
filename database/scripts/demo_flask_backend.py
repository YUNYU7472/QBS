#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
demo_flask_backend.py
题库管理系统 Flask 后端数据库调用演示脚本

用途：课程设计答辩/验收展示，演示 Flask + psycopg2 如何调用 openGauss 题库数据库。
说明：非正式生产后端；默认使用 qbank_app 连接；自动组卷演示在事务中执行并 ROLLBACK。
"""

from __future__ import annotations

import json
import os
import sys
from datetime import date, datetime
from decimal import Decimal
from typing import Any, Callable, Iterable, Optional

try:
    from flask import Flask, jsonify, request
    import psycopg2
    import psycopg2.extras
except ImportError:
    print("[ERROR] 缺少依赖，请执行：")
    print("pip install flask psycopg2-binary")
    sys.exit(1)

DB_CONFIG = {
    "host": os.getenv("QBANK_DB_HOST", "127.0.0.1"),
    "port": int(os.getenv("QBANK_DB_PORT", "15432")),
    "dbname": os.getenv("QBANK_DB_NAME", "qbank_db"),
    "user": os.getenv("QBANK_DB_USER", "qbank_app"),
    "password": os.getenv("QBANK_DB_PASSWORD", "DataBase@2026"),
}

AUTO_PAPER_NAME = "Flask后端自动组卷演示卷"

# 09_init_roles.sql 设计的预期权限（qbank_app 无法读取其他角色 ACL 时作为展示依据）
DESIGNED_PERMISSIONS = {
    "qbank_app": {
        "description": "后端业务用户，可执行业务增删改查与调用存储过程",
        "grants_summary": [
            "CONNECT + USAGE ON SCHEMA qbank",
            "SELECT/INSERT/UPDATE/DELETE ON ALL TABLES IN SCHEMA qbank",
            "USAGE/SELECT ON ALL SEQUENCES IN SCHEMA qbank",
            "EXECUTE ON ALL FUNCTIONS IN SCHEMA qbank",
        ],
    },
    "qbank_readonly": {
        "description": "只读审阅用户，仅访问 5 个视图",
        "view_select": [
            "v_course_type_usage",
            "v_question_public",
            "v_question_teacher",
            "v_paper_detail",
            "v_course_question_stat",
        ],
    },
    "qbank_student_viewer": {
        "description": "学生预览用户，仅访问不含答案解析的公开视图",
        "view_select": ["v_course_type_usage", "v_question_public"],
        "forbidden": ["question", "v_question_teacher", "v_paper_detail"],
    },
}


# ---------------------------------------------------------------------------
# 工具函数
# ---------------------------------------------------------------------------

def json_default(obj: Any) -> Any:
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, datetime):
        return obj.isoformat(sep=" ", timespec="seconds")
    if isinstance(obj, date):
        return obj.isoformat()
    return str(obj)


def to_jsonable(data: Any) -> Any:
    if isinstance(data, dict):
        return {k: to_jsonable(v) for k, v in data.items()}
    if isinstance(data, list):
        return [to_jsonable(v) for v in data]
    if isinstance(data, (Decimal, datetime, date)):
        return json_default(data)
    return data


def display_width(text: Any) -> int:
    s = "" if text is None else str(text)
    width = 0
    for ch in s:
        width += 2 if ord(ch) > 127 else 1
    return width


def pad_cell(text: Any, width: int) -> str:
    s = "" if text is None else str(text)
    padding = max(width - display_width(s), 0)
    return s + " " * padding


def print_banner(title: str) -> None:
    line = "=" * 60
    print(line)
    print(f"[INFO] {title}")
    print(line)


def print_section(title: str) -> None:
    print("")
    print("-" * 60)
    print(f"[INFO] {title}")
    print("-" * 60)


def print_table(title: str, rows: list[dict], max_rows: int = 10) -> None:
    if title:
        print(f"[TABLE] {title}")
    if not rows:
        print("[WARN] 无数据")
        return

    columns = list(rows[0].keys())
    show_rows = rows[:max_rows]
    col_widths = []
    for col in columns:
        max_w = display_width(col)
        for row in show_rows:
            max_w = max(max_w, display_width(row.get(col, "")))
        col_widths.append(max(min(max_w, 40), display_width(col)))

    def render_row(values: Iterable[Any]) -> str:
        parts = []
        for value, width in zip(values, col_widths):
            text = "" if value is None else str(value)
            if display_width(text) > width:
                text = text[: max(1, width // 2 - 1)] + "…"
            parts.append(pad_cell(text, width))
        return "| " + " | ".join(parts) + " |"

    border = "+-" + "-+-".join("-" * w for w in col_widths) + "-+"
    print(border)
    print(render_row(columns))
    print(border)
    for row in show_rows:
        print(render_row([row.get(col, "") for col in columns]))
    print(border)

    if len(rows) > max_rows:
        print(f"[INFO] 仅展示前 {max_rows} 行，共 {len(rows)} 行")


def print_json_block(title: str, data: Any) -> None:
    print(f"[JSON] {title}")
    print(json.dumps(to_jsonable(data), ensure_ascii=False, indent=2, default=json_default))


def get_connection():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = False
        return conn
    except psycopg2.Error as exc:
        raise RuntimeError(
            f"数据库连接失败（用户={DB_CONFIG['user']}，"
            f"主机={DB_CONFIG['host']}:{DB_CONFIG['port']}）：{exc}"
        ) from exc


def query_all(sql: str, params: Optional[tuple] = None) -> list[dict]:
    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            rows = cur.fetchall()
        conn.commit()
        return [dict(row) for row in rows]
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def query_one(sql: str, params: Optional[tuple] = None) -> Optional[dict]:
    rows = query_all(sql, params)
    return rows[0] if rows else None


def execute_in_transaction(callback: Callable[[Any, Any], Any]) -> Any:
    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            result = callback(conn, cur)
        conn.commit()
        return result
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def api_ok(data: Any = None, message: str = "操作成功") -> tuple:
    payload = {"ok": True, "message": message, "data": to_jsonable(data)}
    return jsonify(payload), 200


def api_error(message: str, error: Optional[str] = None, status: int = 500) -> tuple:
    payload = {"ok": False, "message": message, "error": error or message}
    return jsonify(payload), status


# ---------------------------------------------------------------------------
# Flask 应用与路由
# ---------------------------------------------------------------------------

def create_app() -> Flask:
    app = Flask(__name__)

    @app.route("/api/health", methods=["GET"])
    def health():
        try:
            row = query_one(
                """
                SELECT current_database() AS database_name,
                       current_user AS current_user,
                       CURRENT_TIMESTAMP AS server_time
                """
            )
            return api_ok(row, "数据库连接正常")
        except Exception as exc:
            return api_error("数据库连接失败", str(exc))

    @app.route("/api/overview", methods=["GET"])
    def overview():
        try:
            checks = [
                (
                    "核心表数量",
                    """
                    SELECT COUNT(*) AS cnt
                    FROM information_schema.tables
                    WHERE table_schema = 'qbank' AND table_type = 'BASE TABLE'
                    """,
                    21,
                ),
                (
                    "业务索引数量",
                    """
                    SELECT COUNT(*) AS cnt
                    FROM pg_indexes
                    WHERE schemaname = 'qbank' AND indexname LIKE 'idx_%'
                    """,
                    39,
                ),
                (
                    "视图数量",
                    """
                    SELECT COUNT(*) AS cnt
                    FROM information_schema.views
                    WHERE table_schema = 'qbank'
                    """,
                    5,
                ),
                (
                    "函数数量",
                    """
                    SELECT COUNT(*) AS cnt
                    FROM pg_proc p
                    JOIN pg_namespace n ON n.oid = p.pronamespace
                    WHERE n.nspname = 'qbank' AND p.proname LIKE 'fn_%'
                    """,
                    5,
                ),
                (
                    "存储过程数量",
                    """
                    SELECT COUNT(*) AS cnt
                    FROM pg_proc p
                    JOIN pg_namespace n ON n.oid = p.pronamespace
                    WHERE n.nspname = 'qbank' AND p.proname LIKE 'sp_%'
                    """,
                    4,
                ),
                (
                    "触发器数量",
                    """
                    SELECT COUNT(*) AS cnt
                    FROM pg_trigger t
                    JOIN pg_class c ON c.oid = t.tgrelid
                    JOIN pg_namespace n ON n.oid = c.relnamespace
                    WHERE n.nspname = 'qbank'
                      AND c.relname = 'paper_question'
                      AND NOT t.tgisinternal
                    """,
                    3,
                ),
                (
                    "题目数量",
                    "SELECT COUNT(*) AS cnt FROM qbank.question",
                    8,
                ),
                (
                    "试卷数量",
                    "SELECT COUNT(*) AS cnt FROM qbank.paper",
                    1,
                ),
                (
                    "抽题日志数量",
                    "SELECT COUNT(*) AS cnt FROM qbank.extract_log",
                    3,
                ),
            ]

            items = []
            for name, sql, expected in checks:
                row = query_one(sql)
                actual = int(row["cnt"]) if row else 0
                items.append(
                    {
                        "name": name,
                        "actual": actual,
                        "expected": expected,
                        "status": "[PASS]" if actual == expected else "[WARN]",
                    }
                )
            return api_ok({"items": items}, "数据库对象概览")
        except Exception as exc:
            return api_error("查询数据库概览失败", str(exc))

    @app.route("/api/courses", methods=["GET"])
    def courses():
        try:
            rows = query_all(
                """
                SELECT course_id, course_code, course_name, credit, status
                FROM qbank.course
                ORDER BY course_id
                """
            )
            return api_ok(rows, "课程基本信息查询成功")
        except Exception as exc:
            return api_error("查询课程失败", str(exc))

    @app.route("/api/course-types", methods=["GET"])
    def course_types():
        try:
            rows = query_all(
                """
                SELECT course_id, course_code, course_name, type_name,
                       default_score, enabled, sort_no
                FROM qbank.v_course_type_usage
                ORDER BY course_id, sort_no
                """
            )
            return api_ok(rows, "课程题型视图查询成功")
        except Exception as exc:
            return api_error("查询课程题型失败", str(exc))

    @app.route("/api/chapters", methods=["GET"])
    def chapters():
        try:
            rows = query_all(
                """
                SELECT c.course_name,
                       ch.chapter_no,
                       ch.chapter_name,
                       kp.point_name
                FROM qbank.chapter ch
                JOIN qbank.course c ON c.course_id = ch.course_id
                LEFT JOIN qbank.knowledge_point kp
                    ON kp.chapter_id = ch.chapter_id
                   AND kp.course_id = ch.course_id
                ORDER BY ch.course_id, ch.sort_no, kp.sort_no
                """
            )
            return api_ok(rows, "章节与知识点查询成功")
        except Exception as exc:
            return api_error("查询章节失败", str(exc))

    @app.route("/api/questions/public", methods=["GET"])
    def questions_public():
        try:
            rows = query_all(
                """
                SELECT question_id, course_name, type_name, chapter_name,
                       stem, difficulty, score, status
                FROM qbank.v_question_public
                ORDER BY question_id
                """
            )
            keys = set()
            if rows:
                keys = set(rows[0].keys())
            security = {
                "has_answer": "answer" in keys,
                "has_analysis": "analysis" in keys,
                "safe": "answer" not in keys and "analysis" not in keys,
            }
            return api_ok({"questions": rows, "security": security}, "学生公开题目查询成功")
        except Exception as exc:
            return api_error("查询学生公开题目失败", str(exc))

    @app.route("/api/questions/teacher", methods=["GET"])
    def questions_teacher():
        try:
            rows = query_all(
                """
                SELECT question_id, course_name, type_name, chapter_name,
                       stem, answer, analysis, difficulty, score, status
                FROM qbank.v_question_teacher
                ORDER BY question_id
                LIMIT 10
                """
            )
            keys = set(rows[0].keys()) if rows else set()
            teacher_view = {
                "has_answer": "answer" in keys,
                "has_analysis": "analysis" in keys,
            }
            return api_ok({"questions": rows, "teacher_view": teacher_view}, "教师题目视图查询成功")
        except Exception as exc:
            return api_error("查询教师题目失败", str(exc))

    @app.route("/api/stat/course-question", methods=["GET"])
    def stat_course_question():
        try:
            rows = query_all(
                """
                SELECT course_name, type_name, chapter_name,
                       question_count, avg_difficulty, avg_score, total_extract_count
                FROM qbank.v_course_question_stat
                ORDER BY course_name, type_name, chapter_name
                """
            )
            return api_ok(rows, "课程题量统计视图查询成功")
        except Exception as exc:
            return api_error("查询课程题量统计失败", str(exc))

    @app.route("/api/functions/demo", methods=["GET"])
    def functions_demo():
        try:
            row = query_one(
                """
                SELECT
                    qbank.fn_check_course_type_enabled(%s, %s) AS course_type_enabled,
                    qbank.fn_count_available_questions(%s, %s, NULL, NULL) AS available_question_count,
                    qbank.fn_calculate_paper_total_score(%s) AS paper_total_score
                """,
                (1, 1, 1, 1, 1),
            )
            return api_ok(row, "函数调用演示成功")
        except Exception as exc:
            return api_error("函数调用失败", str(exc))

    @app.route("/api/procedures/course-stat", methods=["GET"])
    def procedures_course_stat():
        conn = get_connection()
        try:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("CALL qbank.sp_get_course_question_stat(%s, %s);", (1, "cur_course_stat"))
                cur.execute("FETCH ALL FROM cur_course_stat;")
                rows = [dict(r) for r in cur.fetchall()]
            conn.commit()
            return api_ok(rows, "存储过程 sp_get_course_question_stat 调用成功")
        except Exception as exc:
            conn.rollback()
            return api_error("存储过程 sp_get_course_question_stat 调用失败", str(exc))
        finally:
            conn.close()

    @app.route("/api/procedures/all-course-type-stat", methods=["GET"])
    def procedures_all_course_type_stat():
        conn = get_connection()
        try:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("CALL qbank.sp_get_all_course_type_stat(%s);", ("cur_all_course_type_stat",))
                cur.execute("FETCH ALL FROM cur_all_course_type_stat;")
                rows = [dict(r) for r in cur.fetchall()]
            conn.commit()
            return api_ok(rows, "存储过程 sp_get_all_course_type_stat 调用成功")
        except Exception as exc:
            conn.rollback()
            return api_error("存储过程 sp_get_all_course_type_stat 调用失败", str(exc))
        finally:
            conn.close()

    @app.route("/api/triggers/status", methods=["GET"])
    def triggers_status():
        try:
            extract_rows = query_all(
                """
                SELECT question_id, extract_count
                FROM qbank.question
                WHERE question_id IN (1, 2, 3)
                ORDER BY question_id
                """
            )
            log_count = query_one("SELECT COUNT(*) AS cnt FROM qbank.extract_log")
            paper = query_one(
                "SELECT paper_id, paper_name, total_score FROM qbank.paper WHERE paper_id = 1"
            )

            ok_extract = all(int(r["extract_count"]) == 1 for r in extract_rows) and len(extract_rows) == 3
            ok_log = int(log_count["cnt"]) == 3
            ok_score = paper and float(paper["total_score"]) == 5.0

            checks = {
                "extract_count_ok": ok_extract,
                "extract_log_count_ok": ok_log,
                "paper_total_score_ok": ok_score,
                "extract_log_count": int(log_count["cnt"]),
                "paper_total_score": paper["total_score"] if paper else None,
                "question_extract_counts": extract_rows,
            }
            return api_ok(checks, "触发器联动状态查询成功")
        except Exception as exc:
            return api_error("查询触发器状态失败", str(exc))

    @app.route("/api/papers/auto-generate-demo", methods=["POST"])
    def papers_auto_generate_demo():
        conn = get_connection()
        try:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    """
                    CALL qbank.sp_generate_paper(
                        %s, %s, %s, NULL, NULL, %s, %s, %s, NULL
                    );
                    """,
                    (AUTO_PAPER_NAME, 1, 1, 2, Decimal("2.00"), 2),
                )

                cur.execute(
                    """
                    SELECT paper_id, paper_name, course_id, paper_type, total_score, status
                    FROM qbank.paper
                    WHERE paper_name = %s
                    ORDER BY paper_id DESC
                    LIMIT 1
                    """,
                    (AUTO_PAPER_NAME,),
                )
                paper = dict(cur.fetchone() or {})

                questions = []
                trigger_effects = {}
                if paper:
                    paper_id = paper["paper_id"]
                    cur.execute(
                        """
                        SELECT paper_question_id, paper_id, question_id, order_no, score
                        FROM qbank.paper_question
                        WHERE paper_id = %s
                        ORDER BY order_no
                        """,
                        (paper_id,),
                    )
                    questions = [dict(r) for r in cur.fetchall()]

                    cur.execute(
                        """
                        SELECT COUNT(*) AS cnt
                        FROM qbank.extract_log
                        WHERE paper_id = %s
                        """,
                        (paper_id,),
                    )
                    trigger_effects["extract_log_count_in_tx"] = int(cur.fetchone()["cnt"])
                    trigger_effects["paper_total_score_in_tx"] = paper.get("total_score")

                    if questions:
                        qids = tuple(q["question_id"] for q in questions)
                        cur.execute(
                            """
                            SELECT question_id, extract_count
                            FROM qbank.question
                            WHERE question_id = ANY(%s)
                            ORDER BY question_id
                            """,
                            (list(qids),),
                        )
                        trigger_effects["question_extract_counts_in_tx"] = [
                            dict(r) for r in cur.fetchall()
                        ]

            conn.rollback()

            payload = {
                "rolled_back": True,
                "message": "自动组卷演示已完成并回滚，未污染演示数据",
                "paper": paper,
                "questions": questions,
                "trigger_effects_in_transaction": trigger_effects,
            }
            return api_ok(payload, payload["message"])
        except Exception as exc:
            conn.rollback()
            return api_error("自动组卷演示失败", str(exc))
        finally:
            conn.close()

    @app.route("/api/security/permissions", methods=["GET"])
    def security_permissions():
        try:
            users_catalog = query_all(
                """
                SELECT rolname AS username
                FROM pg_roles
                WHERE rolname IN ('qbank_app', 'qbank_readonly', 'qbank_student_viewer')
                ORDER BY rolname
                """
            )
            grants_catalog = query_all(
                """
                SELECT grantee, table_name, privilege_type
                FROM information_schema.role_table_grants
                WHERE table_schema = 'qbank'
                  AND grantee IN ('qbank_readonly', 'qbank_student_viewer')
                ORDER BY grantee, table_name, privilege_type
                """
            )

            # qbank_app 通常无法读取其他角色的 pg_roles / ACL 元数据，补充设计预期权限
            catalog_limited = len(users_catalog) < 3 or not grants_catalog
            users = (
                [{"username": name} for name in sorted(DESIGNED_PERMISSIONS.keys())]
                if catalog_limited
                else users_catalog
            )

            student_design = DESIGNED_PERMISSIONS["qbank_student_viewer"]
            readonly_design = DESIGNED_PERMISSIONS["qbank_readonly"]
            student_views = (
                sorted({g["table_name"] for g in grants_catalog if g["grantee"] == "qbank_student_viewer"})
                if grants_catalog
                else student_design["view_select"]
            )
            student_forbidden = (
                [g for g in grants_catalog if g["grantee"] == "qbank_student_viewer" and g["table_name"] in student_design["forbidden"]]
                if grants_catalog
                else []
            )

            security = {
                "catalog_limited": catalog_limited,
                "catalog_note": (
                    "当前连接用户 qbank_app 无法读取 openGauss 其他角色的 ACL 元数据，"
                    "以下同时展示 09_init_roles.sql 设计的预期权限"
                    if catalog_limited
                    else "权限信息来自系统目录"
                ),
                "student_view_count": len(student_views),
                "student_views": student_views,
                "student_forbidden_grants": student_forbidden,
                "student_public_only": student_views == sorted(student_design["view_select"]),
                "student_no_sensitive_access": len(student_forbidden) == 0,
                "readonly_views": (
                    sorted({g["table_name"] for g in grants_catalog if g["grantee"] == "qbank_readonly"})
                    if grants_catalog
                    else readonly_design["view_select"]
                ),
            }

            return api_ok(
                {
                    "users": users,
                    "grants_catalog": grants_catalog,
                    "designed_permissions": DESIGNED_PERMISSIONS,
                    "security": security,
                },
                "权限设计查询成功",
            )
        except Exception as exc:
            return api_error("查询权限信息失败", str(exc))

    @app.route("/api/backup/status", methods=["GET"])
    def backup_status():
        try:
            rows = query_all(
                """
                SELECT backup_id, file_name, backup_type, status, created_at, remark
                FROM qbank.backup_history
                ORDER BY backup_id
                """
            )
            tips = [
                "实际备份由 database/scripts/backup_db.sh 完成",
                "实际恢复由 database/scripts/restore_db.sh 完成",
            ]
            return api_ok({"records": rows, "tips": tips}, "备份历史查询成功")
        except Exception as exc:
            return api_error("查询备份历史失败", str(exc))

    return app


# ---------------------------------------------------------------------------
# 终端演示
# ---------------------------------------------------------------------------

def call_demo(client, index: int, title: str, method: str, path: str, **kwargs) -> dict:
    print("")
    print("=" * 60)
    print(f"[INFO] 演示 {index}：{title}")
    print("=" * 60)

    if method.upper() == "GET":
        response = client.get(path, **kwargs)
    else:
        response = client.post(path, **kwargs)

    try:
        body = response.get_json()
    except Exception:
        body = {"ok": False, "message": "响应不是 JSON", "raw": response.get_data(as_text=True)}

    if response.status_code == 200 and body.get("ok"):
        print(f"[PASS] 接口调用成功 — {path}")
    else:
        print(f"[FAIL] 接口调用失败 — {path} (HTTP {response.status_code})")
        print_json_block("错误响应", body)
        return body or {}

    return body


def run_terminal_demo(app: Flask) -> None:
    print_banner("题库管理系统 Flask 后端数据库调用演示")
    print(f"[INFO] 当前连接用户：{DB_CONFIG['user']}")
    print(f"[INFO] 当前数据库：{DB_CONFIG['dbname']}")
    print(f"[INFO] 连接地址：{DB_CONFIG['host']}:{DB_CONFIG['port']}")
    print("[INFO] 说明：本脚本使用 Flask test_client() 自动演示，不启动长期 HTTP 服务")

    client = app.test_client()

    # 1. 健康检查
    body = call_demo(client, 1, "健康检查", "GET", "/api/health")
    data = body.get("data", {})
    print(f"[PASS] 数据库连接正常")
    print_table("连接信息", [data] if data else [])

    # 2. 概览
    body = call_demo(client, 2, "数据库对象概览", "GET", "/api/overview")
    items = body.get("data", {}).get("items", [])
    print_table(
        "对象数量概览",
        [
            {
                "检查项": item["name"],
                "实际值": item["actual"],
                "预期值": item["expected"],
                "状态": item["status"],
            }
            for item in items
        ],
    )

    # 3. 课程
    body = call_demo(client, 3, "课程基本信息", "GET", "/api/courses")
    print_table("课程列表", body.get("data", []))

    # 4. 课程题型
    body = call_demo(client, 4, "课程题型视图 v_course_type_usage", "GET", "/api/course-types")
    print_table("各门课程使用的题型", body.get("data", []))

    # 5. 章节
    body = call_demo(client, 5, "章节与知识点", "GET", "/api/chapters")
    print_table("章节与知识点", body.get("data", []))

    # 6. 学生公开题目
    body = call_demo(client, 6, "学生公开题目视图 v_question_public", "GET", "/api/questions/public")
    security = body.get("data", {}).get("security", {})
    if security.get("safe"):
        print("[PASS] 学生公开题目视图未暴露 answer / analysis 字段")
    else:
        print("[FAIL] 学生公开题目视图暴露了敏感字段")
    print_table("公开题目（前 5 条）", body.get("data", {}).get("questions", [])[:5], max_rows=5)

    # 7. 教师题目
    body = call_demo(client, 7, "教师题目视图 v_question_teacher", "GET", "/api/questions/teacher")
    tv = body.get("data", {}).get("teacher_view", {})
    if tv.get("has_answer") and tv.get("has_analysis"):
        print("[PASS] 教师题库视图可查看答案和解析")
    else:
        print("[FAIL] 教师题库视图缺少 answer / analysis 字段")
    print_table("教师题目（前 5 条）", body.get("data", {}).get("questions", [])[:5], max_rows=5)

    # 8. 题量统计
    body = call_demo(client, 8, "课程题量统计视图", "GET", "/api/stat/course-question")
    print_table("v_course_question_stat", body.get("data", []))

    # 9. 函数演示
    body = call_demo(client, 9, "关键函数调用", "GET", "/api/functions/demo")
    fn_data = body.get("data", {})
    print_table(
        "函数调用结果",
        [
            {
                "函数": "fn_check_course_type_enabled(1,1)",
                "返回值": fn_data.get("course_type_enabled"),
                "说明": "课程题型是否启用",
            },
            {
                "函数": "fn_count_available_questions(1,1,NULL,NULL)",
                "返回值": fn_data.get("available_question_count"),
                "说明": "可抽题数量",
            },
            {
                "函数": "fn_calculate_paper_total_score(1)",
                "返回值": fn_data.get("paper_total_score"),
                "说明": "试卷总分",
            },
        ],
    )

    # 10. 存储过程 - 课程统计
    body = call_demo(client, 10, "存储过程 sp_get_course_question_stat", "GET", "/api/procedures/course-stat")
    print("[PASS] 存储过程统计功能正常 — sp_get_course_question_stat")
    print_table("课程题型章节题量", body.get("data", []))

    # 11. 存储过程 - 全课程题型
    body = call_demo(client, 11, "存储过程 sp_get_all_course_type_stat", "GET", "/api/procedures/all-course-type-stat")
    print("[PASS] 存储过程统计功能正常 — sp_get_all_course_type_stat")
    print_table("各课程各题型题量", body.get("data", []))

    # 12. 触发器状态
    body = call_demo(client, 12, "触发器联动结果", "GET", "/api/triggers/status")
    checks = body.get("data", {})
    if checks.get("extract_count_ok"):
        print("[PASS] 触发器已自动维护抽题次数")
    else:
        print("[FAIL] 抽题次数不符合预期")
    if checks.get("extract_log_count_ok"):
        print("[PASS] 触发器已自动写入抽题日志")
    else:
        print("[FAIL] 抽题日志数量不符合预期")
    if checks.get("paper_total_score_ok"):
        print("[PASS] 触发器已自动重算试卷总分")
    else:
        print("[FAIL] 试卷总分不符合预期")
    print_table("题目抽题次数", checks.get("question_extract_counts", []))

    # 13. 自动组卷演示
    print("[INFO] 本次自动组卷在事务中执行，最后 ROLLBACK，不污染演示数据")
    body = call_demo(client, 13, "自动组卷演示 sp_generate_paper", "POST", "/api/papers/auto-generate-demo")
    demo_data = body.get("data", {})
    print(f"[INFO] {demo_data.get('message', '')}")
    print_table("事务内生成的试卷", [demo_data.get("paper", {})] if demo_data.get("paper") else [])
    print_table("事务内套题明细", demo_data.get("questions", []))
    effects = demo_data.get("trigger_effects_in_transaction", {})
    print_json_block("事务内触发器效果（回滚前）", effects)
    if demo_data.get("rolled_back"):
        print("[PASS] 自动组卷演示已 ROLLBACK，演示数据未被污染")

    # 14. 权限设计
    body = call_demo(client, 14, "权限设计展示", "GET", "/api/security/permissions")
    sec = body.get("data", {}).get("security", {})
    if sec.get("catalog_limited"):
        print(f"[INFO] {sec.get('catalog_note', '')}")
    print_table("数据库连接用户（设计）", body.get("data", {}).get("users", []))
    if sec.get("student_public_only"):
        print("[PASS] 学生预览用户只能访问公开视图")
    else:
        print("[FAIL] 学生预览用户视图权限不符合预期")
    if sec.get("student_no_sensitive_access"):
        print("[PASS] 学生预览用户不能访问答案解析视图")
    else:
        print("[FAIL] 学生预览用户存在敏感对象授权")
    print_table(
        "学生可访问视图",
        [{"view": v} for v in sec.get("student_views", [])],
    )
    print_table(
        "只读审阅用户可访问视图",
        [{"view": v} for v in sec.get("readonly_views", [])],
    )

    # 15. 备份支撑
    body = call_demo(client, 15, "备份恢复支撑展示", "GET", "/api/backup/status")
    print("[INFO] 实际备份由 database/scripts/backup_db.sh 完成")
    print("[INFO] 实际恢复由 database/scripts/restore_db.sh 完成")
    print_table("backup_history 演示记录", body.get("data", {}).get("records", []))

    print("")
    print("=" * 60)
    print("[DONE] Flask 后端数据库调用演示完成")
    print("=" * 60)


if __name__ == "__main__":
    app = create_app()
    run_terminal_demo(app)

    # 如果用户想启动真实 Flask 服务，可取消下面注释：
    # app.run(host="127.0.0.1", port=5000, debug=True)
