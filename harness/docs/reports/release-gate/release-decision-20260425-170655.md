# Release Decision Report
**生成时间**: 20260425-170655

| Gate | 检查项 | 结果 | 证据 |
|------|--------|------|------|
| G0 行为验证总门 | FAILED | ❌ | [查看](.harness/docs/reports/verification/gates-summary-20260425-170416.log) |
| G1 静态审计 | FAILED | ❌ | [查看]() |
| G2 Semgrep 语义扫描 | FAILED | ❌ | [查看](.harness/docs/reports/semgrep-20260425-165024.log) |
| G3 对抗性审查 | FAILED | ❌ | [查看]() |
| G4 安全扫描 | FAILED | ❌ | [查看](.harness/docs/reports/security-scan-20260425-165124.log) |
| G5 单元测试 | FAILED | ❌ | [查看]() |

---

## 最终裁定：🔴 **NO-GO** — 不满足发布条件

### 未通过的门：
- G0 行为验证总门
- G1 静态审计
- G2 Semgrep 语义扫描
- G3 对抗性审查
- G4 安全扫描
- G5 单元测试

请修复上述问题后重新运行发布门禁。
