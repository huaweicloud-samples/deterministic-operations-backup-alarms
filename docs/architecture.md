# 集中备份告警方案 · 架构说明

## 方案概述

本方案实现**集中备份告警**：当云备份（CBR）的备份作业、副本作业或恢复任务执行失败时
自动通过邮件通知运维人员，第一时间发现备份异常。

方案采用华为云原生的 **Cloud Eye 事件监控** 捕获 CBR 失败事件，经 **SMN** 消息通知服务发送邮件。

## 组件与职责

| 组件 | 华为云服务 | 职责 |
|------|-----------|------|
| 事件监控 | Cloud Eye 事件监控（`SYS.CBR`） | 捕获 CBR 失败类事件（`backupFailed` / `replicationFailed` / `restorationFailed`） |
| 告警规则 | Cloud Eye 事件告警（控制台创建） | 事件触发后推送通知 |
| 通知主题 | SMN 主题 + 邮件订阅 | 将告警以邮件形式投递给运维邮箱 |
| 备份资源 | CBR 云备份（存储库 + 备份策略） | 产生备份 / 副本 / 恢复作业事件（被监控对象，可选创建） |
| 密钥 | KMS 密钥 | 本方案的客户托管密钥（CMK） |

> **Terraform 与控制台分工**：KMS / CBR / SMN 由 Terraform 管理；Cloud Eye 告警规则在控制台创建
> （原因见 README「为什么告警规则不走 Terraform」：`huaweicloud` provider v1.96.1 对 EG 官方 CBR 源挂载
> CES 事件告警的 Terraform 支持不完整）。

## 架构图

```mermaid
flowchart LR
CBR[CBR 云备份<br/>备份/副本/恢复作业]
CES[Cloud Eye 事件监控<br/>SYS.CBR]
RULE[事件告警规则<br/>（控制台创建）]
SMN[SMN 主题<br/>${var.name_prefix}-alarm-topic]
MAIL[(运维邮箱 ops@example.com)]

CBR -->|失败事件 backupFailed 等| CES
CES --> RULE -->|触发通知| SMN
SMN --> MAIL
```

## 事件流

1. **备份/副本/恢复失败**：CBR 在 Cloud Eye 事件监控中上报 `SYS.CBR` 命名空间下的失败事件
（`backupFailed` / `replicationFailed` / `restorationFailed`）。
2. **事件告警触发**：控制台创建的对应事件告警规则匹配到事件，触发告警动作。
3. **通知**：告警动作向 SMN 主题 `${var.name_prefix}-alarm-topic` 推送消息，SMN 通过邮件订阅发送给运维邮箱。

## 设计要点

- **单账号实现**：所有资源部署在同一华为云账号与区域内，告警管线集中在账号内闭环。
- **多账号扩展能力**：EG 自定义事件通道支持 `cross_account_ids` 跨账号授权，可用于中心账号聚合多成员账号事件。
- **解耦与可演进**：新增告警类型（如 `vaultDeleteFailed`）只需在 Cloud Eye 控制台追加一条事件告警规则，无需改动 Terraform 管理的通知层。
