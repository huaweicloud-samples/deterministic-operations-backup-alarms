output "smn_topic_urn" {
  description = "SMN 主题 URN（邮件告警入口；告警规则在 Cloud Eye 控制台创建）"
  value       = huaweicloud_smn_topic.this.topic_urn
}

output "kms_key_id" {
  description = "客户托管密钥 ID（CMK）"
  value       = huaweicloud_kms_key.this.key_id
}

output "cbr_vault_id" {
  description = "CBR 存储库 ID（create_cbr_resources=true 时创建）"
  value       = var.create_cbr_resources ? huaweicloud_cbr_vault.this[0].id : null
}
