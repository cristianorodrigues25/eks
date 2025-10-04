variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Ambiente (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
  default     = "laravel-eks"
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block para VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "CIDR blocks para subnets privadas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "CIDR blocks para subnets públicas"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "node_group_config" {
  description = "Configuração do node group"
  type = object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    disk_size      = number
  })
  default = {
    desired_size   = 3
    min_size       = 2
    max_size       = 5
    instance_types = ["t3.medium"]
    disk_size      = 50
  }
}

variable "rds_config" {
  description = "Configuração do RDS Aurora"
  type = object({
    engine_version      = string
    instance_class      = string
    allocated_storage   = number
    storage_encrypted   = bool
    backup_retention    = number
    skip_final_snapshot = bool
  })
  default = {
    engine_version      = "8.0.mysql_aurora.3.04.0"
    instance_class      = "db.t3.medium"
    allocated_storage   = 20
    storage_encrypted   = true
    backup_retention    = 7
    skip_final_snapshot = false
  }
}

variable "redis_config" {
  description = "Configuração do ElastiCache Redis"
  type = object({
    node_type       = string
    num_cache_nodes = number
    engine_version  = string
    port            = number
  })
  default = {
    node_type       = "cache.t3.micro"
    num_cache_nodes = 2
    engine_version  = "7.0"
    port            = 6379
  }
}

variable "enable_monitoring" {
  description = "Habilitar stack de monitoramento (Prometheus, Grafana)"
  type        = bool
  default     = true
}

variable "enable_autoscaling" {
  description = "Habilitar autoscaling no cluster"
  type        = bool
  default     = true
}

variable "enable_ingress" {
  description = "Habilitar NGINX Ingress Controller"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Nome do domínio para aplicação"
  type        = string
  default     = "laravel-app.exemplo.com"
}

variable "certificate_arn" {
  description = "ARN do certificado SSL no ACM"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags adicionais para recursos"
  type        = map(string)
  default     = {}
}