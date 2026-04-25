# 🛡️ Core 03: Automated Testing Engine v2.1

## 原则
- **工具强制**: 所有测试必须通过 Makefile target 启动，禁止直接运行裸测试命令。
- **Dry-Run 闭环**: BDD 阶段必须先 Dry‑Run，实现缺失 Step 后再正式运行。
- **报告归档**: 每次测试/审计结果必须归档到 `.harness/docs/reports/`。

## BDD 规范
- 存储: `.harness/docs/features/`
- 执行: `make -f .harness/Makefile test-bdd MODE=dry-run`

## Gradle 对应命令
- BDD Dry-Run: `./gradlew cucumber -Pcucumber.options='--dry-run'`
- BDD Run: `./gradlew cucumber`
- 单元测试: `./gradlew test`
- 覆盖率验证: `./gradlew jacocoTestCoverageVerification`

## 单元测试与覆盖率
- 隔离: 严禁 `@SpringBootTest`，使用 MockitoExtension
- 覆盖率: Jacoco 行覆盖率 ≥80%
- 命令: `make -f .harness/Makefile test-unit`

## 安全测试
- 命令: `make -f .harness/Makefile security`
- 标准: 不允许任何 CVSS ≥ 7 的漏洞

## 报告归档
测试后，自动将 `build/reports/tests/` 和 `build/reports/jacoco/` 拷贝到 `.harness/docs/reports/` 下。

## 3. 行为验证门 (PHASE_5)
- 命令: `make verify`
- 包含五大门：
    - G1 单元测试
    - G2 契约测试（API 与 OpenAPI 对齐）
    - G3 BDD 验收测试
    - G4 韧性测试（异常/超时模拟）
    - G5 覆盖率门 (JaCoCo ≥80%)
- 全部通过方可进入 PHASE_6，否则 AI 必须根据失败报告修复对应问题。