# Skill: BDD 全生命周期

## BDD 驱动开发的两个阶段

### 阶段一：BDD Spec 验证（PHASE_2_BDD — Dry-Run）

**目的**：确认 Feature 文件的每个 Gherkin 步骤都有对应的 Java Step 定义骨架，形成"红色测试"的起点。

**命令**：
```bash
make -f .harness/Makefile test-bdd MODE=dry-run
```

**预期行为**：
- 成功（exit 0）：所有 Gherkin 步骤都能匹配到 `@Given/@When/@Then` 方法（内容为 `throw new PendingException()` 是正确的）。
- 失败：Cucumber 输出未匹配步骤的骨架代码，AI **必须**将这些骨架添加到 `src/test/` 对应的 Steps 类，然后重新 Dry-Run，形成闭环直到 exit 0。

**绝对禁止**：
- 直接执行 Maven/Cucumber 命令。
- Dry-Run 通过后立即实现业务逻辑（这是 PHASE_3 的工作）。

---

### 阶段二：BDD 完整执行（PHASE_3_IMPLEMENTATION 中 + PHASE_5 G3）

**目的**：验证实现代码确实满足了 Feature 文件描述的业务行为，是 PHASE_3 完成的硬性标准。

**命令**：
```bash
make -f .harness/Makefile test-bdd
# 等价于: ./gradlew cucumber（无 dry-run，真实执行）
```

**BDD 驱动编码循环（PHASE_3 每个任务）**：
```
写实现代码 → make test-bdd → 全部 PASS → 下一任务
                    ↓ 失败
              分析失败原因 → 修复实现 → make test-bdd
```

**前提条件**：
- `cucumber` Gradle task **必须是真实实现**（不是 placeholder）。
- 在开始 PHASE_3 编码前，先运行 `make -f .harness/Makefile check-bdd-real`。
- 若检测到 placeholder，必须先配置真实 Cucumber task（这是 TASKS.yml 中的最高优先级任务）。

**PHASE_3 完成的唯一标准**：
`make test-bdd` 全部通过（exit 0），**任何 PendingException 都算失败**。

---

## 常见错误

| 错误 | 原因 | 修复 |
|------|------|------|
| Dry-Run 成功但 Full-Run 失败 | Step 骨架只有 `throw new PendingException()`，没有实现 | 在 PHASE_3 中实现对应业务逻辑 |
| Full-Run 永远成功（placeholder） | cucumber task 是 placeholder，不执行真实测试 | 配置真实 Cucumber task |
| 步骤匹配失败 | Gherkin 文本与 `@Given` 注解正则不匹配 | 修正注解正则或重写 Gherkin 步骤 |
