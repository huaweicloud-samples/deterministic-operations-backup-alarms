# deterministic-operations-backup-alarms · 集中备份告警方案（华为云）

![License](https://img.shields.io/badge/License-MIT--0-blue)
![Huawei Cloud](https://img.shields.io/badge/Huawei%20Cloud-cn--north--4-red)
![Terraform](https://img.shields.io/badge/Terraform%20Validate-passing-brightgreen)

## 1. 简介 / Overview

### 简介


一套基于华为云的**集中备份告警**最佳实践：当云备份（CBR）的备份作业、副本作业或恢复任务执行失败时
自动通过邮件通知运维人员。

架构采用华为云原生的 **Cloud Eye 事件监控**（命名空间 `SYS.CBR`，事件如 `backupFailed` /
`replicationFailed` / `restorationFailed`）触发告警，经 **SMN** 消息通知服务发送邮件。
其中**基础设施**（KMS 客户密钥、CBR 存储库与备份策略、SMN 主题与邮件订阅）由 Terraform 声明管理；
**告警规则**（CBR 失败事件 → SMN）在 Cloud Eye 控制台创建——原因见下方「为什么告警规则不走 Terraform」。

适用对象：希望在单个华为云账号内统一监控备份健康度、及时发现备份失败的运维 / 云运营团队。

---

## 2. 目录

- [1. 简介 / Overview](#1-简介--overview)
- [2. 目录](#2-目录)
- [3. 架构图](#3-架构图)
- [4. 方案亮点](#4-方案亮点)
- [5. 涉及云服务](#5-涉及云服务)
- [6. 前置条件](#6-前置条件)
- [7. 快速开始](#7-快速开始)
- [8. 分步部署](#8-分步部署)
- [9. 使用方法 / 验证](#9-使用方法--验证)
- [10. 清理资源](#10-清理资源)
- [11. 详细说明](#11-详细说明)
- [12. 依赖](#12-依赖)
- [13. FAQ / 故障排除](#13-faq--故障排除)
- [14. 贡献指南](#14-贡献指南)
- [15. 许可证](#15-许可证)
- [16. 联系方式 / 维护者](#16-联系方式--维护者)

---

## 3. 架构图

```mermaid
flowchart LR
CBR[CBR 云备份] -->|失败事件 SYS.CBR| CES[Cloud Eye 事件监控告警]
CES -->|触发告警| SMN[SMN 主题 ${var.name_prefix}-alarm-topic]
SMN --> MAIL[(运维邮箱 ops@example.com)]
```

> 告警规则（CES 事件告警）在 Cloud Eye 控制台创建，详见 [`docs/deployment-guide.md`](docs/deployment-guide.md) 步骤 4。

---

## 4. 方案亮点

- **基础设施即代码**：KMS / CBR / SMN 全部由 Terraform 声明，可版本化管理、一键复现。
- **原生可靠**：告警采用华为云 Cloud Eye 事件监控（CBR 失败事件的官方暴露途径），零歧义、即时生效。
- **零自定义函数**：仅用 Cloud Eye + SMN 原生能力，无需维护任何运行时代码。

---

## 5. 涉及云服务

| 服务 | 用途 | 备注 |
|---|---|---|
| CBR | 云备份（被监控对象） | 备份/副本/恢复作业 |
| Cloud Eye | 事件监控告警（CBR 失败事件） | 控制台创建告警规则 |
| SMN | 邮件订阅通知 | 需收件人点击确认链接 |
| KMS | 客户托管密钥 | 显式创建 CMK |
| Terraform | IaC 声明基础设施 | 告警规则控制台创建 |

> **提示**：所有服务均可通过本仓库的 Terraform 一键创建；如需清理，请参见 [第 10 节「清理资源」](#10-清理资源)。

---

## 6. 前置条件

- 华为云账号（区域 `cn-north-4`），已开通 CBR / SMN / KMS / Cloud Eye。
- Terraform ≥ 1.0（本仓库用 provider v1.96.1 校验通过）。
- 具备上述服务创建权限；凭据通过环境变量提供（**不要写入代码或配置文件**）。
- 一个可接收告警的邮箱（本仓库示例：`ops@example.com`）。

---

## 7. 快速开始

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars # 填入 email_endpoint
# 导出凭据（禁止写入文件）：
export HW_ACCESS_KEY=<你的AK> HW_SECRET_KEY=<你的SK> HW_PROJECT_ID=<项目ID> HW_REGION_NAME=cn-north-4
terraform init
terraform plan
terraform apply
```

基础设施就绪后，**还需在 Cloud Eye 控制台创建告警规则**（详见 `docs/deployment-guide.md` 步骤 4）
整套方案才具备告警能力。

---

## 8. 分步部署

1. **准备凭据**：导出 `HW_ACCESS_KEY` / `HW_SECRET_KEY` / `HW_REGION_NAME` / `HW_PROJECT_ID`（仅环境变量）。
2. **初始化**：`cd infra && terraform init`（下载 huaweicloud provider）。
3. **预览**：`terraform plan -out=tfplan`，核对 KMS / CBR / SMN 资源清单。
4. **执行**：`terraform apply tfplan`，创建 KMS 客户密钥、CBR 策略与存储库、SMN 主题与邮件订阅。
5. **控制台告警规则**：按 `docs/deployment-guide.md` 步骤 4 在 Cloud Eye 控制台创建 CBR 失败事件告警规则，通知对象为刚创建的 SMN 主题。

---

## 9. 使用方法 / 验证

### 使用方法与验证


1. 登录 SMN 控制台，对 `${var.name_prefix}-alarm-topic` 的邮件订阅点击确认链接（或查收确认邮件）。
2. 登录 Cloud Eye 控制台 → 事件监控，确认已为 `SYS.CBR` 的 `backupFailed` /
`replicationFailed` / `restorationFailed` 创建告警规则，且通知对象为本 SMN 主题。
3. 手动触发一次备份失败（如暂停某资源后制造失败），确认运维邮箱收到告警邮件。

部署完成后请按本节步骤自行验证，确认业务功能可用，方可视为交付完成。

---

## 10. 清理资源

```bash
cd infra && terraform destroy
```

> 注意：`terraform destroy` 仅清理 Terraform 管理的基础设施（KMS / CBR / SMN）。
> Cloud Eye 控制台创建的告警规则需另行在控制台手动删除。

---

## 11. 详细说明

### 为什么告警规则不走 Terraform（诚实说明）


`huaweicloud` provider v1.96.1 对「事件 → 通知」两类能力支持不完整：

- **EG 事件网格**：CBR 失败事件不会自动进入 EG 自定义通道，必须经
`huaweicloud_eg_custom_event_source` 挂载 CBR 官方事件源，而其 `type` / `detail`
参数无可靠文档；盲跑部署能过但告警会静默不触发（等于没配）。
- **CES 事件告警**（`huaweicloud_ces_alarmrule`）：对事件类告警要求 `metric_name` /
资源维度名 / `filter` 等未文档化必填项，API 直接拒绝（`ces.0014`）。

因此告警规则采用控制台创建（官方原生、零歧义），而把 Terraform 留给稳定可自动化的基础设施部分。


- 架构与组件职责见 [`docs/architecture.md`](docs/architecture.md)。
- 部署步骤、访问密钥配置与验证见 [`docs/deployment-guide.md`](docs/deployment-guide.md)。

---

## 12. 依赖

完整架构与部署说明见 `docs/architecture.md` 与 `docs/deployment-guide.md`。

---

## 13. FAQ / 故障排除

### FAQ


**Q：一定要创建 CBR 存储库吗？**
A：不必。若账号内已有 CBR 资源，将 `create_cbr_resources` 设为 `false`，告警管线（SMN + 控制台告警规则）仍可监控现有 CBR 作业。

**Q：邮件一直收不到？**
A：先确认 SMN 邮件订阅已点击确认链接（未确认不投递）；再确认 Cloud Eye 控制台已创建对应告警规则且通知主题正确。

**Q：为什么不用 EG 事件网格？**
A：EG 自定义通道不会自动收到 CBR 官方事件，挂载官方源的参数在当前 provider 无可靠文档，盲跑等于没配。Cloud Eye 事件监控是 CBR 失败事件的官方、零歧义暴露途径，详见上文「为什么告警规则不走 Terraform」。

**Q：要不要多账号集中告警？**
A：单账号已实现完整能力。多账号聚合可扩展 EG 跨账号授权 + RFS StackSets。

---

## 14. 贡献指南

请通过 Issue 提交反馈与改进建议；本仓库不接受直接 PR，统一由维护者评审后合入。

---

## 15. 许可证

本实践采用 **MIT No Attribution** 许可证，详见仓库根目录 [`LICENSE`](LICENSE) 文件。


本项目以 MIT-0 许可证发布。

---

## 16. 联系方式 / 维护者
| 项 | 内容 |
|---|---|
| **创建者** | [dgc-git](https://github.com/dgc-git) |
| **维护者** | [dgc-git](https://github.com/dgc-git) |
| **联系方式** | GitHub Issues / PR（见[第 14 节](#14-贡献指南)） |
