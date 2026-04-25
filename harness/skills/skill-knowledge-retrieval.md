# Skill: Knowledge Retrieval (本地向量检索)

## 触发时机
在 PHASE_0 启动时、PHASE_3 编码前、PHASE_5 修复问题时，必须执行本 Skill。

---

## 工具优先级

本 Skill 按以下优先级执行知识检索，自动降级：

```
优先级 1: BrainBank (bb) — 本地 ChromaDB 向量语义检索
优先级 2: @Codebase   — Cursor 内置语义检索（BrainBank 不可用时）
```

---

## 优先级 1: BrainBank (bb)

### 前置检查（强制安装，禁止跳过直接降级）

```bash
source .harness/.env
if [ "$BB_AVAILABLE" != "true" ]; then
    # 必须先安装，不得直接降级
    make -f .harness/Makefile setup-brainbank
    source .harness/.env  # 重新加载，检查是否安装成功
fi
```

- 安装成功（`BB_AVAILABLE=true`）→ 使用 bb 检索。
- **仅当安装失败后** → 转入优先级 2（@Codebase），并向用户声明原因。
- **⚠️ 严禁在未尝试安装的情况下直接使用降级方案。**

### 使用方式

**1. 检索历史踩坑经验：**
```bash
bb query "订单并发超卖" --collection harness-docs --limit 5
```

**2. 检索架构决策：**
```bash
bb query "为什么使用乐观锁" --collection harness-docs --limit 3
```

**3. 索引新文档（PHASE_6 执行）：**
```bash
bb index --path .harness/docs --collection harness-docs
```

### 输出解读
- `相关度 > 0.75`：高度相关，直接参考
- `相关度 0.5~0.75`：中度相关，结合上下文判断
- `相关度 < 0.5`：参考价值低，不强制采用

---

## 优先级 2: @Codebase 降级方案

当 `BB_AVAILABLE=false` 或 `make setup-brainbank` 失败时，AI **必须明确向用户声明**：

> 「⚠ BrainBank 不可用，当前使用 Cursor @Codebase 语义检索作为降级方案，历史踩坑记录可能无法完整覆盖。」

然后使用 Cursor 原生的 `@Codebase` 进行等效检索：
- 检索 `.harness/docs/LEARNINGS.yaml` 中的历史经验
- 检索 `.harness/docs/adr/` 中的架构决策记录
- 检索 `.harness/docs/specs/` 中的已有规格文档

**降级检索示例：**
```
@Codebase 查找所有关于"并发超卖"的历史记录和解决方案
@Codebase 查找 LEARNINGS.yaml 中 tags 包含 "performance" 的条目
```

---

## 注意事项
- 严禁使用 `cat` 全量加载 `LEARNINGS.yaml`（文件可能超过 100KB）
- 每次检索必须记录：查询词、使用的工具（bb/Codebase）、检索到的关键结论
- BrainBank 索引在 PHASE_6 `make index-docs` 后才包含最新内容，新建项目首次使用时可能返回空结果，属正常现象
