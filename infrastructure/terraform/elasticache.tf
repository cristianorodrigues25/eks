# ===========================================
# ElastiCache Redis para Laravel Cache/Session
# ===========================================

# Subnet group para ElastiCache
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.cluster_name}-redis-subnet"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name        = "${var.cluster_name}-redis-subnet-group"
    Environment = var.environment
  }
}

# Parameter group para Redis
resource "aws_elasticache_parameter_group" "redis" {
  family = "redis7"
  name   = "${var.cluster_name}-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  parameter {
    name  = "tcp-keepalive"
    value = "60"
  }

  tags = {
    Name        = "${var.cluster_name}-redis-params"
    Environment = var.environment
  }
}

# ElastiCache Replication Group (Redis Cluster Mode Disabled)
resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.cluster_name}-redis"
  description                = "Redis cluster for Laravel application"

  # Engine configuration
  engine               = "redis"
  engine_version       = var.redis_config.engine_version
  port                = var.redis_config.port
  parameter_group_name = aws_elasticache_parameter_group.redis.name

  # Node configuration
  node_type            = var.redis_config.node_type
  num_cache_clusters   = var.redis_config.num_cache_nodes

  # Network configuration
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  # High availability
  automatic_failover_enabled = true
  multi_az_enabled          = true

  # Backup configuration
  snapshot_retention_limit = 5
  snapshot_window         = "03:00-05:00"
  maintenance_window      = "sun:05:00-sun:07:00"

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                = random_password.redis_auth.result

  # Notifications
  notification_topic_arn = aws_sns_topic.cache_notifications.arn

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type        = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type        = "engine-log"
  }

  tags = {
    Name        = "${var.cluster_name}-redis"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [engine_version]
  }
}

# ===========================================
# CloudWatch Log Groups for Redis
# ===========================================

resource "aws_cloudwatch_log_group" "redis_slow_log" {
  name              = "/aws/elasticache/${var.cluster_name}/redis/slow-log"
  retention_in_days = 7

  tags = {
    Name        = "${var.cluster_name}-redis-slow-log"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "redis_engine_log" {
  name              = "/aws/elasticache/${var.cluster_name}/redis/engine-log"
  retention_in_days = 7

  tags = {
    Name        = "${var.cluster_name}-redis-engine-log"
    Environment = var.environment
  }
}

# ===========================================
# Random password for Redis AUTH
# ===========================================

resource "random_password" "redis_auth" {
  length  = 32
  special = false  # Redis AUTH doesn't support special characters
}

# ===========================================
# Secrets Manager para Redis credentials
# ===========================================

resource "aws_secretsmanager_secret" "redis" {
  name                    = "${var.cluster_name}-redis-credentials"
  recovery_window_in_days = 30

  tags = {
    Name        = "${var.cluster_name}-redis-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    primary_endpoint   = aws_elasticache_replication_group.main.primary_endpoint_address
    reader_endpoint    = aws_elasticache_replication_group.main.reader_endpoint_address
    port              = var.redis_config.port
    auth_token        = random_password.redis_auth.result
    connection_string = "redis://:${random_password.redis_auth.result}@${aws_elasticache_replication_group.main.primary_endpoint_address}:${var.redis_config.port}"
  })
}

# ===========================================
# SNS Topic for ElastiCache notifications
# ===========================================

resource "aws_sns_topic" "cache_notifications" {
  name = "${var.cluster_name}-cache-notifications"

  tags = {
    Name        = "${var.cluster_name}-cache-notifications"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "cache_email" {
  count = var.environment == "production" ? 1 : 0

  topic_arn = aws_sns_topic.cache_notifications.arn
  protocol  = "email"
  endpoint  = "devops@exemplo.com"  # Substituir pelo email real
}

# ===========================================
# CloudWatch Alarms for Redis
# ===========================================

resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${var.cluster_name}-redis-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "CPUUtilization"
  namespace          = "AWS/ElastiCache"
  period             = "300"
  statistic          = "Average"
  threshold          = "75"
  alarm_description  = "This metric monitors Redis CPU utilization"
  alarm_actions      = [aws_sns_topic.cache_notifications.arn]

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }

  tags = {
    Name        = "${var.cluster_name}-redis-cpu-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${var.cluster_name}-redis-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "DatabaseMemoryUsagePercentage"
  namespace          = "AWS/ElastiCache"
  period             = "300"
  statistic          = "Average"
  threshold          = "80"
  alarm_description  = "This metric monitors Redis memory usage"
  alarm_actions      = [aws_sns_topic.cache_notifications.arn]

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }

  tags = {
    Name        = "${var.cluster_name}-redis-memory-alarm"
    Environment = var.environment
  }
}