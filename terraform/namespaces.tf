# Um namespace por ambiente no mesmo cluster (oficina-hml, oficina-prod). Dois
# clusters dobrariam o custo fixo do EKS no crédito da Academy; a separação por
# namespace mantém homologação e produção isoladas em rede lógica, quotas e
# configuração, e o CD do repo oficina-api escolhe o namespace pela branch.
resource "kubernetes_namespace_v1" "ambiente" {
  for_each = local.namespaces

  metadata {
    name = each.value

    labels = {
      "app.kubernetes.io/part-of" = "oficina"
      "oficina/ambiente"          = each.key
    }
  }

  depends_on = [module.eks]
}

# Teto de recursos por ambiente, para um ambiente não esgotar o cluster.
resource "kubernetes_resource_quota_v1" "ambiente" {
  for_each = local.namespaces

  metadata {
    name      = "quota-${each.key}"
    namespace = kubernetes_namespace_v1.ambiente[each.key].metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "2"
      "requests.memory" = "3Gi"
      "limits.cpu"      = "4"
      "limits.memory"   = "6Gi"
      "pods"            = "20"
    }
  }
}
