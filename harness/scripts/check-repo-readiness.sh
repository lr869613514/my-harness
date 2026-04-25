#!/bin/bash
# check-repo-readiness.sh - 检查仓库对 AI 辅助开发的友好程度
# 注意：不使用 set -e，所有检查结果汇总后统一输出，非零退出码表示有 Critical 问题

REPORT_DIR=".harness/docs/reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/repo-readiness-$(date +%Y%m%d-%H%M%S).log"
ISSUES=0

echo "=== Repo Readiness Report ===" | tee "$REPORT_FILE"

# 1. 检查是否存在 README.md 或 CONTRIBUTING.md
if [ ! -f "README.md" ] && [ ! -f "CONTRIBUTING.md" ]; then
    echo "[WARN] 缺少 README.md，AI 可能无法快速理解项目背景。" | tee -a "$REPORT_FILE"
    ISSUES=$((ISSUES+1))
fi

# 2. 检查源码目录与测试目录是否对应
SRC_DIR="src/main/java"
TEST_DIR="src/test/java"
if [ ! -d "$SRC_DIR" ] || [ ! -d "$TEST_DIR" ]; then
    echo "[ERROR] 标准 Maven/Gradle 目录结构缺失或不对应（src/main/java 或 src/test/java 不存在）。" | tee -a "$REPORT_FILE"
    ISSUES=$((ISSUES+1))
fi

# 3. 检查是否存在循环依赖（使用 jdeps 探测，可选）
if command -v jdeps &>/dev/null; then
    echo "    正在检查包间循环依赖（jdeps）..." | tee -a "$REPORT_FILE"
fi

# 4. 检查必要的 Gradle 插件是否已在 build.gradle 中声明
# 注意：使用 grep -F（固定字符串模式），避免 "." 被当作正则通配符
if [ -f "build.gradle" ]; then
    for plugin in "pmd" "checkstyle" "jacoco" "org.owasp.dependencycheck"; do
        if ! grep -qF "$plugin" build.gradle; then
            echo "[WARN] build.gradle 中未声明插件: ${plugin}，后续静态分析可能无法完整执行。" | tee -a "$REPORT_FILE"
            ISSUES=$((ISSUES+1))
        fi
    done
else
    echo "[ERROR] 未找到 build.gradle，无法进行 Gradle 专项检查。" | tee -a "$REPORT_FILE"
    ISSUES=$((ISSUES+1))
fi

# 5. 检查代码风格是否统一（tab 字符）
TAB_FILES=$(grep -rlP "\t" src/main/java/ 2>/dev/null | head -5)
if [ -n "$TAB_FILES" ]; then
    echo "[INFO] 发现 tab 字符（可能存在缩进不一致）:" | tee -a "$REPORT_FILE"
    echo "$TAB_FILES" | tee -a "$REPORT_FILE"
fi

echo "---------------------------------------" | tee -a "$REPORT_FILE"
if [ "$ISSUES" -gt 0 ]; then
    echo "⚠ 发现 $ISSUES 个问题，建议修复后再进入编码阶段。" | tee -a "$REPORT_FILE"
    echo "  [WARN] 级别问题不阻断流程，[ERROR] 级别问题建议修复后继续。" | tee -a "$REPORT_FILE"
    exit 1
else
    echo "✅ 仓库就绪度检查通过，可以进入 PHASE_3。" | tee -a "$REPORT_FILE"
    exit 0
fi
