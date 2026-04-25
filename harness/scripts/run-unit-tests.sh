#!/bin/bash
# run-unit-tests.sh - 运行单元测试
set -e

source .harness/.env

REPORT_DIR=".harness/docs/reports/unit-test"
mkdir -p "$REPORT_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# 优先从 tech-stack yaml 读取命令，yq 不可用时退回 .env 备用值
if command -v yq &>/dev/null && [ -n "$STACK_ID" ]; then
    CMD=$(yq e '.commands.unit_test' ".harness/core/02-tech-stacks/${STACK_ID}.yaml" 2>/dev/null)
fi
CMD="${CMD:-$CMD_UNIT_TEST}"

if [ -z "$CMD" ] || [ "$CMD" = "null" ]; then
    echo "❌ 无法获取单元测试命令（STACK_ID=$STACK_ID）"
    exit 1
fi

echo "[Harness] Running unit tests: $CMD"
UNIT_LOG="$REPORT_DIR/unit-test-$TIMESTAMP.log"
eval "$CMD" 2>&1 | tee "$UNIT_LOG"
EXIT_CODE=${PIPESTATUS[0]}

if grep -qE "SKIPPED|NO-SOURCE" "$UNIT_LOG"; then
    echo "❌ 单元测试被 Gradle 跳过或没有测试源，不符合生产级验证标准。" | tee -a "$UNIT_LOG"
    exit 1
fi

if [ ! -d "build/test-results/test" ] || ! ls build/test-results/test/TEST-*.xml >/dev/null 2>&1; then
    echo "❌ 未找到 JUnit XML 测试结果，无法证明单元测试真实执行。" | tee -a "$UNIT_LOG"
    exit 1
fi

if ! python3 - build/test-results/test <<'PY' >> "$UNIT_LOG" 2>&1
import glob
import sys
import xml.etree.ElementTree as ET

tests = failures = errors = skipped = 0
for path in glob.glob(sys.argv[1] + "/TEST-*.xml"):
    root = ET.parse(path).getroot()
    tests += int(root.attrib.get("tests", "0"))
    failures += int(root.attrib.get("failures", "0"))
    errors += int(root.attrib.get("errors", "0"))
    skipped += int(root.attrib.get("skipped", "0"))

print(f"JUnit summary: tests={tests}, failures={failures}, errors={errors}, skipped={skipped}")
if tests <= 0 or failures > 0 or errors > 0 or skipped > 0:
    sys.exit(1)
PY
then
    echo "❌ JUnit 结果无效（0 测试、失败、错误或跳过）。" | tee -a "$UNIT_LOG"
    exit 1
fi

# 归档 Gradle 测试报告
if [ -d "build/reports/tests" ]; then
    cp -r build/reports/tests "$REPORT_DIR/reports-$TIMESTAMP"
fi
if [ -d "build/test-results/test" ]; then
    mkdir -p "$REPORT_DIR/reports-$TIMESTAMP"
    cp build/test-results/test/TEST-*.xml "$REPORT_DIR/reports-$TIMESTAMP/" 2>/dev/null || true
fi
if [ -d "build/reports/jacoco" ]; then
    cp -r build/reports/jacoco "$REPORT_DIR/jacoco-$TIMESTAMP"
fi

exit $EXIT_CODE
