#!/bin/bash
# run-verification-gates.sh - 全量行为验证门（PHASE_5）
# 每个门执行前检查 Gradle task 是否已配置
# task 未配置或证据无效 → CRITICAL 阻断，不允许跳过

set -e
source .harness/.env 2>/dev/null || true

REPORT_DIR=".harness/docs/reports/verification"
mkdir -p "$REPORT_DIR"
SUMMARY="$REPORT_DIR/gates-summary-$(date +%Y%m%d-%H%M%S).log"
FAILED=0
BLOCKED=0

log() { echo "$*" | tee -a "$SUMMARY"; }

log "===== Harness Behavioral Verification Gates ====="
log "时间: $(date '+%Y-%m-%d %H:%M:%S')"
log ""

# 辅助：检查 Gradle task 是否存在（运行一次并缓存）
TASK_CACHE=$(mktemp)
./gradlew tasks --all 2>/dev/null > "$TASK_CACHE" || {
    log "❌ CRITICAL: gradlew 执行失败，无法获取 task 列表，终止验证。"
    rm -f "$TASK_CACHE"
    exit 1
}

task_exists() {
    grep -qE "^$1( |$)" "$TASK_CACHE" 2>/dev/null
}

require_task() {
    local task="$1"
    local gate="$2"
    local fix="$3"
    if ! task_exists "$task"; then
        log "❌ [$gate] BLOCKED: Gradle task '$task' 未配置"
        log "   → 修复方法: $fix"
        log "   → 配置完成后重新运行: make -f .harness/Makefile verify"
        BLOCKED=$((BLOCKED+1))
        return 1
    fi
    return 0
}

run_gate() {
    local gate="$1"
    local cmd="$2"
    log "[${gate}] Running: $cmd"
    local gate_output
    gate_output=$(mktemp)
    if eval "$cmd" > "$gate_output" 2>&1; then
        cat "$gate_output" >> "$SUMMARY"
        if grep -qE "SKIPPED|NO-SOURCE" "$gate_output"; then
            log "[${gate}] ❌ BLOCKED: Gradle task was skipped or had no source"
            BLOCKED=$((BLOCKED+1))
            rm -f "$gate_output"
            return 1
        fi
        log "[${gate}] ✅ PASSED"
        rm -f "$gate_output"
        return 0
    else
        cat "$gate_output" >> "$SUMMARY"
        log "[${gate}] ❌ FAILED"
        FAILED=$((FAILED+1))
        rm -f "$gate_output"
        return 1
    fi
}

check_junit_results() {
    local gate="$1"
    local result_dir="$2"
    if [ ! -d "$result_dir" ] || ! ls "$result_dir"/TEST-*.xml >/dev/null 2>&1; then
        log "[${gate}] ❌ BLOCKED: 未找到 JUnit XML 测试结果 ($result_dir)"
        BLOCKED=$((BLOCKED+1))
        return 1
    fi
    if ! python3 - "$result_dir" <<'PY' >> "$SUMMARY" 2>&1
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
    then
        log "[${gate}] ❌ BLOCKED: JUnit 结果无效（0 测试、失败、错误或跳过）"
        BLOCKED=$((BLOCKED+1))
        return 1
    fi
    return 0
}

check_coverage_data() {
    local gate="$1"
    if [ ! -s "build/jacoco/test.exec" ] && ! ls build/reports/jacoco/test/*.xml >/dev/null 2>&1; then
        log "[${gate}] ❌ BLOCKED: 未找到 JaCoCo 覆盖率执行数据或 XML 报告"
        BLOCKED=$((BLOCKED+1))
        return 1
    fi
    return 0
}

prepare_result_dir() {
    local result_dir="$1"
    rm -rf "$result_dir"
    mkdir -p "$result_dir"
}

# 检查 Gradle task 是否为 placeholder（仅打印日志，无真实测试逻辑）
# placeholder task 的 "PASSED" 是假通过，必须阻断并要求配置真实实现
check_not_placeholder() {
    local task="$1"
    local gate="$2"
    # 在 build.gradle (或所有 *.gradle) 中查找该 task 注册，检测是否包含 placeholder 特征
    local placeholder_count
    placeholder_count=$((grep -A10 "tasks.register('${task}')\|task ${task}[^A-Za-z]" build.gradle 2>/dev/null || true) \
        | grep -ciE "placeholder|logger.lifecycle.*placeholder|println.*placeholder" 2>/dev/null || true)
    if [ "$placeholder_count" -gt "0" ]; then
        log ""
        log "╔══════════════════════════════════════════════════════════╗"
        log "║  🔴  [$gate] FAKE PASS — task '${task}' 是 placeholder   ║"
        log "╠══════════════════════════════════════════════════════════╣"
        log "║  该 task 仅打印日志，未执行任何真实测试。                 ║"
        log "║  这是虚假通过，不符合生产级验证标准。                     ║"
        log "║                                                          ║"
        log "║  修复方法：在 build.gradle 中将 placeholder task 替换为  ║"
        log "║  真实的测试配置（参考 tech-stack yaml 中的 plugins 清单）║"
        log "║  修复完成后重新运行: make -f .harness/Makefile verify    ║"
        log "╚══════════════════════════════════════════════════════════╝"
        BLOCKED=$((BLOCKED+1))
        return 1
    fi
    return 0
}

# ── G1: 单元测试 ──────────────────────────────
log "── G1: 单元测试 ──"
if require_task "test" "G1" "Java 插件默认包含 test task，确认 build.gradle 应用了 java/spring-boot 插件"; then
    prepare_result_dir "build/test-results/test"
    if run_gate "G1" "./gradlew test"; then
        check_junit_results "G1" "build/test-results/test"
    fi
fi

# ── G2: 契约测试 ──────────────────────────────
log "── G2: 契约测试 ──"
if require_task "contractTest" "G2" "build.gradle 中注册 contractTest task。示例:\n   task contractTest(type: Test) { testClassesDirs = sourceSets.contractTest.output.classesDirs }"; then
    if check_not_placeholder "contractTest" "G2"; then
        prepare_result_dir "build/test-results/contractTest"
        if run_gate "G2" "./gradlew contractTest"; then
            check_junit_results "G2" "build/test-results/contractTest"
        fi
    fi
fi

# ── G3: BDD 验收测试 ──────────────────────────
log "── G3: BDD 验收测试 ──"
if require_task "cucumber" "G3" "build.gradle 配置 Cucumber task。示例:\n   task cucumber(type: JavaExec) { ... } 或引入 cucumber-junit-platform-engine"; then
    if check_not_placeholder "cucumber" "G3"; then
        prepare_result_dir "build/test-results/cucumber"
        if run_gate "G3" "./gradlew cucumber"; then
            check_junit_results "G3" "build/test-results/cucumber"
        fi
    fi
fi

# ── G4: 韧性测试 ──────────────────────────────
log "── G4: 韧性测试 ──"
if require_task "resilienceTest" "G4" "build.gradle 注册 resilienceTest task（推荐独立 sourceSet，测试超时/降级/异常场景）"; then
    if check_not_placeholder "resilienceTest" "G4"; then
        prepare_result_dir "build/test-results/resilienceTest"
        if run_gate "G4" "./gradlew resilienceTest"; then
            check_junit_results "G4" "build/test-results/resilienceTest"
        fi
    fi
fi

# ── G5: 覆盖率检查 ────────────────────────────
log "── G5: 覆盖率检查 (≥80%) ──"
if require_task "jacocoTestCoverageVerification" "G5" "build.gradle 添加:\n   apply plugin: 'jacoco'\n   jacocoTestCoverageVerification { violationRules { rule { limit { minimum = 0.8 } } } }"; then
    if run_gate "G5" "./gradlew jacocoTestCoverageVerification"; then
        check_coverage_data "G5"
    fi
fi

rm -f "$TASK_CACHE"

# ── 汇总 ──────────────────────────────────────
log ""
log "===== Verification Result ====="
log "BLOCKED (task未配置): $BLOCKED"
log "FAILED  (执行失败):   $FAILED"

if [ $BLOCKED -gt 0 ]; then
    log ""
    log "❌ 验证被阻断：$BLOCKED 个 Gradle task 未配置、被跳过或缺少有效证据。"
    log "   必须先完成 Gradle 配置和真实测试证据，再运行 make verify。"
    log "   参考 .harness/core/02-tech-stacks/java8-spring2.yaml 中的 plugins 清单。"
    exit 1
elif [ $FAILED -gt 0 ]; then
    log ""
    log "❌ 验证失败：$FAILED 个门未通过，请根据报告修复后重新运行。"
    exit 1
else
    log ""
    log "✅ All gates PASSED. Ready for PHASE_6."
    exit 0
fi
