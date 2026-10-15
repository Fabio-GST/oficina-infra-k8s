# ---------------------------------------------------------------------------
# Componentes instalados no cluster via Helm.
# ---------------------------------------------------------------------------

# metrics-server: pré-requisito do HPA da aplicação (CPU/memória dos pods).
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.14.0"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  depends_on = [aws_eks_node_group.principal, aws_eks_addon.basicos]
}

# Cluster Autoscaler: aumenta/diminui o node group conforme pods pendentes.
# Sem IRSA (o Learner Lab não permite criar o OIDC provider), o autoscaler usa
# as permissões da LabRole dos próprios nós.
resource "helm_release" "cluster_autoscaler" {
  count = var.habilitar_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.59.0"

  set {
    name  = "autoDiscovery.clusterName"
    value = local.eks.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.regiao
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  depends_on = [aws_eks_node_group.principal, aws_eks_addon.basicos]
}
