#!/bin/bash
# run-preflight-check.sh - Harness 启动前全量预检验
# 所有 CRITICAL 级别问题必须修复，否则 exit 1 阻断后续流程
# WARN 级别问题打印警告但不阻断

# 注意：不使用 set -e，因为本脚本通过 PASS/FAIL 计数器主动收集所有问题
# 单点失败不应阻断后续检查项的输出
source .harness/.env 2>/dev/null || true

PASS=0
FAIL=0
WARN=0

ok()       { echo "  ✅ $*"; PASS=$((PASS+1)); }
fail()     { echo "  ❌ [CRITICAL] $*"; FAIL=$((FAIL+1)); }
warn()     { echo "  ⚠  [WARN]     $*"; WARN=$((WARN+1)); }
section()  { echo ""; echo "── $* ──────────────────────────────"; }

echo "╔══════════════════════════════════════════╗"
echo "║   Harness Preflight Check                ║"
echo "╚══════════════════════════════════════════╝"

# ════════════════════════════════════════════════
section "1. 核心工具"
# ════════════════════════════════════════════════

if command -v yq &>/dev/null; then
    ok "yq 已安装: $(yq --version 2>/dev/null)"
else
    fail "yq 未安装 → harness.yml 状态机无法更新，整个流程将失效"
    echo "       修复: make -f .harness/Makefile install-tools"
fi

if command -v semgrep &>/dev/null; then
    ok "semgrep 已安装: $(semgrep --version 2>/dev/null | head -1)"
else
    warn "semgrep 未安装 → PHASE_4 语义扫描层将跳过"
    echo "       修复: make -f .harness/Makefile install-tools"
fi

if command -v python3 &>/dev/null; then
    ok "python3: $(python3 --version 2>/dev/null)"
else
    warn "python3 未安装 → BrainBank 不可用，知识检索将降级为 @Codebase"
fi

# ════════════════════════════════════════════════
section "2. Gradle 构建工具"
# ════════════════════════════════════════════════

if [ -f "gradlew" ] && [ -x "gradlew" ]; then
    GRADLE_VER=$(./gradlew --version 2>/dev/null | grep "^Gradle" | head -1)
    ok "gradlew 可执行: $GRADLE_VER"
else
    fail "gradlew 不存在或无执行权限 → 所有 Gradle 任务无法运行"
    echo "       修复: 确认项目根目录有 gradlew 文件，执行 chmod +x gradlew"
fi

# ════════════════════════════════════════════════
section "3. Gradle Task 配置（每个 Harness 阶段的执行基础）"
# ════════════════════════════════════════════════

# 获取所有可用 task（缓存到临时文件，避免重复调用）
TASK_CACHE=$(mktemp)
./gradlew tasks --all 2>/dev/null > "$TASK_CACHE" || true

check_task() {
    local task="$1"
    local phase="$2"
    local fix="$3"
    if grep -qE "^${task}( |$)" "$TASK_CACHE" 2>/dev/null; then
        ok "task '$task' 已配置 (${phase})"
    else
        fail "task '$task' 未配置 → ${phase} 无法执行"
        echo "       修复: ${fix}"
    fi
}

# 检查 task 是否为 placeholder（仅打印日志，不执行真实测试）
check_placeholder() {
    local task="$1"
    local phase="$2"
    if ! grep -qE "^${task}( |$)" "$TASK_CACHE" 2>/dev/null; then
        return  # task 不存在，已由 check_task 报 FAIL，这里不重复
    fi
    local placeholder_count
    placeholder_count=$((grep -A10 "tasks.register('${task}')\|task ${task}[^A-Za-z]" build.gradle 2>/dev/null || true) \
        | grep -ciE "placeholder|logger.lifecycle.*placeholder|println.*placeholder" 2>/dev/null || true)
    if [ "$placeholder_count" -gt "0" ]; then
        warn "task '$task' 是 placeholder（仅打印日志，未执行真实测试）→ ${phase} 将产生虚假通过"
        echo "       影响: PHASE_5 验证门将显示 PASSED，但实际上未执行任何测试"
        echo "       修复: 在 build.gradle 中将 placeholder 替换为真实测试配置，详见 check-bdd-real"
    fi
}

check_disabled_test_gate() {
    if grep -qE "enabled[[:space:]]*=[[:space:]]*false|ignoreFailures[[:space:]]*=[[:space:]]*true" build.gradle 2>/dev/null; then
        warn "Gradle test task 被禁用或允许失败 → 单元测试门可能虚假通过"
        echo "       影响: PHASE_5 G1/G5 可能出现 SKIPPED 但仍 BUILD SUCCESSFUL"
        echo "       修复: 移除 enabled=false 和 ignoreFailures=true，确保测试失败会阻断构建"
    fi
}

check_task "test"    \
    "PHASE_5 G1-单元测试" \
    "build.gradle 中确认存在 test task（Java 插件默认包含）"
check_disabled_test_gate

check_task "check"   \
    "PHASE_4 静态分析" \
    "build.gradle 添加: apply plugin: 'pmd' / 'checkstyle' / 'spotbugs'"

check_task "jacocoTestCoverageVerification" \
    "PHASE_5 G5-覆盖率门(≥80%)" \
    "build.gradle 添加: apply plugin: 'jacoco'，并配置 jacocoTestCoverageVerification"

check_task "dependencyCheckAnalyze" \
    "PHASE_2_5 供应链安全扫描" \
    "build.gradle 添加: id 'org.owasp.dependencycheck' version '8.4.0'"
check_placeholder "dependencyCheckAnalyze" "PHASE_2_5 安全扫描"

check_task "cucumber" \
    "PHASE_2 BDD测试 / PHASE_5 G3" \
    "build.gradle 添加 cucumber task，引入 io.cucumber:cucumber-java:7.x"
check_placeholder "cucumber" "PHASE_2/PHASE_5 BDD验收测试"

check_task "contractTest" \
    "PHASE_5 G2-契约测试" \
    "build.gradle 注册 contractTest task（如 Spring Cloud Contract 或自定义）"
check_placeholder "contractTest" "PHASE_5 契约测试"

check_task "resilienceTest" \
    "PHASE_5 G4-韧性测试" \
    "build.gradle 注册 resilienceTest task（推荐使用独立测试 sourceSet）"
check_placeholder "resilienceTest" "PHASE_5 韧性测试"

rm -f "$TASK_CACHE"

# ════════════════════════════════════════════════
section "4. BrainBank 知识库"
# ════════════════════════════════════════════════

if [ "$BB_AVAILABLE" = "true" ] && command -v bb &>/dev/null; then
    ok "BrainBank 就绪 (ChromaDB v$(python3 -c 'import chromadb; print(chromadb.__version__)' 2>/dev/null || echo '?'))"
else
    warn "BrainBank 未就绪 → 知识检索将降级为 @Codebase"
    echo "       修复: make -f .harness/Makefile setup-brainbank"
fi

# ════════════════════════════════════════════════
section "5. Harness 状态"
# ════════════════════════════════════════════════

if command -v yq &>/dev/null; then
    PHASE=$(yq e '.current_phase' .harness/harness.yml 2>/dev/null || echo "UNKNOWN")
    PENDING=$(yq e '.pending_approval' .harness/harness.yml 2>/dev/null || echo "false")
    ok "当前阶段: $PHASE | pending_approval: $PENDING"
    if [ "$PENDING" = "true" ]; then
        GATE=$(yq e '.approval_gate' .harness/harness.yml 2>/dev/null)
        fail "存在未处理审批门: $GATE → 请人工 Review 后运行 make -f .harness/Makefile resume"
    fi
else
    warn "yq 未安装，无法读取 harness.yml 状态"
fi

# ════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
printf  "║  ✅ PASS: %-3d  ⚠ WARN: %-3d  ❌ FAIL: %-3d║\n" $PASS $WARN $FAIL
echo "╚══════════════════════════════════════════╝"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "❌ Preflight 未通过：发现 $FAIL 个 CRITICAL 问题。"
    echo "   请修复以上所有 [CRITICAL] 问题后重新运行: make -f .harness/Makefile preflight"
    echo "   在 Preflight 通过前，AI 不得启动任何开发阶段。"
    exit 1
else
    echo ""
    if [ $WARN -gt 0 ]; then
        echo "⚠ Preflight 基本通过（$WARN 个警告，不影响主流程）。"
    else
        echo "✅ Preflight 全部通过！Harness 框架已就绪。"
    fi
    exit 0
fi
