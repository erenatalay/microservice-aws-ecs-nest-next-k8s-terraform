aws_region   = "eu-central-1"
environment  = "dev"
project_name = "microservice-cloud"
vpc_cidr     = "10.30.0.0/16"

availability_zone_count            = 2
single_nat_gateway                 = true
service_discovery_namespace        = "svc.local"
enable_container_insights          = true
enable_enhanced_container_insights = true
enable_alb_access_logs             = true
alb_access_log_retention_days      = 7
log_retention_days                 = 7

auth_api_image    = "docker.io/your-dockerhub-namespace/auth-api:latest"
product_api_image = "docker.io/your-dockerhub-namespace/product-api:latest"
gateway_image     = "docker.io/your-dockerhub-namespace/gateway:latest"
ecommerce_image   = "docker.io/your-dockerhub-namespace/ecommerce:latest"

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
loki_retention_period     = "72h"
loki_s3_retention_days    = 7
loki_cpu                  = 512
loki_memory               = 1024
grafana_cpu               = 512
grafana_memory            = 1024

auth_api_desired_count             = 2
auth_api_min_count                 = 2
auth_api_max_count                 = 6
auth_api_cpu                       = 512
auth_api_memory                    = 1024

product_api_desired_count          = 2
product_api_min_count              = 2
product_api_max_count              = 6
product_api_cpu                    = 512
product_api_memory                 = 1024

gateway_desired_count              = 2
gateway_min_count                  = 2
gateway_max_count                  = 10
gateway_cpu                        = 1024
gateway_memory                     = 2048
gateway_request_count_target       = 800

ecommerce_desired_count            = 2
ecommerce_min_count                = 2
ecommerce_max_count                = 8
ecommerce_cpu                      = 1024
ecommerce_memory                   = 2048
ecommerce_request_count_target     = 700

common_tags = {
  managed_by  = "terraform"
  project     = "microservice-cloud"
  environment = "dev"
}
