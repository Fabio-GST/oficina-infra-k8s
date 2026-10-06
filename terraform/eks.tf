# ---------------------------------------------------------------------------
# Cluster EKS com node group gerenciado.
#
# Adaptações para o Learner Lab da AWS Academy:
# - create_iam_role = false em cluster e nós: usa a LabRole existente.
# - Sem KMS para criptografia de secrets e sem log group do control plane
#   (menos permissões necessárias, menos custo).
# - Nós em subnets públicas (sem NAT Gateway).
# ---------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.nome_cluster
  cluster_version = var.versao_kubernetes

  create_iam_role = false
  iam_role_arn    = data.aws_iam_role.lab.arn

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"

  create_kms_key              = false
  cluster_encryption_config   = {}
  create_cloudwatch_log_group = false
  cluster_enabled_log_types   = []

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.public_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  eks_managed_node_groups = {
    principal = {
      create_iam_role = false
      iam_role_arn    = data.aws_iam_role.lab.arn

      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.tipo_instancia]
      capacity_type  = "ON_DEMAND"

      min_size     = var.nos_minimo
      desired_size = var.nos_desejado
      max_size     = var.nos_maximo

      # Tags lidas pelo Cluster Autoscaler para descobrir o Auto Scaling Group.
      tags = {
        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${var.nome_cluster}" = "owned"
      }
    }
  }

  # Permite que o API Gateway (VPC Link) e o RDS conversem com os nós.
  node_security_group_additional_rules = {
    entrada_vpc = {
      description = "Trafego de dentro da VPC (NLB interno / VPC Link)"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      cidr_blocks = [var.cidr_vpc]
    }
  }

  tags = {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.nome_cluster}" = "owned"
  }
}
