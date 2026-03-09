aws_region   = "eu-central-1"
environment  = "dev"
project_name = "microservice-cloud"
vpc_cidr     = "10.60.0.0/16"

auth_api_image    = "docker.io/your-dockerhub-namespace/auth-api:latest"
product_api_image = "docker.io/your-dockerhub-namespace/product-api:latest"
gateway_image     = "docker.io/your-dockerhub-namespace/gateway:latest"
ecommerce_image   = "docker.io/your-dockerhub-namespace/ecommerce:latest"

dockerhub_repository_credentials_secret_arn = ""
auth_database_url                           = ""
product_database_url                        = ""
jwt_secret                                  = ""
loki_retention_period                       = "72h"
loki_s3_retention_days                      = 7
