#!/bin/bash
# run-release-gate.sh - Go/No-Go 发布门禁
set -e

REPORT_DIR=".harness/docs/reports"
GATE_DIR="$REPORT_DIR/release-gate"
mkdir -p "$GATE_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DECISION_FILE="$GATE_DIR/release-decision-$TIMESTAMP.md"
FAILED_GATES=()
PASSED_GATES=()

echo "# Release Decision Report" > "$DECISION_FILE"
echo "**生成时间**: $TIMESTAMP" >> "$DECISION_FILE"
echo "" >> "$DECISION_FILE"
echo "| Gate | 检查项 | 结果 | 证据 |" >> "$DECISION_FILE"
echo "|------|--------|------|------|" >> "$DECISION_FILE"

# 辅助函数：判断通过/失败
check_gate() {
    local gate_name="$1"
    local evidence="$2"
    local condition="$3"

    if eval "$condition"; then
        echo "| $gate_name | PASSED | ✅ | [查看]($evidence) |" >> "$DECISION_FILE"
        PASSED_GATES+=("$gate_name")
    else
        echo "| $gate_name | FAILED | ❌ | [查看]($evidence) |" >> "$DECISION_FILE"
        FAILED_GATES+=("$gate_name")
    fi
}

verification_ok() {
    local file="$1"
    [ -f "$file" ] || return 1
    grep -q "All gates PASSED" "$file" || return 1
    ! grep -qiE "FAKE PASS|placeholder|SKIPPED|NO-SOURCE|BLOCKED .*: [1-9]|FAILED .*: *[1-9]" "$file"
}

static_ok() {
    local file="$1"
    [ -f "$file" ] || return 1
    ! grep -qiE "ERROR|FAILED|SKIPPED" "$file"
}

semgrep_ok() {
    local file="$1"
    [ -f "$file" ] || return 1
    grep -q "Semgrep PASSED" "$file" || return 1
    grep -q "Semgrep findings: 0" "$file" || return 1
}

security_ok() {
    local file="$1"
    [ -f "$file" ] || return 1
    ! grep -qiE "placeholder|CRITICAL|FAILED|vulnerabilities were identified" "$file" || return 1
    grep -qiE "Security scan command completed|No vulnerabilities found|BUILD SUCCESSFUL" "$file"
}

junit_dir_ok() {
    local dir="$1"
    [ -d "$dir" ] || return 1
    python3 - "$dir" <<'PY' >/dev/null 2>&1
import glob
import os
import sys
import xml.etree.ElementTree as ET

files = glob.glob(os.path.join(sys.argv[1], "**", "TEST-*.xml"), recursive=True)
if not files:
    sys.exit(1)

tests = failures = errors = skipped = 0
for path in files:
    root = ET.parse(path).getroot()
    tests += int(root.attrib.get("tests", "0"))
    failures += int(root.attrib.get("failures", "0"))
    errors += int(root.attrib.get("errors", "0"))
    skipped += int(root.attrib.get("skipped", "0"))

sys.exit(0 if tests > 0 and failures == 0 and errors == 0 and skipped == 0 else 1)
PY
}

# G0: PHASE_5 行为验证 — 必须是最新可信 All PASSED
LATEST_VERIFY=$(ls -t "$REPORT_DIR"/verification/gates-summary-*.log 2>/dev/null | head -1)
check_gate "G0 行为验证总门" "$LATEST_VERIFY" \
    "verification_ok '$LATEST_VERIFY'"

# G1: 静态审计 — 检查最新报告是否无 Error/FAILED/SKIPPED
LATEST_STATIC=$(ls -t "$REPORT_DIR"/static-analysis-*.log 2>/dev/null | head -1)
check_gate "G1 静态审计" "$LATEST_STATIC" \
    "static_ok '$LATEST_STATIC'"

# G2: Semgrep 语义扫描 — 不允许存在任何 findings
LATEST_SEMGREP=$(ls -t "$REPORT_DIR"/semgrep-*.log 2>/dev/null | head -1)
check_gate "G2 Semgrep 语义扫描" "$LATEST_SEMGREP" \
    "semgrep_ok '$LATEST_SEMGREP'"

# G3: 对抗性审查 — 检查是否存在未解决的 CRITICAL/HIGH 发现
# 注意：grep 精准匹配「风险等级: CRITICAL/HIGH」，避免误匹配「CRITICAL: 0」等汇总行
LATEST_ADVERSARIAL=$(ls -t "$REPORT_DIR"/adversarial-review-*.md 2>/dev/null | head -1)
check_gate "G3 对抗性审查" "$LATEST_ADVERSARIAL" \
    "[ -f '$LATEST_ADVERSARIAL' ] && ! grep -qE '^\*\*风险等级\*\*: (CRITICAL|HIGH)' '$LATEST_ADVERSARIAL' 2>/dev/null"

# G4: 安全扫描 — 不接受 placeholder 或失败扫描
LATEST_SECURITY=$(ls -t "$REPORT_DIR"/security-scan-*.log 2>/dev/null | head -1)
check_gate "G4 安全扫描" "$LATEST_SECURITY" \
    "security_ok '$LATEST_SECURITY'"

# G5: 单元测试 — 必须存在 JUnit XML，且 tests > 0，无失败/错误/跳过
LATEST_UNIT_DIR=$(ls -dt "$REPORT_DIR"/unit-test/reports-* 2>/dev/null | head -1)
check_gate "G5 单元测试" "$LATEST_UNIT_DIR" \
    "junit_dir_ok '$LATEST_UNIT_DIR'"

echo "" >> "$DECISION_FILE"
echo "---" >> "$DECISION_FILE"
echo "" >> "$DECISION_FILE"

# 最终裁定
if [ ${#FAILED_GATES[@]} -eq 0 ]; then
    echo "## 最终裁定：🟢 **GO** — 建议发布" >> "$DECISION_FILE"
    echo "所有 $(( ${#PASSED_GATES[@]} )) 个发布门均已通过。" >> "$DECISION_FILE"
    # 写入建议版本号
    if [ -f ".harness/.suggested_version" ]; then
        VER=$(cat .harness/.suggested_version)
        echo "建议发布版本：**$VER**" >> "$DECISION_FILE"
    fi
else
    echo "## 最终裁定：🔴 **NO-GO** — 不满足发布条件" >> "$DECISION_FILE"
    echo "" >> "$DECISION_FILE"
    echo "### 未通过的门：" >> "$DECISION_FILE"
    for gate in "${FAILED_GATES[@]}"; do
        echo "- $gate" >> "$DECISION_FILE"
    done
    echo "" >> "$DECISION_FILE"
    echo "请修复上述问题后重新运行发布门禁。" >> "$DECISION_FILE"
fi

# 输出到终端
cat "$DECISION_FILE"