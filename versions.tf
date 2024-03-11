terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.6.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "alekc/kubectl"
      version = "2.0.4"
    }
    template = {
      source = "hashicorp/template"
    }
  }
  required_version = ">= 1.2.5"
}
