# ===========================================
# Outputs
# ===========================================

# EKS Cluster
output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID do cluster EKS"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN do cluster EKS"
  value       = module.eks.cluster_iam_role_arn
}

# VPC
output "vpc_id" {
  description = "ID da VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "IDs das subnets privadas"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "IDs das subnets públicas"
  value       = module.vpc.public_subnets
}

# IAM Roles
# output "ebs_csi_role_arn" {
#   description = "IAM role ARN para EBS CSI Driver"
#   value       = module.ebs_csi_irsa_role.iam_role_arn
# }

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN para Cluster Autoscaler"
  value       = module.cluster_autoscaler_irsa_role.iam_role_arn
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN para AWS Load Balancer Controller"
  value       = module.load_balancer_controller_irsa_role.iam_role_arn
}

# Comandos úteis
output "update_kubeconfig_command" {
  description = "Comando para atualizar kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "get_token_command" {
  description = "Comando para obter token de autenticação"
  value       = "aws eks get-token --cluster-name ${module.eks.cluster_name}"
}