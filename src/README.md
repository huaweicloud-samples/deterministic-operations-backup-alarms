# src/ 说明

本方案**无需任何自定义函数代码**。

告警管线采用「事件过滤 + 投递」的纯配置驱动方式，由 **EG 事件网格（事件通道 + 事件订阅）** 与 **SMN 主题** 原生承担，
全部由 Terraform 声明式配置描述，落在 `../infra/`：

- `infra/main.tf` — EG 自定义事件通道 + 三条 EG 事件订阅（备份作业失败 / 副本作业失败 / 配置变更）→ SMN 目标
- `infra/variables.tf` / `outputs.tf` / `provider.tf` / `versions.tf`

因此本目录不放 FunctionGraph 函数或前端代码；如后续需要：
- 对告警内容做富化 / 格式化（自定义邮件正文），可新增一个 **FunctionGraph** 函数作为 EG 订阅目标（前置处理 SMN 通知）；
- 对接外部工单 / IM（如飞书、钉钉），可在 EG 订阅目标链路中插入 FunctionGraph 调用对应 Webhook。

上述扩展均为可选增强，不在本次实现范围内。
