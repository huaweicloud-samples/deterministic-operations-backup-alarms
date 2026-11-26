# 部署指导书

## 一、前置条件

| 项目 | 要求 |
|------|------|
| 华为云账号 | 已开通 CBR、SMN、KMS、Cloud Eye 服务（华东北京四 `cn-north-4` 或目标区域） |
| 权限 | 具备上述服务的创建 / 修改权限 |
| 工具 | Terraform ≥ 1.0（本仓库已在 `cn-north-4` 用 provider v1.96.1 校验通过） |
| 凭据 | 通过环境变量注入，**禁止硬编码**（见 §四） |
| 邮箱 | 一个可接收告警的邮箱（示例：`ops@example.com`） |

## 二、快速开始

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars # 填入 email_endpoint
terraform init
terraform plan # 预览资源
terraform apply # 创建基础设施
```

> `terraform apply` 仅创建**基础设施**（KMS / CBR / SMN）。告警规则需在 Cloud Eye 控制台创建，见 §五步骤 4。

## 四、访问密钥配置

```bash
export HW_ACCESS_KEY=<HW_ACCESS_KEY>
export HW_SECRET_KEY=<HW_SECRET_KEY>
export HW_REGION_NAME=cn-north-4
export HW_PROJECT_ID=<你的项目ID>
# 如使用临时凭证：
export HW_SECURITY_TOKEN=<TOKEN>
```

AK/SK 请通过环境变量注入，不要写入 `*.tf` 或 `terraform.tfvars`。

## 五、验证步骤

1. **邮件订阅确认**（必做）：`apply` 后登录 SMN 控制台，对 `${var.name_prefix}-alarm-topic` 的邮件订阅点击确认链接（或收件人查收确认邮件）。未确认前不会收到任何告警。
2. **创建 Cloud Eye 事件告警规则**（核心，控制台操作）：
1. 进入 **云监控 Cloud Eye 控制台 → 事件监控**。
2. 在事件列表中找到 **云备份 CBR（SYS.CBR）**，对以下事件逐条点击「操作 → 创建告警规则」（或在「创建告警规则」界面手动指定）：
- `backupFailed`（创建备份失败）
- `replicationFailed`（复制失败）
- `restorationFailed`（使用备份恢复资源失败）
3. 告警规则参数建议：
- 告警类型：事件（系统事件）
- 事件来源：`SYS.CBR`（云备份）
- 触发方式：关联模板 / 自定义均可，级别选「紧急」
- **告警通知**：勾选「发送通知」，通知对象选择 SMN 主题 **`${var.name_prefix}-alarm-topic`**
4. 保存。三条规则创建完成后，任何 CBR 备份 / 副本 / 恢复失败都会向该主题推送邮件。
3. **端到端验证**：手动触发一次备份失败（如临时断开某绑定资源的备份路径制造失败），确认运维邮箱收到告警邮件。

> 关于「为什么告警规则不在 Terraform 里」：详见 README「为什么告警规则不走 Terraform」。
> 简言之，`huaweicloud` provider v1.96.1 对 EG 官方 CBR 源挂载、CES 事件告警的 Terraform 支持不完整
> 控制台创建是官方原生、零歧义的可靠路径。

## 六、清理资源

```bash
cd infra
terraform destroy # 释放 Terraform 管理的基础设施（KMS / CBR / SMN）
```

> 注意：`terraform destroy` **不会**删除 Cloud Eye 控制台创建的告警规则。
> 废弃整套方案时，请另到 Cloud Eye 控制台手动删除 `SYS.CBR` 的告警规则。
