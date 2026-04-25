# Skill: Tool Mapping (工具映射手册)

## 目的
本 Skill 强制 AI 在每个阶段使用指定的 CLI 工具，不得自行编写替代脚本。

## 工具清单及使用场景

| 工具名 | 阶段 | 用途 | 调用方式 |
|--------|------|------|----------|
| `tree-sitter` | PHASE_0 | 提取代码 AST，辅助需求理解 | `tree-sitter parse <file>` |
| `spectral` | PHASE_1 | OpenAPI 规范 Lint | `npx @stoplight/spectral-cli lint <file>` |
| `prism` | PHASE_1 | API Mock Server | `prism mock <spec>` |
| `cucumber` | PHASE_2 | BDD 执行 | `./gradlew cucumber` |
| `owasp/dependency-check` | PHASE_2_5 | Gradle 依赖漏洞扫描 | `./gradlew dependencyCheckAnalyze` |
| `semgrep` | PHASE_4 | 多语言静态分析 | `semgrep --config=auto` |
| `opencommit` | PHASE_3 | 自动生成 Conventional Commit | `opencommit` |
| `gatling` / `k6` | PHASE_5 | 韧性/性能测试 | `npx gatling` 或 `brew install k6` |
| `jacoco` | PHASE_5 | 覆盖率检查 | `./gradlew jacocoTestCoverageVerification` |
| `standard-version` | PHASE_6 | 自动版本和 CHANGELOG | `npx standard-version` |
| `BrainBank (bb)` | PHASE_6 / 全局 | 本地向量知识库索引与检索 | `bb index` / `bb query` |

## 自愈规则
- 若工具缺失，AI 必须通过 `[Skill: Tool-Auto-Loader]` 自动安装（如 `brew install semgrep`），不得绕过。