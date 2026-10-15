# ---------------------------------------------------------------------------
# Observabilidade do cluster: New Relic `nri-bundle` (RFC 0004 do oficina-api).
#
# Instala no namespace `newrelic`:
# - newrelic-infrastructure + kube-state-metrics: CPU/memória por pod e nó,
#   réplicas do HPA, reinícios e estado dos pods (K8sPodSample, K8sNodeSample…);
# - nri-kube-events: eventos do cluster (CrashLoopBackOff, OOMKilled…);
# - newrelic-logging (Fluent Bit): stdout dos containers → Logs; as linhas JSON
#   da API já trazem trace.id/span.id, então o painel correlaciona log → trace;
# - nri-metadata-injection: injeta metadados do K8s nos traces do APM.
#
# Não precisa de IAM/IRSA: autentica só com a license key (variável sensível,
# TF_VAR_new_relic_license_key no CD). Componentes pesados (Prometheus agent,
# Pixie, metrics adapter) ficam desligados — os nós são t3.small.
# ---------------------------------------------------------------------------
resource "helm_release" "nri_bundle" {
  count = var.habilitar_new_relic ? 1 : 0

  name             = "nri-bundle"
  namespace        = "newrelic"
  create_namespace = true
  repository       = "https://helm-charts.newrelic.com"
  chart            = "nri-bundle"
  version          = "8.0.34"
  timeout          = 600

  set_sensitive {
    name  = "global.licenseKey"
    value = var.new_relic_license_key
  }

  set {
    name  = "global.cluster"
    value = var.nome_cluster
  }

  # Menos amostras e atributos: cabe no free tier (100 GB/mês) e nos nós pequenos.
  set {
    name  = "global.lowDataMode"
    value = "true"
  }

  set {
    name  = "newrelic-infrastructure.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-infrastructure.privileged"
    value = "true"
  }

  set {
    name  = "kube-state-metrics.enabled"
    value = "true"
  }

  set {
    name  = "nri-kube-events.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-logging.enabled"
    value = "true"
  }

  set {
    name  = "nri-metadata-injection.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-prometheus-agent.enabled"
    value = "false"
  }

  set {
    name  = "nri-prometheus.enabled"
    value = "false"
  }

  set {
    name  = "newrelic-pixie.enabled"
    value = "false"
  }

  set {
    name  = "pixie-chart.enabled"
    value = "false"
  }

  set {
    name  = "newrelic-k8s-metrics-adapter.enabled"
    value = "false"
  }

  set {
    name  = "k8s-agents-operator.enabled"
    value = "false"
  }

  lifecycle {
    precondition {
      condition     = var.new_relic_license_key != ""
      error_message = "habilitar_new_relic = true exige new_relic_license_key (TF_VAR_new_relic_license_key, secret NEW_RELIC_LICENSE_KEY no GitHub). Desligue com habilitar_new_relic = false."
    }
  }

  depends_on = [module.eks, helm_release.metrics_server]
}
