#!/bin/bash
# run-security-scan.sh - 软件供应链安全扫描（OWASP Dependency-Check）
set -e

source .harness/.env

REPORT_DIR=".harness/docs/reports"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/security-scan-$(date +%Y%m%d-%H%M%S).log"

# 优先从 tech-stack yaml 读取命令，yq 不可用时退回 .env 备用值
if command -v yq &>/dev/null && [ -n "$STACK_ID" ]; then
    CMD=$(yq e '.commands.security_scan' ".harness/core/02-tech-stacks/${STACK_ID}.yaml" 2>/dev/null)
fi
CMD="${CMD:-$CMD_SECURITY_SCAN}"

if [ -z "$CMD" ] || [ "$CMD" = "null" ]; then
    echo "❌ 无法获取安全扫描命令（STACK_ID=$STACK_ID）"
    exit 1
fi

echo "[Harness] Running security scan: $CMD"
eval "$CMD" 2>&1 | tee "$REPORT"
EXIT_CODE=${PIPESTATUS[0]}

if grep -qi "placeholder task executed\|placeholder" "$REPORT"; then
    echo "❌ [CRITICAL] 安全扫描 task 是 placeholder，未执行真实依赖漏洞扫描。" | tee -a "$REPORT"
    echo "   请配置真实 OWASP Dependency-Check 或等价供应链扫描后重试。" | tee -a "$REPORT"
    exit 1
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "[Harness] ✅ Security scan command completed. See dependency-check report for vulnerability details." >> "$REPORT"
fi

exit $EXIT_CODE
