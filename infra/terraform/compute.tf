resource "aws_ecs_cluster" "main" {
  name = "nearby-${var.environment}"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_ecr_repository" "api" {
  name = "nearby-connect-api"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}
resource "aws_ecr_repository" "admin" {
  name = "nearby-connect-admin"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/nearby-${var.environment}/api"
  retention_in_days = 30
}
resource "aws_cloudwatch_log_group" "admin" {
  name              = "/ecs/nearby-${var.environment}/admin"
  retention_in_days = 30
}
resource "aws_lb" "main" {
  name                       = "nearby-${var.environment}"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = values(aws_subnet.public)[*].id
  enable_deletion_protection = true
}
resource "aws_lb_target_group" "api" {
  name        = "nearby-${var.environment}-api"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path    = "/api/v1/health/ready"
    matcher = "200"
  }
  stickiness {
    type            = "lb_cookie"
    enabled         = true
    cookie_duration = 86400
  }
}
resource "aws_lb_target_group" "admin" {
  name        = "nearby-${var.environment}-admin"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path    = "/login"
    matcher = "200-399"
  }
}
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.admin.arn
  }
}
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
  condition {
    path_pattern {
      values = ["/api/*", "/socket.io/*", "/docs*"]
    }
  }
}
resource "aws_secretsmanager_secret" "runtime" {
  name = "nearby/${var.environment}/runtime"
}
resource "aws_secretsmanager_secret_version" "runtime" {
  secret_id = aws_secretsmanager_secret.runtime.id
  secret_string = jsonencode({
    DATABASE_URL = "postgresql://${aws_db_instance.postgres.username}:${random_password.database.result}@${aws_db_instance.postgres.address}:5432/${aws_db_instance.postgres.db_name}?schema=public&sslmode=require", REDIS_URL = "rediss://:${random_password.redis.result}@${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379", JWT_ACCESS_SECRET = var.jwt_access_secret, JWT_REFRESH_SECRET = var.jwt_refresh_secret, STRIPE_SECRET_KEY = var.stripe_secret_key, STRIPE_WEBHOOK_SECRET = var.stripe_webhook_secret, STRIPE_PREMIUM_PRICE_ID = var.stripe_premium_price_id, GOOGLE_CLIENT_ID = var.google_client_id, APPLE_CLIENT_ID = var.apple_client_id, SMTP_HOST = var.smtp_host, SMTP_PORT = tostring(var.smtp_port), SMTP_USER = var.smtp_user, SMTP_PASSWORD = var.smtp_password, SMTP_FROM = var.smtp_from, FIREBASE_PROJECT_ID = var.firebase_project_id, FIREBASE_CLIENT_EMAIL = var.firebase_client_email, FIREBASE_PRIVATE_KEY = var.firebase_private_key
  })
}
resource "aws_iam_role" "ecs_execution" {
  name = "nearby-${var.environment}-ecs-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy" "secrets" {
  role = aws_iam_role.ecs_execution.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = [aws_secretsmanager_secret.runtime.arn]
    }]
  })
}
resource "aws_iam_role" "ecs_task" {
  name               = "nearby-${var.environment}-ecs-task"
  assume_role_policy = aws_iam_role.ecs_execution.assume_role_policy
}
resource "aws_iam_role_policy" "media" {
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["s3:PutObject", "s3:HeadObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.media.arn}/*"
    }]
  })
}
locals {
  common_environment = [{
    name = "NODE_ENV", value = "production"
    }, {
    name = "API_PORT", value = "3000"
    }, {
    name = "APP_ORIGINS", value = "https://${var.domain_name}"
    }, {
    name = "S3_BUCKET", value = aws_s3_bucket.media.id
    }, {
    name = "S3_REGION", value = var.aws_region
    }, {
    name = "CLOUDFRONT_DOMAIN", value = aws_cloudfront_distribution.media.domain_name
  }]
}
resource "aws_ecs_task_definition" "api" {
  family                   = "nearby-${var.environment}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  container_definitions = jsonencode([{
    name = "api", image = var.api_image, essential = true, portMappings = [{
      containerPort = 3000
      }], environment = local.common_environment, secrets = [for key in ["DATABASE_URL", "REDIS_URL", "JWT_ACCESS_SECRET", "JWT_REFRESH_SECRET", "STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET", "STRIPE_PREMIUM_PRICE_ID", "GOOGLE_CLIENT_ID", "APPLE_CLIENT_ID", "SMTP_HOST", "SMTP_PORT", "SMTP_USER", "SMTP_PASSWORD", "SMTP_FROM", "FIREBASE_PROJECT_ID", "FIREBASE_CLIENT_EMAIL", "FIREBASE_PRIVATE_KEY"] : {
      name = key, valueFrom = "${aws_secretsmanager_secret.runtime.arn}:${key}::"
      }], logConfiguration = {
      logDriver = "awslogs", options = {
        "awslogs-group" = aws_cloudwatch_log_group.api.name, "awslogs-region" = var.aws_region, "awslogs-stream-prefix" = "api"
      }
    }
  }])
}
resource "aws_ecs_task_definition" "admin" {
  family                   = "nearby-${var.environment}-admin"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  container_definitions = jsonencode([{
    name = "admin", image = var.admin_image, essential = true, portMappings = [{
      containerPort = 3001
      }], environment = [{
      name = "API_INTERNAL_URL", value = "https://${var.domain_name}/api/v1"
      }, {
      name = "NEXT_PUBLIC_API_URL", value = "https://${var.domain_name}/api/v1"
      }], logConfiguration = {
      logDriver = "awslogs", options = {
        "awslogs-group" = aws_cloudwatch_log_group.admin.name, "awslogs-region" = var.aws_region, "awslogs-stream-prefix" = "admin"
      }
    }
  }])
}
resource "aws_ecs_service" "api" {
  name                   = "api"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.api.arn
  desired_count          = var.api_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true
  network_configuration {
    subnets          = values(aws_subnet.private)[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 3000
  }
  lifecycle {
    ignore_changes = [task_definition]
  }
}
resource "aws_ecs_service" "admin" {
  name            = "admin"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.admin.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = values(aws_subnet.private)[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.admin.arn
    container_name   = "admin"
    container_port   = 3001
  }
  lifecycle {
    ignore_changes = [task_definition]
  }
}
resource "aws_appautoscaling_target" "api" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "api-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
