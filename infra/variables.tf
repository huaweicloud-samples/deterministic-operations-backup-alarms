variable "region" {
  description = "华为云区域"
  type        = string
  default     = "cn-north-4"
}

variable "name_prefix" {
  description = "所有资源命名前缀，便于归属识别与批量清理"
  type        = string
  default     = "cbr-backup-alarms"
}

variable "email_endpoint" {
  description = "接收告警邮件的订阅地址（邮件订阅协议）"
  type        = string
}

variable "create_cbr_resources" {
  description = "是否创建示例 CBR 存储库与备份策略作为被监控对象。若账号内已有 CBR 资源，可设为 false，仅保留告警管线"
  type        = bool
  default     = true
}

variable "cbr_vault_type" {
  description = "CBR 存储库类型：server(云服务器备份) / disk(云硬盘备份) / turbo(SFS Turbo) / sfs(文件系统)"
  type        = string
  default     = "server"
}

variable "cbr_vault_size_gb" {
  description = "CBR 存储库容量(GB)"
  type        = number
  default     = 200
}

variable "backup_execution_time" {
  description = "每日备份执行时间，格式 HH:MM（华为云为 UTC+8）"
  type        = string
  default     = "06:00"
}
