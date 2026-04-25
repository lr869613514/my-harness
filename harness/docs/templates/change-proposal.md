# Change Proposal: [简短变更标题]

> **文件命名规范**: `CP-<需求简述(≤10字)>-<YYYYMMDD>-<NNN>.md`
> **示例**: `CP-账单状态字段补充-20260425-001.md` | `CP-优惠券模块接入-20260425-001.md`
> **存放位置**: `.harness/docs/proposals/`

## 1. 变更元数据
- **提案 ID**: CP-<需求简述>-<YYYYMMDD>-<NNN>
- **关联需求**: [用户故事 ID，如 US-001]
- **提议者**: AI Architect
- **状态**: `draft / approved / implemented`

## 2. 变更动机
[用一句话描述为什么要做这个变更]
例：当前系统中订单创建未支持优惠券校验，需要接入优惠券服务。

## 3. 受影响的规格增量 (Spec Deltas)
### 3.1 API 契约变化
- **新增接口**: `POST /orders/{orderId}/apply-coupon`
- **修改接口**: `POST /orders` 的 `couponCode` 字段将从忽略改为生效
- **链接到相关 OpenAPI 文件**: `.harness/docs/specs/openapi.yaml`

### 3.2 数据模型变化
- **新增字段**: `Order` 聚合根增加 `discountAmount: Money`
- **新增表**: `order_coupons`（记录已用优惠券）

### 3.3 架构组件变化
- **新增领域服务**: `CouponDomainService.java` 负责校验优惠券
- **修改聚合根**: `Order` 增加关联优惠券逻辑

## 4. 兼容性与冲突分析
- **向后兼容**: 旧版客户端不传 `couponCode` 时，行为不变。
- **潜在冲突**: 无。

## 5. 回滚方案
[简述如果上线失败如何回滚]