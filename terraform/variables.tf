variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "microservices"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.30.0.0/16"
}

variable "service_discovery_namespace" {
  description = "Cloud Map private DNS namespace"
  type        = string
  default     = "svc.local"
}

variable "enable_container_insights" {
  description = "Enable ECS Container Insights"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "auth_api_image" {
  description = "Docker image URI for auth-api"
  type        = string
}

variable "product_api_image" {
  description = "Docker image URI for product-api"
  type        = string
}

variable "gateway_image" {
  description = "Docker image URI for gateway"
  type        = string
}

variable "ecommerce_image" {
  description = "Docker image URI for ecommerce"
  type        = string
}

variable "auth_database_url" {
  description = "Database URL for auth-api"
  type        = string
  sensitive   = true
}

variable "product_database_url" {
  description = "Database URL for product-api"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret used by services"
  type        = string
  sensitive   = true
}

variable "jwt_expires_in" {
  description = "JWT expiration duration"
  type        = string
  default     = "1h"
}

variable "jwt_issuer" {
  description = "JWT issuer"
  type        = string
  default     = "auth-service"
}

variable "jwt_audience" {
  description = "JWT audience"
  type        = string
  default     = "api-services"
}

variable "graphql_poll_interval_ms" {
  description = "Apollo Gateway poll interval"
  type        = number
  default     = 10000
}

variable "public_app_url" {
  description = "Public base URL for the app (optional)"
  type        = string
  default     = ""
}

variable "next_public_graphql_url" {
  description = "Public GraphQL URL for ecommerce (optional)"
  type        = string
  default     = ""
}

variable "auth_api_cpu" {
  description = "Fargate CPU for auth-api"
  type        = number
  default     = 256
}

variable "auth_api_memory" {
  description = "Fargate memory (MB) for auth-api"
  type        = number
  default     = 512
}

variable "product_api_cpu" {
  description = "Fargate CPU for product-api"
  type        = number
  default     = 256
}

variable "product_api_memory" {
  description = "Fargate memory (MB) for product-api"
  type        = number
  default     = 512
}

variable "gateway_cpu" {
  description = "Fargate CPU for gateway"
  type        = number
  default     = 256
}

variable "gateway_memory" {
  description = "Fargate memory (MB) for gateway"
  type        = number
  default     = 512
}

variable "ecommerce_cpu" {
  description = "Fargate CPU for ecommerce"
  type        = number
  default     = 512
}

variable "ecommerce_memory" {
  description = "Fargate memory (MB) for ecommerce"
  type        = number
  default     = 1024
}

variable "auth_api_desired_count" {
  description = "Desired task count for auth-api"
  type        = number
  default     = 1
}

variable "product_api_desired_count" {
  description = "Desired task count for product-api"
  type        = number
  default     = 1
}

variable "gateway_desired_count" {
  description = "Desired task count for gateway"
  type        = number
  default     = 1
}

variable "ecommerce_desired_count" {
  description = "Desired task count for ecommerce"
  type        = number
  default     = 1
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
