# ---------------------------------------------------------------------------
# VPC compartilhada por todo o projeto.
#
# - Subnets PÚBLICAS: nós do EKS (com IP público, para sair à internet sem NAT
#   Gateway, que custaria ~US$ 0,045/h no crédito limitado da Academy).
# - Subnets PRIVADAS: RDS (repo oficina-infra-db), NLB interno da API e VPC
#   Link do API Gateway. Nada nelas precisa de saída para a internet.
# ---------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.17"

  name = "${var.nome_cluster}-vpc"
  cidr = var.cidr_vpc

  azs             = local.zonas
  public_subnets  = [for i, _ in local.zonas : cidrsubnet(var.cidr_vpc, 8, i)]
  private_subnets = [for i, _ in local.zonas : cidrsubnet(var.cidr_vpc, 8, i + 10)]

  enable_nat_gateway      = false
  single_nat_gateway      = false
  map_public_ip_on_launch = true
  enable_dns_hostnames    = true
  enable_dns_support      = true

  # Tags que o cloud-controller do EKS usa para escolher subnets dos balanceadores.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.nome_cluster}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.nome_cluster}" = "shared"
  }
}
