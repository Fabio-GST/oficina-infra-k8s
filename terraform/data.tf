# Role pré-existente do Learner Lab. O laboratório bloqueia iam:CreateRole, então
# control plane, nós e (no repo oficina-auth-lambda) a Lambda usam esta role.
data "aws_iam_role" "lab" {
  name = var.nome_role_lab
}

data "aws_availability_zones" "disponiveis" {
  state = "available"

  # Zonas locais/wavelength não suportam EKS.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  # Duas zonas são suficientes para o EKS e para o subnet group do RDS.
  zonas = slice(data.aws_availability_zones.disponiveis.names, 0, 2)

  namespaces = { for amb in var.ambientes : amb => "${var.namespace_prefixo}-${amb}" }
}
