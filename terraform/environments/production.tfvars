aws_region   = "eu-central-1"
environment  = "production"
project_name = "microservice-cloud"
vpc_cidr     = "10.50.0.0/16"

service_discovery_namespace = "svc.local"
enable_container_insights   = true
log_retention_days          = 30

auth_api_image    = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/auth-api:prod"
product_api_image = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/product-api:prod"
gateway_image     = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/gateway:prod"
ecommerce_image   = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/ecommerce:prod"

auth_database_url    = ""
product_database_url = ""
jwt_secret           = ""

jwt_expires_in = "1h"
jwt_issuer     = "auth-service"
jwt_audience   = "api-services"

graphql_poll_interval_ms = 10000

# Production'da custom domain kullanıyorsan doldur
public_app_url          = ""
next_public_graphql_url = ""

auth_api_desired_count    = 2
product_api_desired_count = 2
gateway_desired_count     = 2
ecommerce_desired_count   = 2

auth_api_cpu    = 512
auth_api_memory = 1024

product_api_cpu    = 512
product_api_memory = 1024

gateway_cpu    = 512
gateway_memory = 1024

ecommerce_cpu    = 1024
ecommerce_memory = 2048

common_tags = {
  managed_by  = "terraform"
  project     = "microservice-cloud"
  environment = "production"
  team        = "platform"
}
