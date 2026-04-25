# Skill: Brainstorming (需求分析)

## 来源
开源 Skills 框架：`/brainstorming` (属于 Superpowers 系列)

## 调用时机
在 PHASE_0_REQUIREMENTS，当用户给出模糊需求时。

## 使用方式
AI 在对话中直接声明“我将使用 `/brainstorming` 来细化需求”，然后向用户提问：
- 目标用户是谁？
- 核心痛点是什么？
- 期望的解决方案大致如何？
  经过 3-5 轮收敛后，输出结构化的用户故事和验收条件。