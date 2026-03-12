aws_region   = "eu-central-1"
environment  = "production"
project_name = "microservice-cloud"
vpc_cidr     = "10.50.0.0/16"

availability_zone_count            = 2
single_nat_gateway                 = false
service_discovery_namespace        = "svc.local"
enable_container_insights          = true
enable_enhanced_container_insights = true
enable_alb_access_logs             = true
alb_access_log_retention_days      = 30
log_retention_days                 = 30

auth_api_image    = "docker.io/your-dockerhub-namespace/auth-api:prod"
product_api_image = "docker.io/your-dockerhub-namespace/product-api:prod"
gateway_image     = "docker.io/your-dockerhub-namespace/gateway:prod"
ecommerce_image   = "docker.io/your-dockerhub-namespace/ecommerce:prod"

dockerhub_repository_credentials_secret_arn = ""

auth_database_url    = ""
product_database_url = ""
jwt_secret           = ""

jwt_expires_in            = "1h"
jwt_issuer                = "auth-service"
jwt_audience              = "api-services"
graphql_poll_interval_ms  = 10000
public_app_url            = ""
next_public_graphql_url   = ""
app_frontend_domain       = ""
cookie_secure             = ""
cookie_domain             = ""
loki_retention_period     = "336h"
loki_s3_retention_days    = 30
loki_cpu                  = 1024
loki_memory               = 2048
grafana_cpu               = 512
grafana_memory            = 1024

auth_api_desired_count             = 4
auth_api_min_count                 = 4
auth_api_max_count                 = 24
auth_api_cpu                       = 1024
auth_api_memory                    = 2048

product_api_desired_count          = 4
product_api_min_count              = 4
product_api_max_count              = 24
product_api_cpu                    = 1024
product_api_memory                 = 2048

gateway_desired_count              = 6
gateway_min_count                  = 6
gateway_max_count                  = 60
gateway_cpu                        = 1024
gateway_memory                     = 2048
gateway_request_count_target       = 1200

ecommerce_desired_count            = 6
ecommerce_min_count                = 6
ecommerce_max_count                = 40
ecommerce_cpu                      = 1024
ecommerce_memory                   = 2048
ecommerce_request_count_target     = 1000

common_tags = {
  team = "platform"
}
