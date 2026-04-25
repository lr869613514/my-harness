SHELL := /bin/bash
-include .harness/.env

.PHONY: detect-stack repo-check test-bdd test-unit review security verify \
        contract-test resilience-test release-gate changelog set-phase pause resume \
        setup-brainbank index-docs search-docs install-tools preflight \
        check-no-pending check-bdd-real

# 启动前全量预检验（Critical 问题阻断，Warn 问题提示不阻断）
preflight:
	@bash .harness/scripts/run-preflight-check.sh

# ⛔ 代码编辑前置检查：确认 pending_approval == false，否则 exit 1 阻断
# AI 在修改任何 src/ 文件前必须调用此目标
check-no-pending:
	@if ! command -v yq &>/dev/null; then \
	    echo "❌ yq 未安装，无法检查 pending_approval 状态。请先运行: make -f .harness/Makefile install-tools"; \
	    exit 1; \
	fi
	@PENDING=$$(yq e '.pending_approval // false' .harness/harness.yml 2>/dev/null); \
	GATE=$$(yq e '.approval_gate // ""' .harness/harness.yml 2>/dev/null); \
	PHASE=$$(yq e '.current_phase // "UNKNOWN"' .harness/harness.yml 2>/dev/null); \
	if [ "$$PENDING" = "true" ]; then \
	    echo ""; \
	    echo "╔══════════════════════════════════════════════════════════╗"; \
	    echo "║  🔴  代码编辑被阻断 — 存在待审批门                       ║"; \
	    echo "╠══════════════════════════════════════════════════════════╣"; \
	    printf "║  当前阶段: %s\n" "$$PHASE"; \
	    printf "║  待审批门: %s\n" "$$GATE"; \
	    echo "║  "; \
	    echo "║  禁止在人工审批通过前修改任何 src/ 文件。"; \
	    echo "║  请向用户展示产出物，等待用户输入「继续」后执行:"; \
	    echo "║    make -f .harness/Makefile resume"; \
	    echo "║    make -f .harness/Makefile set-phase PHASE=<下一阶段>"; \
	    echo "╚══════════════════════════════════════════════════════════╝"; \
	    exit 1; \
	fi; \
	if [ "$$PHASE" = "PHASE_0_REQUIREMENTS" ] || [ "$$PHASE" = "PHASE_1_SPEC" ]; then \
	    echo ""; \
	    echo "╔══════════════════════════════════════════════════════════╗"; \
	    echo "║  🔴  代码编辑被阻断 — 当前阶段禁止修改 src/              ║"; \
	    echo "╠══════════════════════════════════════════════════════════╣"; \
	    printf "║  当前阶段: %s\n" "$$PHASE"; \
	    echo "║  本阶段仅允许操作 .harness/docs/ 下的文档文件。"; \
	    echo "║  src/ 代码修改只允许在 PHASE_3_IMPLEMENTATION 之后进行。"; \
	    echo "╚══════════════════════════════════════════════════════════╝"; \
	    exit 1; \
	fi; \
	echo "✅ [check-no-pending] 无待审批门，阶段 [$$PHASE] 允许代码修改。"

# 检查 cucumber Gradle task 是否为真实 BDD 实现（非 placeholder）
# PHASE_2_BDD 期间必须调用，placeholder 时输出警告并 exit 1 要求配置
check-bdd-real:
	@echo "[Harness] 检查 Cucumber task 是否为真实 BDD 实现..."
	@if ! grep -q "cucumber" build.gradle 2>/dev/null && ! find . -name "*.gradle" -exec grep -l "cucumber" {} \; 2>/dev/null | grep -q .; then \
	    echo "❌ [CRITICAL] build.gradle 中未找到 cucumber 相关配置。"; \
	    exit 1; \
	fi
	@PLACEHOLDER=$$((grep -A5 "tasks.register('cucumber')\|task cucumber" build.gradle 2>/dev/null || true) | grep -ciE "placeholder|println|logger.lifecycle" || true); \
	if [ "$$PLACEHOLDER" -gt "0" ]; then \
	    echo ""; \
	    echo "╔══════════════════════════════════════════════════════════╗"; \
	    echo "║  ⚠️   BDD 配置警告 — cucumber task 为 placeholder        ║"; \
	    echo "╠══════════════════════════════════════════════════════════╣"; \
	    echo "║  当前 cucumber task 只打印日志，不执行真实 BDD 测试。     ║"; \
	    echo "║  这意味着 PHASE_5 的 G3 门是虚假通过的。                 ║"; \
	    echo "║                                                          ║"; \
	    echo "║  必须在 TASKS.yml 中加入最高优先级任务：                 ║"; \
	    echo "║  「配置真实 Cucumber Gradle task」，在 PHASE_3 最先执行。║"; \
	    echo "║                                                          ║"; \
	    echo "║  参考配置（build.gradle）：                              ║"; \
	    echo "║    testImplementation 'io.cucumber:cucumber-java:7.x'   ║"; \
	    echo "║    testImplementation 'io.cucumber:cucumber-junit:7.x'  ║"; \
	    echo "║    task cucumber(type: Test) {                          ║"; \
	    echo "║      include '**/*CucumberTest*'                        ║"; \
	    echo "║    }                                                    ║"; \
	echo "╚══════════════════════════════════════════════════════════╝"; \
	    yq e ".bdd_setup_required = true" -i .harness/harness.yml 2>/dev/null || true; \
	    exit 1; \
	fi; \
	yq e ".bdd_setup_required = false" -i .harness/harness.yml 2>/dev/null || true; \
	echo "✅ [check-bdd-real] cucumber task 为真实实现，可执行 BDD 测试。"

# 安装所有强依赖 CLI 工具（yq / semgrep）
# yq 安装失败 → exit 1 阻断（状态机无法工作）
# semgrep 安装失败 → 仅警告（非致命）
install-tools:
	@echo "[Harness] 检查并安装必要工具..."
	@YQ_OK=true; \
	if ! command -v yq &>/dev/null; then \
	    echo "📦 安装 yq（状态机核心依赖）..."; \
	    if brew install yq; then \
	        echo "✅ yq 安装成功: $$(yq --version)"; \
	    else \
	        echo "❌ [CRITICAL] yq 安装失败！harness.yml 状态机将无法工作。"; \
	        echo "   请手动执行: brew install yq"; \
	        YQ_OK=false; \
	    fi; \
	else echo "✅ yq 已安装: $$(yq --version)"; fi; \
	if ! command -v semgrep &>/dev/null; then \
	    echo "📦 安装 semgrep（PHASE_4 语义扫描，非核心）..."; \
	    brew install semgrep && echo "✅ semgrep 安装成功" || echo "⚠ semgrep 安装失败（非致命），PHASE_4 第二层扫描将跳过。手动: brew install semgrep"; \
	else echo "✅ semgrep 已安装: $$(semgrep --version 2>/dev/null | head -1)"; fi; \
	if [ "$$YQ_OK" = "false" ]; then exit 1; fi
	@echo "[Harness] 工具安装完成。"

detect-stack:
	@bash .harness/scripts/detect-stack.sh

repo-check:
	@bash .harness/scripts/check-repo-readiness.sh

# BDD 相关
test-bdd:
	@bash .harness/scripts/run-bdd.sh $(MODE)

# 单元测试
test-unit:
	@bash .harness/scripts/run-unit-tests.sh

# 安全扫描（使用 OWASP Dependency-Check 或 OSV-Scanner）
security:
	@bash .harness/scripts/run-security-scan.sh

# 静态分析（第一层: Gradle PMD/Checkstyle/SpotBugs；第二层: Semgrep 语义规则）
review:
	@bash .harness/scripts/run-static-analysis.sh
	@bash .harness/scripts/run-semgrep.sh

# 契约测试
contract-test:
	@bash .harness/scripts/run-contract-test.sh

# 韧性测试
resilience-test:
	@bash .harness/scripts/run-resilience-test.sh

# 全量验证门（整合单元测试、BDD、契约、韧性、覆盖率）
verify:
	@bash .harness/scripts/run-verification-gates.sh

# 发布门禁
release-gate:
	@bash .harness/scripts/run-release-gate.sh

# 生成 Changelog 并推算版本号
changelog:
	@bash .harness/scripts/generate-changelog.sh

# 阶段流转（用法: make set-phase PHASE=PHASE_3_IMPLEMENTATION）
# ⚠ 部分阶段转入需要审批门已被 make resume 清除，否则 exit 1 阻断
set-phase:
	@[ -n "$(PHASE)" ] || (echo "❌ 用法: make set-phase PHASE=<阶段名>" && exit 1)
	@if ! command -v yq &>/dev/null; then \
	    echo "❌ yq 未安装，无法更新 harness.yml。请先运行: make -f .harness/Makefile install-tools"; \
	    exit 1; \
	fi
	@REQUIRED_GATE=""; \
	case "$(PHASE)" in \
	    PHASE_2_BDD|PHASE_2_5_SECURITY|PHASE_3_IMPLEMENTATION) \
	        REQUIRED_GATE="ARCH_REVIEW" ;; \
	    PHASE_4_REVIEW|PHASE_5_VERIFICATION|PHASE_6_MEMORY) \
	        REQUIRED_GATE="TASK_REVIEW" ;; \
	    IDLE) \
	        REQUIRED_GATE="RELEASE" ;; \
	esac; \
	if [ -n "$$REQUIRED_GATE" ]; then \
	    CLEARED=$$(yq e '.cleared_gates // [] | join(",")' .harness/harness.yml 2>/dev/null || echo ""); \
	    if ! echo ",$$CLEARED," | grep -q ",$$REQUIRED_GATE,"; then \
	        echo ""; \
	        echo "╔══════════════════════════════════════════════════════════╗"; \
	        echo "║  ⛔  GATE BLOCKED — 禁止进入 $(PHASE)"; \
	        echo "╠══════════════════════════════════════════════════════════╣"; \
	        echo "║  需要审批门 [$$REQUIRED_GATE] 已通过，但当前未通过。"; \
	        printf "║  已通过的门: %s\n" "$${CLEARED:-（无）}"; \
	        echo "╠══════════════════════════════════════════════════════════╣"; \
	        case "$$REQUIRED_GATE" in \
	            ARCH_REVIEW) \
	                echo "║  正确步骤:"; \
	                echo "║  1. 完成 PHASE_1_SPEC 产出物:"; \
	                echo "║     - .harness/docs/specs/openapi.yaml (或 openapi-diff.yaml)"; \
	                echo "║     - .harness/docs/designs/DESIGN-<名称>-<日期>.md"; \
	                echo "║  2. make -f .harness/Makefile pause GATE=ARCH_REVIEW"; \
	                echo "║  3. 向用户展示产出物清单，声明「✋ ARCH_REVIEW 审批门」"; \
	                echo "║  4. 等待用户明确输入「继续」"; \
	                echo "║  5. make -f .harness/Makefile resume"; \
	                echo "║  6. 再次调用 make set-phase PHASE=$(PHASE)"; \
	                ;; \
	            TASK_REVIEW) \
	                echo "║  正确步骤:"; \
	                echo "║  1. 生成 .harness/docs/tasks/TASKS.yml（任务拆解）"; \
	                echo "║  2. make -f .harness/Makefile pause GATE=TASK_REVIEW"; \
	                echo "║  3. 展示 TASKS.yml 摘要，声明「✋ TASK_REVIEW 审批门」"; \
	                echo "║  4. 等待用户明确输入「继续」"; \
	                echo "║  5. make -f .harness/Makefile resume"; \
	                echo "║  6. 再次调用 make set-phase PHASE=$(PHASE)"; \
	                ;; \
	            RELEASE) \
	                echo "║  正确步骤:"; \
	                echo "║  1. 完成 PHASE_6_MEMORY 所有步骤"; \
	                echo "║  2. make -f .harness/Makefile pause GATE=RELEASE"; \
	                echo "║  3. 等待用户确认可以发布"; \
	                echo "║  4. make -f .harness/Makefile resume"; \
	                echo "║  5. 再次调用 make set-phase PHASE=IDLE"; \
	                ;; \
	        esac; \
	        echo "╚══════════════════════════════════════════════════════════╝"; \
	        exit 1; \
	    fi; \
	fi; \
	if [ "$(PHASE)" = "IDLE" ]; then \
	    yq e ".current_phase = \"IDLE\" | .pending_approval = false | .approval_gate = \"\" | .cleared_gates = []" -i .harness/harness.yml && \
	    echo "✅ 阶段已重置 → IDLE（已清空 cleared_gates）"; \
	else \
	    yq e ".current_phase = \"$(PHASE)\" | .pending_approval = false | .approval_gate = \"\"" -i .harness/harness.yml && \
	    echo "✅ 阶段已更新 → $(PHASE)"; \
	fi

# 人工审批暂停门（用法: make pause GATE=ARCH_REVIEW）
# AI 在需要人工 Review 时调用，写入 pending_approval=true 并停止自动化
pause:
	@[ -n "$(GATE)" ] || (echo "❌ 用法: make pause GATE=<门名称> PHASE=<当前阶段>" && exit 1)
	@if command -v yq &>/dev/null; then \
	    yq e ".pending_approval = true | .approval_gate = \"$(GATE)\"" -i .harness/harness.yml && \
	    echo "" && \
	    echo "⛔ =========================================" && \
	    echo "⛔  人工审批门: $(GATE)" && \
	    echo "⛔  当前阶段: $$(yq e '.current_phase' .harness/harness.yml)" && \
	    echo "⛔ =========================================" && \
	    echo "⛔  请 Review 上方产出物，确认无误后输入「继续」" && \
	    echo "⛔  AI 将在收到确认前停止所有自动化动作" && \
	    echo "⛔ ========================================="; \
	else \
	    echo "⚠ yq 未安装，手动将 harness.yml 中 pending_approval 设为 true，approval_gate 设为 $(GATE)"; \
	fi

# 审批通过后继续（用法: make resume）
# 同时将已通过的 approval_gate 写入 cleared_gates，供 set-phase 验证
resume:
	@if ! command -v yq &>/dev/null; then \
	    echo "⚠ yq 未安装，手动将 harness.yml 中 pending_approval 设为 false"; \
	    exit 1; \
	fi
	@GATE=$$(yq e '.approval_gate // ""' .harness/harness.yml); \
	if [ -z "$$GATE" ] || [ "$$GATE" = "null" ]; then \
	    echo "⚠ 当前没有待审批门（approval_gate 为空），无需 resume。"; \
	    exit 0; \
	fi; \
	CLEARED=$$(yq e '.cleared_gates // [] | join(",")' .harness/harness.yml 2>/dev/null || echo ""); \
	if echo ",$$CLEARED," | grep -q ",$$GATE,"; then \
	    yq e ".pending_approval = false | .approval_gate = \"\"" -i .harness/harness.yml; \
	    echo ""; \
	    echo "✅ 审批门 [$$GATE] 已由用户确认通过（门已存在于 cleared_gates，跳过重复追加）"; \
	else \
	    yq e ".pending_approval = false | .cleared_gates += [\"$$GATE\"] | .approval_gate = \"\"" -i .harness/harness.yml; \
	    echo ""; \
	    echo "✅ 审批门 [$$GATE] 已由用户确认通过"; \
	fi; \
	echo "   已通过的门: $$(yq e '.cleared_gates | join(", ")' .harness/harness.yml)"; \
	echo "   AI 可继续执行下一步骤。"

# 知识库相关
setup-brainbank:
	@echo "Initializing BrainBank local vector store..."
	@bash .harness/scripts/setup-brainbank.sh

index-docs:
	@source .harness/.env 2>/dev/null; \
	if [ "$$BB_AVAILABLE" = "true" ] && command -v bb &>/dev/null; then \
	    echo "[Harness] Indexing .harness/docs into BrainBank..."; \
	    bb --db-path "$${BB_DB_PATH:-.harness/.brainbank}" index --path .harness/docs --collection harness-docs; \
	else \
	    echo "[Harness] ⚠ BrainBank 不可用，尝试自动安装..."; \
	    bash .harness/scripts/setup-brainbank.sh && \
	    source .harness/.env 2>/dev/null && \
	    if [ "$$BB_AVAILABLE" = "true" ]; then \
	        bb --db-path "$${BB_DB_PATH:-.harness/.brainbank}" index --path .harness/docs --collection harness-docs; \
	    else \
	        echo "[Harness] ⚠ BrainBank 安装失败，降级为 @Codebase — 请在 Cursor 中手动使用 @Codebase 检索 .harness/docs/"; \
	    fi; \
	fi

search-docs:
	@source .harness/.env 2>/dev/null; \
	if [ "$$BB_AVAILABLE" = "true" ] && command -v bb &>/dev/null; then \
	    [ -n "$(QUERY)" ] || (echo "用法: make search-docs QUERY='<关键词>'" && exit 1); \
	    bb --db-path "$${BB_DB_PATH:-.harness/.brainbank}" query "$(QUERY)" --collection harness-docs --limit 5; \
	else \
	    echo "[Harness] ⚠ BrainBank 不可用。"; \
	    echo "  请在 Cursor 中执行: @Codebase 检索 $(QUERY)"; \
	    echo "  或先运行: make -f .harness/Makefile setup-brainbank"; \
	fi