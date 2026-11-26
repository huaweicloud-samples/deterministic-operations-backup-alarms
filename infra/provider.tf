# 华为云 Provider 配置
# 凭据通过环境变量注入：
#   export HW_ACCESS_KEY=<HW_ACCESS_KEY>
#   export HW_SECRET_KEY=<HW_SECRET_KEY>
#   export HW_REGION_NAME=cn-north-4
#   export HW_PROJECT_ID=<你的项目ID>
# 也可使用 securitytoken 临时凭证：HW_SECURITY_TOKEN
provider "huaweicloud" {
  region = var.region
}
