terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }

  # Estado remoto compartilhado entre os desenvolvedores e o pipeline. O bucket
  # e a tabela são criados uma única vez no Learner Lab (ver README). Os valores
  # vêm de `-backend-config` (arquivo backend.hcl) para não fixar nomes aqui.
  backend "s3" {}
}

provider "aws" {
  region = var.regiao

  default_tags {
    tags = {
      projeto     = "oficina"
      repositorio = "oficina-infra-k8s"
      gerenciado  = "terraform"
    }
  }
}

# Os providers kubernetes/helm autenticam no cluster com um token gerado pela
# CLI da AWS (mesmas credenciais do provider aws), sem kubeconfig em disco.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.regiao]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.regiao]
    }
  }
}
