# Skill: Subagent-Driven Development (并行开发)

## 来源
Cursor 原生 Subagent 能力。

## 调用时机
在 PHASE_3_IMPLEMENTATION，当 TASKS.yml 中包含多个独立任务时。

## 使用方式
1. AI 读取 `TASKS.yml` 中状态为 `todo` 的任务。
2. 为每个任务（或一组强相关的任务）启动一个 Subagent。
3. 每个 Subagent 的上下文只包含该任务相关的设计文档、Story 和规范，隔离干扰。
4. 主 AI 汇集 Subagent 的结果，解决合并冲突并更新任务状态。
5. 过程中所有 Subagent 必须遵守以下规范（按优先级）:
   - `.cursor/rules/root.mdc`（Harness 全局约束，含审批门与代码编辑锁定）
   - `.harness/core/04-standards/java8.md`（Java 8 编码标准）
   - `.harness/core/02-tech-stacks/java8-spring2-gradle.yaml`（技术栈约束）
6. 每个 Subagent 完成任务后，**必须先运行 `make -f .harness/Makefile test-bdd`** 确认对应 BDD 场景通过，方可报告任务完成。