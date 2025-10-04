# ===========================================
# RDS Aurora MySQL Serverless
# ===========================================

# Subnet group para RDS
resource "aws_db_subnet_group" "main" {
  name       = "${var.cluster_name}-db-subnet"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name        = "${var.cluster_name}-db-subnet-group"
    Environment = var.environment
  }
}

# Random password para RDS
resource "random_password" "rds" {
  length  = 32
  special = true
}

# Parameter group para Aurora MySQL
resource "aws_rds_cluster_parameter_group" "main" {
  family = "aurora-mysql8.0"
  name   = "${var.cluster_name}-aurora-params"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = "1000"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  tags = {
    Name        = "${var.cluster_name}-aurora-params"
    Environment = var.environment
  }
}

# RDS Aurora Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.cluster_name}-aurora-cluster"

  # Engine configuration
  engine                  = "aurora-mysql"
  engine_version          = var.rds_config.engine_version
  engine_mode             = "provisioned"

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    max_capacity = 2
    min_capacity = 0.5
  }

  # Database configuration
  database_name   = "laravel"
  master_username = "admin"
  master_password = random_password.rds.result

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Parameter group
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name

  # Backup configuration
  backup_retention_period = var.rds_config.backup_retention
  preferred_backup_window = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Encryption
  storage_encrypted = var.rds_config.storage_encrypted
  kms_key_id       = aws_kms_key.rds.arn

  # Final snapshot
  skip_final_snapshot       = var.rds_config.skip_final_snapshot
  final_snapshot_identifier = var.rds_config.skip_final_snapshot ? null : "${var.cluster_name}-aurora-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Enhanced monitoring
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  tags = {
    Name        = "${var.cluster_name}-aurora-cluster"
    Environment = var.environment
  }
}

# RDS Aurora Instance
resource "aws_rds_cluster_instance" "main" {
  count = 2  # Multi-AZ para alta disponibilidade

  identifier          = "${var.cluster_name}-aurora-instance-${count.index + 1}"
  cluster_identifier  = aws_rds_cluster.main.id

  # Instance configuration
  instance_class = "db.serverless"
  engine         = aws_rds_cluster.main.engine
  engine_version = aws_rds_cluster.main.engine_version

  # Monitoring
  performance_insights_enabled = true
  monitoring_interval         = 60
  monitoring_role_arn        = aws_iam_role.rds_enhanced_monitoring.arn

  tags = {
    Name        = "${var.cluster_name}-aurora-instance-${count.index + 1}"
    Environment = var.environment
  }
}

# ===========================================
# KMS Key para RDS
# ===========================================

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS cluster ${var.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.cluster_name}-rds-kms"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.cluster_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ===========================================
# IAM Role para Enhanced Monitoring
# ===========================================

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.cluster_name}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-rds-monitoring-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ===========================================
# Secrets Manager para credenciais RDS
# ===========================================

resource "aws_secretsmanager_secret" "rds" {
  name                    = "${var.cluster_name}-rds-credentials"
  recovery_window_in_days = 30

  tags = {
    Name        = "${var.cluster_name}-rds-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = aws_rds_cluster.main.master_username
    password = random_password.rds.result
    engine   = "mysql"
    host     = aws_rds_cluster.main.endpoint
    port     = 3306
    dbname   = aws_rds_cluster.main.database_name
  })
}