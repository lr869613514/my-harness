#!/bin/bash
# run-bdd.sh - 执行 BDD 测试（支持 dry-run）
set -e

source .harness/.env
MODE=${1:-full}

# 优先从 tech-stack yaml 读取命令，yq 不可用时退回 .env 备用值
if command -v yq &>/dev/null && [ -n "$STACK_ID" ]; then
    if [ "$MODE" = "dry-run" ]; then
        CMD=$(yq e '.commands.bdd_dry_run' ".harness/core/02-tech-stacks/${STACK_ID}.yaml" 2>/dev/null)
    else
        CMD=$(yq e '.commands.bdd_run' ".harness/core/02-tech-stacks/${STACK_ID}.yaml" 2>/dev/null)
    fi
fi

# fallback to .env CMD_ values
if [ -z "$CMD" ] || [ "$CMD" = "null" ]; then
    if [ "$MODE" = "dry-run" ]; then
        CMD="$CMD_BDD_DRY_RUN"
    else
        CMD="$CMD_BDD_RUN"
    fi
fi

if [ -z "$CMD" ]; then
    echo "❌ 无法获取 BDD 命令（STACK_ID=$STACK_ID, MODE=$MODE）"
    exit 1
fi

echo "[Harness] BDD mode: $MODE"
echo "[Harness] Running: $CMD"
if [ "$MODE" != "dry-run" ]; then
    rm -rf build/test-results/cucumber
    mkdir -p build/test-results/cucumber
fi
eval "$CMD"

if [ "$MODE" != "dry-run" ]; then
    RESULT_DIR="build/test-results/cucumber"
    if [ ! -d "$RESULT_DIR" ] || ! ls "$RESULT_DIR"/TEST-*.xml >/dev/null 2>&1; then
        echo "❌ BDD 未生成 JUnit XML 结果，无法证明 Scenario 真实执行。"
        exit 1
    fi
    if ! python3 - "$RESULT_DIR" <<'PY'
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

print(f"BDD JUnit summary: scenarios={tests}, failures={failures}, errors={errors}, skipped={skipped}")
if tests <= 0 or failures > 0 or errors > 0 or skipped > 0:
    sys.exit(1)
PY
    then
        echo "❌ BDD 结果无效（0 Scenario、失败、错误或跳过）。"
        exit 1
    fi
fi
