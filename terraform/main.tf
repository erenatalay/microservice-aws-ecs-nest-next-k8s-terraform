provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

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

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  public_app_url     = var.public_app_url != "" ? var.public_app_url : "http://${aws_lb.main.dns_name}"
  public_graphql_url = var.next_public_graphql_url != "" ? var.next_public_graphql_url : "${local.public_app_url}/graphql"
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
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Tier = "public"
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
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
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
  name               = replace(substr("${local.name_prefix}-alb", 0, 32), "_", "-")
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for s in aws_subnet.public : s.id]

  tags = local.tags
}

resource "aws_lb_target_group" "gateway" {
  name        = replace(substr("${local.name_prefix}-gtw", 0, 32), "_", "-")
  port        = 4000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

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
  name        = replace(substr("${local.name_prefix}-ecom", 0, 32), "_", "-")
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

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
    value = var.enable_container_insights ? "enabled" : "disabled"
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
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "API_PORT", value = "3001" },
        { name = "DATABASE_URL", value = var.auth_database_url },
        { name = "JWT_SECRET", value = var.jwt_secret },
        { name = "JWT_EXPIRES_IN", value = var.jwt_expires_in },
        { name = "JWT_ISSUER", value = var.jwt_issuer },
        { name = "JWT_AUDIENCE", value = var.jwt_audience },
        { name = "CORS_ORIGIN", value = local.public_app_url },
        { name = "CORS_ORIGIN_LOCAL", value = "http://localhost:3000" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "auth-api"
        }
      }
    }
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
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "API_PORT", value = "3002" },
        { name = "DATABASE_URL", value = var.product_database_url },
        { name = "AUTH_SERVICE_URL", value = "http://auth-api.${var.service_discovery_namespace}:3001" },
        { name = "JWT_ISSUER", value = var.jwt_issuer },
        { name = "JWT_AUDIENCE", value = var.jwt_audience },
        { name = "CORS_ORIGIN", value = local.public_app_url },
        { name = "CORS_ORIGIN_LOCAL", value = "http://localhost:3000" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "product-api"
        }
      }
    }
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
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "4000" },
        { name = "AUTH_GRAPHQL_URL", value = "http://auth-api.${var.service_discovery_namespace}:3001/api/graphql" },
        { name = "PRODUCT_GRAPHQL_URL", value = "http://product-api.${var.service_discovery_namespace}:3002/api/graphql" },
        { name = "GRAPHQL_POLL_INTERVAL", value = tostring(var.graphql_poll_interval_ms) }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "gateway"
        }
      }
    }
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
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "3000" },
        { name = "NEXT_PUBLIC_GRAPHQL_URL", value = local.public_graphql_url }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecommerce"
        }
      }
    }
  ])

  tags = local.tags
}

resource "aws_ecs_service" "auth_api" {
  name            = "${local.name_prefix}-auth-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.auth_api.arn
  desired_count   = var.auth_api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for s in aws_subnet.public : s.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.auth_api.arn
  }

  tags = local.tags
}

resource "aws_ecs_service" "product_api" {
  name            = "${local.name_prefix}-product-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.product_api.arn
  desired_count   = var.product_api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for s in aws_subnet.public : s.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.product_api.arn
  }

  depends_on = [aws_ecs_service.auth_api]

  tags = local.tags
}

resource "aws_ecs_service" "gateway" {
  name            = "${local.name_prefix}-gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.gateway.arn
  desired_count   = var.gateway_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for s in aws_subnet.public : s.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.gateway.arn
    container_name   = "gateway"
    container_port   = 4000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.gateway.arn
  }

  depends_on = [aws_lb_listener.http, aws_lb_listener_rule.gateway_api, aws_ecs_service.auth_api, aws_ecs_service.product_api]

  tags = local.tags
}

resource "aws_ecs_service" "ecommerce" {
  name            = "${local.name_prefix}-ecommerce"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ecommerce.arn
  desired_count   = var.ecommerce_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for s in aws_subnet.public : s.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
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
