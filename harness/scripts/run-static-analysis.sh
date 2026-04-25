#!/bin/bash
# run-static-analysis.sh - 静态分析（PMD / Checkstyle / SpotBugs）
set -e

source .harness/.env

REPORT_DIR=".harness/docs/reports"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/static-analysis-$(date +%Y%m%d-%H%M%S).log"

# 优先从 tech-stack yaml 读取命令，yq 不可用时退回 .env 备用值
if command -v yq &>/dev/null && [ -n "$STACK_ID" ]; then
    CMD=$(yq e '.commands.static_analysis' ".harness/core/02-tech-stacks/${STACK_ID}.yaml" 2>/dev/null)
fi
CMD="${CMD:-$CMD_STATIC_ANALYSIS}"

if [ -z "$CMD" ] || [ "$CMD" = "null" ]; then
    echo "❌ 无法获取静态分析命令（STACK_ID=$STACK_ID）"
    exit 1
fi

echo "[Harness] Running static analysis: $CMD"
eval "$CMD" 2>&1 | tee "$REPORT"
exit ${PIPESTATUS[0]}
