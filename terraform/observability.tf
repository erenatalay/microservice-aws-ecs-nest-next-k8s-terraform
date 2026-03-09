locals {
  loki_s3_bucket_name = trimsuffix(
    substr(
      lower(
        replace(
          "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-loki",
          "_",
          "-"
        )
      ),
      0,
      63
    ),
    "-"
  )

  firelens_remove_keys = "container_id,container_name,ecs_cluster,ecs_task_arn,ecs_task_definition,source"

  firelens_log_router_container = {
    name      = "log-router"
    image     = var.fluent_bit_image
    essential = true
    firelensConfiguration = {
      type = "fluentbit"
      options = {
        "enable-ecs-log-metadata" = "true"
      }
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "firelens"
      }
    }
  }

  loki_config = <<-EOT
    auth_enabled: false
    server:
      http_listen_port: 3100
    common:
      path_prefix: /tmp/loki
      replication_factor: 1
      ring:
        kvstore:
          store: inmemory
    schema_config:
      configs:
        - from: 2024-01-01
          store: tsdb
          object_store: s3
          schema: v13
          index:
            prefix: index_
            period: 24h
    storage_config:
      tsdb_shipper:
        active_index_directory: /tmp/loki/index
        cache_location: /tmp/loki/index_cache
      aws:
        s3: s3://${var.aws_region}/${aws_s3_bucket.loki.bucket}
    compactor:
      working_directory: /tmp/loki/compactor
      compaction_interval: 10m
      retention_enabled: true
      delete_request_store: s3
    limits_config:
      retention_period: ${var.loki_retention_period}
      ingestion_rate_mb: ${var.loki_ingestion_rate_mb}
      ingestion_burst_size_mb: ${var.loki_ingestion_burst_size_mb}
      max_cache_freshness_per_query: 10m
      max_query_series: 10000
    query_range:
      align_queries_with_step: true
      cache_results: false
  EOT
}

resource "aws_s3_bucket" "loki" {
  bucket = local.loki_s3_bucket_name

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-loki"
  })
}

resource "aws_s3_bucket_versioning" "loki" {
  bucket = aws_s3_bucket.loki.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "loki" {
  bucket = aws_s3_bucket.loki.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    id     = "expire-old-loki-objects"
    status = "Enabled"

    filter {}

    expiration {
      days = var.loki_s3_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.loki_s3_retention_days
    }
  }
}

resource "aws_security_group" "grafana_efs" {
  name        = "${local.name_prefix}-grafana-efs-sg"
  description = "Grafana EFS security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from ECS tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_efs_file_system" "grafana" {
  encrypted = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-grafana"
  })
}

resource "aws_efs_access_point" "grafana" {
  file_system_id = aws_efs_file_system.grafana.id

  posix_user {
    gid = 472
    uid = 472
  }

  root_directory {
    path = "/grafana"

    creation_info {
      owner_gid   = 472
      owner_uid   = 472
      permissions = "0775"
    }
  }

  tags = local.tags
}

resource "aws_efs_mount_target" "grafana" {
  count = length(aws_subnet.private)

  file_system_id  = aws_efs_file_system.grafana.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.grafana_efs.id]
}

resource "aws_iam_role_policy" "ecs_task_loki_s3" {
  name = "${local.name_prefix}-loki-s3"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = aws_s3_bucket.loki.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListMultipartUploadParts",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.loki.arn}/*"
      }
    ]
  })
}

resource "aws_service_discovery_service" "loki" {
  name = "loki"

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

resource "aws_service_discovery_service" "grafana" {
  name = "grafana"

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

resource "aws_lb_target_group" "grafana" {
  name                          = replace(substr("${local.name_prefix}-grafana", 0, 32), "_", "-")
  port                          = 3000
  protocol                      = "HTTP"
  target_type                   = "ip"
  vpc_id                        = aws_vpc.main.id
  deregistration_delay          = 30
  load_balancing_algorithm_type = "least_outstanding_requests"

  health_check {
    path                = "/grafana/api/health"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 20
  }

  tags = local.tags
}

resource "aws_lb_listener_rule" "grafana" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  condition {
    path_pattern {
      values = ["/grafana", "/grafana/*"]
    }
  }
}

resource "aws_ecs_task_definition" "loki" {
  family                   = "${local.name_prefix}-loki"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.loki_cpu
  memory                   = var.loki_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "loki"
      image     = var.loki_image
      essential = true
      portMappings = [
        {
          containerPort = 3100
          hostPort      = 3100
          protocol      = "tcp"
        }
      ]
      entryPoint = ["/bin/sh", "-euc"]
      command = [
        <<-CMD
        cat > /tmp/loki-config.yaml <<'EOF'
        ${local.loki_config}
        EOF
        exec /usr/bin/loki -config.file=/tmp/loki-config.yaml
        CMD
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "loki"
        }
      }
    }
  ])

  tags = local.tags
}

resource "aws_ecs_task_definition" "grafana" {
  family                   = "${local.name_prefix}-grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.grafana_cpu
  memory                   = var.grafana_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  volume {
    name = "grafana-data"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.grafana.id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.grafana.id
        iam             = "DISABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = var.grafana_image
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "grafana-data"
          containerPath = "/var/lib/grafana"
          readOnly      = false
        }
      ]
      environment = [
        { name = "GF_PATHS_PROVISIONING", value = "/var/lib/grafana/provisioning" },
        { name = "GF_SECURITY_ADMIN_USER", value = var.grafana_admin_user },
        { name = "GF_SECURITY_ADMIN_PASSWORD", value = var.grafana_admin_password },
        { name = "GF_SERVER_ROOT_URL", value = "${local.public_app_url}/grafana/" },
        { name = "GF_SERVER_SERVE_FROM_SUB_PATH", value = "true" },
        { name = "GF_USERS_ALLOW_SIGN_UP", value = "false" }
      ]
      entryPoint = ["/bin/sh", "-euc"]
      command = [
        <<-CMD
        mkdir -p /var/lib/grafana/provisioning/datasources
        cat > /var/lib/grafana/provisioning/datasources/loki.yaml <<'EOF'
        apiVersion: 1
        datasources:
          - name: Loki
            type: loki
            access: proxy
            url: http://loki.${var.service_discovery_namespace}:3100
            isDefault: true
            jsonData:
              maxLines: 5000
        EOF
        exec /run.sh
        CMD
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "grafana"
        }
      }
    }
  ])

  tags = local.tags
}

resource "aws_ecs_service" "loki" {
  name                               = "${local.name_prefix}-loki"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.loki.arn
  desired_count                      = var.loki_desired_count
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
    registry_arn = aws_service_discovery_service.loki.arn
  }

  tags = local.tags
}

resource "aws_ecs_service" "grafana" {
  name                               = "${local.name_prefix}-grafana"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.grafana.arn
  desired_count                      = var.grafana_desired_count
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
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.grafana.arn
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener_rule.grafana,
    aws_ecs_service.loki,
    aws_efs_mount_target.grafana
  ]

  tags = local.tags
}
