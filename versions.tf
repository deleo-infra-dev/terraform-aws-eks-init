################################################################################
# Terraform Providers Version
# 1) Terraform version
# 2) AWS provider version
# 3) Kubernetes provider version
# 4) Kubectl provider version
# 5) Helm provider version
# 6) Fake provider version
################################################################################
terraform {
  required_version = ">= 1.0" # Terraform version 1.0.0 or higher

  required_providers {
    aws = {
      source  = "hashicorp/aws" # AWS provider
      version = ">= 4.47"       # AWS provider version 4.47.0 or higher
    }
    kubernetes = {
      source  = "hashicorp/kubernetes" # Kubernetes provider
      version = ">= 2.20"              # Kubernetes provider version 2.20.0 or higher
    }
    kubectl = {
      source  = "gavinbunney/kubectl" # Kubectl provider
      version = ">= 1.14"             # Kubectl provider version 1.14.0 or higher
    }
    helm = {
      source  = "hashicorp/helm" # Helm provider
      version = ">= 2.9.0"       # Helm provider version 2.9.0 or higher
    }
    fake = {
      source  = "rayshoo/fake" # Fake provider
      version = "1.0.0"        # Fake provider version 1.0.0 or higher
    }
  }
}