aws_region   = "eu-central-1"
environment  = "dev"
project_name = "microservice-cloud"
vpc_cidr     = "10.60.0.0/16"

auth_api_image    = "auth-api:latest"
product_api_image = "product-api:latest"
gateway_image     = "gateway:latest"
ecommerce_image   = "ecommerce:latest"

auth_database_url    = ""
product_database_url = ""
jwt_secret           = ""
