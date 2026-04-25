#!/bin/bash
# run-semgrep.sh - 语义规则静态扫描（Semgrep）
# 不使用 set -e，semgrep 未安装时优雅降级，不影响整体流程

REPORT_DIR=".harness/docs/reports"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/semgrep-$(date +%Y%m%d-%H%M%S).log"
JSON_REPORT="$REPORT.json"

if ! command -v semgrep &>/dev/null; then
    echo "[Harness] ⚠ semgrep 未安装，跳过语义规则扫描。" | tee "$REPORT"
    echo "[Harness]   可运行以下命令安装: make -f .harness/Makefile install-tools" | tee -a "$REPORT"
    echo "[Harness]   或: brew install semgrep" | tee -a "$REPORT"
    exit 0
fi

echo "[Harness] Running Semgrep semantic analysis..." | tee "$REPORT"
semgrep --config=auto --json --output "$JSON_REPORT" . >> "$REPORT" 2>&1
SEMGREP_EXIT=$?

FINDING_COUNT=$(python3 - "$JSON_REPORT" <<'PY' 2>/dev/null || echo "PARSE_ERROR"
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
print(len(data.get("results", [])))
PY
)

if [ "$FINDING_COUNT" = "PARSE_ERROR" ]; then
    echo "[Harness] ❌ Semgrep JSON 结果解析失败，请查看报告: $JSON_REPORT" | tee -a "$REPORT"
    exit 1
fi

echo "[Harness] Semgrep findings: $FINDING_COUNT" | tee -a "$REPORT"

if [ "$SEMGREP_EXIT" -ne 0 ]; then
    echo "[Harness] ❌ Semgrep 执行失败，请查看报告: $REPORT" | tee -a "$REPORT"
    exit "$SEMGREP_EXIT"
fi

if [ "$FINDING_COUNT" -eq 0 ]; then
    echo "[Harness] ✅ Semgrep PASSED" | tee -a "$REPORT"
    exit 0
else
    echo "[Harness] ❌ Semgrep 发现 $FINDING_COUNT 个问题，请查看 JSON 报告: $JSON_REPORT" | tee -a "$REPORT"
    exit 1
fi
