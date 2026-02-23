aws_region   = "eu-central-1"
environment  = "dev"
project_name = "microservice-cloud"
vpc_cidr     = "10.30.0.0/16"

service_discovery_namespace = "svc.local"
enable_container_insights   = true
log_retention_days          = 7

# Container image URIs (ECR or Docker Hub)
auth_api_image    = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/auth-api:latest"
product_api_image = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/product-api:latest"
gateway_image     = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/gateway:latest"
ecommerce_image   = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/ecommerce:latest"

# Secrets
# Example: postgresql://user:password@host:5432/db?schema=public
auth_database_url    = ""
product_database_url = ""
jwt_secret           = ""

jwt_expires_in = "1h"
jwt_issuer     = "auth-service"
jwt_audience   = "api-services"

graphql_poll_interval_ms = 10000

# Optional public URLs (empty => ALB DNS auto-used)
public_app_url          = ""
next_public_graphql_url = ""

auth_api_desired_count    = 1
product_api_desired_count = 1
gateway_desired_count     = 1
ecommerce_desired_count   = 1

common_tags = {
  managed_by  = "terraform"
  project     = "microservice-cloud"
  environment = "dev"
}
