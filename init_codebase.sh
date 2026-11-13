#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${1:-agy-harness-boilerplate}"

echo "🚀 Đang khởi tạo Production Agent Harness Boilerplate tại: ./${PROJECT_DIR} ..."

# ==============================================================================
# 1. TẠO CẤU TRÚC THƯ MỤC CHUẨN (TUÂN THỦ AGS-001: MÃ NGUỒN NẰM TRONG src/)
# ==============================================================================
mkdir -p "${PROJECT_DIR}"/{.agents/rules,docker,storage/artifacts_out}
mkdir -p "${PROJECT_DIR}"/skills/sample_sop/{references,scripts}
mkdir -p "${PROJECT_DIR}"/src/{harness/{execution,sandbox,state,telemetry},domain/tools}
mkdir -p "${PROJECT_DIR}"/tests/{evals,unit}

cd "${PROJECT_DIR}"

# ==============================================================================
# 2. TẠO CÁC FILE __init__.py ĐỂ ĐỊNH NGHĨA PYTHON PACKAGES
# ==============================================================================
touch src/__init__.py \
      src/harness/__init__.py \
      src/harness/execution/__init__.py \
      src/harness/sandbox/__init__.py \
      src/harness/state/__init__.py \
      src/harness/telemetry/__init__.py \
      src/domain/__init__.py \
      src/domain/tools/__init__.py \
      tests/__init__.py \
      tests/evals/__init__.py \
      tests/unit/__init__.py

# ==============================================================================
# 3. KHỞI TẠO CẤU HÌNH .agents/ (ĐỒNG BỘ VỚI ANTIGRAVITY IDE & CLI `agy`)
# ==============================================================================
cat << 'EOF' > .agents/config.json
{
  "version": "2.0",
  "project_standard": "AGS-001",
  "workspace_root": ".",
  "source_root": "src",
  "skills_paths": ["skills"],
  "rules_paths": [".agents/rules"],
  "execution_policy": {
    "default": "deny",
    "allow_read_paths": ["src/**", "tests/**", "skills/**"],
    "allow_write_paths": ["src/**", "tests/**"],
    "deny_paths": [".env*", ".git/**", "storage/**"]
  }
}
EOF

cat << 'EOF' > .agents/rules/ags_001_standard.md
# Quy chuẩn Kiến trúc Hệ thống (AGS-001)

1. **Ngôn ngữ ưu tiên (Tiếng Việt-First):** Mọi tài liệu đặc tả, docstring, log kiểm toán và báo cáo đều trình bày bằng tiếng Việt chuyên ngành rõ ràng.
2. **Cô lập Mã nguồn trong `src/`:** Toàn bộ mã nguồn ứng dụng và thư viện nội bộ bắt buộc đặt trong `src/`. Tuyệt đối không tạo file code rời rạc ở thư mục gốc để tránh xung đột với các công cụ khởi tạo dự án.
3. **Quan sát trước khi Sửa (View-before-Edit):** Luôn đọc nội dung file và kiểm tra schema trước khi gọi công cụ ghi đè.
4. **Kiểm định 3 tầng (Fast-Fail Verification):** Code mới sinh ra phải vượt qua Tầng 1 (`ruff` + `mypy --strict`) trước khi chạy `pytest`.
EOF

# ==============================================================================
# 4. TẠO DOCKERFILE SANDBOX & DOCKER COMPOSE (DỰ ÁN 2)
# ==============================================================================
cat << 'EOF' > docker/Dockerfile.sandbox
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/workspace

RUN pip install --no-cache-dir \
    ruff>=0.4.0 \
    mypy>=1.10.0 \
    pytest>=8.0.0 \
    pytest-cov>=5.0.0 \
    pandas>=2.2.0 \
    matplotlib>=3.8.0

# Tạo user phi đặc quyền (Non-root) để tăng cường bảo mật trong Sandbox
RUN useradd -m -s /bin/bash sandbox_user
USER sandbox_user
WORKDIR /workspace
EOF

cat << 'EOF' > docker/docker-compose.yml
services:
  sandbox-Verification:
    build:
      context: ..
      dockerfile: docker/Dockerfile.sandbox
    image: agy-verification-sandbox:latest
    network_mode: "none"
    mem_limit: 256m
    cpus: 0.5
    read_only: true
    volumes:
      - ../:/workspace:ro
EOF

# ==============================================================================
# 5. TẠO FILE pyproject.toml CHUẨN HÓA (RUFF, MYPY STRICT, PYTEST)
# ==============================================================================
cat << 'EOF' > pyproject.toml
[project]
name = "agy-production-harness"
version = "0.1.0"
description = "Production Agent Harness Boilerplate built on Google Antigravity SDK"
requires-python = ">=3.11"
dependencies = [
    "google-antigravity>=2.0.0",
    "pydantic>=2.7.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.23.0",
    "pytest-cov>=5.0.0",
    "ruff>=0.4.0",
    "mypy>=1.10.0",
]

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
pythonpath = ["."]
addopts = "-v --tb=short"

[tool.ruff]
line-length = 100
target-version = "py311"
src = ["src", "tests"]

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP"]

[tool.mypy]
python_version = "3.11"
strict = true
ignore_missing_imports = true
mypy_path = "src"
EOF

# ==============================================================================
# 6. TẠO MAKEFILE TỰ ĐỘNG HÓA QUY TRÌNH PHÁT TRIỂN & KIỂM ĐỊNH
# ==============================================================================
# Lưu ý: Makefile bắt buộc dùng ký tự TAB ở đầu các dòng lệnh thực thi
cat << 'EOF' > Makefile
.PHONY: install sandbox-build verify test-unit test-evals run clean

install:
	pip install -e ".[dev]"

sandbox-build:
	docker build -t agy-verification-sandbox -f docker/Dockerfile.sandbox .

verify:
	ruff check src/ tests/
	mypy src/

test-unit:
	pytest tests/unit/

test-evals:
	pytest tests/evals/ -s

run:
	python3 -m src.main

clean:
	rm -rf storage/*.db storage/artifacts_out/* .pytest_cache .mypy_cache .ruff_cache
EOF

# ==============================================================================
# 7. TẠO SKILL MẪU ĐA TẦNG (PROGRESSIVE DISCLOSURE - DỰ ÁN 1)
# ==============================================================================
cat << 'EOF' > skills/sample_sop/SKILL.md
---
name: sample-warehouse-sop
description: Quy trình chuẩn (SOP) kiểm tra tồn kho và tự động đề xuất đặt hàng theo ngưỡng an toàn.
---

# Quy trình Kiểm tra Kho & Đặt hàng (SOP)

1. Luôn chuẩn hóa mã hàng về định dạng `SKU-XXXX` trước khi gọi tool `check_inventory`.
2. Đọc file `references/thresholds.json` để tra cứu định mức nhập hàng theo từng danh mục.
3. Nếu cần tính sản lượng đặt hàng tối ưu (EOQ), hãy chạy script `scripts/calc_eoq.py`.
EOF

cat << 'EOF' > skills/sample_sop/references/thresholds.json
{
  "default_restock_qty": 25,
  "emergency_restock_qty": 50
}
EOF

cat << 'EOF' > skills/sample_sop/scripts/calc_eoq.py
#!/usr/bin/env python3
import json
import sys

if __name__ == "__main__":
    print(json.dumps({"status": "ok", "recommended_eoq": 45}))
EOF
chmod +x skills/sample_sop/scripts/calc_eoq.py

# ==============================================================================
# 8. KHỞI TẠO CÁC MODULE TRỤ CỘT TRONG src/harness/
# ==============================================================================

# 8.1. Trụ cột 1: Execution Hooks (src/harness/execution/hooks.py)
cat << 'EOF' > src/harness/execution/hooks.py
from google.antigravity import hooks, types

MAX_OUTPUT_CHARS = 2000

@hooks.post_tool_call
async def truncate_heavy_output(result: types.ToolResult) -> None:
    """Gọt tỉa output quá dài từ công cụ để bảo vệ Context Window."""
    raw_text = str(result.result)
    if len(raw_text) > MAX_OUTPUT_CHARS:
        head = raw_text[:800]
        tail = raw_text[-800:]
        dropped = len(raw_text) - 1600
        result.result = (
            f"{head}\n\n... [HARNESS TRUNCATED: Đã ẩn {dropped} ký tự] ...\n\n{tail}"
        )

@hooks.on_tool_error
async def compact_execution_error(err: Exception) -> str:
    """Bắt lỗi thực thi công cụ và định dạng lại để Agent tự sửa sai (Self-Correction)."""
    return (
        f"LỖI THỰC THI CÔNG CỤ ({type(err).__name__}): {str(err)}\n"
        "Hãy kiểm tra lại định dạng tham số đầu vào và gọi lại công cụ."
    )
EOF

# 8.2. Trụ cột 1: Role-Based Policies (src/harness/execution/policies.py)
cat << 'EOF' > src/harness/execution/policies.py
from pathlib import Path
from typing import Any
from google.antigravity.hooks import policy

def is_safe_rel_path(rel_path: str) -> bool:
    p = Path(rel_path)
    return not p.is_absolute() and ".." not in p.parts

def build_directory_scoped_write_policy(allowed_write_prefix: str) -> list[Any]:
    """Khóa quyền ghi file chỉ vào đúng thư mục được chỉ định (VD: 'tests/' hoặc 'src/')."""
    return [
        policy.allow("view_file", when=lambda a: is_safe_rel_path(str(a.get("path", "")))),
        policy.allow("read_file", when=lambda a: is_safe_rel_path(str(a.get("path", "")))),
        policy.allow(
            "write_file",
            when=lambda a: (
                is_safe_rel_path(str(a.get("path", "")))
                and str(a.get("path", "")).startswith(allowed_write_prefix)
            ),
        ),
    ]
EOF

# 8.3. Trụ cột 3: Tiered Memory Store SQLite + FTS5 (src/harness/state/store.py)
cat << 'EOF' > src/harness/state/store.py
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

class TieredMemoryStore:
    """Kho lưu trữ trạng thái 3 tầng kết hợp SQLite FTS5 BM25 Search."""

    def __init__(self, db_path: Path) -> None:
        self.conn = sqlite3.connect(str(db_path))
        self._init_schema()

    def _init_schema(self) -> None:
        with self.conn:
            self.conn.execute("""
                CREATE TABLE IF NOT EXISTS checkpoints (
                    step_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL,
                    timestamp TEXT NOT NULL,
                    event_type TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    estimated_tokens INTEGER NOT NULL,
                    is_compacted INTEGER DEFAULT 0
                )
            """)
            self.conn.execute("""
                CREATE TABLE IF NOT EXISTS session_summaries (
                    session_id TEXT PRIMARY KEY,
                    summary_json TEXT NOT NULL,
                    last_compacted_step_id INTEGER NOT NULL,
                    updated_at TEXT NOT NULL
                )
            """)
            self.conn.execute("""
                CREATE VIRTUAL TABLE IF NOT EXISTS archived_fts USING fts5(
                    step_id UNINDEXED,
                    session_id UNINDEXED,
                    event_type,
                    payload_text
                )
            """)
            self.conn.execute("""
                CREATE TRIGGER IF NOT EXISTS trg_index_compacted_step
                AFTER UPDATE OF is_compacted ON checkpoints
                WHEN NEW.is_compacted = 1 AND OLD.is_compacted = 0
                BEGIN
                    INSERT INTO archived_fts (step_id, session_id, event_type, payload_text)
                    VALUES (NEW.step_id, NEW.session_id, NEW.event_type, NEW.payload_json);
                END;
            """)

    @staticmethod
    def estimate_tokens(text: str) -> int:
        return max(1, len(text) // 3)

    def add_step(self, session_id: str, event_type: str, payload: dict[str, Any]) -> int:
        payload_str = json.dumps(payload, ensure_ascii=False)
        tokens = self.estimate_tokens(payload_str)
        now_iso = datetime.now(timezone.utc).isoformat()
        with self.conn:
            cur = self.conn.execute(
                """INSERT INTO checkpoints 
                   (session_id, timestamp, event_type, payload_json, estimated_tokens, is_compacted)
                   VALUES (?, ?, ?, ?, ?, 0)""",
                (session_id, now_iso, event_type, payload_str, tokens),
            )
            return int(cur.lastrowid or 0)

    def get_uncompacted_steps(self, session_id: str) -> list[dict[str, Any]]:
        rows = self.conn.execute(
            """SELECT step_id, event_type, payload_json 
               FROM checkpoints WHERE session_id = ? AND is_compacted = 0 ORDER BY step_id ASC""",
            (session_id,),
        ).fetchall()
        return [{"step_id": r[0], "event_type": r[1], "payload": json.loads(r[2])} for r in rows]

    def search_archive_fts(self, session_id: str, query: str, limit: int = 3) -> list[dict[str, Any]]:
        terms = ["".join(c for c in w if c.isalnum() or c in ("_", "-")) for w in query.split()]
        fts_query = " OR ".join(f'"{t}"' for t in terms if t)
        if not fts_query:
            return []
        rows = self.conn.execute(
            """SELECT step_id, event_type, snippet(archived_fts, 3, '<<<', '>>>', '...', 30)
               FROM archived_fts WHERE session_id = ? AND archived_fts MATCH ?
               ORDER BY bm25(archived_fts) LIMIT ?""",
            (session_id, fts_query, limit),
        ).fetchall()
        return [{"step_id": int(r[0]), "event_type": r[1], "snippet": r[2]} for r in rows]

    def build_hydrated_context(self, session_id: str) -> str:
        recent = self.get_uncompacted_steps(session_id)
        return json.dumps({"recent_window": recent}, ensure_ascii=False, indent=2)

def build_memory_recall_tools(store: TieredMemoryStore, session_id: str) -> list[Callable[..., Any]]:
    def search_archived_memory(keyword_query: str) -> str:
        """Tìm kiếm thông tin chi tiết trong lịch sử hội thoại đã bị nén (is_compacted = 1)."""
        matches = store.search_archive_fts(session_id, keyword_query)
        return json.dumps(matches, ensure_ascii=False) if matches else "Không tìm thấy kết quả."

    return [search_archived_memory]
EOF

# 8.4. Trụ cột 4: Telemetry & FinOps Tracer (src/harness/telemetry/tracer.py)
cat << 'EOF' > src/harness/telemetry/tracer.py
import asyncio
import json
import sqlite3
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional
from google.antigravity import Agent, hooks, types

@dataclass
class TelemetrySpan:
    span_id: str
    trace_id: str
    parent_span_id: Optional[str]
    session_id: str
    name: str
    kind: str
    start_time_ns: int
    end_time_ns: int = 0
    status: str = "OK"
    attributes: dict[str, Any] = field(default_factory=dict)

    @property
    def duration_ms(self) -> float:
        return round(max(0, self.end_time_ns - self.start_time_ns) / 1_000_000, 2)

class TelemetryStore:
    def __init__(self, db_path: Path) -> None:
        self.conn = sqlite3.connect(str(db_path))
        with self.conn:
            self.conn.execute("""
                CREATE TABLE IF NOT EXISTS trace_spans (
                    span_id TEXT PRIMARY KEY,
                    trace_id TEXT NOT NULL,
                    parent_span_id TEXT,
                    session_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    kind TEXT NOT NULL,
                    duration_ms REAL NOT NULL,
                    status TEXT NOT NULL,
                    attributes_json TEXT NOT NULL
                )
            """)

    def record_span(self, span: TelemetrySpan) -> None:
        with self.conn:
            self.conn.execute(
                """INSERT OR REPLACE INTO trace_spans VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    span.span_id, span.trace_id, span.parent_span_id, span.session_id,
                    span.name, span.kind, span.duration_ms, span.status,
                    json.dumps(span.attributes, ensure_ascii=False),
                ),
            )

class ObservabilityHarness:
    def __init__(self, store: TelemetryStore, session_id: str, max_budget_usd: float = 0.50) -> None:
        self.store = store
        self.session_id = session_id
        self.max_budget_usd = max_budget_usd
        self._inflight_tools: list[TelemetrySpan] = []

    def create_hooks(self) -> list[Any]:
        @hooks.post_tool_call
        async def on_tool_ok(result: types.ToolResult) -> None:
            if self._inflight_tools:
                sp = self._inflight_tools.pop(0)
                sp.end_time_ns = time.time_ns()
                self.store.record_span(sp)

        return [on_tool_ok]

    async def execute_traced_turn(self, agent: Agent, prompt: str) -> str:
        trace_id = f"trc_{uuid.uuid4().hex[:8]}"
        turn_id = f"spn_{uuid.uuid4().hex[:8]}"
        turn_span = TelemetrySpan(turn_id, trace_id, None, self.session_id, "agent.turn", "TURN", time.time_ns())

        response = await agent.chat(prompt)

        async def tap_tools() -> None:
            async for call in response.tool_calls:
                sp = TelemetrySpan(
                    f"spn_{uuid.uuid4().hex[:8]}", trace_id, turn_id,
                    self.session_id, f"tool.{call.name}", "TOOL", time.time_ns(),
                    attributes={"args": dict(call.args)},
                )
                self._inflight_tools.append(sp)

        tool_task = asyncio.create_task(tap_tools())
        chunks: list[str] = []
        async for token in response:
            chunks.append(token)
        await tool_task

        turn_span.end_time_ns = time.time_ns()
        self.store.record_span(turn_span)
        return "".join(chunks)
EOF

# 8.5. Unified Builder Facade (src/harness/builder.py)
cat << 'EOF' > src/harness/builder.py
from pathlib import Path
from typing import Any, Callable, Optional
from google.antigravity import Agent, LocalAgentConfig
from google.antigravity.hooks import policy

from src.harness.execution.hooks import compact_execution_error, truncate_heavy_output
from src.harness.state.store import TieredMemoryStore
from src.harness.telemetry.tracer import ObservabilityHarness, TelemetryStore

class ProductionAgentHarness:
    """Facade hợp nhất 4 trụ cột: Execution, Sandbox Policies, Tiered Memory & Telemetry."""

    def __init__(
        self,
        session_id: str,
        system_instructions: str,
        storage_dir: Path,
        workspace_dir: Optional[Path] = None,
        skills_dirs: Optional[list[Path]] = None,
        custom_tools: Optional[list[Callable[..., Any]]] = None,
        max_budget_usd: float = 0.50,
    ) -> None:
        self.session_id = session_id
        self.system_instructions = system_instructions
        self.storage_dir = storage_dir
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        self.workspace_dir = (workspace_dir or Path.cwd()).resolve()
        self.skills_dirs = [str(p.resolve()) for p in (skills_dirs or [])]
        self.custom_tools = custom_tools or []

        self.memory_store = TieredMemoryStore(self.storage_dir / "state_memory.db")
        self.telemetry_store = TelemetryStore(self.storage_dir / "telemetry.db")
        self.obs = ObservabilityHarness(self.telemetry_store, self.session_id, max_budget_usd)

    def build_config(self) -> LocalAgentConfig:
        allowed_rules = [policy.deny("*")]
        for tool_fn in self.custom_tools:
            allowed_rules.append(policy.allow(tool_fn.__name__))
        if self.skills_dirs:
            allowed_rules.extend([policy.allow("view_file"), policy.allow("read_file")])

        return LocalAgentConfig(
            system_instructions=self.system_instructions,
            workspace_dir=str(self.workspace_dir),
            skills=self.skills_dirs,
            tools=self.custom_tools,
            hooks=[*self.obs.create_hooks(), truncate_heavy_output, compact_execution_error],
            policies=allowed_rules,
        )

    async def chat_turn(self, prompt: str) -> str:
        self.memory_store.add_step(self.session_id, "USER_PROMPT", {"prompt": prompt})
        config = self.build_config()
        async with Agent(config) as agent:
            reply = await self.obs.execute_traced_turn(agent, prompt)
        self.memory_store.add_step(self.session_id, "AGENT_REPLY", {"reply": reply})
        return reply
EOF

# ==============================================================================
# 9. TẠO LOGIC NGHIỆP VỤ MẪU (src/domain/ & src/main.py)
# ==============================================================================
cat << 'EOF' > src/domain/tools/inventory_tools.py
def check_inventory(item_code: str) -> str:
    """Tra cứu tồn kho theo mã SKU (Bắt buộc định dạng SKU-XXXX)."""
    if not item_code.startswith("SKU-"):
        raise ValueError(f"Mã '{item_code}' sai định dạng. Bắt buộc bắt đầu bằng 'SKU-'.")
    db = {"SKU-1024": 0, "SKU-2048": 42}
    stock = db.get(item_code, -1)
    if stock < 0:
        return f"Không tìm thấy sản phẩm {item_code}."
    return f"Mã {item_code} hiện còn tồn kho: {stock} chiếc."
EOF

cat << 'EOF' > src/main.py
import asyncio
from pathlib import Path
from src.domain.tools.inventory_tools import check_inventory
from src.harness.builder import ProductionAgentHarness

async def main() -> None:
    root_dir = Path(__file__).resolve().parent.parent
    harness = ProductionAgentHarness(
        session_id="SESS-INIT-001",
        system_instructions="Bạn là Trợ lý Quản lý Kho. Hãy tuân thủ SOP trong Skill được cung cấp.",
        storage_dir=root_dir / "storage",
        workspace_dir=root_dir,
        skills_dirs=[root_dir / "skills" / "sample_sop"],
        custom_tools=[check_inventory],
    )
    reply = await harness.chat_turn("Kiểm tra tồn kho mặt hàng mã 1024 giúp tôi.")
    print(f"\n[AGENT RESPONSE]:\n{reply}")

if __name__ == "__main__":
    asyncio.run(main())
EOF

# ==============================================================================
# 10. TẠO BÀI KIỂM THỬ UNIT TEST MẪU CHO BỘ NHỚ FTS5 (tests/unit/)
# ==============================================================================
cat << 'EOF' > tests/unit/test_tiered_memory.py
from pathlib import Path
from src.harness.state.store import TieredMemoryStore

def test_fts5_archive_recall(tmp_path: Path) -> None:
    store = TieredMemoryStore(tmp_path / "test_mem.db")
    session_id = "TEST-SESS"

    step_id = store.add_step(session_id, "TOOL_RESULT", {
        "service": "auth-service",
        "detail": "SSH Brute-force from IP 185.220.101.42",
    })

    # Đánh dấu bước này là đã nén (is_compacted = 1) để kích hoạt SQLite FTS5 Trigger
    with store.conn:
        store.conn.execute("UPDATE checkpoints SET is_compacted = 1 WHERE step_id = ?", (step_id,))

    results = store.search_archive_fts(session_id, "185.220.101.42")
    assert len(results) == 1
    assert results[0]["step_id"] == step_id
EOF

# ==============================================================================
# 11. TẠO FILE .gitignore
# ==============================================================================
cat << 'EOF' > .gitignore
__pycache__/
*.py[cod]
.venv/
venv/
.env
storage/*.db
storage/artifacts_out/*
.pytest_cache/
.mypy_cache/
.ruff_cache/
EOF

echo "✅ Hoàn tất! Cấu trúc dự án '${PROJECT_DIR}' đã sẵn sàng."
echo ""
echo "👉 Các bước tiếp theo:"
echo "   1. cd ${PROJECT_DIR}"
echo "   2. make install          # Cài đặt dependencies & công cụ kiểm định"
echo "   3. make verify           # Chạy kiểm tra tĩnh Tầng 1 (Ruff + Mypy --strict)"
echo "   4. make test-unit        # Chạy kiểm thử SQLite FTS5 Tiered Memory"
echo "   5. make sandbox-build    # Đóng gói Docker Image cho Sandbox"
