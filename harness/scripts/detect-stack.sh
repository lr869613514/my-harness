#!/bin/bash
# detect-stack.sh - 自动探测技术栈，写入 harness.yml 和 .env
set -e

HARNESS_DIR=".harness"
ENV_FILE="$HARNESS_DIR/.env"
STATE_FILE="$HARNESS_DIR/harness.yml"

# ── 探测技术栈 ────────────────────────────────
if [ -f "build.gradle" ] || [ -f "settings.gradle" ]; then
    DETECTED="java8-spring2-gradle"
elif [ -f "pom.xml" ]; then
    DETECTED="java8-spring2-maven"
elif [ -f "package.json" ]; then
    DETECTED="node20-next"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    DETECTED="python3-fastapi"
else
    echo "❌ 无法探测技术栈，请手动设置 stack_id 在 $STATE_FILE"
    exit 1
fi

# ── 写入 .env（含常用命令备用值，供 yq 不可用时使用）────
# 保留已有的 BB_AVAILABLE 等字段，只更新栈相关字段
{
    grep -v "^STACK_ID\|^TECH_STACK\|^CMD_" "$ENV_FILE" 2>/dev/null || true
} > "${ENV_FILE}.tmp"

cat >> "${ENV_FILE}.tmp" << EOF
STACK_ID=$DETECTED
TECH_STACK=$DETECTED
EOF

# 写入各栈的备用命令（yq 不可用时的 fallback）
case "$DETECTED" in
    java8-spring2-gradle)
        cat >> "${ENV_FILE}.tmp" << 'EOF'
CMD_UNIT_TEST="./gradlew test"
CMD_BDD_DRY_RUN="./gradlew cucumber -Pcucumber.options=--dry-run"
CMD_BDD_RUN="./gradlew cucumber"
CMD_STATIC_ANALYSIS="./gradlew check"
CMD_SECURITY_SCAN="./gradlew dependencyCheckAnalyze"
CMD_COVERAGE_CHECK="./gradlew jacocoTestCoverageVerification"
CMD_CONTRACT_TEST="./gradlew contractTest"
CMD_RESILIENCE_TEST="./gradlew resilienceTest"
CMD_BUILD="./gradlew clean build"
EOF
        ;;
    java8-spring2-maven)
        cat >> "${ENV_FILE}.tmp" << 'EOF'
CMD_UNIT_TEST="mvn test"
CMD_BDD_DRY_RUN="mvn verify -Pcucumber-dry-run"
CMD_BDD_RUN="mvn verify -Pcucumber"
CMD_STATIC_ANALYSIS="mvn verify -Pstatic-analysis"
CMD_SECURITY_SCAN="mvn dependency-check:check"
CMD_COVERAGE_CHECK="mvn verify -Pjacoco"
CMD_CONTRACT_TEST="mvn verify -Pcontract-test"
CMD_RESILIENCE_TEST="mvn verify -Presilience-test"
CMD_BUILD="mvn clean package"
EOF
        ;;
    node20-next)
        cat >> "${ENV_FILE}.tmp" << 'EOF'
CMD_UNIT_TEST="npm test -- --ci --coverage"
CMD_BDD_DRY_RUN="npx cucumber-js --dry-run"
CMD_BDD_RUN="npx cucumber-js"
CMD_STATIC_ANALYSIS="npx eslint . --ext .ts,.tsx,.js,.jsx"
CMD_SECURITY_SCAN="npm audit --audit-level=high"
CMD_COVERAGE_CHECK="npm test -- --ci --coverage"
CMD_CONTRACT_TEST="npm run test:contract"
CMD_RESILIENCE_TEST="npm run test:resilience"
CMD_BUILD="npm run build"
EOF
        ;;
    python3-fastapi)
        cat >> "${ENV_FILE}.tmp" << 'EOF'
CMD_UNIT_TEST="python -m pytest tests/unit/ -v --tb=short"
CMD_BDD_DRY_RUN="python -m pytest --collect-only -q features/"
CMD_BDD_RUN="python -m pytest features/ -v"
CMD_STATIC_ANALYSIS="ruff check . && mypy ."
CMD_SECURITY_SCAN="pip-audit --require-hashes -r requirements.txt"
CMD_COVERAGE_CHECK="python -m pytest --cov=app --cov-fail-under=80 tests/"
CMD_CONTRACT_TEST="python -m pytest tests/contract/ -v"
CMD_RESILIENCE_TEST="python -m pytest tests/resilience/ -v"
CMD_BUILD="pip install -r requirements.txt"
EOF
        ;;
esac

mv "${ENV_FILE}.tmp" "$ENV_FILE"

# ── 写入 harness.yml（需要 yq — 缺失则阻断）────
if command -v yq &>/dev/null; then
    yq e ".stack_id = \"$DETECTED\"" -i "$STATE_FILE"
    echo "✅ 探测到技术栈: $DETECTED（已写入 harness.yml）"
else
    echo ""
    echo "❌ [CRITICAL] yq 未安装，无法写入 harness.yml"
    echo "   harness.yml 是整个 Harness 状态机的核心，yq 缺失时:"
    echo "   - 阶段流转 (make set-phase) 无法执行"
    echo "   - 人工审批门 (make pause/resume) 无法执行"
    echo "   - AI 无法正确追踪开发进度"
    echo ""
    echo "   ⚡ 立即修复: make -f .harness/Makefile install-tools"
    echo "      或直接执行: brew install yq"
    echo ""
    echo "✅ .env 已更新: STACK_ID=$DETECTED（.env 写入成功，harness.yml 未更新）"
    exit 1
fi

echo "✅ .env 已更新: STACK_ID=$DETECTED"
