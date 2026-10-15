# ---------------------------------------------------------------------------
# Cluster EKS com node group gerenciado, em recursos nativos (sem o módulo
# terraform-aws-modules/eks).
#
# Por que sem o módulo: ele resolve a identidade do executor com
# `data "aws_iam_session_context"`, que chama iam:GetRole na role `voclabs` do
# Learner Lab — negada explicitamente pela política do laboratório. Os recursos
# nativos não precisam dessa chamada.
#
# Adaptações ao Learner Lab da AWS Academy:
# - Cluster e nós usam a LabRole existente (o lab não cria roles IAM).
# - bootstrap_cluster_creator_admin_permissions = true: a própria API do EKS dá
#   admin ao executor (role voclabs), sem GetRole; o pipeline e o grupo usam a
#   mesma role, então kubectl funciona para todos.
# - Sem KMS para secrets e sem logs do control plane (menos permissões e custo).
# - Nós em subnets públicas (sem NAT Gateway).
# ---------------------------------------------------------------------------
resource "aws_eks_cluster" "oficina" {
  name     = var.nome_cluster
  version  = var.versao_kubernetes
  role_arn = data.aws_iam_role.lab.arn

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = module.vpc.public_subnets
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  upgrade_policy {
    support_type = "STANDARD"
  }

  tags = {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.nome_cluster}" = "owned"
  }

  depends_on = [module.vpc]
}

# Permite que o API Gateway (VPC Link), o NLB interno e o RDS conversem com os
# nós, que usam o security group primário do cluster.
resource "aws_vpc_security_group_ingress_rule" "nos_entrada_vpc" {
  security_group_id = aws_eks_cluster.oficina.vpc_config[0].cluster_security_group_id
  description       = "Trafego de dentro da VPC (NLB interno / VPC Link)"
  cidr_ipv4         = var.cidr_vpc
  ip_protocol       = "-1"
}

resource "aws_eks_addon" "basicos" {
  for_each = toset(["coredns", "kube-proxy", "vpc-cni"])

  cluster_name                = aws_eks_cluster.oficina.name
  addon_name                  = each.key
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # coredns só fica saudável com nós; os demais podem vir antes.
  depends_on = [aws_eks_node_group.principal]
}

resource "aws_eks_node_group" "principal" {
  cluster_name    = aws_eks_cluster.oficina.name
  node_group_name = "principal"
  node_role_arn   = data.aws_iam_role.lab.arn
  subnet_ids      = module.vpc.public_subnets

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = [var.tipo_instancia]
  capacity_type  = "ON_DEMAND"
  disk_size      = 20

  scaling_config {
    min_size     = var.nos_minimo
    desired_size = var.nos_desejado
    max_size     = var.nos_maximo
  }

  update_config {
    max_unavailable = 1
  }

  # O EKS propaga automaticamente ao Auto Scaling Group as tags
  # k8s.io/cluster-autoscaler/enabled e k8s.io/cluster-autoscaler/<cluster>,
  # que o Cluster Autoscaler usa para descobrir o grupo.
  tags = {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.nome_cluster}" = "owned"
  }

  lifecycle {
    # O autoscaler altera o desired_size em tempo de execução.
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# Interface estável para os demais arquivos (antes exposta pelo módulo).
locals {
  eks = {
    cluster_name                       = aws_eks_cluster.oficina.name
    cluster_endpoint                   = aws_eks_cluster.oficina.endpoint
    cluster_certificate_authority_data = aws_eks_cluster.oficina.certificate_authority[0].data
    cluster_security_group_id          = aws_eks_cluster.oficina.vpc_config[0].cluster_security_group_id
    # Node groups gerenciados sem launch template usam o SG primário do cluster.
    node_security_group_id = aws_eks_cluster.oficina.vpc_config[0].cluster_security_group_id
  }
}
