# Skill: Session Resume (中断恢复)

## 触发条件
当 `current_phase != "IDLE"` 时，AI 在启动后必须执行本协议。

## 步骤
1. 读取 `.harness/docs/tasks/TASKS.yml`（若存在）。
2. 识别所有 `status: in-progress` 或 `status: todo` 的任务。
3. 向用户报告：
   - 当前所处阶段（`current_phase`）
   - 未完成任务列表（含任务 ID、描述、关联 Story ID）
   - 最近一次会话的已完成工作（取 `status: done` 中最后 3 条）
4. 询问用户确认：「是否从断点继续？还是需要重新设计某个任务？」
5. 根据用户指令，将对应任务状态从 `todo` → `in-progress`，继续执行。

## 恢复规则
- **禁止重复执行已完成任务**：`status: done` 的任务跳过。
- **中断点任务优先**：`status: in-progress` 的任务排在 `todo` 之前恢复。
- **阶段上下文重载**：恢复前必须按照 `.harness/AGENTS.md` 的「阶段加载协议」重新加载当前阶段所需的规范文件，不得依赖上一会话的记忆。

## TASKS.yml 格式参考
```yaml
tasks:
  - id: "T001"
    story_id: "US-01"
    title: "实现用户登录接口"
    status: done       # todo | in-progress | done
    assignee: subagent-1
    completed_at: "2026-04-25T10:00:00"

  - id: "T002"
    story_id: "US-01"
    title: "编写登录接口单元测试"
    status: in-progress
    assignee: subagent-1

  - id: "T003"
    story_id: "US-02"
    title: "实现权限校验中间件"
    status: todo
    assignee: ~
```

## 异常情况
- 若 `TASKS.yml` 不存在但 `current_phase != IDLE`，说明任务拆解尚未完成，应回到 PHASE_3_IMPLEMENTATION 的第一步重新生成任务拆解。
- 若 `harness.yml` 中 `pending_approval: true`，必须先提示用户完成人工审批，方可继续流转。
