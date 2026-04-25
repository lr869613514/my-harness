# 🎨 Java 8 Coding Aesthetics & Tactical DDD

## 核心约束
- 禁止使用 Java 9+ 特性（var, record, 文本块等）
- 所有 Java EE API 使用 `javax.*` 命名空间，严禁 `jakarta.*`
- 构建工具: Maven，Spring Boot 2.7.x

## 代码美学
- Optional 护航：所有单对象返回用 `Optional`，禁止 `if (obj != null)`
- Stream 规范：3 个以上操作必须换行对齐点号
- MapStruct 强制：所有 Entity ↔ DTO 转换必须使用 MapStruct 接口
- 异常分级：ClientException, BusinessException, SystemException
- 统一响应：Controller 返回 `Result<T>`
- 禁止 `BeanUtils.copyProperties`

## 战术 DDD
- 聚合根模式，值对象（VO）替代基本类型
- 领域服务处理跨实体逻辑

## 技术与债务标记
- 允许战略性 `// [TECH-DEBT]` 注释，但必须附加任务 ID