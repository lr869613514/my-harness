# 🧠 Core 05: Knowledge Distillation v2.1
## 0. 发布门禁 (Go/No-Go Gate)
在记录架构决策之前，必须通过发布门禁。
执行 `make release-gate`，确保 `.harness/docs/reports/release-gate/release-decision-*.md` 中的裁定为 **GO**。

## 架构决策 (ADR)
- 位置: `.harness/docs/adr/YYYYMMDD_决策名称.md`
- 格式: MADR 3.0

## 结构化经验库
- 文件: `.harness/docs/LEARNINGS.yaml`
- 格式示例:
  ```yaml
  - id: "L001"
    pattern: "N+1 query in MyBatis"
    solution: "Use <collection> in XML"
    tags: ["performance", "mybatis"]