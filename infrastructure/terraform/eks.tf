# ===========================================
# EKS Cluster
# ===========================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # Networking
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Cluster endpoint access
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Cluster addons (essenciais apenas)
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Node groups configuration (simplificado)
  eks_managed_node_groups = {
    main = {
      name = "${var.cluster_name}-ng"

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      min_size     = 2
      max_size     = 4
      desired_size = 2

      disk_size = 50

      labels = {
        Environment = var.environment
      }

      tags = {
        Name = "${var.cluster_name}-node-group"
      }
    }
  }

  # Cluster security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # CloudWatch Log Groups (opcional - desabilitado para simplificar)
  cluster_enabled_log_types = []

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
  }
}

# ===========================================
# IAM OIDC Provider já é criado automaticamente pelo módulo EKS
# ===========================================

# ===========================================
# Cluster Autoscaler IAM Role
# ===========================================

module "cluster_autoscaler_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                        = "${var.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = {
    Name        = "${var.cluster_name}-cluster-autoscaler-role"
    Environment = var.environment
  }
}

# ===========================================
# EBS CSI Driver IAM Role (Removido - usando gp2 in-tree)
# ===========================================

# module "ebs_csi_irsa_role" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version = "~> 5.0"
#
#   role_name             = "${var.cluster_name}-ebs-csi-controller"
#   attach_ebs_csi_policy = true
#
#   oidc_providers = {
#     ex = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
#     }
#   }
#
#   tags = {
#     Name        = "${var.cluster_name}-ebs-csi-role"
#     Environment = var.environment
#   }
# }

# ===========================================
# AWS Load Balancer Controller IAM Role
# ===========================================

module "load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${var.cluster_name}-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Name        = "${var.cluster_name}-lb-controller-role"
    Environment = var.environment
  }
}