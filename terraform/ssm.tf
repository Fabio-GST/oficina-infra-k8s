# ---------------------------------------------------------------------------
# Contrato com os outros repositórios: tudo que eles precisam saber desta
# infraestrutura é publicado no SSM Parameter Store, sem acoplar os states.
#
#   oficina-infra-db   lê vpc/id, vpc/subnets-privadas, eks/sg-nos
#   oficina-api        lê eks/nome, <amb>/namespace, <amb>/gateway/url
#   oficina-auth-lambda lê vpc/*, <amb>/gateway/id
# ---------------------------------------------------------------------------
locals {
  parametros_base = {
    "/oficina/vpc/id"               = module.vpc.vpc_id
    "/oficina/vpc/cidr"             = var.cidr_vpc
    "/oficina/vpc/subnets-publicas" = join(",", module.vpc.public_subnets)
    "/oficina/vpc/subnets-privadas" = join(",", module.vpc.private_subnets)
    "/oficina/eks/nome"             = local.eks.cluster_name
    "/oficina/eks/endpoint"         = local.eks.cluster_endpoint
    "/oficina/eks/sg-nos"           = local.eks.node_security_group_id
    "/oficina/eks/sg-cluster"       = local.eks.cluster_security_group_id
    "/oficina/iam/lab-role-arn"     = data.aws_iam_role.lab.arn
  }

  parametros_namespaces = {
    for amb, ns in local.namespaces : "/oficina/${amb}/namespace" => ns
  }

  parametros_gateway = merge(
    { for amb in local.ambientes_gateway : "/oficina/${amb}/gateway/id" => aws_apigatewayv2_api.api[amb].id },
    { for amb in local.ambientes_gateway : "/oficina/${amb}/gateway/url" => aws_apigatewayv2_api.api[amb].api_endpoint },
    { for amb in local.ambientes_gateway : "/oficina/${amb}/gateway/vpc-link-id" => aws_apigatewayv2_vpc_link.api[amb].id },
  )
}

resource "aws_ssm_parameter" "infra" {
  for_each = merge(local.parametros_base, local.parametros_namespaces, local.parametros_gateway)

  name  = each.key
  type  = "String"
  value = each.value
}
