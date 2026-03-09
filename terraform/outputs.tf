output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "alb_dns_name" {
  description = "Public ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "public_app_url" {
  description = "Public URL for ecommerce app"
  value       = local.public_app_url
}

output "public_graphql_url" {
  description = "Public GraphQL URL"
  value       = local.public_graphql_url
}

output "cloud_map_namespace" {
  description = "Cloud Map namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "cloudwatch_log_group_name" {
  description = "Shared CloudWatch log group for platform, FireLens, Loki and Grafana logs"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "cloudwatch_dashboard_name" {
  description = "Operations dashboard name"
  value       = aws_cloudwatch_dashboard.operations.dashboard_name
}

output "alb_access_logs_bucket_name" {
  description = "S3 bucket name for ALB access logs"
  value       = var.enable_alb_access_logs ? aws_s3_bucket.alb_access_logs[0].bucket : null
}

output "grafana_url" {
  description = "Public URL for Grafana"
  value       = "${local.public_app_url}/grafana"
}

output "loki_bucket_name" {
  description = "S3 bucket used by Loki for long-term log storage"
  value       = aws_s3_bucket.loki.bucket
}

output "loki_internal_url" {
  description = "Internal Loki push/query endpoint"
  value       = "http://loki.${var.service_discovery_namespace}:3100"
}

output "service_endpoints_internal" {
  description = "Internal service discovery URLs"
  value = {
    auth_api    = "http://auth-api.${var.service_discovery_namespace}:3001"
    product_api = "http://product-api.${var.service_discovery_namespace}:3002"
    gateway     = "http://gateway.${var.service_discovery_namespace}:4000"
    ecommerce   = "http://ecommerce.${var.service_discovery_namespace}:3000"
    grafana     = "http://grafana.${var.service_discovery_namespace}:3000"
    loki        = "http://loki.${var.service_discovery_namespace}:3100"
  }
}
