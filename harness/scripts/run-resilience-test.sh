#!/bin/bash
# run-resilience-test.sh - 韧性测试（超时、降级、重试、熔断等场景）
# task 未配置 → CRITICAL 阻断，不允许跳过
set -e

source .harness/.env 2>/dev/null || true

REPORT_DIR=".harness/docs/reports/resilience-test"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/resilience-test-$(date +%Y%m%d-%H%M%S).log"

echo "[Harness] Running resilience tests..." | tee "$REPORT"

check_junit_results() {
    local result_dir="$1"
    if [ ! -d "$result_dir" ] || ! ls "$result_dir"/TEST-*.xml >/dev/null 2>&1; then
        echo "❌ [CRITICAL] 未找到 JUnit XML 测试结果 ($result_dir)" | tee -a "$REPORT"
        return 1
    fi
    python3 - "$result_dir" <<'PY' >> "$REPORT" 2>&1
import glob
import sys
import xml.etree.ElementTree as ET

files = glob.glob(sys.argv[1] + "/TEST-*.xml")
tests = failures = errors = skipped = 0
for path in files:
    root = ET.parse(path).getroot()
    tests += int(root.attrib.get("tests", "0"))
    failures += int(root.attrib.get("failures", "0"))
    errors += int(root.attrib.get("errors", "0"))
    skipped += int(root.attrib.get("skipped", "0"))

print(f"JUnit summary: tests={tests}, failures={failures}, errors={errors}, skipped={skipped}")
if tests <= 0 or failures > 0 or errors > 0 or skipped > 0:
    sys.exit(1)
PY
}

# 优先从 tech-stack yaml 读取命令，yq 不可用时退回 .env 备用值
if command -v yq &>/dev/null && [ -n "$STACK_ID" ]; then
    CMD=$(yq e '.commands.resilience_test // ""' ".harness/core/02-tech-stacks/${STACK_ID}.yaml" 2>/dev/null)
fi
CMD="${CMD:-$CMD_RESILIENCE_TEST}"

if [ -z "$CMD" ] || [ "$CMD" = "null" ]; then
    echo "❌ [CRITICAL] 无法获取韧性测试命令（STACK_ID=$STACK_ID）" | tee -a "$REPORT"
    exit 1
fi

# 若命令涉及 Gradle task，验证 task 存在
TASK=$(printf '%s\n' "$CMD" | awk '{for (i=1; i<=NF; i++) if ($i ~ /(^|\/)gradlew$/) {print $(i+1); exit}}')
if [ -n "$TASK" ]; then
    if ! ./gradlew tasks --all 2>/dev/null | grep -qE "^${TASK}( |$)"; then
        echo "❌ [CRITICAL] Gradle task '$TASK' 未配置" | tee -a "$REPORT"
        echo "   修复方法: build.gradle 注册 resilienceTest task（推荐独立 sourceSet）" | tee -a "$REPORT"
        echo "   示例:" | tee -a "$REPORT"
        echo "     sourceSets { resilienceTest { java { srcDirs = ['src/resilienceTest/java'] } } }" | tee -a "$REPORT"
        echo "     task resilienceTest(type: Test) { testClassesDirs = sourceSets.resilienceTest.output.classesDirs }" | tee -a "$REPORT"
        echo "   配置后重新运行: make -f .harness/Makefile resilience-test" | tee -a "$REPORT"
        exit 1
    fi
fi

echo "[Harness] Running: $CMD" | tee -a "$REPORT"
rm -rf build/test-results/resilienceTest
mkdir -p build/test-results/resilienceTest
eval "$CMD" 2>&1 | tee -a "$REPORT"
EXIT_CODE=${PIPESTATUS[0]}

if grep -qi "placeholder task executed\|placeholder" "$REPORT"; then
    echo "[Harness] ❌ Resilience tests BLOCKED — resilienceTest 是 placeholder" | tee -a "$REPORT"
    exit 1
fi

if grep -qE "SKIPPED|NO-SOURCE" "$REPORT"; then
    echo "[Harness] ❌ Resilience tests BLOCKED — Gradle 跳过了韧性测试或没有测试源" | tee -a "$REPORT"
    exit 1
fi

if ! check_junit_results "build/test-results/resilienceTest"; then
    echo "[Harness] ❌ Resilience tests BLOCKED — 未执行任何有效韧性测试" | tee -a "$REPORT"
    exit 1
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "[Harness] ✅ Resilience tests PASSED" | tee -a "$REPORT"
else
    echo "[Harness] ❌ Resilience tests FAILED" | tee -a "$REPORT"
fi

exit $EXIT_CODE
