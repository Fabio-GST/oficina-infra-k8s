variable "regiao" {
  description = "Região AWS. O Learner Lab da AWS Academy libera us-east-1 (e às vezes us-west-2)."
  type        = string
  default     = "us-east-1"
}

variable "nome_cluster" {
  description = "Nome do cluster EKS."
  type        = string
  default     = "oficina"
}

variable "versao_kubernetes" {
  description = "Versão do Kubernetes do cluster EKS."
  type        = string
  default     = "1.31"
}

variable "nome_role_lab" {
  description = "Role IAM pré-existente do Learner Lab, usada pelo control plane e pelos nós (a Academy não permite criar roles)."
  type        = string
  default     = "LabRole"
}

variable "cidr_vpc" {
  description = "CIDR da VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "tipo_instancia" {
  description = "Tipo de instância dos nós. t3.small é o mínimo razoável para a API + agentes de observabilidade."
  type        = string
  default     = "t3.small"
}

variable "nos_minimo" {
  description = "Quantidade mínima de nós do node group."
  type        = number
  default     = 2
}

variable "nos_desejado" {
  description = "Quantidade inicial de nós do node group."
  type        = number
  default     = 2
}

variable "nos_maximo" {
  description = "Quantidade máxima de nós do node group (teto do autoescalonamento)."
  type        = number
  default     = 4
}

variable "ambientes" {
  description = "Ambientes hospedados no cluster. Cada um vira um namespace e, se habilitado, um API Gateway."
  type        = list(string)
  default     = ["hml", "prod"]
}

variable "habilitar_cluster_autoscaler" {
  description = "Instala o Cluster Autoscaler usando as permissões da role dos nós (LabRole). Desligue se o Learner Lab negar as chamadas de Auto Scaling."
  type        = bool
  default     = true
}

variable "habilitar_gateway" {
  description = "Cria o API Gateway por ambiente. Requer que a aplicação (repo oficina-api) já tenha criado o NLB via Service type=LoadBalancer; deixe false no primeiro apply."
  type        = bool
  default     = false
}

variable "namespace_prefixo" {
  description = "Prefixo dos namespaces da aplicação (ex.: oficina-hml, oficina-prod)."
  type        = string
  default     = "oficina"
}

variable "nome_service_api" {
  description = "Nome do Service Kubernetes da API (usado para localizar o NLB criado pelo cloud-controller via tag kubernetes.io/service-name)."
  type        = string
  default     = "oficina-api"
}
