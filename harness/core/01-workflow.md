# 🌊 Core 01: Industry-Standard Workflow v2.3

## 核心理念
严禁依赖大模型直觉。每个 Phase 必须通过业界标准协议及硬脚本校验。**每个 Phase 必须在确认产出物完整后，方可调用 `make set-phase` 流转到下一阶段。**

---

## ⛔ 阶段代码访问权限矩阵（全局硬约束）

| 阶段 | 允许操作的文件范围 | 禁止操作 |
|------|------------------|---------|
| PHASE_0_REQUIREMENTS | `.harness/docs/proposals/`、`.harness/docs/requirements/` | **src/ 下任何文件** |
| PHASE_1_SPEC | `.harness/docs/specs/`、`.harness/docs/designs/` | **src/ 下任何文件** |
| PHASE_2_BDD | `.harness/docs/features/`、`src/test/`（仅 Step 骨架） | `src/main/` 下任何文件 |
| PHASE_2_5_SECURITY | `.harness/docs/reports/security-*` | src/ 下任何文件（除修复 CVE 漏洞依赖） |
| PHASE_3_IMPLEMENTATION | `src/main/`、`src/test/`、`.harness/docs/tasks/` | 已通过审批门后方可操作 |
| PHASE_4_REVIEW | `.harness/docs/reports/`（仅修复问题） | 不得新增功能代码 |
| PHASE_5_VERIFICATION | `src/test/`（仅修复测试失败） | 不得修改业务逻辑 |
| PHASE_6_MEMORY | `.harness/docs/`（LEARNINGS、ADR、reports） | src/ 下任何文件 |

> **AI 在每次修改 `src/` 文件前，必须执行 `make -f .harness/Makefile check-no-pending`，确认无待审批门。**

---

## 产出物完整性检查规则（适用所有 Phase）

在调用 `make set-phase` 之前，AI **必须**：
1. 逐一列出本 Phase 的"产出物"清单。
2. 确认每个文件已实际生成（可读取文件首行作为存在性证明）。
3. 若有缺失，必须补全后再流转，不得跳过。

---

## 标准流水线阶段

### [PHASE_0_REQUIREMENTS] 需求结构化

- **前置 — 历史知识检索**（强制）:
  ```bash
  make -f .harness/Makefile search-docs QUERY="<需求核心业务词>"
  ```
  检索到相关 LEARNINGS/ADR 时，必须在需求文档中显式引用。

- **动作**:
  1. **判断变更类型**:
     - **全新功能**: 从用户模糊需求中提取结构化用户故事，写入 `.harness/docs/requirements/user-stories.md`；生成 `.harness/docs/requirements/acceptance-criteria.yaml`，每条故事附带验收条件，并映射故事 ID 到后续 Feature 文件。
     - **功能变更**: 必须先用 `@Codebase` 检索受影响的核心类与表，再生成变更提案。
  2. **生成变更提案**（功能变更时必须执行）: 严格按照 `docs/templates/change-proposal.md` 模板生成文件，禁止自行编造格式。
     - **命名规范**: `CP-<需求简述(≤10字,中文或英文)>-<YYYYMMDD>-<NNN>.md`
     - **示例**: `CP-账单状态字段补充-20260425-001.md`、`CP-优惠券接入-20260425-001.md`
     - **存放位置**: `.harness/docs/proposals/`
  3. **冲突检查**: 提案生成后，逐条对比 `acceptance-criteria.yaml`，确认新变更不破坏已有验收条件。若违反，必须在提案中显式标注 `⚠ CONFLICT`，并等待人工决策。

- **产出物清单**（流转前必须全部确认存在）:
  - 全新功能: `docs/requirements/user-stories.md` + `docs/requirements/acceptance-criteria.yaml`
  - 功能变更: `docs/proposals/CP-<名称>-<日期>-<NNN>.md`

- **结束**: `make -f .harness/Makefile set-phase PHASE=PHASE_1_SPEC`

---

### [PHASE_1_SPEC] 架构与规格基建

- **动作**:
  1. 使用 `@Codebase` 检索相关业务实体与现有规格。
  2. 在 `.harness/docs/specs/` 下生成契约文件：
     - RESTful API: `openapi.yaml` 或 `openapi-diff.yaml`（增量变更）
     - 消息队列: `asyncapi.yaml`
  3. 在 `.harness/docs/designs/` 下生成技术方案文档（含 Mermaid 序列图 + 需求追溯章节）。
     - **命名规范**: `DESIGN-<需求简述>-<YYYYMMDD>.md`
  4. 若 spectral 可用，运行: `npx @stoplight/spectral-cli lint .harness/docs/specs/openapi.yaml`

- **产出物清单**（流转前必须全部确认存在）:
  - `docs/specs/openapi.yaml` 或 `docs/specs/openapi-diff.yaml`
  - `docs/designs/DESIGN-<名称>-<日期>.md`（含 Mermaid 图）

- **⛔ 强制人工审批门 — ARCH_REVIEW**:

  产出物生成后，AI **必须执行以下操作，不得跳过**:

  1. 运行: `make -f .harness/Makefile pause GATE=ARCH_REVIEW`
  2. 向用户展示本阶段产出物路径清单。
  3. 声明：「✋ 已到达 **ARCH_REVIEW** 审批门。请 Review 技术方案和 API 规格，确认无误后输入「继续」。」
  4. **进入等待状态，直到用户明确输入「继续」或等效确认词，不得执行任何后续动作。**
  5. 收到确认后: `make -f .harness/Makefile resume`，然后 `make -f .harness/Makefile set-phase PHASE=PHASE_2_BDD`

---

### [PHASE_2_BDD] 行为驱动测试契约

> **BDD 驱动开发核心理念**：Feature 文件是需求规格的唯一真相来源。PHASE_2 建立"测试合约"，PHASE_3 的实现以让 BDD 全部通过为完成标准。严禁先实现后补测试。

- **工具**: `cucumber`（`./gradlew cucumber`）

- **Step 1 — 编写 Feature 文件**:
  1. 严格基于 `docs/specs/openapi.yaml` 和 `docs/proposals/CP-*.md` 中的验收条件，生成 `.feature` 文件到 `.harness/docs/features/`。
  2. 每个验收条件（AC）对应至少一个 `Scenario`，使用 Given/When/Then 精确描述业务行为，**禁止写模糊的场景描述**。
  3. 命名规范：`<CP-需求ID>.feature`，如 `CP-收款状态查询.feature`。

- **Step 2 — BDD Dry-Run 校验（准入门）**:
  - 运行: `make -f .harness/Makefile test-bdd MODE=dry-run`
  - 目的：确认每个 Gherkin 步骤都有对应的 Step 定义骨架（即 Java `@Given/@When/@Then` 方法存在，内容可为 `throw new PendingException()`）。
  - Dry-Run 失败 → AI 自动补全缺失的 Step 骨架到 `src/test/` 对应 Steps 类 → 重新 Dry-Run，形成闭环，直到 exit 0。

- **⚠️ Dry-Run 通过 ≠ BDD 通过**：此时步骤骨架均为 `PendingException`（红色状态），是正确的 TDD 起点。PHASE_3 的实现就是要让这些红色变绿色。

- **Step 3 — 检查 Cucumber task 是否为真实实现**:
  - 运行: `make -f .harness/Makefile check-bdd-real`
  - 若检测到 `cucumber` task 为 placeholder，**必须**将此信息作为 `bdd_setup_required: true` 记录到 `.harness/harness.yml`（或在本阶段的产出物摘要中明确标注），待 PHASE_3 第一步生成 `TASKS.yml` 时，将「配置真实 Cucumber Gradle task（引入 cucumber-junit-platform-engine）」作为**优先级最高的第一个任务**加入，并在 `TASK_REVIEW` 审批门前向用户明确说明。  
  > ⚠️ **注意**：TASKS.yml 在 PHASE_2 期间尚不存在，不得提前创建或在 PHASE_2 写入任务，必须等到 PHASE_3 任务拆解阶段统一生成。

- **产出物清单**（流转前必须全部确认存在）:
  - `docs/features/<CP-ID>.feature`（至少一个，覆盖所有 AC）
  - `src/test/.../steps/` 下对应 Step 骨架类（所有 Gherkin 步骤有映射）
  - Dry-Run 退出码为 0

- **结束**: `make -f .harness/Makefile set-phase PHASE=PHASE_2_5_SECURITY`

---

### [PHASE_2_5_SECURITY] 软件供应链安全

- **动作**: `make -f .harness/Makefile security`
- **卡点**: 存在 CVSS ≥ 7 的漏洞时，AI 必须提示升级依赖版本，修复后重新扫描，不得跳过。

- **产出物清单**:
  - `docs/reports/security-scan-<timestamp>.log`

- **结束**: `make -f .harness/Makefile set-phase PHASE=PHASE_3_IMPLEMENTATION`

---

### [PHASE_3_IMPLEMENTATION] 约束驱动编码

- **前置**:
  1. 加载 `02-tech-stacks/<id>.yaml` 及 `04-standards/<lang>.md`。
  2. `make -f .harness/Makefile repo-check`（失败时先修复 Critical 问题）。
  3. 加载 `skills/skill-tool-mapping.md`，确认工具就绪。

- **前置 — 历史知识检索**（强制）:
  ```bash
  make -f .harness/Makefile search-docs QUERY="<Story 核心业务词>"
  ```
  将相关度 > 0.75 的结果附在 `TASKS.yml` 对应任务的 `notes` 字段。

- **动作 — 第一步: 生成任务拆解（仅此步，然后暂停）**:
  1. **先检查**: `yq e '.bdd_setup_required // false' .harness/harness.yml`
     - 若为 `true`（PHASE_2 检测到 cucumber 为 placeholder）：**第一个任务必须是**「T000 - 配置真实 Cucumber Gradle task，引入 io.cucumber:cucumber-java:7.x 和 cucumber-junit-platform-engine，替换 build.gradle 中的 placeholder」，优先级高于所有业务任务。
  2. 生成 `.harness/docs/tasks/TASKS.yml`，每个任务包含:
     - `id`, `story_id`, `title`, `status: todo`, `notes`（来自知识检索）
  3. 生成后**立即暂停，执行 TASK_REVIEW 审批门**，不得开始编码。

- **⛔ 强制人工审批门 — TASK_REVIEW**:

  1. 运行: `make -f .harness/Makefile pause GATE=TASK_REVIEW`
  2. 展示 `TASKS.yml` 内容摘要（任务数、各任务标题和关联 Story）。
  3. 声明：「✋ 已到达 **TASK_REVIEW** 审批门。请确认任务拆解是否合理，确认后输入「继续」。」
  4. **进入等待状态，不得开始任何编码。**
  5. 收到确认后: `make -f .harness/Makefile resume`，开始编码。

- **动作 — 第二步: BDD 驱动编码**:
  1. 按任务优先级逐项编码，实时更新 `status: in-progress → done`。
  2. **每完成一个任务后，立即运行**: `make -f .harness/Makefile test-bdd`（无 dry-run 参数，真实执行）。
     - BDD 场景通过 → 继续下一任务。
     - BDD 场景失败 → 分析失败原因，修复实现，重新运行，形成闭环，**不得跳过**。
  3. 可使用 Subagent 并行开发（`skills/skill-subagent-driven-dev.md`）。
  4. 会话中断时，按 `skill-resume-session.md` 恢复。

- **⛔ PHASE_3 完成的唯一标准**: 所有任务 `status: done` **且** `make test-bdd`（完整执行，非 dry-run）全部通过（exit 0）。  
  任何"代码实现完了但 BDD 没过"的状态，**不允许**调用 `make set-phase PHASE=PHASE_4_REVIEW`。

- **产出物清单**:
  - `docs/tasks/TASKS.yml`（所有任务 status: done）
  - 实际代码变更文件
  - BDD 完整执行通过的证据（终端输出截图或 `docs/reports/bdd-<timestamp>.log`）

- **结束**: `make -f .harness/Makefile set-phase PHASE=PHASE_4_REVIEW`

---

### [PHASE_4_REVIEW] 静态语法树审计

- **动作**:
  1. `make -f .harness/Makefile review`（Gradle check + Semgrep）。
  2. 静态审计通过后，加载 `skills/skill-adversarial-review.md`，依次扮演三个角色进行对抗性审查。
  3. 生成审查报告: `docs/reports/adversarial-review-<timestamp>.md`。
  4. 若报告中有 `CRITICAL` 或 `HIGH`，立即修复，重新运行审计和对抗性审查（闭环）。

- **产出物清单**:
  - `docs/reports/static-analysis-<timestamp>.log`（无 ERROR）
  - `docs/reports/adversarial-review-<timestamp>.md`（无 CRITICAL/HIGH）

- **结束**: `make -f .harness/Makefile set-phase PHASE=PHASE_5_VERIFICATION`

---

### [PHASE_5_VERIFICATION] 动态测试与覆盖率

- **动作**:
  1. `make -f .harness/Makefile verify`（五道门：单元/契约/BDD/韧性/覆盖率）。
  2. 读取 `docs/reports/verification/gates-summary-*.log`，定位失败的门。
  3. **失败时先检索历史经验再修复**:
     ```bash
     make -f .harness/Makefile search-docs QUERY="<失败的测试错误关键词>"
     ```
  4. 修复后重新运行，直至所有门通过。

- **产出物清单**:
  - `docs/reports/verification/gates-summary-<timestamp>.log`（All PASSED）
  - `docs/reports/unit-test/`（测试报告归档）

- **卡点**: 核心业务覆盖率 ≥ 80%。

- **结束**: `make -f .harness/Makefile set-phase PHASE=PHASE_6_MEMORY`

---

### [PHASE_6_MEMORY] 决策沉淀与状态重置

- **前置**:
  1. `make -f .harness/Makefile release-gate` → 生成 GO/NO-GO 报告。
  2. NO-GO → 根据失败门回到 PHASE_4 或 PHASE_5 修复，直至 GO。

- **动作**:
  1. `make -f .harness/Makefile index-docs`（将新 ADR、LEARNINGS 索引到向量库）。
  2. 采用 MADR 格式记录架构决策: `docs/adr/YYYYMMDD-<决策名>.md`。
  3. 追加经验到 `docs/LEARNINGS.yaml`（格式参考文件顶部示例）。
  4. `make -f .harness/Makefile changelog`（推算版本号，生成 CHANGELOG）。
  5. 设置最终发布审批门: `make -f .harness/Makefile pause GATE=RELEASE`，等待人类审核发布。

- **产出物清单**:
  - `docs/reports/release-gate/release-decision-<timestamp>.md`（GO）
  - `docs/adr/YYYYMMDD-<决策名>.md`
  - `docs/LEARNINGS.yaml`（已追加新条目）
  - `CHANGELOG.md`（已更新）

- **清理**（收到发布确认后，按序执行）:
  1. `make -f .harness/Makefile resume`
  2. `make -f .harness/Makefile set-phase PHASE=IDLE`
  3. **必须删除以下临时文件**（它们已完成使命，不应永久留存）:
     - `docs/tasks/TASKS.yml`（任务拆解，属于过程产物）
     - `docs/reports/` 下所有带时间戳的 `.log` 文件（验证报告、静态分析、安全扫描等）
     - `docs/reports/adversarial-review-*.md`（对抗性审查报告）
     - `docs/reports/release-gate/release-decision-*.md`（发布决策报告）
  4. **必须保留的永久文件**:
     - `docs/LEARNINGS.yaml`（持续追加）
     - `docs/adr/`（架构决策记录）
     - `docs/features/`（BDD 契约，作为需求基线归档）
     - `docs/proposals/`、`docs/designs/`、`docs/specs/`（变更历史，按需归档）
     - `CHANGELOG.md`

> 临时文件的 `.gitignore` 排除方案：在 `.harness/docs/reports/` 目录下维护 `.gitignore`，排除 `*.log` 和 `adversarial-review-*.md`，避免报告文件污染 git 历史。
