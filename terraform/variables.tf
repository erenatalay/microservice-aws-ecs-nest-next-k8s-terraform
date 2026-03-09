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

variable "availability_zone_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ"
  type        = bool
  default     = true
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

variable "enable_enhanced_container_insights" {
  description = "Enable enhanced ECS Container Insights when supported"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_alb_access_logs" {
  description = "Enable ALB access logs"
  type        = bool
  default     = true
}

variable "alb_access_logs_prefix" {
  description = "S3 prefix for ALB access logs"
  type        = string
  default     = "alb"
}

variable "alb_access_log_retention_days" {
  description = "Retention period for ALB access logs"
  type        = number
  default     = 30
}

variable "dockerhub_repository_credentials_secret_arn" {
  description = "AWS Secrets Manager ARN for Docker Hub repository credentials"
  type        = string
  default     = ""
}

variable "loki_image" {
  description = "Container image for Loki"
  type        = string
  default     = "grafana/loki:3.6.0"
}

variable "grafana_image" {
  description = "Container image for Grafana"
  type        = string
  default     = "grafana/grafana:12.1"
}

variable "fluent_bit_image" {
  description = "Container image for Fluent Bit FireLens router"
  type        = string
  default     = "fluent/fluent-bit:4.2.2"
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

variable "jwt_refresh_secret" {
  description = "JWT refresh secret for auth-api"
  type        = string
  default     = ""
  sensitive   = true
}

variable "jwt_expires_in" {
  description = "JWT expiration duration"
  type        = string
  default     = "1h"
}

variable "jwt_refresh_expires_in" {
  description = "JWT refresh expiration duration"
  type        = string
  default     = "7d"
}

variable "password_reset_expires_in" {
  description = "Password reset token expiration duration"
  type        = string
  default     = "15m"
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

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true

  validation {
    condition     = trimspace(var.grafana_admin_password) != ""
    error_message = "grafana_admin_password must not be empty."
  }
}

variable "loki_retention_period" {
  description = "Loki retention period"
  type        = string
  default     = "168h"
}

variable "loki_s3_retention_days" {
  description = "S3 retention for Loki objects in days"
  type        = number
  default     = 30
}

variable "loki_ingestion_rate_mb" {
  description = "Loki ingestion rate limit in MB/sec"
  type        = number
  default     = 24
}

variable "loki_ingestion_burst_size_mb" {
  description = "Loki burst ingestion rate in MB"
  type        = number
  default     = 48
}

variable "graphql_poll_interval_ms" {
  description = "Apollo Gateway poll interval"
  type        = number
  default     = 10000
}

variable "public_app_url" {
  description = "Public base URL for the app"
  type        = string
  default     = ""
}

variable "next_public_graphql_url" {
  description = "Public GraphQL URL for ecommerce"
  type        = string
  default     = ""
}

variable "auth_api_cpu" {
  description = "Fargate CPU for auth-api"
  type        = number
  default     = 512
}

variable "auth_api_memory" {
  description = "Fargate memory in MB for auth-api"
  type        = number
  default     = 1024
}

variable "auth_api_desired_count" {
  description = "Desired task count for auth-api"
  type        = number
  default     = 2
}

variable "auth_api_min_count" {
  description = "Minimum task count for auth-api"
  type        = number
  default     = 2
}

variable "auth_api_max_count" {
  description = "Maximum task count for auth-api"
  type        = number
  default     = 20
}

variable "auth_api_cpu_target_utilization" {
  description = "Target CPU utilization for auth-api autoscaling"
  type        = number
  default     = 60
}

variable "auth_api_memory_target_utilization" {
  description = "Target memory utilization for auth-api autoscaling"
  type        = number
  default     = 70
}

variable "product_api_cpu" {
  description = "Fargate CPU for product-api"
  type        = number
  default     = 512
}

variable "product_api_memory" {
  description = "Fargate memory in MB for product-api"
  type        = number
  default     = 1024
}

variable "product_api_desired_count" {
  description = "Desired task count for product-api"
  type        = number
  default     = 2
}

variable "product_api_min_count" {
  description = "Minimum task count for product-api"
  type        = number
  default     = 2
}

variable "product_api_max_count" {
  description = "Maximum task count for product-api"
  type        = number
  default     = 20
}

variable "product_api_cpu_target_utilization" {
  description = "Target CPU utilization for product-api autoscaling"
  type        = number
  default     = 60
}

variable "product_api_memory_target_utilization" {
  description = "Target memory utilization for product-api autoscaling"
  type        = number
  default     = 70
}

variable "gateway_cpu" {
  description = "Fargate CPU for gateway"
  type        = number
  default     = 1024
}

variable "gateway_memory" {
  description = "Fargate memory in MB for gateway"
  type        = number
  default     = 2048
}

variable "gateway_desired_count" {
  description = "Desired task count for gateway"
  type        = number
  default     = 4
}

variable "gateway_min_count" {
  description = "Minimum task count for gateway"
  type        = number
  default     = 4
}

variable "gateway_max_count" {
  description = "Maximum task count for gateway"
  type        = number
  default     = 60
}

variable "gateway_cpu_target_utilization" {
  description = "Target CPU utilization for gateway autoscaling"
  type        = number
  default     = 55
}

variable "gateway_memory_target_utilization" {
  description = "Target memory utilization for gateway autoscaling"
  type        = number
  default     = 70
}

variable "gateway_request_count_target" {
  description = "ALB request count per target for gateway autoscaling"
  type        = number
  default     = 1200
}

variable "loki_cpu" {
  description = "Fargate CPU for Loki"
  type        = number
  default     = 512
}

variable "loki_memory" {
  description = "Fargate memory in MB for Loki"
  type        = number
  default     = 1024
}

variable "loki_desired_count" {
  description = "Desired task count for Loki"
  type        = number
  default     = 1
}

variable "ecommerce_cpu" {
  description = "Fargate CPU for ecommerce"
  type        = number
  default     = 1024
}

variable "ecommerce_memory" {
  description = "Fargate memory in MB for ecommerce"
  type        = number
  default     = 2048
}

variable "ecommerce_desired_count" {
  description = "Desired task count for ecommerce"
  type        = number
  default     = 4
}

variable "ecommerce_min_count" {
  description = "Minimum task count for ecommerce"
  type        = number
  default     = 4
}

variable "ecommerce_max_count" {
  description = "Maximum task count for ecommerce"
  type        = number
  default     = 40
}

variable "ecommerce_cpu_target_utilization" {
  description = "Target CPU utilization for ecommerce autoscaling"
  type        = number
  default     = 55
}

variable "ecommerce_memory_target_utilization" {
  description = "Target memory utilization for ecommerce autoscaling"
  type        = number
  default     = 70
}

variable "ecommerce_request_count_target" {
  description = "ALB request count per target for ecommerce autoscaling"
  type        = number
  default     = 1000
}

variable "grafana_cpu" {
  description = "Fargate CPU for Grafana"
  type        = number
  default     = 512
}

variable "grafana_memory" {
  description = "Fargate memory in MB for Grafana"
  type        = number
  default     = 1024
}

variable "grafana_desired_count" {
  description = "Desired task count for Grafana"
  type        = number
  default     = 1
}

variable "scale_in_cooldown_seconds" {
  description = "Scale in cooldown for ECS autoscaling"
  type        = number
  default     = 120
}

variable "scale_out_cooldown_seconds" {
  description = "Scale out cooldown for ECS autoscaling"
  type        = number
  default     = 60
}

variable "alb_target_response_time_alarm_threshold" {
  description = "Average ALB target response time alarm threshold in seconds"
  type        = number
  default     = 1.5
}

variable "alb_target_5xx_alarm_threshold" {
  description = "Target 5xx count alarm threshold"
  type        = number
  default     = 10
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
