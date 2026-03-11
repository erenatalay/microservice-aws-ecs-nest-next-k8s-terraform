provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.common_tags
  )

  azs                  = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)
  nat_gateway_count    = var.single_nat_gateway ? 1 : length(local.azs)
  public_subnet_cidrs  = [for index in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 4, index)]
  private_subnet_cidrs = [for index in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 4, index + length(local.azs))]

  alb_access_logs_bucket_name = trimsuffix(
    substr(
      lower(
        replace(
          "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-alb-logs",
          "_",
          "-"
        )
      ),
      0,
      63
    ),
    "-"
  )

  container_insights_value = var.enable_container_insights ? (
    var.enable_enhanced_container_insights ? "enhanced" : "enabled"
  ) : "disabled"

  use_dockerhub_credentials = trimspace(var.dockerhub_repository_credentials_secret_arn) != ""

  public_app_url = trimspace(var.public_app_url) != "" ? trimspace(var.public_app_url) : "http://${aws_lb.main.dns_name}"
  public_graphql_url = trimspace(var.next_public_graphql_url) != "" ? trimspace(var.next_public_graphql_url) : "${local.public_app_url}/graphql"
  app_frontend_domain = trimspace(var.app_frontend_domain) != "" ? trimspace(var.app_frontend_domain) : local.public_app_url
  cookie_secure_value = trimspace(var.cookie_secure) != "" ? trimspace(var.cookie_secure) : (startswith(local.public_app_url, "https://") ? "true" : "false")
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Tier = "private"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(local.azs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "main" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  count = length(local.azs)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count = length(local.azs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_s3_bucket" "alb_access_logs" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = local.alb_access_logs_bucket_name

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb-access-logs"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_access_logs" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_access_logs" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_access_logs" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_access_logs[0].id

  rule {
    id     = "expire-old-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.alb_access_log_retention_days
    }
  }
}

resource "aws_s3_bucket_policy" "alb_access_logs" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_access_logs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowALBLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_access_logs[0].arn
      },
      {
        Sid    = "AllowALBLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_access_logs[0].arn}/${var.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      }
    ]
  })
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "ECS tasks security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Gateway from ALB"
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Ecommerce from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Service-to-service communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_lb" "main" {
  name                       = replace(substr("${local.name_prefix}-alb", 0, 32), "_", "-")
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [for subnet in aws_subnet.public : subnet.id]
  drop_invalid_header_fields = true
  idle_timeout               = 120

  dynamic "access_logs" {
    for_each = var.enable_alb_access_logs ? [1] : []
    content {
      bucket  = aws_s3_bucket.alb_access_logs[0].bucket
      prefix  = var.alb_access_logs_prefix
      enabled = true
    }
  }

  tags = local.tags
}

resource "aws_lb_target_group" "gateway" {
  name                          = replace(substr("${local.name_prefix}-gtw", 0, 32), "_", "-")
  port                          = 4000
  protocol                      = "HTTP"
  target_type                   = "ip"
  vpc_id                        = aws_vpc.main.id
  deregistration_delay          = 30
  load_balancing_algorithm_type = "least_outstanding_requests"

  health_check {
    path                = "/"
    matcher             = "200-499"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 20
  }

  tags = local.tags
}

resource "aws_lb_target_group" "ecommerce" {
  name                          = replace(substr("${local.name_prefix}-ecom", 0, 32), "_", "-")
  port                          = 3000
  protocol                      = "HTTP"
  target_type                   = "ip"
  vpc_id                        = aws_vpc.main.id
  deregistration_delay          = 30
  load_balancing_algorithm_type = "least_outstanding_requests"

  health_check {
    path                = "/"
    matcher             = "200-499"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 20
  }

  tags = local.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecommerce.arn
  }
}

resource "aws_lb_listener_rule" "gateway_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }

  condition {
    path_pattern {
      values = ["/api*", "/graphql*"]
    }
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-ecs"

  setting {
    name  = "containerInsights"
    value = local.container_insights_value
  }

  tags = local.tags
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = var.service_discovery_namespace
  vpc  = aws_vpc.main.id

  tags = local.tags
}

resource "aws_service_discovery_service" "auth_api" {
  name = "auth-api"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "product_api" {
  name = "product-api"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "gateway" {
  name = "gateway"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "ecommerce" {
  name = "ecommerce"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

resource "aws_iam_role" "ecs_execution" {
  name = "${local.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_dockerhub_secret" {
  count = local.use_dockerhub_credentials ? 1 : 0

  name = "${local.name_prefix}-dockerhub-secret"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.dockerhub_repository_credentials_secret_arn
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_ecs_task_definition" "auth_api" {
  family                   = "${local.name_prefix}-auth-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.auth_api_cpu
  memory                   = var.auth_api_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    local.firelens_log_router_container,
    merge(
      {
        name      = "auth-api"
        image     = var.auth_api_image
        essential = true
        portMappings = [
          {
            containerPort = 3001
            hostPort      = 3001
            protocol      = "tcp"
          }
        ]
        dependsOn = [
          {
            containerName = "log-router"
            condition     = "START"
          }
        ]
        environment = [
          { name = "NODE_ENV", value = "production" },
          { name = "PORT", value = "3001" },
          { name = "API_PORT", value = "3001" },
          { name = "API_GLOBAL_PREFIX", value = "api" },
          { name = "DATABASE_URL", value = var.auth_database_url },
          { name = "JWT_SECRET", value = var.jwt_secret },
          { name = "JWT_REFRESH_SECRET", value = trimspace(var.jwt_refresh_secret) != "" ? var.jwt_refresh_secret : var.jwt_secret },
          { name = "JWT_EXPIRES_IN", value = var.jwt_expires_in },
          { name = "JWT_REFRESH_EXPIRES_IN", value = var.jwt_refresh_expires_in },
          { name = "PASSWORD_RESET_EXPIRES_IN", value = var.password_reset_expires_in },
          { name = "JWT_ISSUER", value = var.jwt_issuer },
          { name = "JWT_AUDIENCE", value = var.jwt_audience },
          { name = "APP_FRONTEND_DOMAIN", value = local.app_frontend_domain },
          { name = "CORS_ORIGIN", value = local.public_app_url },
          { name = "CORS_ORIGIN_LOCAL", value = "http://localhost:3000" }
        ]
        logConfiguration = {
          logDriver = "awsfirelens"
          options = {
            Name            = "loki"
            host            = "loki.${var.service_discovery_namespace}"
            port            = "3100"
            labels          = "service=auth-api,environment=${var.environment},project=${var.project_name}"
            remove_keys     = local.firelens_remove_keys
            drop_single_key = "raw"
            line_format     = "json"
          }
        }
      },
      local.use_dockerhub_credentials ? {
        repositoryCredentials = {
          credentialsParameter = var.dockerhub_repository_credentials_secret_arn
        }
      } : {}
    )
  ])

  tags = local.tags
}

resource "aws_ecs_task_definition" "product_api" {
  family                   = "${local.name_prefix}-product-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.product_api_cpu
  memory                   = var.product_api_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    local.firelens_log_router_container,
    merge(
      {
        name      = "product-api"
        image     = var.product_api_image
        essential = true
        portMappings = [
          {
            containerPort = 3002
            hostPort      = 3002
            protocol      = "tcp"
          }
        ]
        dependsOn = [
          {
            containerName = "log-router"
            condition     = "START"
          }
        ]
        environment = [
          { name = "NODE_ENV", value = "production" },
          { name = "PORT", value = "3002" },
          { name = "API_PORT", value = "3002" },
          { name = "API_GLOBAL_PREFIX", value = "api" },
          { name = "DATABASE_URL", value = var.product_database_url },
          { name = "JWT_SECRET", value = var.jwt_secret },
          { name = "AUTH_SERVICE_URL", value = "http://auth-api.${var.service_discovery_namespace}:3001" },
          { name = "JWT_ISSUER", value = var.jwt_issuer },
          { name = "JWT_AUDIENCE", value = var.jwt_audience },
          { name = "CORS_ORIGIN", value = local.public_app_url },
          { name = "CORS_ORIGIN_LOCAL", value = "http://localhost:3000" }
        ]
        logConfiguration = {
          logDriver = "awsfirelens"
          options = {
            Name            = "loki"
            host            = "loki.${var.service_discovery_namespace}"
            port            = "3100"
            labels          = "service=product-api,environment=${var.environment},project=${var.project_name}"
            remove_keys     = local.firelens_remove_keys
            drop_single_key = "raw"
            line_format     = "json"
          }
        }
      },
      local.use_dockerhub_credentials ? {
        repositoryCredentials = {
          credentialsParameter = var.dockerhub_repository_credentials_secret_arn
        }
      } : {}
    )
  ])

  tags = local.tags
}

resource "aws_ecs_task_definition" "gateway" {
  family                   = "${local.name_prefix}-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.gateway_cpu
  memory                   = var.gateway_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    local.firelens_log_router_container,
    merge(
      {
        name      = "gateway"
        image     = var.gateway_image
        essential = true
        portMappings = [
          {
            containerPort = 4000
            hostPort      = 4000
            protocol      = "tcp"
          }
        ]
        dependsOn = [
          {
            containerName = "log-router"
            condition     = "START"
          }
        ]
        environment = [
          { name = "NODE_ENV", value = "production" },
          { name = "PORT", value = "4000" },
          { name = "AUTH_GRAPHQL_URL", value = "http://auth-api.${var.service_discovery_namespace}:3001/api/graphql" },
          { name = "PRODUCT_GRAPHQL_URL", value = "http://product-api.${var.service_discovery_namespace}:3002/api/graphql" },
          { name = "GRAPHQL_POLL_INTERVAL", value = tostring(var.graphql_poll_interval_ms) }
        ]
        logConfiguration = {
          logDriver = "awsfirelens"
          options = {
            Name            = "loki"
            host            = "loki.${var.service_discovery_namespace}"
            port            = "3100"
            labels          = "service=gateway,environment=${var.environment},project=${var.project_name}"
            remove_keys     = local.firelens_remove_keys
            drop_single_key = "raw"
            line_format     = "json"
          }
        }
      },
      local.use_dockerhub_credentials ? {
        repositoryCredentials = {
          credentialsParameter = var.dockerhub_repository_credentials_secret_arn
        }
      } : {}
    )
  ])

  tags = local.tags
}

resource "aws_ecs_task_definition" "ecommerce" {
  family                   = "${local.name_prefix}-ecommerce"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecommerce_cpu
  memory                   = var.ecommerce_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    local.firelens_log_router_container,
    merge(
      {
        name      = "ecommerce"
        image     = var.ecommerce_image
        essential = true
        portMappings = [
          {
            containerPort = 3000
            hostPort      = 3000
            protocol      = "tcp"
          }
        ]
        dependsOn = [
          {
            containerName = "log-router"
            condition     = "START"
          }
        ]
        environment = [
          { name = "NODE_ENV", value = "production" },
          { name = "PORT", value = "3000" },
          { name = "HOSTNAME", value = "0.0.0.0" },
          { name = "COOKIE_SECURE", value = local.cookie_secure_value },
          { name = "COOKIE_DOMAIN", value = var.cookie_domain },
          { name = "INTERNAL_GRAPHQL_URL", value = "http://gateway.${var.service_discovery_namespace}:4000/graphql" },
          { name = "NEXT_PUBLIC_GRAPHQL_URL", value = local.public_graphql_url }
        ]
        logConfiguration = {
          logDriver = "awsfirelens"
          options = {
            Name            = "loki"
            host            = "loki.${var.service_discovery_namespace}"
            port            = "3100"
            labels          = "service=ecommerce,environment=${var.environment},project=${var.project_name}"
            remove_keys     = local.firelens_remove_keys
            drop_single_key = "raw"
            line_format     = "json"
          }
        }
      },
      local.use_dockerhub_credentials ? {
        repositoryCredentials = {
          credentialsParameter = var.dockerhub_repository_credentials_secret_arn
        }
      } : {}
    )
  ])

  tags = local.tags
}

resource "aws_ecs_service" "auth_api" {
  name                               = "${local.name_prefix}-auth-api"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.auth_api.arn
  desired_count                      = var.auth_api_desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [for subnet in aws_subnet.private : subnet.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.auth_api.arn
  }

  tags = local.tags
}

resource "aws_ecs_service" "product_api" {
  name                               = "${local.name_prefix}-product-api"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.product_api.arn
  desired_count                      = var.product_api_desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [for subnet in aws_subnet.private : subnet.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.product_api.arn
  }

  depends_on = [aws_ecs_service.auth_api]

  tags = local.tags
}

resource "aws_ecs_service" "gateway" {
  name                               = "${local.name_prefix}-gateway"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.gateway.arn
  desired_count                      = var.gateway_desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 60

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [for subnet in aws_subnet.private : subnet.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.gateway.arn
    container_name   = "gateway"
    container_port   = 4000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.gateway.arn
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener_rule.gateway_api,
    aws_ecs_service.auth_api,
    aws_ecs_service.product_api
  ]

  tags = local.tags
}

resource "aws_ecs_service" "ecommerce" {
  name                               = "${local.name_prefix}-ecommerce"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.ecommerce.arn
  desired_count                      = var.ecommerce_desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 60

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [for subnet in aws_subnet.private : subnet.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecommerce.arn
    container_name   = "ecommerce"
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.ecommerce.arn
  }

  depends_on = [aws_lb_listener.http]

  tags = local.tags
}

resource "aws_appautoscaling_target" "auth_api" {
  max_capacity       = var.auth_api_max_count
  min_capacity       = var.auth_api_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.auth_api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "auth_api_cpu" {
  name               = "${local.name_prefix}-auth-api-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.auth_api.resource_id
  scalable_dimension = aws_appautoscaling_target.auth_api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.auth_api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.auth_api_cpu_target_utilization
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_policy" "auth_api_memory" {
  name               = "${local.name_prefix}-auth-api-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.auth_api.resource_id
  scalable_dimension = aws_appautoscaling_target.auth_api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.auth_api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.auth_api_memory_target_utilization
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_target" "product_api" {
  max_capacity       = var.product_api_max_count
  min_capacity       = var.product_api_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.product_api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "product_api_cpu" {
  name               = "${local.name_prefix}-product-api-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.product_api.resource_id
  scalable_dimension = aws_appautoscaling_target.product_api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.product_api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.product_api_cpu_target_utilization
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_policy" "product_api_memory" {
  name               = "${local.name_prefix}-product-api-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.product_api.resource_id
  scalable_dimension = aws_appautoscaling_target.product_api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.product_api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.product_api_memory_target_utilization
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_target" "gateway" {
  max_capacity       = var.gateway_max_count
  min_capacity       = var.gateway_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.gateway.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "gateway_cpu" {
  name               = "${local.name_prefix}-gateway-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.gateway.resource_id
  scalable_dimension = aws_appautoscaling_target.gateway.scalable_dimension
  service_namespace  = aws_appautoscaling_target.gateway.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.gateway_cpu_target_utilization
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_policy" "gateway_memory" {
  name               = "${local.name_prefix}-gateway-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.gateway.resource_id
  scalable_dimension = aws_appautoscaling_target.gateway.scalable_dimension
  service_namespace  = aws_appautoscaling_target.gateway.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.gateway_memory_target_utilization
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_policy" "gateway_requests" {
  name               = "${local.name_prefix}-gateway-requests"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.gateway.resource_id
  scalable_dimension = aws_appautoscaling_target.gateway.scalable_dimension
  service_namespace  = aws_appautoscaling_target.gateway.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.gateway.arn_suffix}"
    }

    target_value       = var.gateway_request_count_target
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_target" "ecommerce" {
  max_capacity       = var.ecommerce_max_count
  min_capacity       = var.ecommerce_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.ecommerce.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecommerce_cpu" {
  name               = "${local.name_prefix}-ecommerce-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecommerce.resource_id
  scalable_dimension = aws_appautoscaling_target.ecommerce.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecommerce.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.ecommerce_cpu_target_utilization
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_policy" "ecommerce_memory" {
  name               = "${local.name_prefix}-ecommerce-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecommerce.resource_id
  scalable_dimension = aws_appautoscaling_target.ecommerce.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecommerce.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.ecommerce_memory_target_utilization
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_policy" "ecommerce_requests" {
  name               = "${local.name_prefix}-ecommerce-requests"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecommerce.resource_id
  scalable_dimension = aws_appautoscaling_target.ecommerce.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecommerce.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.ecommerce.arn_suffix}"
    }

    target_value       = var.ecommerce_request_count_target
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_cloudwatch_dashboard" "operations" {
  dashboard_name = "${local.name_prefix}-operations"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ALB traffic and latency"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum" }],
            [".", "TargetResponseTime", ".", ".", { stat = "Average", yAxis = "right" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum" }],
            [".", "HTTPCode_ELB_5XX_Count", ".", ".", { stat = "Sum" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Healthy targets"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.gateway.arn_suffix, "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average" }],
            [".", ".", "TargetGroup", aws_lb_target_group.ecommerce.arn_suffix, "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average" }],
            [".", ".", "TargetGroup", aws_lb_target_group.grafana.arn_suffix, "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ECS CPU utilization"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.gateway.name, { stat = "Average" }],
            [".", ".", ".", ".", ".", aws_ecs_service.ecommerce.name, { stat = "Average" }],
            [".", ".", ".", ".", ".", aws_ecs_service.auth_api.name, { stat = "Average" }],
            [".", ".", ".", ".", ".", aws_ecs_service.product_api.name, { stat = "Average" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ECS memory utilization"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.gateway.name, { stat = "Average" }],
            [".", ".", ".", ".", ".", aws_ecs_service.ecommerce.name, { stat = "Average" }],
            [".", ".", ".", ".", ".", aws_ecs_service.auth_api.name, { stat = "Average" }],
            [".", ".", ".", ".", ".", aws_ecs_service.product_api.name, { stat = "Average" }]
          ]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  alarm_name          = "${local.name_prefix}-alb-target-5xx"
  alarm_description   = "Application target 5xx responses are above threshold"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.alb_target_5xx_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${local.name_prefix}-alb-response-time"
  alarm_description   = "ALB target response time is above threshold"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = var.alb_target_response_time_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.tags
}
