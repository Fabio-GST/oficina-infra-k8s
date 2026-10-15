output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnets_publicas" {
  value = module.vpc.public_subnets
}

output "subnets_privadas" {
  value = module.vpc.private_subnets
}

output "cluster_nome" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "sg_nos" {
  description = "Security group dos nós — o RDS libera 3306 para ele."
  value       = module.eks.node_security_group_id
}

output "namespaces" {
  value = local.namespaces
}

output "gateway_urls" {
  description = "URL base do API Gateway por ambiente (vazio até habilitar_gateway = true)."
  value       = { for amb in local.ambientes_gateway : amb => aws_apigatewayv2_api.api[amb].api_endpoint }
}

output "comando_kubeconfig" {
  value = "aws eks update-kubeconfig --region ${var.regiao} --name ${module.eks.cluster_name}"
}
