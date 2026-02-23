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

output "service_endpoints_internal" {
  description = "Internal service discovery URLs"
  value = {
    auth_api    = "http://auth-api.${var.service_discovery_namespace}:3001"
    product_api = "http://product-api.${var.service_discovery_namespace}:3002"
    gateway     = "http://gateway.${var.service_discovery_namespace}:4000"
    ecommerce   = "http://ecommerce.${var.service_discovery_namespace}:3000"
  }
}
