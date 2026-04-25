# 🧠 Industrial AI Harness: Control System v2.3

## 1. 启动协议（会话开启后立即顺序执行，不可跳过任何步骤）

1. 运行 `make -f .harness/Makefile install-tools`，强制安装 `yq`（状态机核心）和 `semgrep`。
   - **`yq` 安装失败 → exit 1，整个框架无法运行，必须手动修复后重新启动。**
   - `semgrep` 安装失败 → 仅警告，不阻断。

2. 运行 `make -f .harness/Makefile detect-stack`，探测技术栈，写入 `.harness/harness.yml` 和 `.harness/.env`。
   - **`yq` 未安装时 detect-stack 会 exit 1 阻断，不会继续执行任何后续步骤。**

3. **运行 `make -f .harness/Makefile preflight`，执行全量预检验**：
   - 检查工具（yq / semgrep / python3）
   - 检查 Gradle task 是否配置（test / check / jacoco / owasp / cucumber / contractTest / resilienceTest）
   - 检查 BrainBank 状态
   - 检查 harness.yml 审批门状态
   - **若出现任何 `[CRITICAL]` 错误，AI 必须停止并向用户展示错误信息及修复方法，不得继续任何开发阶段。**
   - `[WARN]` 级别问题不阻断，但必须在汇报中提及。

4. 根据 `STACK_ID`，加载 `.harness/core/02-tech-stacks/<STACK_ID>.yaml`。

5. **知识库强制安装**（⚠️ 严禁跳过安装直接降级）：
   - 读取 `.harness/.env`，若 `BB_AVAILABLE` 不为 `true` 或字段不存在：
     - **必须立即执行**（不询问用户，直接运行）：
       ```
       make -f .harness/Makefile setup-brainbank
       ```
     - 等待安装完成，重新读取 `.harness/.env`。
     - 安装成功（`BB_AVAILABLE=true`）→ 继续。
     - **仅当安装命令执行后仍失败** → 才允许降级，输出：「⚠ BrainBank 安装失败，降级为 @Codebase。」
   - **绝对禁止**：未执行 `make setup-brainbank` 就输出"BB_AVAILABLE 未配置，降级"——这是违规行为。

6. 读取 `.harness/harness.yml` 确定 `current_phase`：
   - 若 `pending_approval: true`：**立即停止**，展示审批门信息，等待用户明确输入「继续」。
   - 若 `current_phase != IDLE`：执行恢复协议（`skills/skill-resume-session.md`）。
   - 若 `current_phase == IDLE`：等待用户输入需求，进入 PHASE_0。

7. **向用户汇报初始化结果**：当前阶段、工具状态摘要（含 Preflight 结果）、知识库状态。

---

## 2. 超能力与自愈协议

- **`[Skill: Tool-Auto-Loader]`**: 脚本执行失败时追加检查缺失工具，安装后重试。
- **`[Skill: State-Driver]`**: 所有阶段流转必须通过 `make -f .harness/Makefile set-phase PHASE=<阶段>`，禁止手动编辑 YAML。
- **`[Skill: Vector-Retrieval]`**: 优先用 `bb query` 检索；`BB_AVAILABLE!=true` 时自动尝试安装；安装失败降级为 `@Codebase`，并向用户声明。详见 `skills/skill-knowledge-retrieval.md`。

---

## 3. 需求推进实现准则

- 上述前置工作完成后才可以开始本次需求，加载 `01-workflow.md`，严格按照指引步骤进行需求研发推进，不得直接实现！

---

## 4. 零容忍原则

- 绝对禁止绕过 Makefile/scripts 直接运行 `./gradlew test` 等裸命令。
- 遇到不确定的执行方式，必须先查阅 `skills/` 目录下的对应 Skill 文件。
- **凡遇到 `pending_approval: true`，必须完全停止自动化，等待用户明确确认。**

### ⛔ 代码编辑硬锁定（与审批门同等级的零容忍规则）

在以下情况下，**AI 绝对禁止创建或修改任何 `src/` 目录下的文件**（包括 `src/main/` 和 `src/test/`）：

1. **`pending_approval: true`** 时 —— 无论理由是"提前预览"还是"顺带实现"，一律禁止。
2. **当前阶段为 PHASE_0、PHASE_1** 时 —— 这两个阶段仅操作 `.harness/docs/` 文档，任何业务代码修改都是违规。
3. **`cleared_gates` 中缺少进入当前实现阶段所需的审批门** 时。

> 🔴 **反模式举例（严禁）**：  
> "在审批门前已完成编码，供您一并 Review" —— 这是严重违规。代码变更必须在人工审批通过、`make resume` 执行完毕、`make set-phase PHASE=PHASE_3_IMPLEMENTATION` 成功后才可开始。

在开始任何 `src/` 文件修改前，AI **必须**先执行：
```bash
make -f .harness/Makefile check-no-pending
```
该命令会验证 `pending_approval == false`，失败则 exit 1 阻断。

### ⛔ 审批门是 Makefile 技术层面的硬约束，无法绕过

`make set-phase` 在以下阶段转入时会验证 `harness.yml` 中的 `cleared_gates` 字段，若未通过则 **exit 1 阻断**，AI 自身也无法绕过：

| 目标阶段 | 必须已通过的门 |
|----------|--------------|
| PHASE_2_BDD / PHASE_2_5_SECURITY / PHASE_3_IMPLEMENTATION | `ARCH_REVIEW` |
| PHASE_4_REVIEW / PHASE_5_VERIFICATION / PHASE_6_MEMORY | `TASK_REVIEW` |
| IDLE（发布后重置） | `RELEASE` |

`cleared_gates` 仅由 `make resume`（用户确认后）写入，**AI 无法自行修改**。

**必须严格遵守的操作序列：**
```
① 生成阶段产出物（文件必须存在）
② make -f .harness/Makefile pause GATE=<门名>   → pending_approval=true
③ 向用户展示产出物清单，声明审批门，等待「继续」
④ [用户确认] → make -f .harness/Makefile resume → cleared_gates += [门名]
⑤ make -f .harness/Makefile set-phase PHASE=<下一阶段>
```

**任何跳过上述序列、尝试直接 `set-phase` 的行为，Makefile 都会拦截并打印修复步骤，AI 必须遵从。**

---

## 5. **工具强制加载**: 在进入任何阶段前，必须读取 `skills/skill-tool-mapping.md`，确认所需工具可用。若无，自愈装载。

## 6. **知识检索强制**: 在 PHASE_0、PHASE_3、PHASE_5 启动时，必须执行 `make -f .harness/Makefile search-docs QUERY="<当前需求关键词>"` 检索历史文档和踩坑记录。若 BrainBank 不可用，使用 `@Codebase` 检索 `.harness/docs/LEARNINGS.yaml` 和 `.harness/docs/adr/` 作为降级方案，并向用户声明。详见 `skills/skill-knowledge-retrieval.md`。
