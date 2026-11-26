# ============================================================================
# 集中备份告警方案 —— 华为云 Terraform 实现（单账号）
# 业务能力：CBR 备份/副本/恢复失败 → 邮件告警
#
# 分工（重要）：
#   - Terraform 负责「基础设施」：KMS 客户密钥、CBR 存储库+备份策略（被监控对象）、
#     SMN 主题+邮件订阅（通知入口）。这部分已验证可稳定 apply。
#   - 「CBR 失败事件 → SMN 邮件」的告警规则，在 Cloud Eye 控制台创建，
#     详见 docs/deployment-guide.md 的步骤 4。
#
# 为什么告警规则不走 Terraform（诚实说明）：
#   huaweicloud provider v1.96.1 对「事件→通知」两类能力支持不完整——
#   ① EG 事件网格：CBR 失败事件不会自动进入 EG 自定义通道，必须经
#      huaweicloud_eg_custom_event_source 挂载 CBR 官方源，而其 type/detail
#      参数无可靠文档，盲跑部署能过但告警静默不触发；
#   ② CES 事件告警（huaweicloud_ces_alarmrule）：对事件类告警要求
#      metric_name / 资源维度名 / filter 等未文档化必填项，API 直接拒绝（ces.0014）。
#   因此告警规则采用华为云原生的 Cloud Eye 事件监控控制台创建，零歧义、立刻可用。
# ============================================================================

# ----------------------------------------------------------------------------
# 0. 客户托管密钥
#    华为云 SMN 主题 / CBR 存储库在当前 provider 版本未暴露「绑定客户 KMS 密钥」
#    的 Terraform 属性，服务侧默认使用华为云服务托管密钥加密。
#    此处显式创建 CMK，作为本备份告警方案的客户密钥资产。
# ----------------------------------------------------------------------------
resource "huaweicloud_kms_key" "this" {
  key_alias       = "${var.name_prefix}-cmk"
  key_description = "集中备份告警方案的客户托管密钥(CMK)"
}

# ----------------------------------------------------------------------------
# 1. 被监控对象：CBR 存储库 + 备份策略
#    可选：账号内已有 CBR 资源时可关闭，告警管线不受影响。
# ----------------------------------------------------------------------------
resource "huaweicloud_cbr_policy" "this" {
  count = var.create_cbr_resources ? 1 : 0

  name    = "${var.name_prefix}-policy"
  type    = "backup"
  enabled = true

  backup_cycle {
    # interval=1 表示每天执行（days 为按周，二者至少填其一）
    interval         = 1
    execution_times = [var.backup_execution_time]
  }
}

resource "huaweicloud_cbr_vault" "this" {
  count = var.create_cbr_resources ? 1 : 0

  name            = "${var.name_prefix}-vault"
  type            = var.cbr_vault_type
  protection_type = "backup"
  size            = var.cbr_vault_size_gb

  policy {
    id = huaweicloud_cbr_policy.this[0].id
  }
}

# ----------------------------------------------------------------------------
# 2. 通知层：SMN 主题 + 邮件订阅
#    告警规则（Cloud Eye 控制台创建）触发后，向本主题推送邮件通知。
# ----------------------------------------------------------------------------
resource "huaweicloud_smn_topic" "this" {
  name         = "${var.name_prefix}-alarm-topic"
  display_name = "集中备份告警"
  introduction = "集中接收 CBR 备份/副本/恢复失败告警（规则在 Cloud Eye 控制台创建）"
}

resource "huaweicloud_smn_subscription" "email" {
  topic_urn = huaweicloud_smn_topic.this.topic_urn
  protocol  = "email"
  endpoint  = var.email_endpoint
  remark    = "备份告警邮件订阅（需收件人点击确认链接后生效）"
  # status 为服务侧计算值（待确认=0，已确认=1），不在配置中，天然不会被回滚
}
