# Skill: Code Simplifier (代码简化)

## 来源
开源 Skills 框架：`/code-simplifier` (Superpowers 系列)

## 调用时机
在 PHASE_4_REVIEW 静态审计通过后，可选执行。

## 使用方式
AI 针对某个类或方法，调用 `/code-simplifier` 命令，自动应用以下优化：
- 消除冗余变量
- 提取魔法值为常量
- 简化过于复杂的 Stream 链
- 保持功能完全不变
- 优化函数复杂度