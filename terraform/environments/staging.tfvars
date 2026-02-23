aws_region   = "eu-central-1"
environment  = "staging"
project_name = "microservice-cloud"
vpc_cidr     = "10.40.0.0/16"

service_discovery_namespace = "svc.local"
enable_container_insights   = true
log_retention_days          = 14

auth_api_image    = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/auth-api:staging"
product_api_image = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/product-api:staging"
gateway_image     = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/gateway:staging"
ecommerce_image   = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/ecommerce:staging"

auth_database_url    = ""
product_database_url = ""
jwt_secret           = ""

jwt_expires_in = "1h"
jwt_issuer     = "auth-service"
jwt_audience   = "api-services"

graphql_poll_interval_ms = 10000

public_app_url          = ""
next_public_graphql_url = ""

auth_api_desired_count    = 2
product_api_desired_count = 2
gateway_desired_count     = 2
ecommerce_desired_count   = 2

common_tags = {
  managed_by  = "terraform"
  project     = "microservice-cloud"
  environment = "staging"
}
